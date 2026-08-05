import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:retro_eshop/models/game_item.dart';
import 'package:retro_eshop/models/config/provider_config.dart';
import 'package:retro_eshop/services/database_service.dart';

/// v15 → v16: the cached library moves from the source to the **cache owner**,
/// so a group of sources holds one list instead of one per member.
///
/// The migration itself must not lose a row — it only backfills the new column
/// from `source_id` and re-keys the unique index. The merging happens later, in
/// [DatabaseService.adoptCacheInto], because groups live in the config file and
/// this layer cannot read it; a migration that guessed at them would be a
/// migration that deletes rows on a guess.
void main() {
  late Database db;
  late DatabaseService service;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    DatabaseService.resetForTesting();
    // The v15 schema exactly as production left it.
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 15,
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
              'CREATE UNIQUE INDEX idx_games_system_filename_source ON games (systemSlug, filename, source_id)');
          await db.execute('CREATE INDEX idx_games_source ON games (source_id)');
          await db.execute('''
            CREATE TABLE game_metadata (
              filename TEXT NOT NULL,
              system_slug TEXT NOT NULL,
              summary TEXT,
              genres TEXT,
              developer TEXT,
              publisher TEXT,
              release_date TEXT,
              rating REAL,
              players TEXT,
              last_updated INTEGER NOT NULL,
              PRIMARY KEY (filename, system_slug)
            )
          ''');
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
        'endpoint_id': 'ep-lan',
        ...row,
      });
    }
  }

  Future<void> migrate() => service.upgradeForTesting(db, 15);

  GameItem game(String filename, {String? sourceId}) => GameItem(
        filename: filename,
        displayName: filename.replaceAll('.zip', ''),
        url: 'http://lan/$filename',
        providerConfig: sourceId == null
            ? null
            : ProviderConfig(
                type: ProviderType.romm,
                priority: 0,
                url: 'http://lan',
                sourceId: sourceId,
              ),
      );

  group('the migration', () {
    test('every source keeps its own library', () async {
      await seed([
        {'filename': 'Mario.zip', 'source_id': 'src-a'},
        {'filename': 'Zelda.zip', 'source_id': 'src-a'},
        {'filename': 'Mario.zip', 'source_id': 'src-b'},
      ]);

      await migrate();

      final rows = await db.query('games', orderBy: 'source_id, filename');
      expect(rows, hasLength(3));
      // One-to-one: no source's rows moved and none were dropped.
      expect(
        rows.map((r) => r['cache_owner_id']),
        ['src-a', 'src-a', 'src-b'],
      );
    });

    test('the local bucket stays in the no-owner bucket', () async {
      await seed([
        {
          'filename': 'OnDisk.nes',
          'source_id': '',
          'url': '',
          'provider_config': null,
        },
      ]);

      await migrate();

      expect((await db.query('games')).single['cache_owner_id'], '');
    });

    test('the unique key moves to the owner and the old one is gone', () async {
      await migrate();

      final names = (await db.rawQuery('PRAGMA index_list(games)'))
          .map((r) => r['name'] as String)
          .toSet();
      expect(names, contains('idx_games_system_filename_owner'));
      expect(names, contains('idx_games_owner'));
      expect(names, isNot(contains('idx_games_system_filename_source')));
      // Still indexed: re-stamping a departing member and purgeOrDetachSource
      // both look rows up by the source that fetched them.
      expect(names, contains('idx_games_source'));

      final cols = await db
          .rawQuery('PRAGMA index_info(idx_games_system_filename_owner)');
      expect(cols.map((r) => r['name']),
          ['systemSlug', 'filename', 'cache_owner_id']);
    });

    test('an empty database migrates cleanly', () async {
      await migrate();

      expect(await db.query('games'), isEmpty);
    });

    test('a re-sync after migrating updates in place rather than duplicating',
        () async {
      await seed([
        {'filename': 'Mario.zip', 'source_id': 'src-a'},
      ]);

      await migrate();
      DatabaseService.testDatabase = db;
      await service.saveGames(
        'snes',
        [game('Mario.zip', sourceId: 'src-a')],
        sourceId: 'src-a',
        endpointId: 'ep-net',
      );

      final rows = await db.query('games');
      expect(rows, hasLength(1));
      expect(rows.single['endpoint_id'], 'ep-net');
      expect(rows.single['cache_owner_id'], 'src-a');
    });
  });

  group('adoptCacheInto — joining a group', () {
    setUp(() async {
      await migrate();
      DatabaseService.testDatabase = db;
    });

    test('the members end up sharing one list', () async {
      await service.saveGames('snes', [game('Mario.zip'), game('Zelda.zip')],
          sourceId: 'src-a');
      await service.saveGames('snes', [game('Metroid.zip')], sourceId: 'src-b');

      await service.adoptCacheInto(ownerId: 'src-a', memberIds: ['src-b']);

      expect(await service.getGameCountForOwner('src-a'), 3);
      expect(await service.getGameCountForOwner('src-b'), 0);
      expect(
        (await service.getGames('snes', cacheOwnerId: 'src-a'))
            .map((g) => g.filename),
        ['Mario.zip', 'Metroid.zip', 'Zelda.zip'],
      );
    });

    test('the same game held by both members collapses to one row', () async {
      await service.saveGames('snes', [game('Mario.zip')], sourceId: 'src-a');
      await service.saveGames('snes', [game('Mario.zip')], sourceId: 'src-b');

      final collapsed =
          await service.adoptCacheInto(ownerId: 'src-a', memberIds: ['src-b']);

      expect(collapsed, 1);
      expect(await service.getGameCountForOwner('src-a'), 1);
    });

    test('the copy already on the device survives the collapse', () async {
      // purgeOrDetachSource leaves an installed game behind with its
      // provider_config and url stripped. That row is the user's downloaded
      // copy; dropping it makes the library forget a game they own.
      await service.saveGames('snes', [game('Mario.zip')], sourceId: 'src-a');
      await service.saveGames('snes', [game('Mario.zip')], sourceId: 'src-b');
      await db.update(
        'games',
        {'provider_config': null, 'url': ''},
        where: 'source_id = ?',
        whereArgs: ['src-b'],
      );

      await service.adoptCacheInto(ownerId: 'src-a', memberIds: ['src-b']);

      final row = (await db.query('games')).single;
      expect(row['provider_config'], isNull);
      expect(row['cache_owner_id'], 'src-a');
    });

    test('covers and thumbnails are salvaged onto the survivor', () async {
      await service.saveGames('snes', [game('Mario.zip')], sourceId: 'src-a');
      await service.saveGames('snes', [game('Mario.zip')], sourceId: 'src-b');
      await db.update(
        'games',
        {'cover_url': 'http://covers/mario.png', 'has_thumbnail': 1},
        where: 'source_id = ?',
        whereArgs: ['src-b'],
      );

      await service.adoptCacheInto(ownerId: 'src-a', memberIds: ['src-b']);

      final row = (await db.query('games')).single;
      expect(row['cover_url'], 'http://covers/mario.png');
      expect(row['has_thumbnail'], 1);
    });

    test('a third member folds in later without disturbing the first two',
        () async {
      await service.saveGames('snes', [game('Mario.zip')], sourceId: 'src-a');
      await service.saveGames('snes', [game('Zelda.zip')], sourceId: 'src-b');
      await service.adoptCacheInto(ownerId: 'src-a', memberIds: ['src-b']);

      await service.saveGames('snes', [game('Metroid.zip')], sourceId: 'src-c');
      await service.adoptCacheInto(ownerId: 'src-a', memberIds: ['src-c']);

      expect(await service.getGameCountForOwner('src-a'), 3);
    });

    test('sources outside the group are untouched', () async {
      await service.saveGames('snes', [game('Mario.zip')], sourceId: 'src-a');
      await service.saveGames('snes', [game('Mario.zip')], sourceId: 'src-b');
      await service.saveGames('snes', [game('Mario.zip')], sourceId: 'other');

      await service.adoptCacheInto(ownerId: 'src-a', memberIds: ['src-b']);

      expect(await service.getGameCountForOwner('other'), 1);
    });

    test('the local bucket is never adopted', () async {
      await service.saveGames('snes', [game('OnDisk.nes')]);
      await service.saveGames('snes', [game('Mario.zip')], sourceId: 'src-a');

      await service.adoptCacheInto(ownerId: 'src-a', memberIds: ['', 'src-b']);

      expect(await service.getGames('snes', cacheOwnerId: ''), hasLength(1));
    });

    test('adopting into itself is a no-op', () async {
      await service.saveGames('snes', [game('Mario.zip')], sourceId: 'src-a');

      expect(
        await service.adoptCacheInto(ownerId: 'src-a', memberIds: ['src-a']),
        0,
      );
      expect(await service.getGameCountForOwner('src-a'), 1);
    });

    test('the unique index is back afterwards, so a re-sync still upserts',
        () async {
      await service.saveGames('snes', [game('Mario.zip')], sourceId: 'src-a');
      await service.saveGames('snes', [game('Mario.zip')], sourceId: 'src-b');
      await service.adoptCacheInto(ownerId: 'src-a', memberIds: ['src-b']);

      final names = (await db.rawQuery('PRAGMA index_list(games)'))
          .map((r) => r['name'] as String)
          .toSet();
      expect(names, contains('idx_games_system_filename_owner'));

      // Re-syncing over the other member writes into the same row.
      await service.saveGames('snes', [game('Mario.zip')],
          sourceId: 'src-b', cacheOwnerId: 'src-a');
      expect(await service.getGameCountForOwner('src-a'), 1);
    });
  });

  group('leaving a group', () {
    setUp(() async {
      await migrate();
      DatabaseService.testDatabase = db;
      // Both rows carry the provider_config blob a real sync writes: it names
      // the source that fetched them, which is what purgeOrDetachSource
      // matches on and therefore what the guard has to survive.
      await service.saveGames('snes', [game('Mario.zip', sourceId: 'src-a')],
          sourceId: 'src-a');
      await service.saveGames('snes', [game('Zelda.zip', sourceId: 'src-b')],
          sourceId: 'src-b');
      await service.adoptCacheInto(ownerId: 'src-a', memberIds: ['src-b']);
    });

    test('moveCacheOwnership hands the whole list to the new owner', () async {
      await service.moveCacheOwnership(
          fromOwnerId: 'src-a', toOwnerId: 'src-b');

      expect(await service.getGameCountForOwner('src-b'), 2);
      expect(await service.getGameCountForOwner('src-a'), 0);
    });

    test('moveCacheOwnership collapses what the move makes duplicate',
        () async {
      // src-b left the group earlier and re-synced a list of its own.
      await service.saveGames('snes', [game('Mario.zip')],
          sourceId: 'src-b', cacheOwnerId: 'src-b');

      await service.moveCacheOwnership(
          fromOwnerId: 'src-a', toOwnerId: 'src-b');

      expect(await service.getGameCountForOwner('src-b'), 2);
    });

    test('releaseCacheFrom leaves the list with the group', () async {
      await service.releaseCacheFrom(sourceId: 'src-b', ownerId: 'src-a');

      expect(await service.getGameCountForOwner('src-a'), 2);
      // The leaver has nothing: there is no honest way to split rows nothing
      // recorded the origin of, so it re-syncs.
      expect(await service.getGameCountForOwner('src-b'), 0);
    });

    test('releaseCacheFrom re-stamps attribution to the owner', () async {
      await service.releaseCacheFrom(sourceId: 'src-b', ownerId: 'src-a');

      final sources = (await db.query('games', columns: ['source_id']))
          .map((r) => r['source_id'])
          .toSet();
      expect(sources, {'src-a'});
    });

    test('removing the departed source cannot take the group rows with it',
        () async {
      // Attribution is re-stamped, but the provider_config blob still names
      // src-b — that is what protectedOwnerIds is for.
      final result = await service.purgeOrDetachSource(
        'src-b',
        systemTargetFolders: const {},
        protectedOwnerIds: const {'src-a'},
      );

      expect(result.deleted, 0);
      expect(await service.getGameCountForOwner('src-a'), 2);
    });

    test('without the guard, removing it does take them', () async {
      final result = await service.purgeOrDetachSource(
        'src-b',
        systemTargetFolders: const {},
      );

      expect(result.deleted, 1);
    });
  });
}
