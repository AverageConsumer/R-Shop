import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/config/provider_config.dart';
import '../models/game_item.dart';
import '../models/ra_models.dart';
import '../utils/ra_name_matcher.dart';

class DatabaseService {
  static Future<Database>? _initFuture;
  static const String _tableName = 'games';
  static const int _dbVersion = 7;

  @visibleForTesting
  static Database? testDatabase;

  Future<Database> get database {
    if (testDatabase != null) return Future.value(testDatabase!);
    return _initFuture ??= _initDatabase();
  }

  @visibleForTesting
  static void resetForTesting() {
    _initFuture = null;
    testDatabase = null;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'rshop.db');

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        systemSlug TEXT NOT NULL,
        filename TEXT NOT NULL,
        displayName TEXT NOT NULL,
        url TEXT NOT NULL,
        region TEXT,
        cover_url TEXT,
        provider_config TEXT,
        thumb_hash TEXT,
        has_thumbnail INTEGER NOT NULL DEFAULT 0,
        is_folder INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_systemSlug ON $_tableName (systemSlug)
    ''');

    await db.execute('''
      CREATE INDEX idx_displayName ON $_tableName (displayName)
    ''');

    await db.execute('''
      CREATE INDEX idx_filename ON $_tableName (filename)
    ''');

    // RetroAchievements tables
    await db.execute('''
      CREATE TABLE ra_games (
        ra_game_id INTEGER PRIMARY KEY,
        console_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        num_achievements INTEGER NOT NULL DEFAULT 0,
        points INTEGER NOT NULL DEFAULT 0,
        image_icon TEXT,
        normalized_title TEXT NOT NULL,
        last_updated INTEGER NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_ra_games_console ON ra_games(console_id)');
    await db.execute(
        'CREATE INDEX idx_ra_games_norm_title ON ra_games(normalized_title)');
    await db.execute('''
      CREATE TABLE ra_hashes (
        hash TEXT PRIMARY KEY,
        ra_game_id INTEGER NOT NULL,
        rom_name TEXT
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_ra_hashes_game ON ra_hashes(ra_game_id)');
    await db.execute('''
      CREATE TABLE ra_matches (
        game_filename TEXT NOT NULL,
        system_slug TEXT NOT NULL,
        ra_game_id INTEGER,
        match_type TEXT NOT NULL,
        is_mastered INTEGER NOT NULL DEFAULT 0,
        last_updated INTEGER NOT NULL,
        PRIMARY KEY (game_filename, system_slug)
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Each migration step is wrapped in a transaction so a partial failure
    // (e.g. disk full) doesn't leave the DB in a half-migrated state.
    // Note: SQLite DDL (ALTER TABLE) is transactional in SQLite.
    if (oldVersion < 2) {
      await db.transaction((txn) async {
        await txn.execute('ALTER TABLE $_tableName ADD COLUMN cover_url TEXT');
        await txn.execute(
            'CREATE INDEX IF NOT EXISTS idx_filename ON $_tableName (filename)');
      });
    }
    if (oldVersion < 3) {
      await db.transaction((txn) async {
        await txn.execute(
            'ALTER TABLE $_tableName ADD COLUMN provider_config TEXT');
      });
    }
    if (oldVersion < 4) {
      await db.transaction((txn) async {
        await txn.execute(
            'ALTER TABLE $_tableName ADD COLUMN thumb_hash TEXT');
        await txn.execute(
            'ALTER TABLE $_tableName ADD COLUMN has_thumbnail INTEGER NOT NULL DEFAULT 0');
      });
    }
    if (oldVersion < 5) {
      await db.transaction((txn) async {
        await txn.execute(
            'ALTER TABLE $_tableName ADD COLUMN is_folder INTEGER NOT NULL DEFAULT 0');
      });
    }
    if (oldVersion < 6) {
      await db.transaction((txn) async {
        await txn.execute('''
          CREATE TABLE ra_games (
            ra_game_id INTEGER PRIMARY KEY,
            console_id INTEGER NOT NULL,
            title TEXT NOT NULL,
            num_achievements INTEGER NOT NULL DEFAULT 0,
            points INTEGER NOT NULL DEFAULT 0,
            image_icon TEXT,
            normalized_title TEXT NOT NULL,
            last_updated INTEGER NOT NULL
          )
        ''');
        await txn.execute(
            'CREATE INDEX idx_ra_games_console ON ra_games(console_id)');
        await txn.execute(
            'CREATE INDEX idx_ra_games_norm_title ON ra_games(normalized_title)');
        await txn.execute('''
          CREATE TABLE ra_hashes (
            hash TEXT PRIMARY KEY,
            ra_game_id INTEGER NOT NULL,
            rom_name TEXT
          )
        ''');
        await txn.execute(
            'CREATE INDEX idx_ra_hashes_game ON ra_hashes(ra_game_id)');
        await txn.execute('''
          CREATE TABLE ra_matches (
            game_filename TEXT NOT NULL,
            system_slug TEXT NOT NULL,
            ra_game_id INTEGER,
            match_type TEXT NOT NULL,
            last_updated INTEGER NOT NULL,
            PRIMARY KEY (game_filename, system_slug)
          )
        ''');
      });
    }
    if (oldVersion < 7) {
      await db.transaction((txn) async {
        await txn.execute(
          'ALTER TABLE ra_matches ADD COLUMN is_mastered INTEGER NOT NULL DEFAULT 0',
        );
      });
    }
  }

  Future<void> saveGames(String systemSlug, List<GameItem> games) async {
    final db = await database;
    await db.transaction((txn) async {
      // Preserve existing thumbnail data before delete
      final existing = await txn.query(
        _tableName,
        columns: ['filename', 'has_thumbnail'],
        where: 'systemSlug = ?',
        whereArgs: [systemSlug],
      );
      final thumbData = <String, Map<String, dynamic>>{};
      for (final row in existing) {
        thumbData[row['filename'] as String] = row;
      }

      await txn.delete(
        _tableName,
        where: 'systemSlug = ?',
        whereArgs: [systemSlug],
      );

      final batch = txn.batch();
      for (final game in games) {
        final prev = thumbData[game.filename];
        batch.insert(_tableName, {
          'systemSlug': systemSlug,
          'filename': game.filename,
          'displayName': game.displayName,
          'url': game.url,
          'region': _extractRegion(game.filename),
          'cover_url': game.cachedCoverUrl,
          'provider_config': game.providerConfig != null
              ? jsonEncode(game.providerConfig!.toJsonWithoutAuth())
              : null,
          'has_thumbnail':
              game.hasThumbnail ? 1 : (prev?['has_thumbnail'] ?? 0),
          'is_folder': game.isFolder ? 1 : 0,
        });
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> updateGameCover(String filename, String coverUrl) async {
    final db = await database;
    await db.update(
      _tableName,
      {'cover_url': coverUrl},
      where: 'filename = ?',
      whereArgs: [filename],
    );
  }

  Future<void> updateGameThumbnailData(
    String filename, {
    bool? hasThumbnail,
  }) async {
    if (hasThumbnail == null) return;
    final db = await database;
    await db.update(
      _tableName,
      {'has_thumbnail': hasThumbnail ? 1 : 0},
      where: 'filename = ?',
      whereArgs: [filename],
    );
  }

  Future<void> batchUpdateThumbnailData(
    List<String> filenames, {
    bool? hasThumbnail,
  }) async {
    if (hasThumbnail == null || filenames.isEmpty) return;
    final db = await database;
    final values = {'has_thumbnail': hasThumbnail ? 1 : 0};
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final filename in filenames) {
        batch.update(
          _tableName,
          values,
          where: 'filename = ?',
          whereArgs: [filename],
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> batchUpdateCoverUrl(
      List<String> filenames, String coverUrl) async {
    if (filenames.isEmpty) return;
    final db = await database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final filename in filenames) {
        batch.update(
          _tableName,
          {'cover_url': coverUrl},
          where: 'filename = ?',
          whereArgs: [filename],
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> clearThumbnailData() async {
    final db = await database;
    await db.update(_tableName, {'thumb_hash': null, 'has_thumbnail': 0});
  }

  Future<List<Map<String, dynamic>>> getGamesNeedingThumbnails() async {
    final db = await database;
    return db.query(
      _tableName,
      columns: ['filename', 'cover_url'],
      where: 'cover_url IS NOT NULL AND has_thumbnail = 0',
    );
  }

  Future<Set<String>> getAllCoverUrls() async {
    final db = await database;
    final rows = await db.query(
      _tableName,
      columns: ['cover_url'],
      where: 'cover_url IS NOT NULL',
    );
    return rows.map((r) => r['cover_url'] as String).toSet();
  }

  Future<List<Map<String, dynamic>>> getGamesNeedingCovers() async {
    final db = await database;
    return db.query(
      _tableName,
      columns: ['filename', 'systemSlug', 'cover_url'],
      where: 'has_thumbnail = 0',
    );
  }

  Future<List<GameItem>> getGames(String systemSlug) async {
    final db = await database;
    final maps = await db.query(
      _tableName,
      where: 'systemSlug = ?',
      whereArgs: [systemSlug],
      orderBy: 'displayName ASC',
    );

    return maps
        .map((map) => GameItem(
              filename: map['filename'] as String,
              displayName: map['displayName'] as String,
              url: map['url'] as String,
              cachedCoverUrl: map['cover_url'] as String?,
              providerConfig: _decodeProviderConfig(
                  map['provider_config'] as String?),
              hasThumbnail: (map['has_thumbnail'] as int?) == 1,
              isFolder: (map['is_folder'] as int?) == 1,
            ))
        .toList();
  }

  static String _escapeLike(String input) =>
      input.replaceAll('\\', '\\\\').replaceAll('%', '\\%').replaceAll('_', '\\_');

  Future<List<Map<String, dynamic>>> getAllGames({
    String? orderBy,
    String? searchQuery,
    List<String>? systemSlugs,
  }) async {
    final db = await database;
    String? where;
    List<dynamic>? whereArgs;

    final conditions = <String>[];
    final args = <dynamic>[];

    if (searchQuery != null && searchQuery.isNotEmpty) {
      final escaped = _escapeLike(searchQuery);
      conditions.add("displayName LIKE ? ESCAPE '\\'");
      args.add('%$escaped%');
    }
    if (systemSlugs != null && systemSlugs.isNotEmpty) {
      final placeholders = List.filled(systemSlugs.length, '?').join(', ');
      conditions.add('systemSlug IN ($placeholders)');
      args.addAll(systemSlugs);
    }

    if (conditions.isNotEmpty) {
      where = conditions.join(' AND ');
      whereArgs = args;
    }

    return db.query(
      _tableName,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy ?? 'displayName ASC',
    );
  }

  Future<bool> hasCache(String systemSlug) async {
    final db = await database;
    final result = await db.query(
      _tableName,
      where: 'systemSlug = ?',
      whereArgs: [systemSlug],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<void> clearCache() async {
    final db = await database;
    await db.delete(_tableName);
  }

  static ProviderConfig? _decodeProviderConfig(String? json) {
    if (json == null) return null;
    try {
      return ProviderConfig.fromJson(
          jsonDecode(json) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Failed to decode provider config: $e');
      return null;
    }
  }

  String _extractRegion(String filename) {
    if (filename.contains('(USA)') || filename.contains('(U)')) return 'USA';
    if (filename.contains('(Europe)') || filename.contains('(E)')) {
      return 'Europe';
    }
    if (filename.contains('(Japan)') || filename.contains('(J)')) {
      return 'Japan';
    }
    if (filename.contains('(Germany)')) return 'Germany';
    if (filename.contains('(France)')) return 'France';
    if (filename.contains('(Spain)')) return 'Spain';
    if (filename.contains('(Italy)')) return 'Italy';
    if (filename.contains('(World)')) return 'World';
    return 'Unknown';
  }

  // ---------------------------------------------------------------------------
  // RetroAchievements cache
  // ---------------------------------------------------------------------------

  Future<void> saveRaGames(int consoleId, List<RaGame> games) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      // Clear existing games for this console
      await txn.delete('ra_games',
          where: 'console_id = ?', whereArgs: [consoleId]);
      // Also clear hashes for games of this console (cascading cleanup)
      await txn.rawDelete('''
        DELETE FROM ra_hashes WHERE ra_game_id NOT IN (
          SELECT ra_game_id FROM ra_games
        )
      ''');

      final batch = txn.batch();
      for (final game in games) {
        batch.insert(
          'ra_games',
          {
            'ra_game_id': game.raGameId,
            'console_id': consoleId,
            'title': game.title,
            'num_achievements': game.numAchievements,
            'points': game.points,
            'image_icon': game.imageIcon,
            'normalized_title': RaNameMatcher.normalize(game.title),
            'last_updated': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        // Also save inline hashes from GetGameList
        for (final hash in game.hashes) {
          batch.insert(
            'ra_hashes',
            {
              'hash': hash,
              'ra_game_id': game.raGameId,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<RaGame>> getRaGames(int consoleId) async {
    final db = await database;
    final rows = await db.query(
      'ra_games',
      where: 'console_id = ?',
      whereArgs: [consoleId],
    );
    return rows
        .map((row) => RaGame(
              raGameId: row['ra_game_id'] as int,
              title: row['title'] as String,
              consoleId: row['console_id'] as int,
              numAchievements: row['num_achievements'] as int? ?? 0,
              points: row['points'] as int? ?? 0,
              imageIcon: row['image_icon'] as String?,
            ))
        .toList();
  }

  Future<RaGame?> getRaGame(int raGameId) async {
    final db = await database;
    final rows = await db.query(
      'ra_games',
      where: 'ra_game_id = ?',
      whereArgs: [raGameId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return RaGame(
      raGameId: row['ra_game_id'] as int,
      title: row['title'] as String,
      consoleId: row['console_id'] as int,
      numAchievements: row['num_achievements'] as int? ?? 0,
      points: row['points'] as int? ?? 0,
      imageIcon: row['image_icon'] as String?,
    );
  }

  Future<void> saveRaHashes(
      int raGameId, List<RaHashEntry> hashes) async {
    final db = await database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final entry in hashes) {
        if (entry.md5.isEmpty) continue;
        batch.insert(
          'ra_hashes',
          {
            'hash': entry.md5,
            'ra_game_id': raGameId,
            'rom_name': entry.name,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  /// Look up a game ID by ROM hash.
  Future<int?> lookupRaGameByHash(String hash) async {
    final db = await database;
    final rows = await db.query(
      'ra_hashes',
      columns: ['ra_game_id'],
      where: 'hash = ?',
      whereArgs: [hash],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['ra_game_id'] as int;
  }

  /// Get ROM filenames from the hash table, grouped by game ID.
  Future<Map<int, List<String>>> getRaRomNames(int consoleId) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT h.ra_game_id, h.rom_name
      FROM ra_hashes h
      INNER JOIN ra_games g ON h.ra_game_id = g.ra_game_id
      WHERE g.console_id = ? AND h.rom_name IS NOT NULL
    ''', [consoleId]);

    final map = <int, List<String>>{};
    for (final row in rows) {
      final gameId = row['ra_game_id'] as int;
      final name = row['rom_name'] as String;
      (map[gameId] ??= []).add(name);
    }
    return map;
  }

  Future<void> saveRaMatch(
    String filename,
    String systemSlug,
    RaMatchResult match,
  ) async {
    final db = await database;
    // MAX preserves existing is_mastered=1 so sync never accidentally un-masters
    await db.rawInsert('''
      INSERT INTO ra_matches (game_filename, system_slug, ra_game_id, match_type, is_mastered, last_updated)
      VALUES (?, ?, ?, ?, ?, ?)
      ON CONFLICT(game_filename, system_slug) DO UPDATE SET
        ra_game_id = excluded.ra_game_id,
        match_type = excluded.match_type,
        is_mastered = MAX(ra_matches.is_mastered, excluded.is_mastered),
        last_updated = excluded.last_updated
    ''', [
      filename,
      systemSlug,
      match.raGameId,
      match.type.name,
      match.isMastered ? 1 : 0,
      DateTime.now().millisecondsSinceEpoch,
    ]);
  }

  /// Explicitly set the mastered flag for a game match.
  /// Unlike [saveRaMatch], this can both master and un-master.
  Future<void> updateRaMastered(
    String filename,
    String systemSlug,
    bool isMastered,
  ) async {
    final db = await database;
    await db.update(
      'ra_matches',
      {
        'is_mastered': isMastered ? 1 : 0,
        'last_updated': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'game_filename = ? AND system_slug = ?',
      whereArgs: [filename, systemSlug],
    );
  }

  Future<Map<String, RaMatchResult>> getRaMatchesForSystem(
      String systemSlug) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT m.game_filename, m.match_type, m.ra_game_id, m.is_mastered,
             g.title, g.num_achievements, g.points, g.image_icon
      FROM ra_matches m
      LEFT JOIN ra_games g ON m.ra_game_id = g.ra_game_id
      WHERE m.system_slug = ?
    ''', [systemSlug]);

    final map = <String, RaMatchResult>{};
    for (final row in rows) {
      final filename = row['game_filename'] as String;
      final typeName = row['match_type'] as String;
      map[filename] = RaMatchResult(
        type: RaMatchType.values.firstWhere(
          (e) => e.name == typeName,
          orElse: () => RaMatchType.none,
        ),
        raGameId: row['ra_game_id'] as int?,
        raTitle: row['title'] as String?,
        achievementCount: row['num_achievements'] as int?,
        points: row['points'] as int?,
        imageIcon: row['image_icon'] as String?,
        isMastered: (row['is_mastered'] as int?) == 1,
      );
    }
    return map;
  }

  /// Look up the RA image icon path for a single game.
  /// Returns the raw path (e.g. "/Images/090065.png") or null.
  Future<String?> getRaImageIconForGame(
    String filename,
    String systemSlug,
  ) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT g.image_icon
      FROM ra_matches m
      INNER JOIN ra_games g ON m.ra_game_id = g.ra_game_id
      WHERE m.game_filename = ? AND m.system_slug = ?
        AND m.match_type != 'none'
        AND g.image_icon IS NOT NULL AND g.image_icon != ''
      LIMIT 1
    ''', [filename, systemSlug]);
    if (rows.isEmpty) return null;
    return rows.first['image_icon'] as String?;
  }

  Future<bool> hasRaCache(int consoleId) async {
    final db = await database;
    final result = await db.query(
      'ra_games',
      where: 'console_id = ?',
      whereArgs: [consoleId],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<void> clearRaCache() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('ra_matches');
      await txn.delete('ra_hashes');
      await txn.delete('ra_games');
    });
  }
}
