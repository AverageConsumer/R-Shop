import 'package:flutter_test/flutter_test.dart';

import 'package:retro_eshop/services/device_info_service.dart';

void main() {
  group('DeviceMemoryInfo', () {
    test('totalGB converts bytes to gigabytes', () {
      const info = DeviceMemoryInfo(
        totalBytes: 4 * 1024 * 1024 * 1024,
        tier: MemoryTier.low,
      );
      expect(info.totalGB, 4.0);
    });

    test('totalGB handles zero bytes', () {
      const info = DeviceMemoryInfo(totalBytes: 0, tier: MemoryTier.low);
      expect(info.totalGB, 0.0);
    });

    test('low tier returns conservative cache values', () {
      const info = DeviceMemoryInfo(totalBytes: 0, tier: MemoryTier.low);
      expect(info.imageCacheMaxBytes, 50 * 1024 * 1024);
      expect(info.imageCacheMaxImages, 500);
      expect(info.memCacheWidthMax, 350);
      expect(info.gridCacheExtent, 200);
      expect(info.libraryCacheExtent, 300);
      expect(info.coverCacheMaxConcurrent, 6);
      expect(info.coverCacheRequestDelayMs, 10);
      expect(info.coverDiskCacheMaxObjects, 5000);
      expect(info.preloadPhase1Pool, 6);
      expect(info.preloadPhase2Pool, 4);
    });

    test('standard tier returns moderate cache values', () {
      const info = DeviceMemoryInfo(totalBytes: 0, tier: MemoryTier.standard);
      expect(info.imageCacheMaxBytes, 80 * 1024 * 1024);
      expect(info.imageCacheMaxImages, 750);
      expect(info.memCacheWidthMax, 400);
      expect(info.gridCacheExtent, 400);
      expect(info.libraryCacheExtent, 600);
      expect(info.coverCacheMaxConcurrent, 6);
      expect(info.coverCacheRequestDelayMs, 10);
      expect(info.coverDiskCacheMaxObjects, 5000);
      expect(info.preloadPhase1Pool, 6);
      expect(info.preloadPhase2Pool, 4);
    });

    test('high tier returns generous cache values', () {
      const info = DeviceMemoryInfo(totalBytes: 0, tier: MemoryTier.high);
      expect(info.imageCacheMaxBytes, 150 * 1024 * 1024);
      expect(info.imageCacheMaxImages, 1500);
      expect(info.memCacheWidthMax, 500);
      expect(info.gridCacheExtent, 600);
      expect(info.libraryCacheExtent, 800);
      expect(info.coverCacheMaxConcurrent, 12);
      expect(info.coverCacheRequestDelayMs, 2);
      expect(info.coverDiskCacheMaxObjects, 10000);
      expect(info.preloadPhase1Pool, 10);
      expect(info.preloadPhase2Pool, 8);
    });

    test('each tier has progressively higher cache limits', () {
      const low = DeviceMemoryInfo(totalBytes: 0, tier: MemoryTier.low);
      const std = DeviceMemoryInfo(totalBytes: 0, tier: MemoryTier.standard);
      const high = DeviceMemoryInfo(totalBytes: 0, tier: MemoryTier.high);

      expect(low.imageCacheMaxBytes, lessThan(std.imageCacheMaxBytes));
      expect(std.imageCacheMaxBytes, lessThan(high.imageCacheMaxBytes));

      expect(low.imageCacheMaxImages, lessThan(std.imageCacheMaxImages));
      expect(std.imageCacheMaxImages, lessThan(high.imageCacheMaxImages));

      expect(low.gridCacheExtent, lessThan(std.gridCacheExtent));
      expect(std.gridCacheExtent, lessThan(high.gridCacheExtent));
    });

    test('high tier has lower request delay for faster loading', () {
      const low = DeviceMemoryInfo(totalBytes: 0, tier: MemoryTier.low);
      const high = DeviceMemoryInfo(totalBytes: 0, tier: MemoryTier.high);

      expect(high.coverCacheRequestDelayMs,
          lessThan(low.coverCacheRequestDelayMs));
    });
  });

  group('DeviceInfoService', () {
    setUp(() {
      DeviceInfoService.resetForTesting();
    });

    test('returns cached result on subsequent calls', () async {
      final first = await DeviceInfoService.getDeviceMemory();
      final second = await DeviceInfoService.getDeviceMemory();
      expect(identical(first, second), true);
    });

    test('non-Android fallback returns high tier with 16GB', () async {
      // Test runs on Linux, not Android
      final info = await DeviceInfoService.getDeviceMemory();
      expect(info.tier, MemoryTier.high);
      expect(info.totalGB, 16.0);
    });

    test('resetForTesting allows re-query', () async {
      final first = await DeviceInfoService.getDeviceMemory();
      DeviceInfoService.resetForTesting();
      final second = await DeviceInfoService.getDeviceMemory();
      // After reset, a new call should still succeed with same values
      expect(first.tier, second.tier);
      expect(first.totalBytes, second.totalBytes);
    });
  });
}
