import 'package:flutter_test/flutter_test.dart';
import 'package:retro_eshop/services/download_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // ─── DownloadProgress model ─────────────────────────────

  group('DownloadProgress', () {
    test('displayText shows percentage when totalBytes known', () {
      final p = DownloadProgress(
        status: DownloadStatus.downloading,
        progress: 0.5,
        receivedBytes: 500,
        totalBytes: 1000,
      );
      expect(p.displayText, '50%');
    });

    test('displayText shows MB when totalBytes unknown', () {
      final p = DownloadProgress(
        status: DownloadStatus.downloading,
        progress: 0,
        receivedBytes: 5 * 1024 * 1024, // 5 MB
      );
      expect(p.displayText, '5.0 MB');
    });

    test('displayText for extracting with no progress', () {
      final p = DownloadProgress(
        status: DownloadStatus.extracting,
        progress: 0.0,
      );
      expect(p.displayText, 'Extracting...');
    });

    test('displayText for extracting at 100% shows Extracting...', () {
      final p = DownloadProgress(
        status: DownloadStatus.extracting,
        progress: 1.0,
      );
      expect(p.displayText, 'Extracting...');
    });

    test('displayText for extracting with mid-progress shows percentage', () {
      final p = DownloadProgress(
        status: DownloadStatus.extracting,
        progress: 0.42,
      );
      expect(p.displayText, 'Extracting 42%');
    });

    test('displayText for moving', () {
      final p = DownloadProgress(status: DownloadStatus.moving);
      expect(p.displayText, 'Moving...');
    });

    test('displayText for error', () {
      final p = DownloadProgress(
        status: DownloadStatus.error,
        error: 'Something failed',
      );
      expect(p.displayText, 'Error');
    });

    test('displayText for cancelled', () {
      final p = DownloadProgress(status: DownloadStatus.cancelled);
      expect(p.displayText, 'Cancelled');
    });

    test('speedText returns null when no speed', () {
      final p = DownloadProgress(status: DownloadStatus.downloading);
      expect(p.speedText, isNull);
    });

    test('speedText returns KB/s for low speeds', () {
      final p = DownloadProgress(
        status: DownloadStatus.downloading,
        downloadSpeed: 512,
      );
      expect(p.speedText, '512 KB/s');
    });

    test('speedText returns MB/s for high speeds', () {
      final p = DownloadProgress(
        status: DownloadStatus.downloading,
        downloadSpeed: 2048,
      );
      expect(p.speedText, '2.0 MB/s');
    });

    test('speedText returns null for zero speed', () {
      final p = DownloadProgress(
        status: DownloadStatus.downloading,
        downloadSpeed: 0,
      );
      expect(p.speedText, isNull);
    });

    test('speedText returns null for negative speed', () {
      final p = DownloadProgress(
        status: DownloadStatus.downloading,
        downloadSpeed: -10,
      );
      expect(p.speedText, isNull);
    });
  });

  // ─── DownloadService state management ───────────────────

  group('DownloadService', () {
    late DownloadService service;

    setUp(() {
      service = DownloadService();
    });

    tearDown(() {
      service.dispose();
    });

    test('isDownloadInProgress is false initially', () {
      expect(service.isDownloadInProgress, isFalse);
    });

    test('currentTempFilePath is null initially', () {
      expect(service.currentTempFilePath, isNull);
    });

    test('reset clears state', () {
      service.reset();
      expect(service.isDownloadInProgress, isFalse);
      expect(service.currentTempFilePath, isNull);
    });

    test('cancelDownload is safe to call when idle', () async {
      // Should not throw
      await service.cancelDownload();
      expect(service.isDownloadInProgress, isFalse);
    });

    test('cancelDownload with preserveTempFile is safe when idle', () async {
      await service.cancelDownload(preserveTempFile: true);
      expect(service.isDownloadInProgress, isFalse);
    });

    test('dispose is safe to call multiple times', () {
      service.dispose();
      service.dispose();
    });
  });

  // ─── Orphan temp file cleanup ───────────────────────────

  group('cleanOrphanedTempFiles', () {
    test('does not throw on empty temp dir', () async {
      // Should complete without error
      await DownloadService.cleanOrphanedTempFiles();
    });
  });

  // ─── DownloadStatus enum ────────────────────────────────

  group('DownloadStatus', () {
    test('has all expected values', () {
      expect(DownloadStatus.values, containsAll([
        DownloadStatus.idle,
        DownloadStatus.downloading,
        DownloadStatus.extracting,
        DownloadStatus.moving,
        DownloadStatus.completed,
        DownloadStatus.error,
        DownloadStatus.cancelled,
      ]));
    });
  });

  // ─── Edge cases for displayText ─────────────────────────

  group('DownloadProgress edge cases', () {
    test('downloading with zero totalBytes shows MB format', () {
      final p = DownloadProgress(
        status: DownloadStatus.downloading,
        progress: 0,
        receivedBytes: 0,
        totalBytes: 0,
      );
      expect(p.displayText, '0.0 MB');
    });

    test('downloading at exactly 100% shows 100%', () {
      final p = DownloadProgress(
        status: DownloadStatus.downloading,
        progress: 1.0,
        receivedBytes: 1000,
        totalBytes: 1000,
      );
      expect(p.displayText, '100%');
    });

    test('progress slightly above 0 rounds correctly', () {
      final p = DownloadProgress(
        status: DownloadStatus.downloading,
        progress: 0.004,
        receivedBytes: 4,
        totalBytes: 1000,
      );
      expect(p.displayText, '0%');
    });

    test('speedText at exactly 1024 KB/s shows 1.0 MB/s', () {
      final p = DownloadProgress(
        status: DownloadStatus.downloading,
        downloadSpeed: 1024,
      );
      expect(p.speedText, '1.0 MB/s');
    });

    test('speedText just under 1024 shows KB/s', () {
      final p = DownloadProgress(
        status: DownloadStatus.downloading,
        downloadSpeed: 1023,
      );
      expect(p.speedText, '1023 KB/s');
    });
  });
}
