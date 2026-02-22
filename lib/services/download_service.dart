import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/game_item.dart';
import '../models/system_model.dart';
import '../utils/friendly_error.dart';
import 'download_handle.dart';
import 'provider_factory.dart';
import 'rom_manager.dart';

enum DownloadStatus {
  idle,
  downloading,
  extracting,
  moving,
  completed,
  error,
  cancelled,
}

class DownloadProgress {
  final DownloadStatus status;
  final double progress;
  final String? error;
  final int receivedBytes;
  final int? totalBytes;
  final double? downloadSpeed;

  DownloadProgress({
    required this.status,
    this.progress = 0.0,
    this.error,
    this.receivedBytes = 0,
    this.totalBytes,
    this.downloadSpeed,
  });

  String get displayText {
    switch (status) {
      case DownloadStatus.extracting:
        return 'Extracting...';
      case DownloadStatus.moving:
        return 'Moving...';
      case DownloadStatus.error:
        return 'Error';
      case DownloadStatus.cancelled:
        return 'Cancelled';
      default:
        if (totalBytes != null && totalBytes! > 0) {
          return '${(progress * 100).toStringAsFixed(0)}%';
        } else {
          final mb = receivedBytes / (1024 * 1024);
          return '${mb.toStringAsFixed(1)} MB';
        }
    }
  }

  String? get speedText {
    if (downloadSpeed == null || downloadSpeed! <= 0) return null;
    if (downloadSpeed! >= 1024) {
      return '${(downloadSpeed! / 1024).toStringAsFixed(1)} MB/s';
    }
    return '${downloadSpeed!.toStringAsFixed(0)} KB/s';
  }
}

class DownloadService {
  static const _zipChannel = MethodChannel('com.retro.rshop/zip');

  HttpClient? _httpClient;
  String? _tempFilePath;
  bool _isCancelled = false;
  bool _isDownloadInProgress = false;
  StreamSubscription? _downloadSubscription;
  StreamController<DownloadProgress>? _progressController;
  Future<void> Function()? _activeConnectionCleanup;

  static const int _progressIntervalMs = 500;
  static const int _initialDelayMs = 1000;

