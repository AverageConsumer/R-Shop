import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:retro_eshop/models/game_item.dart';
import 'package:retro_eshop/services/database_service.dart';

/// v14 → v15: collapse the per-route copies of a list into one per source.
///
/// This is the only step of v15 that can lose data. The fixture is the real
/// v14 schema and the upgrade is the real `_onUpgrade`, because a migration
/// that throws is an app that cannot open its database at all.
void main() {
  late Database db;
  late DatabaseService service;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    DatabaseService.resetForTesting();
    // The v14 schema exactly as production left it.
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 14,
        onCreate: (db, _) async {
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
          await db.execute(
              'CREATE INDEX idx_games_route ON games (source_id, endpoint_id)');
        },
      ),
    );
    service = DatabaseService();
  });

  tearDown(() async {
    await db.close();
    DatabaseService.resetForTesting();
  });

  Future<void> seed(List<Map<String, Object?>> rows) async {
    for (final row in rows) {
      await db.insert('games', {
        'systemSlug': 'snes',
        'displayName': (row['filename'] as String).replaceAll('.zip', ''),
        'url': 'http://lan/${row['filename']}',
        'provider_config': '{"type":"romm","source_id":"${row['source_id']}"}',
        ...row,
      });
    }
  }

  /// Runs the real upgrade, from v14 to whatever the app ships.
  Future<void> migrate() => service.upgradeForTesting(db, 14);

  test('a v14 install still upgrades through v15 on the way to what ships',
      () {
    // The fixture is v14, so every later step runs in order. Pinning the
    // shipped version here is what proves this file exercises the upgrade
    // users get rather than a path that stopped at v15.
    expect(DatabaseService.schemaVersion, 16);
  });

  test('two routes of one source collapse to a single row', () async {
    await seed([
      {'filename': 'Mario.zip', 'source_id': 'src-a', 'endpoint_id': 'ep-lan'},
      {'filename': 'Mario.zip', 'source_id': 'src-a', 'endpoint_id': 'ep-net'},
      {'filename': 'Zelda.zip', 'source_id': 'src-a', 'endpoint_id': 'ep-lan'},
      {'filename': 'Zelda.zip', 'source_id': 'src-a', 'endpoint_id': 'ep-net'},
    ]);

    await migrate();

    final rows = await db.query('games', orderBy: 'filename');
    expect(rows.map((r) => r['filename']), ['Mario.zip', 'Zelda.zip']);
    // Neither copy is on the device, so the oldest row wins and the surviving
    // endpoint_id is the route that first fetched it.
    expect(rows.map((r) => r['endpoint_id']), ['ep-lan', 'ep-lan']);
  });

  test('three routes of one source collapse to one row', () async {
    await seed([
      for (final ep in ['ep-1', 'ep-2', 'ep-3'])
        {'filename': 'Mario.zip', 'source_id': 'src-a', 'endpoint_id': ep},
    ]);

    await migrate();

    expect(await db.query('games'), hasLength(1));
  });

  test('the copy already on the device wins, even with a later id', () async {
    // purgeOrDetachSource leaves installed games behind with their
    // provider_config and url stripped: that row is the user's downloaded
    // copy, and dropping it makes the library forget a game they own.
    await seed([
      {
        'filename': 'Mario.zip',
        'source_id': 'src-a',
        'endpoint_id': 'ep-lan',
        'url': 'http://lan/Mario.zip',
      },
      {
        'filename': 'Mario.zip',
        'source_id': 'src-a',
        'endpoint_id': 'ep-net',
        'url': '',
        'provider_config': null,
      },
    ]);

    await migrate();

    final row = (await db.query('games')).single;
    expect(row['endpoint_id'], 'ep-net');
    expect(row['provider_config'], isNull);
  });

  test('two on-device copies still collapse, oldest first', () async {
    await seed([
      {
        'filename': 'Mario.zip',
        'source_id': 'src-a',
        'endpoint_id': 'ep-lan',
        'url': '',
        'provider_config': null,
      },
      {
        'filename': 'Mario.zip',
        'source_id': 'src-a',
        'endpoint_id': 'ep-net',
        'url': '',
        'provider_config': null,
      },
    ]);

    await migrate();

    expect((await db.query('games')).single['endpoint_id'], 'ep-lan');
  });

  test('different sources with the same game are left alone', () async {
    await seed([
      {'filename': 'Mario.zip', 'source_id': 'src-a', 'endpoint_id': 'ep-lan'},
      {'filename': 'Mario.zip', 'source_id': 'src-b', 'endpoint_id': 'ep-lan'},
    ]);

    await migrate();

    expect(await db.query('games'), hasLength(2));
  });

  test('the same filename under two systems is left alone', () async {
    await seed([
      {'filename': 'Mario.zip', 'source_id': 'src-a', 'endpoint_id': 'ep-lan'},
      {
        'filename': 'Mario.zip',
        'systemSlug': 'nes',
        'source_id': 'src-a',
        'endpoint_id': 'ep-lan',
      },
    ]);

    await migrate();

    expect(await db.query('games'), hasLength(2));
  });

  test('the local bucket is not swallowed by a source', () async {
    await seed([
      {'filename': 'Mario.zip', 'source_id': 'src-a', 'endpoint_id': 'ep-lan'},
      {
        'filename': 'Mario.zip',
        'source_id': '',
        'endpoint_id': '',
        'url': '',
        'provider_config': null,
      },
    ]);

    await migrate();

    final rows = await db.query('games', orderBy: 'source_id');
    expect(rows.map((r) => r['source_id']), ['', 'src-a']);
  });

  test('covers and thumbnail flags are salvaged onto the survivor', () async {
    // Rebuilding a thumbnail costs a download, and the survivor may be the
    // copy that never had one.
    await seed([
      {
        'filename': 'Mario.zip',
        'source_id': 'src-a',
        'endpoint_id': 'ep-lan',
        'cover_url': null,
        'has_thumbnail': 0,
        'alternative_sources': null,
      },
      {
        'filename': 'Mario.zip',
        'source_id': 'src-a',
        'endpoint_id': 'ep-net',
        'cover_url': 'http://covers/mario.png',
        'has_thumbnail': 1,
        'alternative_sources': '[{"sourceId":"src-b"}]',
      },
    ]);

    await migrate();

    final row = (await db.query('games')).single;
    expect(row['endpoint_id'], 'ep-lan');
    expect(row['cover_url'], 'http://covers/mario.png');
    expect(row['has_thumbnail'], 1);
    expect(row['alternative_sources'], '[{"sourceId":"src-b"}]');
  });

  test('a database with nothing to collapse comes through untouched', () async {
    await seed([
      {
        'filename': 'Mario.zip',
        'source_id': 'src-a',
        'endpoint_id': 'ep-lan',
        'cover_url': 'http://covers/mario.png',
        'has_thumbnail': 1,
      },
      {'filename': 'Zelda.zip', 'source_id': 'src-a', 'endpoint_id': 'ep-lan'},
    ]);

    await migrate();

    final rows = await db.query('games', orderBy: 'filename');
    expect(rows, hasLength(2));
    expect(rows.first['cover_url'], 'http://covers/mario.png');
    expect(rows.first['has_thumbnail'], 1);
  });

  test('an empty database migrates cleanly', () async {
    await migrate();

    expect(await db.query('games'), isEmpty);
  });

  test('the unique key drops endpoint_id and the old one is gone', () async {
    await seed([
      {'filename': 'Mario.zip', 'source_id': 'src-a', 'endpoint_id': 'ep-lan'},
    ]);

    await migrate();

    final names = (await db.rawQuery('PRAGMA index_list(games)'))
        .map((r) => r['name'] as String)
        .toSet();
    expect(names, isNot(contains('idx_games_system_filename_route')));
    expect(names, isNot(contains('idx_games_dedupe_tmp')));
    // v16 re-keys again, from the source to the cache owner; the shape it
    // arrives in is that file's business. What matters here is that the route
    // key is gone and its scratch index cleaned up.

    // endpoint_id stays as a column — it still records the last route used.
    final tableCols = await db.rawQuery('PRAGMA table_info(games)');
    expect(tableCols.map((r) => r['name']), contains('endpoint_id'));
  });

  test('after migrating, a re-sync over a third route updates in place',
      () async {
    await seed([
      {'filename': 'Mario.zip', 'source_id': 'src-a', 'endpoint_id': 'ep-lan'},
      {'filename': 'Mario.zip', 'source_id': 'src-a', 'endpoint_id': 'ep-net'},
    ]);

    await migrate();
    DatabaseService.testDatabase = db;
    await service.saveGames(
      'snes',
      [
        const GameItem(
          filename: 'Mario.zip',
          displayName: 'Mario',
          url: 'http://third/Mario.zip',
        ),
      ],
      sourceId: 'src-a',
      endpointId: 'ep-third',
    );

    final rows = await db.query('games');
    expect(rows, hasLength(1));
    expect(rows.single['endpoint_id'], 'ep-third');
    expect(rows.single['url'], 'http://third/Mario.zip');
  });
}
