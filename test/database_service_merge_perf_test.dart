import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:retro_eshop/services/database_service.dart';

/// Joining a group on a **real-sized** library, which is the only size at
/// which this ever went wrong.
///
/// The merge drops the unique index to re-stamp the owner column, and that
/// index is also the only thing backing the de-duplication self-join. Without
/// a replacement the join degrades to a scan per row: this took **over ten
/// minutes** on 65k rows, and on the device the tap that started it simply
/// looked dead. The guard is the elapsed time, not the row count — a correct
/// but quadratic merge passes every other test in this repo.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('joining a group with 65k cached games stays interactive', () async {
    DatabaseService.resetForTesting();
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 16,
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
              endpoint_id TEXT NOT NULL DEFAULT '',
              cache_owner_id TEXT NOT NULL DEFAULT ''
            )
          ''');
          await db.execute(
              'CREATE UNIQUE INDEX idx_games_system_filename_owner ON games (systemSlug, filename, cache_owner_id)');
          await db.execute('CREATE INDEX idx_games_owner ON games (cache_owner_id)');
          await db.execute('CREATE INDEX idx_games_source ON games (source_id)');
        },
      ),
    );
    DatabaseService.testDatabase = db;
    final service = DatabaseService();

    // 60k rows in one library, 5k in the one joining it.
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (var i = 0; i < 60000; i++) {
        batch.insert('games', {
          'systemSlug': 'snes',
          'filename': 'Game$i.zip',
          'displayName': 'Game $i',
          'url': 'http://lan/Game$i.zip',
          'provider_config': '{"source_id":"lan"}',
          'source_id': 'lan',
          'cache_owner_id': 'lan',
        });
      }
      for (var i = 0; i < 5000; i++) {
        batch.insert('games', {
          'systemSlug': 'snes',
          'filename': 'Game$i.zip', // overlaps: same server, same games
          'displayName': 'Game $i',
          'url': 'http://wan/Game$i.zip',
          'provider_config': '{"source_id":"wan"}',
          'source_id': 'wan',
          'cache_owner_id': 'wan',
        });
      }
      await batch.commit(noResult: true);
    });

    final sw = Stopwatch()..start();
    final collapsed =
        await service.adoptCacheInto(ownerId: 'lan', memberIds: ['wan']);
    sw.stop();

    expect(collapsed, 5000);
    expect(await service.getGameCountForOwner('lan'), 60000);
    // Generous on purpose: it runs in well under a second with the index and
    // in minutes without it, so anything in between is still a red flag
    // without making the test flaky on a busy machine.
    expect(
      sw.elapsed,
      lessThan(const Duration(seconds: 30)),
      reason: 'the merge lost its index — see the doc comment',
    );
    await db.close();
    DatabaseService.resetForTesting();
  }, timeout: const Timeout(Duration(minutes: 10)));
}
