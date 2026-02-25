import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum MemoryTier { low, standard, high }

class DeviceMemoryInfo {
  final int totalBytes;
  final MemoryTier tier;

  const DeviceMemoryInfo({required this.totalBytes, required this.tier});

  double get totalGB => totalBytes / (1024 * 1024 * 1024);

  int get imageCacheMaxBytes => switch (tier) {
        MemoryTier.low => 50 * 1024 * 1024,
        MemoryTier.standard => 80 * 1024 * 1024,
        MemoryTier.high => 150 * 1024 * 1024,
      };

  int get imageCacheMaxImages => switch (tier) {
        MemoryTier.low => 500,
        MemoryTier.standard => 750,
        MemoryTier.high => 1500,
      };

  int get memCacheWidthMax => switch (tier) {
        MemoryTier.low => 350,
        MemoryTier.standard => 400,
        MemoryTier.high => 500,
      };

  double get gridCacheExtent => switch (tier) {
        MemoryTier.low => 200,
        MemoryTier.standard => 400,
        MemoryTier.high => 600,
      };

  double get libraryCacheExtent => switch (tier) {
        MemoryTier.low => 300,
        MemoryTier.standard => 600,
        MemoryTier.high => 800,
      };

  int get coverCacheMaxConcurrent => switch (tier) {
        MemoryTier.low => 6,
        MemoryTier.standard => 6,
        MemoryTier.high => 12,
      };

  int get coverCacheRequestDelayMs => switch (tier) {
        MemoryTier.low => 10,
        MemoryTier.standard => 10,
        MemoryTier.high => 2,
      };

  int get coverDiskCacheMaxObjects => switch (tier) {
        MemoryTier.low => 5000,
        MemoryTier.standard => 5000,
        MemoryTier.high => 10000,
      };

  int get preloadPhase1Pool => switch (tier) {
        MemoryTier.low => 6,
        MemoryTier.standard => 6,
        MemoryTier.high => 10,
      };

  int get preloadPhase2Pool => switch (tier) {
        MemoryTier.low => 4,
        MemoryTier.standard => 4,
        MemoryTier.high => 8,
      };
}

class DeviceInfoService {
  static const _channel = MethodChannel('com.retro.rshop/storage');
  static DeviceMemoryInfo? _cached;

  static MemoryTier _classify(int totalBytes) {
    final gb = totalBytes / (1024 * 1024 * 1024);
    if (gb <= 4.5) return MemoryTier.low;
    if (gb <= 8.5) return MemoryTier.standard;
    return MemoryTier.high;
  }

  static Future<DeviceMemoryInfo> getDeviceMemory() async {
    if (_cached != null) return _cached!;

    if (!Platform.isAndroid) {
      _cached = const DeviceMemoryInfo(
        totalBytes: 16 * 1024 * 1024 * 1024, // 16GB assumed for desktop
        tier: MemoryTier.high,
      );
      return _cached!;
    }

    try {
      final result = await _channel
          .invokeMapMethod<String, dynamic>('getDeviceMemory');
      if (result != null) {
        final totalBytes = (result['totalBytes'] as num).toInt();
        _cached = DeviceMemoryInfo(
          totalBytes: totalBytes,
          tier: _classify(totalBytes),
        );
        return _cached!;
      }
    } catch (e) {
      debugPrint('DeviceInfoService: failed to get device memory: $e');
    }

    // Fallback: assume low to avoid OOM
    _cached = const DeviceMemoryInfo(totalBytes: 0, tier: MemoryTier.low);
    return _cached!;
  }
}
