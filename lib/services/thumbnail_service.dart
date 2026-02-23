import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import 'image_cache_service.dart';


class ThumbnailResult {
  final bool success;
  const ThumbnailResult({required this.success});
  static const failed = ThumbnailResult(success: false);
}

// Message classes for worker isolate communication
class _WorkerRequest {
  final int id;
  final String sourcePath;
  final String outputPath;
  const _WorkerRequest({
    required this.id,
    required this.sourcePath,
    required this.outputPath,
  });
}

class _WorkerResponse {
  final int id;
  final bool success;
  const _WorkerResponse({
    required this.id,
    required this.success,
  });
}

// Top-level worker entry point
void _workerEntryPoint(SendPort mainPort) {
  final workerPort = ReceivePort();
  mainPort.send(workerPort.sendPort);

  workerPort.listen((message) {
    final request = message as _WorkerRequest;
    final response = _processImage(request);
    mainPort.send(response);
  });
}

// Image processing — runs sequentially inside the worker isolate
_WorkerResponse _processImage(_WorkerRequest request) {
  try {
    final sourceBytes = File(request.sourcePath).readAsBytesSync();

    // Quick magic bytes check before expensive decode
    if (sourceBytes.length < 4) {
      return _WorkerResponse(id: request.id, success: false);
    }
    final isPng = sourceBytes[0] == 0x89 && sourceBytes[1] == 0x50;
    final isJpeg = sourceBytes[0] == 0xFF && sourceBytes[1] == 0xD8;
    final isGif = sourceBytes[0] == 0x47 && sourceBytes[1] == 0x49;
    final isWebP = sourceBytes.length >= 12 &&
        sourceBytes[0] == 0x52 &&
        sourceBytes[8] == 0x57;
    if (!isPng && !isJpeg && !isGif && !isWebP) {
      return _WorkerResponse(id: request.id, success: false);
    }

    final image = img.decodeImage(sourceBytes);
    if (image == null) {
      return _WorkerResponse(id: request.id, success: false);
    }

    // Generate 400px wide thumbnail as JPEG
    final thumbnail = img.copyResize(image, width: 400);
    final jpegBytes = img.encodeJpg(thumbnail, quality: 85);
    File(request.outputPath).writeAsBytesSync(jpegBytes);

    return _WorkerResponse(
      id: request.id,
      success: true,
    );
  } catch (e) {
    return _WorkerResponse(id: request.id, success: false);
  }
}

class ThumbnailService {
  static Directory? _thumbDir;
  static final Set<String> _inProgress = {};

  // Persistent worker isolate state
  static Isolate? _workerIsolate;
  static SendPort? _workerSendPort;
  static ReceivePort? _mainReceivePort;
  static ReceivePort? _errorPort;
  static ReceivePort? _exitPort;
  static StreamSubscription? _mainSubscription;
  static StreamSubscription? _errorSubscription;
  static StreamSubscription? _exitSubscription;
  static final Map<int, Completer<ThumbnailResult>> _pending = {};
  static int _nextRequestId = 0;
  static Completer<void>? _workerReady;
  static bool _isSpawning = false;
  static bool _disposed = false;
  static int _respawnAttempts = 0;
  static const int _maxRespawnAttempts = 3;
  static const List<Duration> _respawnDelays = [
    Duration(seconds: 1),
    Duration(seconds: 5),
    Duration(seconds: 15),
  ];

  static Future<void> init() async {
    final appDir = await getApplicationSupportDirectory();
    _thumbDir = Directory('${appDir.path}/cover_thumbnails');
    if (!_thumbDir!.existsSync()) {
      await _thumbDir!.create(recursive: true);
    }
    _disposed = false;
    _respawnAttempts = 0;
    await _spawnWorker();
  }

  static Future<void> _spawnWorker() async {
    if (_isSpawning) {
      // Another spawn is in progress, wait for it
      if (_workerReady != null) await _workerReady!.future;
      return;
    }
    _isSpawning = true;
    _workerReady = Completer<void>();
    _mainReceivePort = ReceivePort();

    _workerIsolate = await Isolate.spawn(
      _workerEntryPoint,
      _mainReceivePort!.sendPort,
    );

    // Listen for crash / exit to recover
    _errorPort?.close();
    _exitPort?.close();
    _errorPort = ReceivePort();
    _exitPort = ReceivePort();
    _workerIsolate!.addErrorListener(_errorPort!.sendPort);
    _workerIsolate!.addOnExitListener(_exitPort!.sendPort);

    _errorSubscription?.cancel();
    _errorSubscription = _errorPort!.listen((message) {
      debugPrint('Thumbnail worker error: $message');
      _handleWorkerCrash();
    });
    _exitSubscription?.cancel();
    _exitSubscription = _exitPort!.listen((_) {
      debugPrint('Thumbnail worker exited unexpectedly');
      _handleWorkerCrash();
    });

    _mainSubscription?.cancel();
    _mainSubscription = _mainReceivePort!.listen((message) {
      if (message is SendPort) {
        // Handshake: worker sends its SendPort
        _workerSendPort = message;
        _workerReady!.complete();
      } else if (message is _WorkerResponse) {
        final completer = _pending.remove(message.id);
        if (completer != null) {
          completer.complete(ThumbnailResult(
            success: message.success,
          ));
        }
      }
    });

    await _workerReady!.future;
    _isSpawning = false;
    _respawnAttempts = 0;
  }

