import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/config/provider_config.dart';
import '../models/game_item.dart';

class DatabaseService {
  static Future<Database>? _initFuture;
  static const String _tableName = 'games';
  static const int _dbVersion = 4;

  Future<Database> get database => _initFuture ??= _initDatabase();

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
        has_thumbnail INTEGER NOT NULL DEFAULT 0
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
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE $_tableName ADD COLUMN cover_url TEXT');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_filename ON $_tableName (filename)');
    }
    if (oldVersion < 3) {
      await db.execute(
          'ALTER TABLE $_tableName ADD COLUMN provider_config TEXT');
    }
    if (oldVersion < 4) {
      await db.execute(
          'ALTER TABLE $_tableName ADD COLUMN thumb_hash TEXT');
      await db.execute(
          'ALTER TABLE $_tableName ADD COLUMN has_thumbnail INTEGER NOT NULL DEFAULT 0');
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
              ? jsonEncode(game.providerConfig!.toJson())
              : null,
          'has_thumbnail':
              game.hasThumbnail ? 1 : (prev?['has_thumbnail'] ?? 0),
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
}
