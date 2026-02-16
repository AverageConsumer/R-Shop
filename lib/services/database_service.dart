import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/game_item.dart';

class DatabaseService {
  static Database? _database;
  static const String _tableName = 'games';
  static const int _dbVersion = 2;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
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
        cover_url TEXT
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
  }

  Future<void> saveGames(String systemSlug, List<GameItem> games) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        _tableName,
        where: 'systemSlug = ?',
        whereArgs: [systemSlug],
      );

      final batch = txn.batch();
      for (final game in games) {
        batch.insert(_tableName, {
          'systemSlug': systemSlug,
          'filename': game.filename,
          'displayName': game.displayName,
          'url': game.url,
          'region': _extractRegion(game.filename),
          'cover_url': game.cachedCoverUrl,
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

  Future<void> updateGameCovers(Map<String, String> coverMap) async {
    final db = await database;
    final batch = db.batch();

    for (final entry in coverMap.entries) {
      batch.update(
        _tableName,
        {'cover_url': entry.value},
        where: 'filename = ?',
        whereArgs: [entry.key],
      );
    }
    await batch.commit(noResult: true);
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
            ))
        .toList();
  }

  Future<List<GameItem>> searchGames(String query) async {
    final db = await database;
    final maps = await db.query(
      _tableName,
      where: 'displayName LIKE ? OR filename LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'displayName ASC',
      limit: 100,
    );

    return maps
        .map((map) => GameItem(
              filename: map['filename'] as String,
              displayName: map['displayName'] as String,
              url: map['url'] as String,
              cachedCoverUrl: map['cover_url'] as String?,
            ))
        .toList();
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

  String _extractRegion(String filename) {
    if (filename.contains('(USA)') || filename.contains('(U)')) return 'USA';
    if (filename.contains('(Europe)') || filename.contains('(E)'))
      return 'Europe';
    if (filename.contains('(Japan)') || filename.contains('(J)'))
      return 'Japan';
    if (filename.contains('(Germany)')) return 'Germany';
    if (filename.contains('(France)')) return 'France';
    if (filename.contains('(Spain)')) return 'Spain';
    if (filename.contains('(Italy)')) return 'Italy';
    if (filename.contains('(World)')) return 'World';
    return 'Unknown';
  }
}
