import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/config/provider_config.dart';
import '../models/game_item.dart';
import '../models/game_metadata_info.dart';
import '../models/ra_models.dart';
import '../utils/ra_name_matcher.dart';

class DatabaseService {
  static Future<Database>? _initFuture;
  static const String _tableName = 'games';
  static const int _dbVersion = 13;

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
        is_folder INTEGER NOT NULL DEFAULT 0,
        alternative_sources TEXT
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

    await db.execute('''
      CREATE UNIQUE INDEX idx_games_system_filename ON $_tableName (systemSlug, filename)
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

    // Game metadata from RomM/IGDB
    await db.execute('''
      CREATE TABLE game_metadata (
        filename TEXT NOT NULL,
        system_slug TEXT NOT NULL,
        summary TEXT,
        genres TEXT,
        developer TEXT,
        publisher TEXT,
        release_year INTEGER,
        release_date TEXT,
        game_modes TEXT,
        rating REAL,
        franchises TEXT,
        themes TEXT,
        player_perspectives TEXT,
        age_rating TEXT,
        screenshots TEXT,
        file_size INTEGER,
        siblings TEXT,
        last_updated INTEGER NOT NULL,
        PRIMARY KEY (filename, system_slug)
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
    if (oldVersion < 8) {
      await db.transaction((txn) async {
        await txn.execute('''
          CREATE TABLE game_metadata (
            filename TEXT NOT NULL,
            system_slug TEXT NOT NULL,
            summary TEXT,
            genres TEXT,
            developer TEXT,
            release_year INTEGER,
            game_modes TEXT,
            rating REAL,
            last_updated INTEGER NOT NULL,
            PRIMARY KEY (filename, system_slug)
          )
        ''');
      });
    }
    if (oldVersion < 9) {
      await db.transaction((txn) async {
        // Remove any duplicate (systemSlug, filename) rows before adding constraint
        await txn.execute('''
          DELETE FROM $_tableName WHERE id NOT IN (
            SELECT MIN(id) FROM $_tableName GROUP BY systemSlug, filename
          )
        ''');
        await txn.execute(
          'CREATE UNIQUE INDEX idx_games_system_filename ON $_tableName (systemSlug, filename)',
        );
      });
    }
    if (oldVersion < 10) {
      await db.transaction((txn) async {
        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_has_thumbnail ON $_tableName (has_thumbnail)',
        );
      });
    }
    if (oldVersion < 11) {
      await db.transaction((txn) async {
        await txn.execute(
            'ALTER TABLE game_metadata ADD COLUMN publisher TEXT');
        await txn.execute(
            'ALTER TABLE game_metadata ADD COLUMN release_date TEXT');
        await txn.execute(
            'ALTER TABLE game_metadata ADD COLUMN franchises TEXT');
        await txn.execute(
            'ALTER TABLE game_metadata ADD COLUMN themes TEXT');
        await txn.execute(
            'ALTER TABLE game_metadata ADD COLUMN player_perspectives TEXT');
        await txn.execute(
            'ALTER TABLE game_metadata ADD COLUMN age_rating TEXT');
      });
    }
    if (oldVersion < 12) {
      await db.transaction((txn) async {
        await txn.execute(
            'ALTER TABLE game_metadata ADD COLUMN screenshots TEXT');
        await txn.execute(
            'ALTER TABLE game_metadata ADD COLUMN file_size INTEGER');
        await txn.execute(
            'ALTER TABLE game_metadata ADD COLUMN siblings TEXT');
      });
    }
    if (oldVersion < 13) {
      // alternative_sources: JSON list serialised by AlternativeSource.toJson.
      // Carries the merged secondary sources for a game so the grid can
      // render multi-source dots and the detail screen's "from <source>"
      // download picker survives a DB roundtrip.
      await db.transaction((txn) async {
        await txn.execute(
            'ALTER TABLE $_tableName ADD COLUMN alternative_sources TEXT');
      });
    }
  }

