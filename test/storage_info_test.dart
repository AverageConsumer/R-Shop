import 'package:flutter_test/flutter_test.dart';
import 'package:retro_eshop/services/disk_space_service.dart';

void main() {
  const oneGB = 1024 * 1024 * 1024;
  const fiveGB = 5 * oneGB;

  group('StorageInfo', () {
    test('freeGB calculates correctly', () {
      const info = StorageInfo(freeBytes: 2 * oneGB, totalBytes: 10 * oneGB);
      expect(info.freeGB, closeTo(2.0, 0.01));
    });

    test('totalGB calculates correctly', () {
      const info = StorageInfo(freeBytes: oneGB, totalBytes: 8 * oneGB);
      expect(info.totalGB, closeTo(8.0, 0.01));
    });

    test('usagePercent is (total - free) / total clamped 0-1', () {
      const info = StorageInfo(freeBytes: 2 * oneGB, totalBytes: 10 * oneGB);
      expect(info.usagePercent, closeTo(0.8, 0.01));
    });

    test('usagePercent returns 0 when totalBytes is 0', () {
      const info = StorageInfo(freeBytes: 0, totalBytes: 0);
      expect(info.usagePercent, 0.0);
    });

    test('isLow true when less than 1GB', () {
      const info = StorageInfo(freeBytes: oneGB - 1, totalBytes: 10 * oneGB);
      expect(info.isLow, isTrue);
    });

    test('isLow false when at or above 1GB', () {
      const info = StorageInfo(freeBytes: oneGB, totalBytes: 10 * oneGB);
      expect(info.isLow, isFalse);
    });

    test('isWarning true between 1GB and 5GB', () {
      const info = StorageInfo(freeBytes: 3 * oneGB, totalBytes: 10 * oneGB);
      expect(info.isWarning, isTrue);
    });

    test('isWarning false below 1GB', () {
      const info = StorageInfo(freeBytes: oneGB ~/ 2, totalBytes: 10 * oneGB);
      expect(info.isWarning, isFalse);
    });

    test('isWarning false at 5GB or above', () {
      const info = StorageInfo(freeBytes: fiveGB, totalBytes: 10 * oneGB);
      expect(info.isWarning, isFalse);
    });

    test('isHealthy true at 5GB or above', () {
      const info = StorageInfo(freeBytes: fiveGB, totalBytes: 10 * oneGB);
      expect(info.isHealthy, isTrue);
    });

    test('isHealthy false below 5GB', () {
      const info = StorageInfo(freeBytes: fiveGB - 1, totalBytes: 10 * oneGB);
      expect(info.isHealthy, isFalse);
    });

    test('freeSpaceText shows GB when >= 1GB', () {
      const info = StorageInfo(freeBytes: 2.5 * oneGB ~/ 1, totalBytes: 10 * oneGB);
      expect(info.freeSpaceText, contains('GB free'));
    });

    test('freeSpaceText shows MB when < 1GB', () {
      const info = StorageInfo(freeBytes: 512 * 1024 * 1024, totalBytes: 10 * oneGB);
      expect(info.freeSpaceText, '512 MB free');
    });

    test('boundary: exactly 1GB is isWarning, not isLow', () {
      const info = StorageInfo(freeBytes: oneGB, totalBytes: 10 * oneGB);
      expect(info.isLow, isFalse);
      expect(info.isWarning, isTrue);
    });

    test('boundary: exactly 5GB is isHealthy, not isWarning', () {
      const info = StorageInfo(freeBytes: fiveGB, totalBytes: 10 * oneGB);
      expect(info.isWarning, isFalse);
      expect(info.isHealthy, isTrue);
    });
  });
}