  static void _handleWorkerCrash() {
    _workerSendPort = null;
    _workerIsolate = null;
    _mainSubscription?.cancel();
    _mainSubscription = null;
    _mainReceivePort?.close();
    _mainReceivePort = null;
    _errorSubscription?.cancel();
    _errorSubscription = null;
    _errorPort?.close();
    _errorPort = null;
    _exitSubscription?.cancel();
    _exitSubscription = null;
    _exitPort?.close();
    _exitPort = null;
    _isSpawning = false;

    // Fail all pending requests — copy first since clear() invalidates iteration
    final pendingCopy = Map.of(_pending);
    _pending.clear();
    for (final completer in pendingCopy.values) {
      if (!completer.isCompleted) {
        completer.complete(ThumbnailResult.failed);
      }
    }

    // Respawn worker with exponential backoff
    if (_disposed || _respawnAttempts >= _maxRespawnAttempts) {
      if (!_disposed) {
        debugPrint(
            'ThumbnailService: max respawn attempts ($_maxRespawnAttempts) reached, giving up');
      }
      return;
    }

    final delay = _respawnDelays[_respawnAttempts];
    _respawnAttempts++;
    debugPrint(
        'ThumbnailService: respawning worker in ${delay.inSeconds}s (attempt $_respawnAttempts/$_maxRespawnAttempts)');

    Future.delayed(delay, () {
      if (_disposed) return;
      _spawnWorker().catchError((e) {
        debugPrint('ThumbnailService: respawn failed: $e');
      });
    });
  }

  static String? thumbnailPath(String url) {
    if (_thumbDir == null) return null;
    final hash = sha1.convert(utf8.encode(url)).toString();
    return '${_thumbDir!.path}/$hash.jpg';
  }

  static File? getThumbnailFile(String url) {
    final path = thumbnailPath(url);
    if (path == null) return null;
    final file = File(path);
    return file.existsSync() ? file : null;
  }

  static Future<ThumbnailResult> generateThumbnail(String coverUrl) async {
    if (_inProgress.contains(coverUrl)) return ThumbnailResult.failed;
    _inProgress.add(coverUrl);
    try {
      final cacheFile =
          await GameCoverCacheManager.instance.getFileFromCache(coverUrl);
      if (cacheFile == null) return ThumbnailResult.failed;

      final outputPath = thumbnailPath(coverUrl);
      if (outputPath == null) return ThumbnailResult.failed;

      // Wait for worker to be ready (handles respawn case)
      if (_workerSendPort == null) {
        if (_workerReady != null && !_workerReady!.isCompleted) {
          await _workerReady!.future;
        }
        if (_workerSendPort == null) return ThumbnailResult.failed;
      }

      final id = _nextRequestId++;
      final completer = Completer<ThumbnailResult>();
      _pending[id] = completer;

      _workerSendPort!.send(_WorkerRequest(
        id: id,
        sourcePath: cacheFile.file.path,
        outputPath: outputPath,
      ));

      return await completer.future;
    } catch (e) {
      debugPrint('Thumbnail generation failed for $coverUrl: $e');
      return ThumbnailResult.failed;
    } finally {
      _inProgress.remove(coverUrl);
    }
  }

  static Future<void> clearAll() async {
    if (_thumbDir != null && _thumbDir!.existsSync()) {
      await _thumbDir!.delete(recursive: true);
      await _thumbDir!.create();
    }
  }

  static void dispose() {
    _disposed = true;
    _workerIsolate?.kill(priority: Isolate.immediate);
    _workerIsolate = null;
    _workerSendPort = null;
    _mainSubscription?.cancel();
    _mainSubscription = null;
    _mainReceivePort?.close();
    _mainReceivePort = null;
    _errorSubscription?.cancel();
    _errorSubscription = null;
    _errorPort?.close();
    _errorPort = null;
    _exitSubscription?.cancel();
    _exitSubscription = null;
    _exitPort?.close();
    _exitPort = null;
    for (final completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.complete(ThumbnailResult.failed);
      }
    }
    _pending.clear();
  }
}