  Future<void> saveGames(
    String systemSlug,
    List<GameItem> games, {
    bool deleteOrphans = false,
    bool forceDeleteOrphans = false,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      // 1. Delete orphans when requested.
      // forceDeleteOrphans: unconditional (safe for local filesystem scans).
      // deleteOrphans: guarded — blocks mass deletion from incomplete fetches.
      if (deleteOrphans || forceDeleteOrphans) {
        final existing = await txn.query(
          _tableName,
          columns: ['filename'],
          where: 'systemSlug = ?',
          whereArgs: [systemSlug],
        );
        final existingFiles =
            existing.map((r) => r['filename'] as String).toSet();
        final incomingFiles = games.map((g) => g.filename).toSet();

        final orphans = existingFiles.difference(incomingFiles);
        if (orphans.isNotEmpty) {
          // Safety: if incoming data looks incomplete, skip deletion to prevent
          // data loss from partial fetches (e.g. RomM timeout mid-pagination).
          // forceDeleteOrphans bypasses this for authoritative sources (local scan).
          if (!forceDeleteOrphans &&
              existingFiles.length >= 10 &&
              incomingFiles.length < existingFiles.length ~/ 2) {
            debugPrint(
              'saveGames($systemSlug): BLOCKED orphan deletion — '
              'incoming ${incomingFiles.length} vs existing ${existingFiles.length}. '
              'Looks like incomplete fetch data.',
            );
          } else {
            final orphanList = orphans.toList();
            for (var i = 0; i < orphanList.length; i += 100) {
              final chunk = orphanList.skip(i).take(100).toList();
              final placeholders = List.filled(chunk.length, '?').join(',');
              await txn.rawDelete(
                'DELETE FROM $_tableName WHERE systemSlug = ? AND filename IN ($placeholders)',
                [systemSlug, ...chunk],
              );
              // Cascade: remove orphaned metadata and RA matches
              await txn.rawDelete(
                'DELETE FROM game_metadata WHERE system_slug = ? AND filename IN ($placeholders)',
                [systemSlug, ...chunk],
              );
              await txn.rawDelete(
                'DELETE FROM ra_matches WHERE system_slug = ? AND game_filename IN ($placeholders)',
                [systemSlug, ...chunk],
              );
            }
          }
        }
      }

      // 2. Upsert incoming games — preserves cover_url and has_thumbnail
      final batch = txn.batch();
      for (final game in games) {
        batch.rawInsert('''
          INSERT INTO $_tableName (systemSlug, filename, displayName, url, region, cover_url, provider_config, has_thumbnail, is_folder, alternative_sources)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ON CONFLICT(systemSlug, filename) DO UPDATE SET
            displayName = excluded.displayName,
            url = excluded.url,
            region = excluded.region,
            cover_url = COALESCE(excluded.cover_url, cover_url),
            provider_config = excluded.provider_config,
            has_thumbnail = MAX(has_thumbnail, excluded.has_thumbnail),
            is_folder = excluded.is_folder,
            alternative_sources = excluded.alternative_sources
        ''', [
          systemSlug,
          game.filename,
          game.displayName,
          game.url,
          _extractRegion(game.filename),
          game.cachedCoverUrl,
          game.providerConfig != null
              ? jsonEncode(game.providerConfig!.toJsonWithoutAuth())
              : null,
          game.hasThumbnail ? 1 : 0,
          game.isFolder ? 1 : 0,
          game.alternativeSources.isEmpty
              ? null
              : jsonEncode(
                  game.alternativeSources.map((a) => a.toJson()).toList()),
        ]);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<Map<String, int>> getGameCountsPerSystem() async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT systemSlug, COUNT(*) as count FROM $_tableName GROUP BY systemSlug',
    );
    return {
      for (final row in rows)
        row['systemSlug'] as String: row['count'] as int,
    };
  }

  /// Returns remote game counts (games with a remote provider) per system slug.
  /// Local counts are derived from the filesystem via [InstalledFilesProvider].
  Future<Map<String, int>> getRemoteGameCountsPerSystem() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT systemSlug, COUNT(*) AS remote_count
      FROM $_tableName
      WHERE provider_config IS NOT NULL
      GROUP BY systemSlug
    ''');
    return {
      for (final row in rows)
        row['systemSlug'] as String: (row['remote_count'] as int?) ?? 0,
    };
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
    final value = hasThumbnail ? 1 : 0;
    await db.transaction((txn) async {
      for (var i = 0; i < filenames.length; i += 100) {
        final chunk = filenames.skip(i).take(100).toList();
        final placeholders = List.filled(chunk.length, '?').join(',');
        await txn.rawUpdate(
          'UPDATE $_tableName SET has_thumbnail = ? WHERE filename IN ($placeholders)',
          [value, ...chunk],
        );
      }
    });
  }

  Future<void> batchUpdateCoverUrl(
      List<String> filenames, String coverUrl) async {
    if (filenames.isEmpty) return;
    final db = await database;
    await db.transaction((txn) async {
      for (var i = 0; i < filenames.length; i += 100) {
        final chunk = filenames.skip(i).take(100).toList();
        final placeholders = List.filled(chunk.length, '?').join(',');
        await txn.rawUpdate(
          'UPDATE $_tableName SET cover_url = ? WHERE filename IN ($placeholders)',
          [coverUrl, ...chunk],
        );
      }
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
              alternativeSources: _decodeAlternativeSources(
                  map['alternative_sources'] as String?),
            ))
        .toList();
  }

  static List<AlternativeSource> _decodeAlternativeSources(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) =>
              AlternativeSource.fromJson((e as Map).cast<String, dynamic>()))
          .toList(growable: false);
    } catch (e) {
      debugPrint('_decodeAlternativeSources: $e');
      return const [];
    }
  }

  /// Cleans up cached games when a [Source] is disabled or removed.
  ///
  /// We can't simply DELETE every row tagged with the source: a game may
  /// have been downloaded from that source and now lives on disk as a
  /// local file the user expects to keep seeing in their library. So for
  /// each matching row we check whether the file (or its extracted
  /// folder) exists in the system's [systemTargetFolders] and:
  ///   - **installed** rows have their `provider_config` and `url` nulled
  ///     out (the row stays so the library/grid keeps the entry; install
  ///     detection works off the filesystem so it keeps working);
  ///   - **non-installed** rows are removed entirely.
  ///
  /// The sourceId is validated against `[A-Za-z0-9_-]+` before it hits
  /// the LIKE pattern so it can't be hijacked into a wildcard.
  /// Returns `(detached, deleted)` row counts for logging.
  Future<({int detached, int deleted})> purgeOrDetachSource(
    String sourceId, {
    required Map<String, String> systemTargetFolders,
  }) async {
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(sourceId)) {
      debugPrint('purgeOrDetachSource: refusing unsafe id "$sourceId"');
      return (detached: 0, deleted: 0);
    }
    final db = await database;
    final pattern = '%"source_id":"$sourceId"%';
    final rows = await db.query(
      _tableName,
      columns: ['systemSlug', 'filename'],
      where: 'provider_config LIKE ?',
      whereArgs: [pattern],
    );

    final installedFilenames = <(String, String)>[];
    final orphanFilenames = <(String, String)>[];
    for (final row in rows) {
      final slug = row['systemSlug'] as String;
      final filename = row['filename'] as String;
      final folder = systemTargetFolders[slug];
      if (folder != null && _isFilenameOnDisk(folder, filename)) {
        installedFilenames.add((slug, filename));
      } else {
        orphanFilenames.add((slug, filename));
      }
    }

    int detached = 0;
    int deleted = 0;
    await db.transaction((txn) async {
      for (final (slug, filename) in installedFilenames) {
        detached += await txn.rawUpdate(
          'UPDATE $_tableName SET provider_config = NULL, url = NULL '
          'WHERE systemSlug = ? AND filename = ?',
          [slug, filename],
        );
      }
      for (final (slug, filename) in orphanFilenames) {
        deleted += await txn.delete(
          _tableName,
          where: 'systemSlug = ? AND filename = ?',
          whereArgs: [slug, filename],
        );
      }
    });
    debugPrint(
      'purgeOrDetachSource($sourceId): detached=$detached deleted=$deleted',
    );
    return (detached: detached, deleted: deleted);
  }

  /// Returns true when [filename] (or its extracted folder counterpart)
  /// exists in [folder]. Mirrors the install-detection used by the UI:
  /// archive files like `.zip`/`.7z` are also considered installed when
  /// their extracted folder is present.
  static bool _isFilenameOnDisk(String folder, String filename) {
    try {
      final direct = File('$folder/$filename');
      if (direct.existsSync()) return true;
      final lower = filename.toLowerCase();
      const archives = ['.zip', '.7z', '.rar'];
      for (final ext in archives) {
        if (lower.endsWith(ext)) {
          final stripped = filename.substring(0, filename.length - ext.length);
          if (Directory('$folder/$stripped').existsSync()) return true;
          if (File('$folder/$stripped').existsSync()) return true;
        }
      }
    } catch (e) {
      debugPrint('_isFilenameOnDisk: $folder/$filename: $e');
    }
    return false;
  }

  Future<void> deleteGame(String systemSlug, String filename) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        _tableName,
        where: 'systemSlug = ? AND filename = ?',
        whereArgs: [systemSlug, filename],
      );
      // Cascade: remove orphaned metadata and RA matches
      await txn.delete(
        'game_metadata',
        where: 'system_slug = ? AND filename = ?',
        whereArgs: [systemSlug, filename],
      );
      await txn.delete(
        'ra_matches',
        where: 'system_slug = ? AND game_filename = ?',
        whereArgs: [systemSlug, filename],
      );
    });
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

  /// Returns the set of system slugs (from [slugs]) that have at least one
  /// cached game. Single query instead of N individual hasCache() calls.
  Future<Set<String>> systemsWithCache(List<String> slugs) async {
    if (slugs.isEmpty) return {};
    final db = await database;
    final placeholders = List.filled(slugs.length, '?').join(',');
    final result = await db.rawQuery(
      'SELECT DISTINCT systemSlug FROM $_tableName WHERE systemSlug IN ($placeholders)',
      slugs,
    );
    return result.map((r) => r['systemSlug'] as String).toSet();
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

  static final _regionPattern = RegExp(
    r'\((USA|U|Europe|E|Japan|J|Germany|France|Spain|Italy|World)\)',
  );

  static const _regionMap = {
    'USA': 'USA', 'U': 'USA',
    'Europe': 'Europe', 'E': 'Europe',
    'Japan': 'Japan', 'J': 'Japan',
    'Germany': 'Germany',
    'France': 'France',
    'Spain': 'Spain',
    'Italy': 'Italy',
    'World': 'World',
  };

  String _extractRegion(String filename) {
    final match = _regionPattern.firstMatch(filename);
    if (match == null) return 'Unknown';
    return _regionMap[match.group(1)] ?? 'Unknown';
  }

  // ---------------------------------------------------------------------------
  // Game metadata (RomM / IGDB)
  // ---------------------------------------------------------------------------

  Future<void> saveGameMetadata(
      String systemSlug, List<GameMetadataInfo> metadata) async {
    if (metadata.isEmpty) return;
    final db = await database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final m in metadata) {
        batch.insert('game_metadata', m.toDbRow(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<GameMetadataInfo?> getGameMetadata(
      String filename, String systemSlug) async {
    final db = await database;
    final rows = await db.query(
      'game_metadata',
      where: 'filename = ? AND system_slug = ?',
      whereArgs: [filename, systemSlug],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return GameMetadataInfo.fromDbRow(rows.first);
  }

  Future<Map<String, GameMetadataInfo>> getMetadataForSystem(
      String systemSlug) async {
    final db = await database;
    final rows = await db.query(
      'game_metadata',
      where: 'system_slug = ?',
      whereArgs: [systemSlug],
    );
    return {
      for (final row in rows)
        row['filename'] as String: GameMetadataInfo.fromDbRow(row),
    };
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
