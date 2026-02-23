import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class StorageInfo {
  final int freeBytes;
  final int totalBytes;

  const StorageInfo({required this.freeBytes, required this.totalBytes});

  double get freeGB => freeBytes / (1024 * 1024 * 1024);
  double get totalGB => totalBytes / (1024 * 1024 * 1024);
  double get usagePercent =>
      totalBytes > 0 ? (totalBytes - freeBytes) / totalBytes : 0;

  /// Less than 1 GB free.
  bool get isLow => freeBytes < 1024 * 1024 * 1024;

  /// Between 1 GB and 5 GB free.
  bool get isWarning =>
      freeBytes >= 1024 * 1024 * 1024 && freeBytes < 5 * 1024 * 1024 * 1024;

  /// More than 5 GB free.
  bool get isHealthy => freeBytes >= 5 * 1024 * 1024 * 1024;

  String get freeSpaceText {
    if (freeGB >= 1.0) {
      return '${freeGB.toStringAsFixed(1)} GB free';
    }
    final mb = freeBytes / (1024 * 1024);
    return '${mb.toStringAsFixed(0)} MB free';
  }
}

class DiskSpaceService {
  static const _channel = MethodChannel('com.retro.rshop/storage');

  static Future<StorageInfo?> getFreeSpace(String path) async {
    if (!Platform.isAndroid) return null;
    try {
      final result =
          await _channel.invokeMapMethod<String, dynamic>('getFreeSpace', {
        'path': path,
      });
      if (result == null) return null;
      return StorageInfo(
        freeBytes: (result['freeBytes'] as num).toInt(),
        totalBytes: (result['totalBytes'] as num).toInt(),
      );
    } catch (e) {
      debugPrint('DiskSpaceService: failed to get free space: $e');
      return null;
    }
  }
}
