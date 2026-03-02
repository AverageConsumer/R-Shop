import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:retro_eshop/services/database_service.dart';
import 'package:retro_eshop/services/thumbnail_migration_service.dart';

Future<Database> _createTestDb() async {
  return databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE games (
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
        await db.execute('CREATE INDEX idx_systemSlug ON games (systemSlug)');
        await db.execute('CREATE INDEX idx_filename ON games (filename)');
      },
    ),
  );
}

Future<void> _insertGame(
  Database db, {
  required String filename,
  String? coverUrl,
  int hasThumbnail = 0,
}) async {
  await db.insert('games', {
    'systemSlug': 'snes',
    'filename': filename,
    'displayName': filename,
    'url': 'http://example.com/$filename',
    'cover_url': coverUrl,
    'has_thumbnail': hasThumbnail,
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;
  late DatabaseService dbService;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    DatabaseService.resetForTesting();
    db = await _createTestDb();
    DatabaseService.testDatabase = db;
    dbService = DatabaseService();
  });

  tearDown(() async {
    DatabaseService.resetForTesting();
    await db.close();
  });

  // ── Version check logic ─────────────────────────────────
  // These tests only run the migration with no games needing thumbnails,
  // so ThumbnailService.generateThumbnail() is never called.

  group('version check', () {
    test('upgrades version and stores new value', () async {
      SharedPreferences.setMockInitialValues({'thumbnail_version': 0});

      await ThumbnailMigrationService.migrateIfNeeded(dbService);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('thumbnail_version'), 2);
    });

    test('upgrades when version key is missing (defaults to 0)', () async {
      SharedPreferences.setMockInitialValues({});

      await ThumbnailMigrationService.migrateIfNeeded(dbService);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('thumbnail_version'), 2);
    });

    test('upgrades from version 1 to current', () async {
      SharedPreferences.setMockInitialValues({'thumbnail_version': 1});

      await ThumbnailMigrationService.migrateIfNeeded(dbService);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('thumbnail_version'), 2);
    });

    test('skips upgrade when version matches current', () async {
      SharedPreferences.setMockInitialValues({'thumbnail_version': 2});
      await _insertGame(db,
          filename: 'game.sfc', coverUrl: 'http://img/a', hasThumbnail: 1);

      await ThumbnailMigrationService.migrateIfNeeded(dbService);

      // Thumbnail data should still be intact (clearThumbnailData was NOT called)
      final rows = await db.query('games',
          where: 'filename = ?', whereArgs: ['game.sfc']);
      expect(rows.first['has_thumbnail'], 1);
    });
  });

  // ── clearThumbnailData on upgrade ───────────────────────

  group('clearThumbnailData on version upgrade', () {
    test('resets has_thumbnail for all games on upgrade', () async {
      SharedPreferences.setMockInitialValues({'thumbnail_version': 0});
      // Games without cover_url so getGamesNeedingThumbnails returns empty
      // (avoids triggering ThumbnailService.generateThumbnail in test env)
      await _insertGame(db,
          filename: 'a.sfc', coverUrl: null, hasThumbnail: 1);
      await _insertGame(db,
          filename: 'b.sfc', coverUrl: null, hasThumbnail: 1);

      await ThumbnailMigrationService.migrateIfNeeded(dbService);

      // After clearThumbnailData, all has_thumbnail flags should be reset
      final rows = await db.query('games');
      for (final row in rows) {
        expect(row['has_thumbnail'], 0,
            reason: '${row['filename']} should have has_thumbnail=0 after clear');
      }
    });

    test('resets thumb_hash for all games on upgrade', () async {
      SharedPreferences.setMockInitialValues({'thumbnail_version': 0});
      await db.insert('games', {
        'systemSlug': 'snes',
        'filename': 'hashgame.sfc',
        'displayName': 'hashgame.sfc',
        'url': 'http://x',
        'thumb_hash': 'abc123',
        'has_thumbnail': 1,
      });

      await ThumbnailMigrationService.migrateIfNeeded(dbService);

      final rows = await db.query('games',
          where: 'filename = ?', whereArgs: ['hashgame.sfc']);
      expect(rows.first['thumb_hash'], isNull);
    });
  });

  // ── DB query behavior ──────────────────────────────────
  // These test getGamesNeedingThumbnails directly (no migration call)

  group('getGamesNeedingThumbnails', () {
    test('returns games with cover_url but no thumbnail', () async {
      await _insertGame(db, filename: 'need.sfc', coverUrl: 'http://img/1');

      final rows = await dbService.getGamesNeedingThumbnails();

      expect(rows, hasLength(1));
      expect(rows.first['filename'], 'need.sfc');
      expect(rows.first['cover_url'], 'http://img/1');
    });

    test('excludes games without cover_url', () async {
      await _insertGame(db, filename: 'no_cover.sfc', coverUrl: null);

      final rows = await dbService.getGamesNeedingThumbnails();

      expect(rows, isEmpty);
    });

    test('excludes games that already have thumbnails', () async {
      await _insertGame(db,
          filename: 'done.sfc', coverUrl: 'http://img/x', hasThumbnail: 1);

      final rows = await dbService.getGamesNeedingThumbnails();

      expect(rows, isEmpty);
    });

    test('returns multiple games needing thumbnails', () async {
      for (var i = 0; i < 5; i++) {
        await _insertGame(db,
            filename: 'game$i.sfc', coverUrl: 'http://img/$i');
      }

      final rows = await dbService.getGamesNeedingThumbnails();

      expect(rows, hasLength(5));
    });
  });

  // ── Empty game list ────────────────────────────────────

  group('migration with no work', () {
    test('completes cleanly with empty database', () async {
      SharedPreferences.setMockInitialValues({'thumbnail_version': 2});

      await ThumbnailMigrationService.migrateIfNeeded(dbService);
    });

    test('completes when all games already have thumbnails', () async {
      SharedPreferences.setMockInitialValues({'thumbnail_version': 2});
      await _insertGame(db,
          filename: 'done.sfc', coverUrl: 'http://img/x', hasThumbnail: 1);

      await ThumbnailMigrationService.migrateIfNeeded(dbService);

      // Game should be unchanged
      final rows = await db.query('games');
      expect(rows.first['has_thumbnail'], 1);
    });
  });
}