  DownloadService() {
    _httpClient = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30)
      ..idleTimeout = const Duration(minutes: 5);
  }

  bool get isDownloadInProgress => _isDownloadInProgress;

  void reset() {
    _isCancelled = false;
    _isDownloadInProgress = false;
    _tempFilePath = null;
    _downloadSubscription?.cancel();
    _downloadSubscription = null;
  }

  Future<void> cancelDownload() async {
    _isCancelled = true;
    _downloadSubscription?.cancel();
    _downloadSubscription = null;

    // Close active SMB/FTP connections
    try {
      await _activeConnectionCleanup?.call();
    } catch (_) {}
    _activeConnectionCleanup = null;

    if (_tempFilePath != null) {
      final file = File(_tempFilePath!);
      if (await file.exists()) {
        await file.delete();
      }
    }

    _httpClient?.close(force: true);
    _httpClient = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30)
      ..idleTimeout = const Duration(minutes: 5);

    _isDownloadInProgress = false;
  }

  Stream<DownloadProgress> downloadGameStream(
    GameItem game,
    String targetFolder,
    SystemModel system,
  ) {
    final oldController = _progressController;
    final controller = StreamController<DownloadProgress>();
    _progressController = controller;

    // Close old controller after replacing the reference to avoid
    // emitting to a stale listener.
    if (oldController?.isClosed == false) {
      oldController!.close();
    }

    _startDownload(game, targetFolder, system);

    return controller.stream;
  }

  Future<void> _startDownload(
    GameItem game,
    String targetFolder,
    SystemModel system,
  ) async {
    if (_isDownloadInProgress) {
      _progressController?.add(DownloadProgress(
        status: DownloadStatus.error,
        error: 'Another download is already in progress',
      ));
      _progressController?.close();
      return;
    }

    _isDownloadInProgress = true;
    _isCancelled = false;

    if (_progressController?.isClosed == false) {
      _progressController?.add(DownloadProgress(
        status: DownloadStatus.downloading,
        progress: 0,
        receivedBytes: 0,
        totalBytes: null,
      ));
    }

    try {
      await Future.delayed(const Duration(milliseconds: _initialDelayMs));

      if (_isCancelled) {
        _emitCancelled();
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final safeFilename = p.basename(game.filename);
      final uniquePrefix = '${DateTime.now().millisecondsSinceEpoch}_${identityHashCode(this)}';
      _tempFilePath = '${tempDir.path}/${uniquePrefix}_$safeFilename';
      final tempFile = File(_tempFilePath!);

      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      await tempFile.parent.create(recursive: true);

      // Resolve download handle via provider
      if (game.providerConfig == null) {
        _emitError('No provider configured for this game');
        return;
      }
      final provider = ProviderFactory.getProvider(game.providerConfig!);
      final handle = await provider.resolveDownload(game);

      if (_isCancelled) {
        _emitCancelled();
        return;
      }

      switch (handle) {
        case HttpDownloadHandle():
          await _downloadHttp(handle, tempFile);
        case SmbDownloadHandle():
          await _downloadSmb(handle, tempFile);
        case FtpDownloadHandle():
          await _downloadFtp(handle, tempFile);
      }

      if (_isCancelled) {
        _emitCancelled();
        return;
      }

      await _handlePostDownload(game, tempFile, targetFolder, system);
    } catch (e) {
      if (!_isCancelled && _progressController?.isClosed == false) {
        _progressController?.add(DownloadProgress(
          status: DownloadStatus.error,
          error: _getUserFriendlyError(e),
        ));
        _progressController?.close();
      }
    } finally {
      _isDownloadInProgress = false;
    }
  }

  Future<void> _downloadHttp(
    HttpDownloadHandle handle,
    File tempFile,
  ) async {
    _httpClient?.close(force: true);
    _httpClient = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30)
      ..idleTimeout = const Duration(minutes: 5);

    final encodedUrl = _encodeUrl(handle.url);
    final uri = Uri.parse(encodedUrl);
    final request = await _httpClient!.openUrl('GET', uri);

    request.headers.set('User-Agent',
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
    request.headers.set('Accept', '*/*');
    request.headers.set('Accept-Language', 'en-US,en;q=0.9');
    request.headers.set('Referer', '${uri.scheme}://${uri.host}/');

    // Apply auth headers from the download handle
    if (handle.headers != null) {
      for (final entry in handle.headers!.entries) {
        request.headers.set(entry.key, entry.value);
      }
    }

    final response = await request.close();

    if (response.statusCode != 200) {
      // Drain the response to free resources
      await response.drain<void>();
      throw Exception('Server returned status ${response.statusCode}');
    }

    final contentLength = response.contentLength;
    final sink = tempFile.openWrite();
    int downloadedBytes = 0;
    int lastUpdateTime = DateTime.now().millisecondsSinceEpoch;
    final stopwatch = Stopwatch()..start();

    final completer = Completer<void>();

    // Inactivity timer: cancel if no data received for 60s
    Timer? inactivityTimer;
    void resetInactivityTimer() {
      inactivityTimer?.cancel();
      inactivityTimer = Timer(const Duration(seconds: 60), () {
        if (!completer.isCompleted) {
          _downloadSubscription?.cancel();
          sink.close().catchError((_) {});
          completer.completeError(
              Exception('Download stalled — no data received for 60 seconds'));
        }
      });
    }

    resetInactivityTimer();

    _downloadSubscription = response.listen(
      (chunk) {
        if (_isCancelled) {
          inactivityTimer?.cancel();
          _downloadSubscription?.cancel();
          sink.close().catchError((_) {});
          if (!completer.isCompleted) completer.complete();
          return;
        }

        sink.add(chunk);
        downloadedBytes += chunk.length;
        resetInactivityTimer();

        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - lastUpdateTime >= _progressIntervalMs) {
          lastUpdateTime = now;
          _emitProgress(downloadedBytes, contentLength, stopwatch);
        }
      },
      onDone: () async {
        inactivityTimer?.cancel();
        if (_isCancelled) {
          completer.complete();
          return;
        }
        try {
          await sink.close();
          _emitProgress(downloadedBytes, contentLength, stopwatch);
          completer.complete();
        } catch (e) {
          completer.completeError(e);
        }
      },
      onError: (e) async {
        inactivityTimer?.cancel();
        try {
          await sink.close();
        } catch (_) {}
        completer.completeError(e);
      },
      cancelOnError: true,
    );

    await completer.future;
  }

  Future<void> _downloadSmb(
    SmbDownloadHandle handle,
    File tempFile,
  ) async {
    final reader = await handle.openFile();
    _activeConnectionCleanup = () => reader.close();
    try {
      final sink = tempFile.openWrite();
      int downloadedBytes = 0;
      final totalBytes = reader.size;
      final stopwatch = Stopwatch()..start();
      int lastUpdateTime = DateTime.now().millisecondsSinceEpoch;

      try {
        await for (final chunk in reader.stream) {
          if (_isCancelled) {
            await sink.close();
            return;
          }

          sink.add(chunk);
          downloadedBytes += chunk.length;

          final now = DateTime.now().millisecondsSinceEpoch;
          if (now - lastUpdateTime >= _progressIntervalMs) {
            lastUpdateTime = now;
            _emitProgress(downloadedBytes, totalBytes, stopwatch);
          }
        }

        await sink.close();
        _emitProgress(downloadedBytes, totalBytes, stopwatch);
      } catch (e) {
        try {
          await sink.close();
        } catch (_) {}
        rethrow;
      }
    } finally {
      try {
        await reader.close();
      } finally {
        _activeConnectionCleanup = null;
      }
    }
  }

  Future<void> _downloadFtp(
    FtpDownloadHandle handle,
    File tempFile,
  ) async {
    _activeConnectionCleanup = handle.disconnect;
    try {
      if (_isCancelled) return;

      if (_progressController?.isClosed == false) {
        _progressController?.add(DownloadProgress(
          status: DownloadStatus.downloading,
          progress: 0,
          receivedBytes: 0,
          totalBytes: null,
        ));
      }

      final stopwatch = Stopwatch()..start();
      int lastUpdateTime = DateTime.now().millisecondsSinceEpoch;

      await handle.downloadToFile(tempFile, onProgress: (percent, received, total) {
        if (_isCancelled) return;
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - lastUpdateTime >= _progressIntervalMs) {
          lastUpdateTime = now;
          _emitProgress(received, total, stopwatch);
        }
      });
    } finally {
      _activeConnectionCleanup = null;
    }
  }

  void _emitProgress(int downloadedBytes, int totalBytes, Stopwatch stopwatch) {
    if (_progressController?.isClosed != false) return;

    double progress = 0;
    if (totalBytes > 0) {
      progress = downloadedBytes / totalBytes;
    }
    final speed = stopwatch.elapsedMilliseconds > 0
        ? (downloadedBytes / stopwatch.elapsedMilliseconds * 1000 / 1024)
        : 0.0;

    _progressController?.add(DownloadProgress(
      status: DownloadStatus.downloading,
      progress: progress,
      receivedBytes: downloadedBytes,
      totalBytes: totalBytes > 0 ? totalBytes : null,
      downloadSpeed: speed,
    ));
  }

  void _emitError(String message) {
    if (_progressController?.isClosed == false) {
      _progressController?.add(DownloadProgress(
        status: DownloadStatus.error,
        error: message,
      ));
      _progressController?.close();
    }
    _isDownloadInProgress = false;
  }

  Future<void> _cleanupTempFile(File tempFile) async {
    try {
      if (await tempFile.exists()) await tempFile.delete();
    } catch (_) {}
  }

  void _emitCancelled() {
    if (_progressController?.isClosed == false) {
      _progressController?.add(DownloadProgress(
        status: DownloadStatus.cancelled,
      ));
      _progressController?.close();
    }
    _isDownloadInProgress = false;
  }

  Future<void> _handlePostDownload(
    GameItem game,
    File tempFile,
    String targetFolder,
    SystemModel system,
  ) async {
    if (_isCancelled || _progressController?.isClosed == true) return;

    final targetDir = Directory(targetFolder);
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final extension = game.filename.toLowerCase();
    if (extension.endsWith('.zip')) {
      if (_progressController?.isClosed == false) {
        _progressController?.add(DownloadProgress(
          status: DownloadStatus.extracting,
          progress: 1.0,
        ));
      }

      final hasMultiFile = system.multiFileExtensions != null &&
          system.multiFileExtensions!.isNotEmpty;

      if (hasMultiFile) {
        await _extractZipWithMultiFileSupport(
            tempFile, targetFolder, system, game);
      } else {
        await _extractZipNative(tempFile, targetFolder);
      }
      if (_isCancelled) { _cleanupTempFile(tempFile); _emitCancelled(); return; }
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    } else if (extension.endsWith('.7z')) {
      if (_progressController?.isClosed == false) {
        _progressController?.add(DownloadProgress(
          status: DownloadStatus.moving,
          progress: 1.0,
        ));
      }
      await _moveToTarget(tempFile, targetFolder);
      if (_isCancelled) { _cleanupTempFile(tempFile); _emitCancelled(); return; }
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    } else {
      if (_progressController?.isClosed == false) {
        _progressController?.add(DownloadProgress(
          status: DownloadStatus.moving,
          progress: 1.0,
        ));
      }
      final targetPath = RomManager.safePath(targetFolder, game.filename);
      final targetFile = File(targetPath);
      if (await targetFile.exists()) {
        await targetFile.delete();
      }
      await tempFile.copy(targetFile.path);
      if (_isCancelled) { _cleanupTempFile(tempFile); _emitCancelled(); return; }
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    }

    if (_isCancelled) { _emitCancelled(); return; }

    if (_progressController?.isClosed == false) {
      _progressController?.add(DownloadProgress(
        status: DownloadStatus.completed,
        progress: 1.0,
      ));
      _progressController?.close();
    }
  }

  Future<void> _extractZipNative(File zipFile, String targetFolder) async {
    try {
      await _zipChannel.invokeMethod<List<dynamic>>('extractZip', {
        'zipPath': zipFile.path,
        'targetPath': targetFolder,
      });
    } on PlatformException catch (e) {
      throw Exception('ZIP extraction failed: ${e.message}');
    }
  }

  /// Maximum total size of extracted files (2 GB). Protects against zip bombs.
  static const int _maxExtractedBytes = 2 * 1024 * 1024 * 1024;

  Future<void> _extractZipWithMultiFileSupport(
    File zipFile,
    String targetFolder,
    SystemModel system,
    GameItem game,
  ) async {
    final tempDir = await getTemporaryDirectory();
    final extractTempDir = Directory(
        '${tempDir.path}/extract_${DateTime.now().millisecondsSinceEpoch}');
    await extractTempDir.create(recursive: true);

    try {
      await _extractZipNative(zipFile, extractTempDir.path);

      final files = _listFilesRecursively(extractTempDir);

      // Guard against zip bombs: check total extracted size
      int totalSize = 0;
      for (final file in files) {
        totalSize += file.lengthSync();
        if (totalSize > _maxExtractedBytes) {
          throw Exception(
            'Extracted archive exceeds 2 GB safety limit — aborting',
          );
        }
      }

      final hasBinFiles = files.any((f) {
        return p.extension(f.path).toLowerCase() == '.bin';
      });

      if (hasBinFiles) {
        final gameName = RomManager.extractGameName(game.filename) ?? game.filename;
        final subFolderPath = RomManager.safePath(targetFolder, gameName);
        final subFolder = Directory(subFolderPath);
        await subFolder.create(recursive: true);

        for (final file in files) {
          final fileName = p.basename(file.path);
          final targetPath = RomManager.safePath(subFolder.path, fileName);
          await file.copy(targetPath);
        }
      } else {
        for (final file in files) {
          final fileName = p.basename(file.path);
          final targetPath = RomManager.safePath(targetFolder, fileName);
          await file.copy(targetPath);
        }
      }
    } finally {
      if (await extractTempDir.exists()) {
        await extractTempDir.delete(recursive: true);
      }
    }
  }

  List<File> _listFilesRecursively(Directory dir) =>
      dir.listSync(recursive: true).whereType<File>().toList();

  Future<void> _moveToTarget(File file, String targetFolder) async {
    final targetPath = RomManager.safePath(targetFolder, p.basename(file.path));
    final targetFile = File(targetPath);
    await targetFile.parent.create(recursive: true);
    await file.copy(targetFile.path);
  }

  String _getUserFriendlyError(dynamic e) => getUserFriendlyError(e);

  void dispose() {
    _httpClient?.close(force: true);
    _httpClient = null;
  }

  String _encodeUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.replace(pathSegments: uri.pathSegments).toString();
    } catch (_) {
      return url;
    }
  }
}
