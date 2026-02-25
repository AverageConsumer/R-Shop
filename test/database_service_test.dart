import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:retro_eshop/models/config/provider_config.dart';
import 'package:retro_eshop/models/game_item.dart';
import 'package:retro_eshop/services/database_service.dart';

void main() {
  late Database db;
  late DatabaseService service;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    DatabaseService.resetForTesting();
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 4,
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
              has_thumbnail INTEGER NOT NULL DEFAULT 0
            )
          ''');
          await db.execute('CREATE INDEX idx_systemSlug ON games (systemSlug)');
          await db.execute('CREATE INDEX idx_displayName ON games (displayName)');
          await db.execute('CREATE INDEX idx_filename ON games (filename)');
        },
      ),
    );
    DatabaseService.testDatabase = db;
    service = DatabaseService();
  });

  tearDown(() async {
    DatabaseService.resetForTesting();
    await db.close();
  });

  // ─── Schema ─────────────────────────────────────────────

  group('Schema', () {
    test('games table exists with all columns', () async {
      final info = await db.rawQuery('PRAGMA table_info(games)');
      final columns = info.map((r) => r['name'] as String).toSet();
      expect(columns, containsAll([
        'id', 'systemSlug', 'filename', 'displayName', 'url',
        'region', 'cover_url', 'provider_config', 'thumb_hash', 'has_thumbnail',
      ]));
    });

    test('indices exist', () async {
      final indices = await db.rawQuery('PRAGMA index_list(games)');
      final names = indices.map((r) => r['name'] as String).toSet();
      expect(names, containsAll(['idx_systemSlug', 'idx_displayName', 'idx_filename']));
    });
  });

  // ─── saveGames / getGames round-trip ───────────────────

  group('saveGames / getGames round-trip', () {
    test('basic fields preserved', () async {
      final games = [
        const GameItem(
          filename: 'Zelda (USA).zip',
          displayName: 'Zelda',
          url: 'http://example.com/zelda.zip',
        ),
      ];
      await service.saveGames('snes', games);
      final loaded = await service.getGames('snes');
      expect(loaded.length, 1);
      expect(loaded.first.filename, 'Zelda (USA).zip');
      expect(loaded.first.displayName, 'Zelda');
      expect(loaded.first.url, 'http://example.com/zelda.zip');
    });

    test('cachedCoverUrl preserved', () async {
      final games = [
        const GameItem(
          filename: 'Mario (USA).zip',
          displayName: 'Mario',
          url: 'http://example.com/mario.zip',
          cachedCoverUrl: 'http://covers.example.com/mario.png',
        ),
      ];
      await service.saveGames('snes', games);
      final loaded = await service.getGames('snes');
      expect(loaded.first.cachedCoverUrl, 'http://covers.example.com/mario.png');
    });

    test('ProviderConfig (web) JSON round-trip', () async {
      const config = ProviderConfig(
        type: ProviderType.web,
        priority: 1,
        url: 'http://roms.example.com/snes/',
      );
      final games = [
        const GameItem(
          filename: 'Zelda (USA).zip',
          displayName: 'Zelda',
          url: 'http://example.com/zelda.zip',
          providerConfig: config,
        ),
      ];
      await service.saveGames('snes', games);
      final loaded = await service.getGames('snes');
      expect(loaded.first.providerConfig, isNotNull);
      expect(loaded.first.providerConfig!.type, ProviderType.web);
      expect(loaded.first.providerConfig!.url, 'http://roms.example.com/snes/');
      expect(loaded.first.providerConfig!.priority, 1);
    });

    test('ProviderConfig (smb with auth) round-trip', () async {
      const config = ProviderConfig(
        type: ProviderType.smb,
        priority: 2,
        host: '192.168.1.100',
        share: 'roms',
        path: '/snes',
        auth: AuthConfig(user: 'admin', pass: 'secret', domain: 'WORKGROUP'),
      );
      final games = [
        const GameItem(
          filename: 'Mario (Japan).zip',
          displayName: 'Mario',
          url: 'smb://192.168.1.100/roms/snes/Mario.zip',
          providerConfig: config,
        ),
      ];
      await service.saveGames('snes', games);
      final loaded = await service.getGames('snes');
      final pc = loaded.first.providerConfig!;
      expect(pc.type, ProviderType.smb);
      expect(pc.host, '192.168.1.100');
      expect(pc.share, 'roms');
      expect(pc.path, '/snes');
      expect(pc.auth!.user, 'admin');
      expect(pc.auth!.pass, 'secret');
      expect(pc.auth!.domain, 'WORKGROUP');
    });

    test('null providerConfig loads as null', () async {
      final games = [
        const GameItem(
          filename: 'Test.zip',
          displayName: 'Test',
          url: 'http://example.com/test.zip',
        ),
      ];
      await service.saveGames('snes', games);
      final loaded = await service.getGames('snes');
      expect(loaded.first.providerConfig, isNull);
    });

    test('empty game list loads as empty', () async {
      await service.saveGames('snes', []);
      final loaded = await service.getGames('snes');
      expect(loaded, isEmpty);
    });

    test('save replaces previous for same systemSlug', () async {
      final batch1 = [
        const GameItem(filename: 'A.zip', displayName: 'A', url: 'http://a'),
        const GameItem(filename: 'B.zip', displayName: 'B', url: 'http://b'),
      ];
      await service.saveGames('snes', batch1);

      final batch2 = [
        const GameItem(filename: 'C.zip', displayName: 'C', url: 'http://c'),
      ];
      await service.saveGames('snes', batch2);

      final loaded = await service.getGames('snes');
      expect(loaded.length, 1);
      expect(loaded.first.filename, 'C.zip');
    });

    test('save for system A does not affect system B', () async {
      final gamesA = [
        const GameItem(filename: 'A.zip', displayName: 'A', url: 'http://a'),
      ];
      final gamesB = [
        const GameItem(filename: 'B.zip', displayName: 'B', url: 'http://b'),
      ];
      await service.saveGames('snes', gamesA);
      await service.saveGames('gba', gamesB);

      // Replace snes games
      await service.saveGames('snes', []);
      final loadedB = await service.getGames('gba');
      expect(loadedB.length, 1);
      expect(loadedB.first.filename, 'B.zip');
    });
  });

  // ─── hasThumbnail preservation ─────────────────────────

  group('hasThumbnail preservation', () {
    test('re-save fresh (false) preserves old true flag', () async {
      final games1 = [
        const GameItem(
          filename: 'Zelda.zip',
          displayName: 'Zelda',
          url: 'http://z',
          hasThumbnail: true,
        ),
      ];
      await service.saveGames('snes', games1);

      // Re-save same file without hasThumbnail (defaults to false)
      final games2 = [
        const GameItem(
          filename: 'Zelda.zip',
          displayName: 'Zelda',
          url: 'http://z',
        ),
      ];
      await service.saveGames('snes', games2);

      final loaded = await service.getGames('snes');
      expect(loaded.first.hasThumbnail, isTrue);
    });

    test('save with true overwrites old false', () async {
      final games1 = [
        const GameItem(
          filename: 'Zelda.zip',
          displayName: 'Zelda',
          url: 'http://z',
        ),
      ];
      await service.saveGames('snes', games1);

      final games2 = [
        const GameItem(
          filename: 'Zelda.zip',
          displayName: 'Zelda',
          url: 'http://z',
          hasThumbnail: true,
        ),
      ];
      await service.saveGames('snes', games2);

      final loaded = await service.getGames('snes');
      expect(loaded.first.hasThumbnail, isTrue);
    });
  });

  // ─── getAllGames ────────────────────────────────────────

  group('getAllGames', () {
    setUp(() async {
      await service.saveGames('snes', [
        const GameItem(filename: 'Zelda (USA).zip', displayName: 'Zelda', url: 'http://z'),
        const GameItem(filename: 'Mario (USA).zip', displayName: 'Mario', url: 'http://m'),
      ]);
      await service.saveGames('gba', [
        const GameItem(filename: 'Pokemon (USA).zip', displayName: 'Pokemon', url: 'http://p'),
      ]);
    });

    test('returns all across systems', () async {
      final all = await service.getAllGames();
      expect(all.length, 3);
    });

    test('searchQuery filters case-insensitive', () async {
      final results = await service.getAllGames(searchQuery: 'zelda');
      expect(results.length, 1);
      expect(results.first['displayName'], 'Zelda');
    });

    test('searchQuery with special chars (%, _) escaped', () async {
      // Save a game with special chars in name
      await service.saveGames('nes', [
        const GameItem(filename: '100%.zip', displayName: '100% Complete', url: 'http://100'),
        const GameItem(filename: 'a_b.zip', displayName: 'a_b Game', url: 'http://ab'),
      ]);

      // % should not act as wildcard
      final pctResults = await service.getAllGames(searchQuery: '100%');
      expect(pctResults.length, 1);

      // _ should not act as single-char wildcard
      final underResults = await service.getAllGames(searchQuery: 'a_b');
      expect(underResults.length, 1);
    });

    test('systemSlugs filter', () async {
      final results = await service.getAllGames(systemSlugs: ['gba']);
      expect(results.length, 1);
      expect(results.first['displayName'], 'Pokemon');
    });
  });

  // ─── hasCache / clearCache / clearThumbnailData ────────

  group('hasCache / clearCache / clearThumbnailData', () {
    test('hasCache false when empty', () async {
      expect(await service.hasCache('snes'), isFalse);
    });

    test('hasCache true after save', () async {
      await service.saveGames('snes', [
        const GameItem(filename: 'A.zip', displayName: 'A', url: 'http://a'),
      ]);
      expect(await service.hasCache('snes'), isTrue);
    });

    test('clearCache removes all data', () async {
      await service.saveGames('snes', [
        const GameItem(filename: 'A.zip', displayName: 'A', url: 'http://a'),
      ]);
      await service.clearCache();
      expect(await service.hasCache('snes'), isFalse);
    });

    test('clearThumbnailData resets has_thumbnail', () async {
      await service.saveGames('snes', [
        const GameItem(
          filename: 'A.zip',
          displayName: 'A',
          url: 'http://a',
          hasThumbnail: true,
        ),
      ]);
      await service.clearThumbnailData();
      final loaded = await service.getGames('snes');
      expect(loaded.first.hasThumbnail, isFalse);
    });
  });

  // ─── batchUpdateThumbnailData / batchUpdateCoverUrl ────

  group('batchUpdateThumbnailData', () {
    test('updates specified filenames', () async {
      await service.saveGames('snes', [
        const GameItem(filename: 'A.zip', displayName: 'A', url: 'http://a'),
        const GameItem(filename: 'B.zip', displayName: 'B', url: 'http://b'),
      ]);
      await service.batchUpdateThumbnailData(['A.zip'], hasThumbnail: true);
      final loaded = await service.getGames('snes');
      final a = loaded.firstWhere((g) => g.filename == 'A.zip');
      final b = loaded.firstWhere((g) => g.filename == 'B.zip');
      expect(a.hasThumbnail, isTrue);
      expect(b.hasThumbnail, isFalse);
    });

    test('empty list is no-op', () async {
      await service.saveGames('snes', [
        const GameItem(filename: 'A.zip', displayName: 'A', url: 'http://a'),
      ]);
      await service.batchUpdateThumbnailData([], hasThumbnail: true);
      final loaded = await service.getGames('snes');
      expect(loaded.first.hasThumbnail, isFalse);
    });

    test('null hasThumbnail is no-op', () async {
      await service.saveGames('snes', [
        const GameItem(filename: 'A.zip', displayName: 'A', url: 'http://a'),
      ]);
      await service.batchUpdateThumbnailData(['A.zip'], hasThumbnail: null);
      final loaded = await service.getGames('snes');
      expect(loaded.first.hasThumbnail, isFalse);
    });
  });

  group('batchUpdateCoverUrl', () {
    test('updates specified filenames', () async {
      await service.saveGames('snes', [
        const GameItem(filename: 'A.zip', displayName: 'A', url: 'http://a'),
        const GameItem(filename: 'B.zip', displayName: 'B', url: 'http://b'),
      ]);
      await service.batchUpdateCoverUrl(['A.zip'], 'http://covers/a.png');
      final rows = await db.query('games', where: "filename = 'A.zip'");
      expect(rows.first['cover_url'], 'http://covers/a.png');

      final bRows = await db.query('games', where: "filename = 'B.zip'");
      expect(bRows.first['cover_url'], isNull);
    });

    test('empty list is no-op', () async {
      await service.saveGames('snes', [
        const GameItem(filename: 'A.zip', displayName: 'A', url: 'http://a'),
      ]);
      await service.batchUpdateCoverUrl([], 'http://covers/a.png');
      final loaded = await service.getGames('snes');
      expect(loaded.first.cachedCoverUrl, isNull);
    });
  });
}
