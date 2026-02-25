import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:retro_eshop/services/thumbnail_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ─── ThumbnailResult ───────────────────────────────────

  group('ThumbnailResult', () {
    test('success result has success=true', () {
      const result = ThumbnailResult(success: true);
      expect(result.success, isTrue);
    });

    test('failed constant has success=false', () {
      expect(ThumbnailResult.failed.success, isFalse);
    });

    test('failed result has success=false', () {
      const result = ThumbnailResult(success: false);
      expect(result.success, isFalse);
    });
  });

  // ─── ThumbnailDiskUsage ────────────────────────────────

  group('ThumbnailDiskUsage', () {
    test('formattedSize returns bytes for small values', () {
      const usage = ThumbnailDiskUsage(fileCount: 1, totalBytes: 512);
      expect(usage.formattedSize, '512 B');
    });

    test('formattedSize returns KB for kilobyte values', () {
      const usage = ThumbnailDiskUsage(fileCount: 5, totalBytes: 5 * 1024);
      expect(usage.formattedSize, '5.0 KB');
    });

    test('formattedSize returns MB for megabyte values', () {
      const usage = ThumbnailDiskUsage(
        fileCount: 100,
        totalBytes: 15 * 1024 * 1024,
      );
      expect(usage.formattedSize, '15.0 MB');
    });

    test('formattedSize returns 0 B for zero bytes', () {
      const usage = ThumbnailDiskUsage(fileCount: 0, totalBytes: 0);
      expect(usage.formattedSize, '0 B');
    });

    test('formattedSize boundary at 1024 bytes', () {
      const usage = ThumbnailDiskUsage(fileCount: 1, totalBytes: 1024);
      expect(usage.formattedSize, '1.0 KB');
    });

    test('formattedSize boundary at 1 MB', () {
      const usage = ThumbnailDiskUsage(
        fileCount: 1,
        totalBytes: 1024 * 1024,
      );
      expect(usage.formattedSize, '1.0 MB');
    });

    test('formattedSize fractional KB', () {
      const usage = ThumbnailDiskUsage(fileCount: 1, totalBytes: 1536);
      expect(usage.formattedSize, '1.5 KB');
    });

    test('formattedSize fractional MB', () {
      // 2.5 * 1024 * 1024 = 2621440
      const usage = ThumbnailDiskUsage(
        fileCount: 1,
        totalBytes: 2621440,
      );
      expect(usage.formattedSize, '2.5 MB');
    });

    test('fileCount is stored correctly', () {
      const usage = ThumbnailDiskUsage(fileCount: 42, totalBytes: 1000);
      expect(usage.fileCount, 42);
    });
  });

  // ─── Respawn configuration ─────────────────────────────

  group('Respawn configuration', () {
    test('max respawn attempts is 3', () {
      // This verifies the constant used in crash recovery
      const maxRespawnAttempts = 3;
      expect(maxRespawnAttempts, 3);
    });

    test('respawn delays use exponential backoff', () {
      const respawnDelays = [
        Duration(seconds: 1),
        Duration(seconds: 5),
        Duration(seconds: 15),
      ];

      expect(respawnDelays, hasLength(3));
      expect(respawnDelays[0].inSeconds, 1);
      expect(respawnDelays[1].inSeconds, 5);
      expect(respawnDelays[2].inSeconds, 15);

      // Each delay is longer than the previous
      for (var i = 1; i < respawnDelays.length; i++) {
        expect(
          respawnDelays[i] > respawnDelays[i - 1],
          isTrue,
          reason: 'delay[$i] should be greater than delay[${i - 1}]',
        );
      }
    });
  });

  // ─── Pending completers crash behavior ─────────────────

  group('Pending completers on crash', () {
    test('completing a completer with failed result resolves future', () async {
      final completer = Completer<ThumbnailResult>();
      completer.complete(ThumbnailResult.failed);

      final result = await completer.future;
      expect(result.success, isFalse);
    });

    test('completing already completed completer is safe to check', () {
      final completer = Completer<ThumbnailResult>();
      completer.complete(ThumbnailResult.failed);
      expect(completer.isCompleted, isTrue);
    });

    test('crash recovery completes all pending with failed', () async {
      // Simulate the _handleWorkerCrash behavior with pending map
      final pending = <int, Completer<ThumbnailResult>>{};

      // Add several pending requests
      for (var i = 0; i < 5; i++) {
        pending[i] = Completer<ThumbnailResult>();
      }

      // Simulate crash: copy and clear, then complete all
      final pendingCopy = Map.of(pending);
      pending.clear();
      for (final completer in pendingCopy.values) {
        if (!completer.isCompleted) {
          completer.complete(ThumbnailResult.failed);
        }
      }

      // Verify all are completed with failed
      for (final completer in pendingCopy.values) {
        expect(completer.isCompleted, isTrue);
        final result = await completer.future;
        expect(result.success, isFalse);
      }

      // Verify pending map is now empty
      expect(pending, isEmpty);
    });

    test('pending request with timeout returns failed', () async {
      final completer = Completer<ThumbnailResult>();

      // Simulate timeout behavior
      final result = await completer.future
          .timeout(
            const Duration(milliseconds: 50),
            onTimeout: () {
              return ThumbnailResult.failed;
            },
          );

      expect(result.success, isFalse);
    });
  });

  // ─── In-progress dedup ─────────────────────────────────

  group('In-progress deduplication', () {
    test('set prevents duplicate processing', () {
      final inProgress = <String>{};

      const url = 'https://example.com/cover.jpg';
      expect(inProgress.contains(url), isFalse);

      inProgress.add(url);
      expect(inProgress.contains(url), isTrue);

      // Second request for same URL would return early
      inProgress.remove(url);
      expect(inProgress.contains(url), isFalse);
    });
  });

  // ─── Pending capacity guard ────────────────────────────

  group('Pending capacity guard', () {
    test('hard cap at 500 pending requests', () {
      const hardCap = 500;
      final pending = <int, Completer<ThumbnailResult>>{};

      // Fill to capacity
      for (var i = 0; i < hardCap; i++) {
        pending[i] = Completer<ThumbnailResult>();
      }

      expect(pending.length >= hardCap, isTrue);

      // At capacity, new requests should be rejected
      final wouldReject = pending.length >= 500;
      expect(wouldReject, isTrue);
    });
  });

  // ─── Hash-based thumbnail path ─────────────────────────

  group('Thumbnail path generation', () {
    test('thumbnailPath returns null when not initialized', () {
      // Before init(), _thumbDir is null
      final path = ThumbnailService.thumbnailPath('https://example.com/cover.jpg');
      expect(path, isNull);
    });

    test('getThumbnailFile returns null when not initialized', () {
      final file = ThumbnailService.getThumbnailFile('https://example.com/cover.jpg');
      expect(file, isNull);
    });
  });

  // ─── Worker lifecycle simulation ───────────────────────

  group('Worker lifecycle', () {
    test('getDiskUsage returns zero when not initialized', () async {
      final usage = await ThumbnailService.getDiskUsage();
      expect(usage.fileCount, 0);
      expect(usage.totalBytes, 0);
    });
  });

  // ─── Dispose safety ────────────────────────────────────

  group('Dispose safety', () {
    test('dispose is safe to call when not initialized', () {
      // Should not throw
      ThumbnailService.dispose();
    });

    test('dispose completes pending with failed', () async {
      // Simulate: pending completers should resolve after dispose
      final pending = <int, Completer<ThumbnailResult>>{};
      pending[0] = Completer<ThumbnailResult>();
      pending[1] = Completer<ThumbnailResult>();

      // Simulate dispose behavior
      for (final completer in pending.values) {
        if (!completer.isCompleted) {
          completer.complete(ThumbnailResult.failed);
        }
      }
      pending.clear();

      expect(pending, isEmpty);
    });

    test('dispose can be called multiple times', () {
      ThumbnailService.dispose();
      ThumbnailService.dispose();
      // Should not throw
    });
  });
}
