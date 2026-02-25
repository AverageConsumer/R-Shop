import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:retro_eshop/services/image_cache_service.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('image_cache_test_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
    FailedUrlsCache.instance.clear();
  });

  File createTempFile(String name, List<int> bytes) {
    final file = File('${tempDir.path}/$name');
    file.writeAsBytesSync(bytes);
    return file;
  }

  group('isValidImageFile', () {
    test('recognizes PNG', () {
      final file = createTempFile('test.png', [
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00,
        0x0D,
      ]);
      expect(isValidImageFile(file), isTrue);
    });

    test('recognizes JPEG', () {
      final file = createTempFile('test.jpg', [
        0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00,
        0x01,
      ]);
      expect(isValidImageFile(file), isTrue);
    });

    test('recognizes GIF', () {
      final file = createTempFile('test.gif', [
        0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 0x01, 0x00, 0x01, 0x00, 0x80,
        0x00,
      ]);
      expect(isValidImageFile(file), isTrue);
    });

    test('recognizes WebP', () {
      // RIFF....WEBP
      final file = createTempFile('test.webp', [
        0x52, 0x49, 0x46, 0x46, // RIFF
        0x24, 0x00, 0x00, 0x00, // file size
        0x57, 0x45, 0x42, 0x50, // WEBP
      ]);
      expect(isValidImageFile(file), isTrue);
    });

    test('returns false for file < 12 bytes', () {
      final file = createTempFile('tiny.bin', [0x89, 0x50, 0x4E]);
      expect(isValidImageFile(file), isFalse);
    });

    test('returns false for empty file', () {
      final file = createTempFile('empty.bin', []);
      expect(isValidImageFile(file), isFalse);
    });

    test('returns false for HTML error page', () {
      const html = '<!DOCTYPE html><html><body>404</body></html>';
      final file = createTempFile('error.html', html.codeUnits);
      expect(isValidImageFile(file), isFalse);
    });

    test('returns false for random bytes', () {
      final file = createTempFile('random.bin', [
        0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B,
        0x0C,
      ]);
      expect(isValidImageFile(file), isFalse);
    });

    test('returns false for non-existent file', () {
      final file = File('${tempDir.path}/does_not_exist.png');
      expect(isValidImageFile(file), isFalse);
    });

    test('returns false for file with only PNG start but too short', () {
      final file = createTempFile('short_png.bin', [
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00,
      ]);
      expect(isValidImageFile(file), isFalse);
    });
  });

  group('FailedUrlsCache', () {
    test('markFailed + hasFailed returns true', () {
      FailedUrlsCache.instance.markFailed('https://example.com/image.png');
      expect(
        FailedUrlsCache.instance.hasFailed('https://example.com/image.png'),
        isTrue,
      );
    });

    test('hasFailed returns false for unknown URL', () {
      expect(
        FailedUrlsCache.instance.hasFailed('https://unknown.com/image.png'),
        isFalse,
      );
    });

    test('clear resets all entries', () {
      FailedUrlsCache.instance.markFailed('https://example.com/a.png');
      FailedUrlsCache.instance.markFailed('https://example.com/b.png');
      FailedUrlsCache.instance.clear();
      expect(
        FailedUrlsCache.instance.hasFailed('https://example.com/a.png'),
        isFalse,
      );
      expect(
        FailedUrlsCache.instance.hasFailed('https://example.com/b.png'),
        isFalse,
      );
    });

    test('multiple URLs tracked independently', () {
      FailedUrlsCache.instance.markFailed('https://example.com/a.png');
      expect(
        FailedUrlsCache.instance.hasFailed('https://example.com/a.png'),
        isTrue,
      );
      expect(
        FailedUrlsCache.instance.hasFailed('https://example.com/b.png'),
        isFalse,
      );
    });

    test('hard cap: >1000 entries trims to 500', () {
      for (int i = 0; i < 1001; i++) {
        FailedUrlsCache.instance.markFailed('https://example.com/$i.png');
      }
      // After the 1001st entry, oldest should be trimmed
      // The first entries should be gone (trimmed to newest 500)
      // Entry 0 was the oldest → should be gone
      expect(
        FailedUrlsCache.instance.hasFailed('https://example.com/0.png'),
        isFalse,
      );
      // The last entry should still be there
      expect(
        FailedUrlsCache.instance.hasFailed('https://example.com/1000.png'),
        isTrue,
      );
    });

    test('markFailed overwrites existing timestamp', () {
      FailedUrlsCache.instance.markFailed('https://example.com/a.png');
      // Mark again — should not throw or create duplicate
      FailedUrlsCache.instance.markFailed('https://example.com/a.png');
      expect(
        FailedUrlsCache.instance.hasFailed('https://example.com/a.png'),
        isTrue,
      );
    });
  });
}
