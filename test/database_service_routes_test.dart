import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:retro_eshop/models/game_item.dart';
import 'package:retro_eshop/services/database_service.dart';

/// Per-route game lists (schema v14).
///
/// The same server reached over the LAN and over the internet keeps two
/// independent lists, so switching routes swaps which list you see instead of
/// forcing a re-sync. Everything here guards that separation — above all that
/// syncing one route never deletes another route's rows.
void main() {
  late Database db;
  late DatabaseService service;

  const lan = ('src-romm', 'ep-lan');
  const remote = ('src-romm', 'ep-remote');

  GameItem game(String name) => GameItem(
        filename: name,
        displayName: name.replaceAll('.zip', ''),
        url: 'http://server/$name',
      );

  Future<void> save(
    String system,
    List<String> names,
    (String, String) route, {
    bool deleteOrphans = false,
  }) =>
      service.saveGames(
        system,
        names.map(game).toList(),
        deleteOrphans: deleteOrphans,
        sourceId: route.$1,
        endpointId: route.$2,
      );

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    DatabaseService.resetForTesting();
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 14,
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
              is_folder INTEGER NOT NULL DEFAULT 0,
              alternative_sources TEXT,
              source_id TEXT NOT NULL DEFAULT '',
              endpoint_id TEXT NOT NULL DEFAULT ''
            )
          ''');
          await db.execute(
              'CREATE UNIQUE INDEX idx_games_system_filename_route ON games (systemSlug, filename, source_id, endpoint_id)');
          await db.execute('''
            CREATE TABLE game_metadata (
              filename TEXT NOT NULL,
              system_slug TEXT NOT NULL,
              summary TEXT,
              PRIMARY KEY (filename, system_slug)
            )
          ''');
          await db.execute('''
            CREATE TABLE ra_matches (
              game_filename TEXT NOT NULL,
              system_slug TEXT NOT NULL,
              ra_game_id INTEGER,
              PRIMARY KEY (game_filename, system_slug)
            )
          ''');
        },
      ),
    );
    DatabaseService.testDatabase = db;
    service = DatabaseService();
  });

  tearDown(() async {
    await db.close();
    DatabaseService.resetForTesting();
  });

  group('routes keep separate lists', () {
    test('the same filename can exist once per route', () async {
      await save('snes', ['Mario.zip'], lan);
      await save('snes', ['Mario.zip'], remote);

      final rows = await db.query('games', where: 'filename = ?', whereArgs: ['Mario.zip']);
      expect(rows, hasLength(2));
    });

    test('getGames filtered by route returns only that route', () async {
      await save('snes', ['A.zip', 'B.zip'], lan);
      await save('snes', ['C.zip'], remote);

      final lanGames = await service.getGames(
        'snes',
        sourceId: lan.$1,
        endpointId: lan.$2,
      );
      final remoteGames = await service.getGames(
        'snes',
        sourceId: remote.$1,
        endpointId: remote.$2,
      );

      expect(lanGames.map((g) => g.filename), ['A.zip', 'B.zip']);
      expect(remoteGames.map((g) => g.filename), ['C.zip']);
    });

    test('getGames without a route filter still returns everything', () async {
      // The global library and the thumbnail jobs want all rows.
      await save('snes', ['A.zip'], lan);
      await save('snes', ['C.zip'], remote);

      expect(await service.getGames('snes'), hasLength(2));
    });

    test('includeLocal folds the no-route bucket in with one route', () async {
      // Local filesystem scans belong to no route; a route view should still
      // be able to show them alongside.
      await save('snes', ['Remote.zip'], remote);
      await service.saveGames('snes', [game('OnDisk.nes')]);

      final justRemote = await service.getGames(
        'snes',
        sourceId: remote.$1,
        endpointId: remote.$2,
      );
      final withLocal = await service.getGames(
        'snes',
        sourceId: remote.$1,
        endpointId: remote.$2,
        includeLocal: true,
      );

      expect(justRemote.map((g) => g.filename), ['Remote.zip']);
      expect(withLocal.map((g) => g.filename), ['OnDisk.nes', 'Remote.zip']);
    });
  });

  group('orphan deletion is scoped to one route', () {
    test('syncing the LAN never deletes the internet route — the whole point',
        () async {
      await save('snes', ['A.zip', 'B.zip', 'C.zip'], remote);
      // LAN sees a completely different set and prunes its own orphans.
      await save('snes', ['X.zip'], lan, deleteOrphans: true);

      final remoteGames = await service.getGames(
        'snes',
        sourceId: remote.$1,
        endpointId: remote.$2,
      );
      expect(remoteGames.map((g) => g.filename), ['A.zip', 'B.zip', 'C.zip']);
    });

    test('a route still prunes its own orphans', () async {
      await save('snes', ['A.zip', 'B.zip'], lan);
      await save('snes', ['A.zip'], lan, deleteOrphans: true);

      final lanGames = await service.getGames(
        'snes',
        sourceId: lan.$1,
        endpointId: lan.$2,
      );
      expect(lanGames.map((g) => g.filename), ['A.zip']);
    });

    test('local scans do not prune a route, and a route does not prune local',
        () async {
      await save('snes', ['A.zip'], lan);
      await service.saveGames(
        'snes',
        [game('OnDisk.nes')],
        forceDeleteOrphans: true,
      );

      expect(
        (await service.getGames('snes', sourceId: lan.$1, endpointId: lan.$2)),
        hasLength(1),
      );
      expect(await service.getGames('snes'), hasLength(2));
    });

    test('metadata survives while another route still lists the file',
        () async {
      // game_metadata and ra_matches are keyed by (system, filename) with no
      // route dimension. Cascading on a route-scoped delete would strip the
      // cover and RA progress of a game the other route still shows.
      await save('snes', ['Shared.zip'], lan);
      await save('snes', ['Shared.zip'], remote);
      await db.insert('game_metadata',
          {'filename': 'Shared.zip', 'system_slug': 'snes', 'summary': 'x'});
      await db.insert('ra_matches',
          {'game_filename': 'Shared.zip', 'system_slug': 'snes', 'ra_game_id': 7});

      // LAN drops it; the internet route still has it.
      await save('snes', ['Other.zip'], lan, deleteOrphans: true);

      expect(await db.query('game_metadata'), hasLength(1));
      expect(await db.query('ra_matches'), hasLength(1));
    });

    test('metadata is cascaded once no route lists the file any more',
        () async {
      await save('snes', ['Gone.zip'], lan);
      await db.insert('game_metadata',
          {'filename': 'Gone.zip', 'system_slug': 'snes', 'summary': 'x'});

      await save('snes', ['Other.zip'], lan, deleteOrphans: true);

      expect(await db.query('game_metadata'), isEmpty);
    });
  });

  group('counts — what did this route actually find', () {
    test('getGameCountsPerRoute reports each route separately', () async {
      await save('snes', ['A.zip', 'B.zip'], lan);
      await save('snes', ['C.zip'], remote);

      expect(await service.getGameCountsPerRoute(), {
        'src-romm|ep-lan': 2,
        'src-romm|ep-remote': 1,
      });
    });

    test('the no-route bucket is excluded from per-route counts', () async {
      // Local files belong to no route; counting them would misattribute
      // them to whichever route happened to be open.
      await save('snes', ['A.zip'], lan);
      await service.saveGames('snes', [game('OnDisk.nes')]);

      expect(await service.getGameCountsPerRoute(), {'src-romm|ep-lan': 1});
    });

    test('getGameCountForRoute answers for one route', () async {
      await save('snes', ['A.zip', 'B.zip'], lan);
      await save('nes', ['C.zip'], lan);

      expect(await service.getGameCountForRoute(lan.$1, lan.$2), 3);
      expect(await service.getGameCountForRoute(remote.$1, remote.$2), 0);
    });
  });

  group('deleteRoute', () {
    test('removes one route and leaves its sibling intact', () async {
      await save('snes', ['A.zip'], lan);
      await save('snes', ['A.zip', 'B.zip'], remote);

      final deleted = await service.deleteRoute(lan.$1, lan.$2);

      expect(deleted, 1);
      expect(
        await service.getGames('snes', sourceId: remote.$1, endpointId: remote.$2),
        hasLength(2),
      );
    });

    test('refuses an empty source id rather than wiping the local bucket',
        () async {
      await service.saveGames('snes', [game('OnDisk.nes')]);

      expect(await service.deleteRoute('', ''), 0);
      expect(await service.getGames('snes'), hasLength(1));
    });
  });
}
