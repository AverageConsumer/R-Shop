import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SmbFileEntry {
  final String name;
  final String path;
  final bool isDirectory;
  final int size;
  final String? parentPath;

  const SmbFileEntry({
    required this.name,
    required this.path,
    required this.isDirectory,
    required this.size,
    this.parentPath,
  });
}

class NativeSmbService {
  static const _channel = MethodChannel('com.retro.rshop/smb');
  static const _progressChannel = EventChannel('com.retro.rshop/smb_progress');

  Stream<Map<String, dynamic>>? _progressStream;

  Stream<Map<String, dynamic>> get progressStream {
    _progressStream ??= _progressChannel
        .receiveBroadcastStream()
        .where((event) => event is Map)
        .map((event) => Map<String, dynamic>.from(event as Map))
        .asBroadcastStream();
    return _progressStream!;
  }

  Future<({bool success, String? error})> testConnection({
    required String host,
    int port = 445,
    required String share,
    String path = '',
    String user = 'guest',
    String pass = '',
    String domain = '',
  }) async {
    try {
      final result = await _channel.invokeMethod<Map>('testConnection', {
        'host': host,
        'port': port,
        'share': share,
        'path': path,
        'user': user,
        'pass': pass,
        'domain': domain,
      });
      if (result == null) {
        return (success: false, error: 'No response from SMB service');
      }
      final success = result['success'] as bool? ?? false;
      final error = result['error'] as String?;
      return (success: success, error: error);
    } on PlatformException catch (e) {
      return (success: false, error: e.message ?? 'SMB connection failed');
    }
  }

  Future<List<SmbFileEntry>> listFiles({
    required String host,
    int port = 445,
    required String share,
    required String path,
    String user = 'guest',
    String pass = '',
    String domain = '',
    int maxDepth = 0,
  }) async {
    try {
      final result = await _channel.invokeMethod<List>('listFiles', {
        'host': host,
        'port': port,
        'share': share,
        'path': path,
        'user': user,
        'pass': pass,
        'domain': domain,
        'maxDepth': maxDepth,
      });
      if (result == null) return [];

      return result.map((entry) {
        final map = Map<String, dynamic>.from(entry as Map);
        return SmbFileEntry(
          name: map['name'] as String,
          path: map['path'] as String,
          isDirectory: map['isDirectory'] as bool,
          size: (map['size'] as num).toInt(),
          parentPath: map['parentPath'] as String?,
        );
      }).toList();
    } on PlatformException catch (e) {
      throw Exception(e.message ?? 'Failed to list SMB files');
    }
  }

  Future<void> startDownload({
    required String downloadId,
    required String host,
    int port = 445,
    required String share,
    required String filePath,
    required String outputPath,
    String user = 'guest',
    String pass = '',
    String domain = '',
  }) async {
    try {
      await _channel.invokeMethod<void>('startDownload', {
        'downloadId': downloadId,
        'host': host,
        'port': port,
        'share': share,
        'filePath': filePath,
        'outputPath': outputPath,
        'user': user,
        'pass': pass,
        'domain': domain,
      });
    } on PlatformException catch (e) {
      throw Exception(e.message ?? 'Failed to start SMB download');
    }
  }

  Future<void> cancelDownload(String downloadId) async {
    try {
      await _channel.invokeMethod<void>('cancelDownload', {
        'downloadId': downloadId,
      });
    } on PlatformException catch (e) {
      debugPrint('NativeSmbService: cancel failed: ${e.message}');
    }
  }
}
