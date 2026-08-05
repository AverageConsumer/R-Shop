import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:retro_eshop/models/game_item.dart';
import 'package:retro_eshop/services/database_service.dart';

/// One cached list per *source* (schema v16, ungrouped).
///
/// The routes of one source are the same server reached by another address, so
/// there is only ever one game list behind them. v14 stored a copy per route
/// and nothing could tell whether the copies were supposed to agree; v15 keys
/// on the source alone and keeps `endpoint_id` only as a record of which route
/// last fetched the row. v16 moved the key on again, from the source to the
/// cache owner — which *is* the source until the user puts it in a group, so
/// everything here still describes what an ungrouped install does. The grouped
/// case is in `database_service_v16_migration_test.dart`.
///
/// Everything here guards two things: syncing one source never touches
/// another's rows, and switching route never splits or re-fetches a list.
void main() {
  late Database db;
  late DatabaseService service;

  const romm = 'src-romm';
  const smb = 'src-smb';
  const lan = 'ep-lan';
  const remote = 'ep-remote';

  GameItem game(String name) => GameItem(
        filename: name,
        displayName: name.replaceAll('.zip', ''),
        url: 'http://server/$name',
      );

  Future<void> save(
    String system,
    List<String> names,
    String sourceId, {
    String endpointId = lan,
    bool deleteOrphans = false,
  }) =>
      service.saveGames(
        system,
        names.map(game).toList(),
        deleteOrphans: deleteOrphans,
        sourceId: sourceId,
        endpointId: endpointId,
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
        version: 16,
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
              endpoint_id TEXT NOT NULL DEFAULT '',
              cache_owner_id TEXT NOT NULL DEFAULT ''
            )
          ''');
          await db.execute(
              'CREATE UNIQUE INDEX idx_games_system_filename_owner ON games (systemSlug, filename, cache_owner_id)');
          await db.execute(
              'CREATE INDEX idx_games_source ON games (source_id)');
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

  group('one list per source', () {
    test('the same game fetched over two routes is stored once', () async {
      await save('snes', ['Mario.zip'], romm, endpointId: lan);
      await save('snes', ['Mario.zip'], romm, endpointId: remote);

      final rows =
          await db.query('games', where: 'filename = ?', whereArgs: ['Mario.zip']);
      expect(rows, hasLength(1));
    });

    test('endpoint_id records the route that last fetched the row', () async {
      await save('snes', ['Mario.zip'], romm, endpointId: lan);
      await save('snes', ['Mario.zip'], romm, endpointId: remote);

      final rows = await db.query('games');
      expect(rows.single['endpoint_id'], remote);
    });

    test('two different sources still keep separate rows', () async {
      // Two servers are two lists — that separation is the one v15 keeps.
      await save('snes', ['Mario.zip'], romm);
      await save('snes', ['Mario.zip'], smb);

      final rows =
          await db.query('games', where: 'filename = ?', whereArgs: ['Mario.zip']);
      expect(rows, hasLength(2));
    });

    test('getGames filtered by source returns only that source', () async {
      await save('snes', ['A.zip', 'B.zip'], romm);
      await save('snes', ['C.zip'], smb);

      expect(
        (await service.getGames('snes', sourceId: romm)).map((g) => g.filename),
        ['A.zip', 'B.zip'],
      );
      expect(
        (await service.getGames('snes', sourceId: smb)).map((g) => g.filename),
        ['C.zip'],
      );
    });

    test('the endpoint argument does not narrow a source query', () async {
      // Callers hand over a whole route without caring; only the source half
      // selects. Asking over the LAN must not hide what the remote fetched.
      await save('snes', ['A.zip'], romm, endpointId: remote);

      final overLan =
          await service.getGames('snes', sourceId: romm, endpointId: lan);
      expect(overLan.map((g) => g.filename), ['A.zip']);
    });

    test('getGames without a source filter still returns everything', () async {
      await save('snes', ['A.zip'], romm);
      await save('snes', ['C.zip'], smb);

      expect(await service.getGames('snes'), hasLength(2));
    });

    test('includeLocal folds the no-source bucket in with one source', () async {
      await save('snes', ['Remote.zip'], romm);
      await service.saveGames('snes', [game('OnDisk.nes')]);

      expect(
        (await service.getGames('snes', sourceId: romm)).map((g) => g.filename),
        ['Remote.zip'],
      );
      expect(
        (await service.getGames('snes', sourceId: romm, includeLocal: true))
            .map((g) => g.filename),
        ['OnDisk.nes', 'Remote.zip'],
      );
    });
  });

  group('getGamesForRoutes', () {
    test('two routes of one source resolve to one list, not a doubled one',
        () async {
      await save('snes', ['A.zip', 'B.zip'], romm);

      final games = await service.getGamesForRoutes(
        'snes',
        const [(source: romm, endpoint: lan), (source: romm, endpoint: remote)],
        includeLocal: false,
      );

      expect(games.map((g) => g.filename), ['A.zip', 'B.zip']);
    });

    test('a route the source never synced still shows the source list',
        () async {
      // Switching route must not look like an empty library.
      await save('snes', ['A.zip'], romm, endpointId: lan);

      final games = await service.getGamesForRoutes(
        'snes',
        const [(source: romm, endpoint: 'ep-brand-new')],
        includeLocal: false,
      );

      expect(games.map((g) => g.filename), ['A.zip']);
    });

    test('several sources are unioned, and local comes along by default',
        () async {
      await save('snes', ['A.zip'], romm);
      await save('snes', ['B.zip'], smb);
      await service.saveGames('snes', [game('OnDisk.nes')]);

      final games = await service.getGamesForRoutes(
        'snes',
        const [(source: romm, endpoint: lan), (source: smb, endpoint: lan)],
      );

      expect(games.map((g) => g.filename), ['A.zip', 'B.zip', 'OnDisk.nes']);
    });

    test('no routes and no local means no query at all', () async {
      await save('snes', ['A.zip'], romm);

      expect(
        await service.getGamesForRoutes('snes', const [], includeLocal: false),
        isEmpty,
      );
    });
  });

  group('orphan deletion is scoped to one source', () {
    test('syncing one source never deletes another source', () async {
      await save('snes', ['A.zip', 'B.zip', 'C.zip'], smb);
      await save('snes', ['X.zip'], romm, deleteOrphans: true);

      expect(
        (await service.getGames('snes', sourceId: smb)).map((g) => g.filename),
        ['A.zip', 'B.zip', 'C.zip'],
      );
    });

    test('a source prunes its own orphans even when the route changed',
        () async {
      // v14 would have pruned nothing here: the second sync arrived over a
      // different route and so looked like a different list.
      await save('snes', ['A.zip', 'B.zip'], romm, endpointId: lan);
      await save('snes', ['A.zip'], romm,
          endpointId: remote, deleteOrphans: true);

      expect(
        (await service.getGames('snes', sourceId: romm)).map((g) => g.filename),
        ['A.zip'],
      );
    });

    test('local scans do not prune a source, and a source does not prune local',
        () async {
      await save('snes', ['A.zip'], romm);
      await service.saveGames(
        'snes',
        [game('OnDisk.nes')],
        forceDeleteOrphans: true,
      );

      expect(await service.getGames('snes', sourceId: romm), hasLength(1));
      expect(await service.getGames('snes'), hasLength(2));
    });

    test('metadata survives while another source still lists the file',
        () async {
      // game_metadata and ra_matches are keyed by (system, filename) with no
      // source dimension. Cascading on a source-scoped delete would strip the
      // cover and RA progress of a game the other source still shows.
      await save('snes', ['Shared.zip'], romm);
      await save('snes', ['Shared.zip'], smb);
      await db.insert('game_metadata',
          {'filename': 'Shared.zip', 'system_slug': 'snes', 'summary': 'x'});
      await db.insert('ra_matches',
          {'game_filename': 'Shared.zip', 'system_slug': 'snes', 'ra_game_id': 7});

      await save('snes', ['Other.zip'], romm, deleteOrphans: true);

      expect(await db.query('game_metadata'), hasLength(1));
      expect(await db.query('ra_matches'), hasLength(1));
    });

    test('metadata is cascaded once no source lists the file any more',
        () async {
      await save('snes', ['Gone.zip'], romm);
      await db.insert('game_metadata',
          {'filename': 'Gone.zip', 'system_slug': 'snes', 'summary': 'x'});

      await save('snes', ['Other.zip'], romm, deleteOrphans: true);

      expect(await db.query('game_metadata'), isEmpty);
    });
  });

  group('counts — what did this source actually find', () {
    test('getGameCountsPerCacheOwner reports each library once', () async {
      await save('snes', ['A.zip', 'B.zip'], romm, endpointId: lan);
      await save('snes', ['B.zip'], romm, endpointId: remote);
      await save('snes', ['C.zip'], smb);

      expect(await service.getGameCountsPerCacheOwner(), {romm: 2, smb: 1});
    });

    test('the no-source bucket is excluded from per-library counts', () async {
      await save('snes', ['A.zip'], romm);
      await service.saveGames('snes', [game('OnDisk.nes')]);

      expect(await service.getGameCountsPerCacheOwner(), {romm: 1});
    });

    test('getGameCountForOwner answers for one library', () async {
      await save('snes', ['A.zip', 'B.zip'], romm);
      await save('nes', ['C.zip'], romm);

      expect(await service.getGameCountForOwner(romm), 3);
      expect(await service.getGameCountForOwner(smb), 0);
    });
  });

  group('deleteCacheOwnedBy', () {
    test('removes one source and leaves its sibling intact', () async {
      await save('snes', ['A.zip'], romm);
      await save('snes', ['A.zip', 'B.zip'], smb);

      expect(await service.deleteCacheOwnedBy(romm), 1);
      expect(await service.getGames('snes', sourceId: smb), hasLength(2));
    });

    test('refuses an empty source id rather than wiping the local bucket',
        () async {
      await service.saveGames('snes', [game('OnDisk.nes')]);

      expect(await service.deleteCacheOwnedBy(''), 0);
      expect(await service.getGames('snes'), hasLength(1));
    });
  });
}
