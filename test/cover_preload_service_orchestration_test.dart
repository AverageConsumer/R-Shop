import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:retro_eshop/services/cover_preload_service.dart';
import 'package:retro_eshop/services/database_service.dart';

// ---------------------------------------------------------------------------
// Testable subclass: overrides processWithCoverUrl / processWithoutCoverUrl
// so tests don't need real network, cache, or thumbnail workers.
// ---------------------------------------------------------------------------

class _TestableCoverPreloadService extends CoverPreloadService {
  final List<String> phase1Calls = [];
  final List<String> phase2Calls = [];
  bool phase1Result = true;
  bool phase2Result = true;
  Duration? phase1Delay;
  Duration? phase2Delay;

  /// Track call order across phases
  final List<String> callOrder = [];

  @override
  Future<bool> processWithCoverUrl({
    required DatabaseService db,
    required String filename,
    required String coverUrl,
  }) async {
    if (phase1Delay != null) {
      await Future.delayed(phase1Delay!);
    }
    phase1Calls.add(filename);
    callOrder.add('p1:$filename');
    return phase1Result;
  }

  @override
  Future<bool> processWithoutCoverUrl({
    required DatabaseService db,
    required String filename,
    required String systemSlug,
    required Map systemMap,
  }) async {
    if (phase2Delay != null) {
      await Future.delayed(phase2Delay!);
    }
    phase2Calls.add(filename);
    callOrder.add('p2:$filename');
    return phase2Result;
  }
}

void main() {
  late Database db;
  late DatabaseService dbService;

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
          await db.execute(
              'CREATE INDEX idx_systemSlug ON games (systemSlug)');
          await db.execute(
              'CREATE INDEX idx_displayName ON games (displayName)');
          await db.execute(
              'CREATE INDEX idx_filename ON games (filename)');
        },
      ),
    );
    DatabaseService.testDatabase = db;
    dbService = DatabaseService();
  });

  tearDown(() async {
    DatabaseService.resetForTesting();
    await db.close();
  });

  // Helper to insert a test game row
  Future<void> insertGame(String filename, String systemSlug,
      {String? coverUrl}) async {
    await db.insert('games', {
      'systemSlug': systemSlug,
      'filename': filename,
      'displayName': filename,
      'url': '',
      'has_thumbnail': 0,
      if (coverUrl != null) 'cover_url': coverUrl,
    });
  }

  // ─── preloadAll orchestration ──────────────────────────────────

  group('preloadAll orchestration', () {
    test('double-start guard (returns if already running)', () async {
      final svc = _TestableCoverPreloadService();
      svc.phase1Delay = const Duration(milliseconds: 50);

      await insertGame('game1.gba', 'gba', coverUrl: 'http://example.com/1');

      final first = svc.preloadAll(dbService);

      // Second call while running — should return immediately
      await svc.preloadAll(dbService);

      await first;
      // Only one run processed the item
      expect(svc.phase1Calls.length, 1);
    });

    test('empty rows → resets state, returns immediately', () async {
      final svc = _TestableCoverPreloadService();

      await svc.preloadAll(dbService);

      expect(svc.state.isRunning, isFalse);
      expect(svc.state.total, 0);
      expect(svc.phase1Calls, isEmpty);
      expect(svc.phase2Calls, isEmpty);
    });

    test('partitions phase1 (has cover_url) vs phase2 (no cover_url)',
        () async {
      final svc = _TestableCoverPreloadService();

      await insertGame('with_cover.gba', 'gba', coverUrl: 'http://example.com/cover');
      await insertGame('no_cover.gba', 'gba');

      await svc.preloadAll(dbService);

      expect(svc.phase1Calls, ['with_cover.gba']);
      expect(svc.phase2Calls, ['no_cover.gba']);
    });

    test('sets total = row count', () async {
      final svc = _TestableCoverPreloadService();

      await insertGame('a.gba', 'gba', coverUrl: 'http://a');
      await insertGame('b.gba', 'gba');
      await insertGame('c.gba', 'gba', coverUrl: 'http://c');

      await svc.preloadAll(dbService);

      // After completion, total should equal the row count
      expect(svc.state.total, 3);
    });

    test('runs phase1 before phase2 (track call order)', () async {
      final svc = _TestableCoverPreloadService();

      await insertGame('first.gba', 'gba', coverUrl: 'http://first');
      await insertGame('second.gba', 'gba');

      await svc.preloadAll(dbService, phase1Pool: 1, phase2Pool: 1);

      // All phase1 calls should come before phase2 calls
      final phase1Indices =
          svc.callOrder.where((c) => c.startsWith('p1:')).toList();
      final phase2Indices =
          svc.callOrder.where((c) => c.startsWith('p2:')).toList();

      expect(phase1Indices, isNotEmpty);
      expect(phase2Indices, isNotEmpty);

      final lastPhase1 = svc.callOrder.lastIndexOf(phase1Indices.last);
      final firstPhase2 = svc.callOrder.indexOf(phase2Indices.first);
      expect(lastPhase1, lessThan(firstPhase2));
    });

    test('skips phase2 when cancelled during phase1', () async {
      final svc = _TestableCoverPreloadService();
      // Delay phase1 so we can cancel mid-way
      svc.phase1Delay = const Duration(milliseconds: 10);

      await insertGame('a.gba', 'gba', coverUrl: 'http://a');
      await insertGame('b.gba', 'gba', coverUrl: 'http://b');
      await insertGame('c.gba', 'gba'); // phase2

      final future = svc.preloadAll(dbService, phase1Pool: 1, phase2Pool: 1);

      // Give phase1 a moment to start
      await Future.delayed(const Duration(milliseconds: 5));
      svc.cancel();

      await future;

      // Phase2 should not have been called (or only partially)
      expect(svc.phase2Calls, isEmpty);
    });

    test('sets isRunning=false on completion', () async {
      final svc = _TestableCoverPreloadService();
      await insertGame('game.gba', 'gba', coverUrl: 'http://cover');

      await svc.preloadAll(dbService);

      expect(svc.state.isRunning, isFalse);
    });
  });

  // ─── worker pool ───────────────────────────────────────────────

  group('worker pool', () {
    test('spawns min(poolSize, items.length) workers', () async {
      final svc = _TestableCoverPreloadService();
      // Add just 2 items, pool size 6 — should spawn only 2 workers
      await insertGame('a.gba', 'gba', coverUrl: 'http://a');
      await insertGame('b.gba', 'gba', coverUrl: 'http://b');

      await svc.preloadAll(dbService, phase1Pool: 6, phase2Pool: 4);

      expect(svc.phase1Calls.length, 2);
    });

    test('all items processed exactly once (no duplicates)', () async {
      final svc = _TestableCoverPreloadService();

      for (int i = 0; i < 10; i++) {
        await insertGame('game_$i.gba', 'gba', coverUrl: 'http://cover_$i');
      }

      await svc.preloadAll(dbService, phase1Pool: 4, phase2Pool: 2);

      // Each of the 10 games should be processed exactly once
      expect(svc.phase1Calls.length, 10);
      expect(svc.phase1Calls.toSet().length, 10);
    });

    test('state counters correct: succeeded + failed = completed = total',
        () async {
      final svc = _TestableCoverPreloadService();
      svc.phase1Result = true;

      for (int i = 0; i < 5; i++) {
        await insertGame('game_$i.gba', 'gba', coverUrl: 'http://cover_$i');
      }

      await svc.preloadAll(dbService, phase1Pool: 2, phase2Pool: 1);

      expect(svc.state.completed, svc.state.total);
      expect(svc.state.succeeded + svc.state.failed, svc.state.completed);
    });

    test('cancel stops remaining items', () async {
      final svc = _TestableCoverPreloadService();
      svc.phase1Delay = const Duration(milliseconds: 20);

      for (int i = 0; i < 20; i++) {
        await insertGame('game_$i.gba', 'gba', coverUrl: 'http://cover_$i');
      }

      final future = svc.preloadAll(dbService, phase1Pool: 1, phase2Pool: 1);

      // Let a few items process, then cancel
      await Future.delayed(const Duration(milliseconds: 50));
      svc.cancel();

      await future;

      // Not all 20 should be processed
      expect(svc.phase1Calls.length, lessThan(20));
    });

    test('all-success: succeeded == total, failed == 0', () async {
      final svc = _TestableCoverPreloadService();
      svc.phase1Result = true;

      for (int i = 0; i < 3; i++) {
        await insertGame('game_$i.gba', 'gba', coverUrl: 'http://cover_$i');
      }

      await svc.preloadAll(dbService, phase1Pool: 2, phase2Pool: 1);

      expect(svc.state.succeeded, 3);
      expect(svc.state.failed, 0);
    });

    test('all-failure: failed == total, succeeded == 0', () async {
      final svc = _TestableCoverPreloadService();
      svc.phase1Result = false;

      for (int i = 0; i < 3; i++) {
        await insertGame('game_$i.gba', 'gba', coverUrl: 'http://cover_$i');
      }

      await svc.preloadAll(dbService, phase1Pool: 2, phase2Pool: 1);

      expect(svc.state.failed, 3);
      expect(svc.state.succeeded, 0);
    });
  });

  // ─── cancel ────────────────────────────────────────────────────

  group('cancel', () {
    test('cancel() stops active workers', () async {
      final svc = _TestableCoverPreloadService();
      svc.phase1Delay = const Duration(milliseconds: 30);

      for (int i = 0; i < 10; i++) {
        await insertGame('game_$i.gba', 'gba', coverUrl: 'http://cover_$i');
      }

      final future = svc.preloadAll(dbService, phase1Pool: 1, phase2Pool: 1);
      await Future.delayed(const Duration(milliseconds: 40));
      svc.cancel();
      await future;

      expect(svc.phase1Calls.length, lessThan(10));
    });

    test('cancel before start is no-op', () {
      final svc = _TestableCoverPreloadService();
      // Should not throw
      svc.cancel();
      expect(svc.state.isRunning, isFalse);
    });

    test('state reflects partial completion after cancel', () async {
      final svc = _TestableCoverPreloadService();
      svc.phase1Delay = const Duration(milliseconds: 20);

      for (int i = 0; i < 10; i++) {
        await insertGame('game_$i.gba', 'gba', coverUrl: 'http://cover_$i');
      }

      final future = svc.preloadAll(dbService, phase1Pool: 1, phase2Pool: 1);
      await Future.delayed(const Duration(milliseconds: 50));
      svc.cancel();
      await future;

      expect(svc.state.completed, lessThan(svc.state.total));
      expect(svc.state.isRunning, isFalse);
    });
  });

  // ─── edge cases ────────────────────────────────────────────────

  group('edge cases', () {
    test('pool size 0 clamped to 1', () async {
      final svc = _TestableCoverPreloadService();

      await insertGame('game.gba', 'gba', coverUrl: 'http://cover');

      // phase1Pool = 0 should still work (clamped to 1)
      await svc.preloadAll(dbService, phase1Pool: 0, phase2Pool: 0);

      expect(svc.phase1Calls.length, 1);
    });

    test('single item with pool > 1 works correctly', () async {
      final svc = _TestableCoverPreloadService();

      await insertGame('only.gba', 'gba', coverUrl: 'http://only');

      await svc.preloadAll(dbService, phase1Pool: 6, phase2Pool: 4);

      expect(svc.phase1Calls.length, 1);
      expect(svc.state.completed, 1);
      expect(svc.state.total, 1);
    });
  });
}
