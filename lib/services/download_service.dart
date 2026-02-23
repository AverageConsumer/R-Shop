import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
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
  Directory? _extractTempDir;
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

  /// Exposes the current temp file path for resume tracking.
  String? get currentTempFilePath => _tempFilePath;

  void reset() {
    _isCancelled = false;
    _isDownloadInProgress = false;
    _tempFilePath = null;
    _downloadSubscription?.cancel();
    _downloadSubscription = null;
  }

  Future<void> cancelDownload({bool preserveTempFile = false}) async {
    _isCancelled = true;
    _downloadSubscription?.cancel();
    _downloadSubscription = null;

    // Close active SMB/FTP connections
    try {
      await _activeConnectionCleanup?.call();
    } catch (e) {
      debugPrint('DownloadService: connection cleanup failed: $e');
    }
    _activeConnectionCleanup = null;

    if (_tempFilePath != null && !preserveTempFile) {
      try {
        final file = File(_tempFilePath!);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint('DownloadService: temp file cleanup failed: $e');
      }
    }

    // Clean up any partially extracted files
    final extractDir = _extractTempDir;
    _extractTempDir = null;
    if (extractDir != null && await extractDir.exists()) {
      try { await extractDir.delete(recursive: true); } catch (e) {
        debugPrint('DownloadService: extract dir cleanup failed: $e');
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
    SystemModel system, {
    String? existingTempFilePath,
  }) {
    // Cancel any in-flight download before starting a new one
    final oldController = _progressController;
    if (oldController?.isClosed == false) {
      oldController!.add(DownloadProgress(status: DownloadStatus.cancelled));
      oldController.close();
    }
    _downloadSubscription?.cancel();
    _downloadSubscription = null;

    final controller = StreamController<DownloadProgress>();
    _progressController = controller;
    _isDownloadInProgress = false;

    try {
      _startDownload(game, targetFolder, system,
          existingTempFilePath: existingTempFilePath);
    } catch (e) {
      controller.addError(e);
      controller.close();
    }

    return controller.stream;
  }

  Future<void> _startDownload(
    GameItem game,
    String targetFolder,
    SystemModel system, {
    String? existingTempFilePath,
  }) async {
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

      File tempFile;
      if (existingTempFilePath != null && await File(existingTempFilePath).exists()) {
        _tempFilePath = existingTempFilePath;
        tempFile = File(_tempFilePath!);
      } else {
        final tempDir = await getTemporaryDirectory();
        final safeFilename = p.basename(game.filename);
        final uniquePrefix = '${DateTime.now().millisecondsSinceEpoch}_${identityHashCode(this)}';
        _tempFilePath = '${tempDir.path}/${uniquePrefix}_$safeFilename';
        tempFile = File(_tempFilePath!);
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
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
    File tempFile, {
    int depth = 0,
  }) async {
    _httpClient?.close(force: true);
    _httpClient = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30)
      ..idleTimeout = const Duration(minutes: 5);

    final client = _httpClient;
    if (client == null) throw StateError('DownloadService has been disposed');

    // Check for existing partial download (resume support)
    int existingBytes = 0;
    if (await tempFile.exists()) {
      existingBytes = await tempFile.length();
    }

    final encodedUrl = _encodeUrl(handle.url);
    final uri = Uri.parse(encodedUrl);
    final request = await client.openUrl('GET', uri);

    request.headers.set('User-Agent',
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
    request.headers.set('Accept', '*/*');
    request.headers.set('Accept-Language', 'en-US,en;q=0.9');
    request.headers.set('Referer', '${uri.scheme}://${uri.host}/');

    // Request resume from existing position
    if (existingBytes > 0) {
      request.headers.set('Range', 'bytes=$existingBytes-');
    }

    // Apply auth headers from the download handle
    if (handle.headers != null) {
      for (final entry in handle.headers!.entries) {
        request.headers.set(entry.key, entry.value);
      }
    }

    final response = await request.close();

    FileMode writeMode;
    int totalBytes;
    int downloadedBytes;

    if (response.statusCode == 206 && existingBytes > 0) {
      // Resume successful — append to existing file
      writeMode = FileMode.append;
      downloadedBytes = existingBytes;
      final contentLength = response.contentLength > 0 ? response.contentLength : null;
      totalBytes = contentLength != null ? contentLength + existingBytes : -1;
      debugPrint('DownloadService: resuming at $existingBytes bytes');
    } else if (response.statusCode == 200) {
      // Server ignored Range or fresh download — start from scratch
      writeMode = FileMode.write;
      downloadedBytes = 0;
      totalBytes = response.contentLength > 0 ? response.contentLength : -1;
      if (existingBytes > 0) {
        debugPrint('DownloadService: server returned 200, restarting download');
      }
    } else {
      await response.drain<void>();
      throw Exception('Server returned status ${response.statusCode}');
    }

    // Safety check: existing bytes exceed expected total
    if (totalBytes > 0 && downloadedBytes >= totalBytes) {
      await response.drain<void>();
      if (depth >= 1) {
        throw Exception('HTTP download restart failed: temp file still oversized after retry');
      }
      debugPrint('DownloadService: temp file already complete or oversized, restarting');
      await tempFile.delete();
      // Recurse once with fresh state
      return _downloadHttp(handle, tempFile, depth: depth + 1);
    }

    final effectiveTotalBytes = totalBytes > 0 ? totalBytes : null;
    final sink = tempFile.openWrite(mode: writeMode);
    int lastUpdateTime = DateTime.now().millisecondsSinceEpoch;
    // Stopwatch only measures new bytes for speed calculation
    final stopwatch = Stopwatch()..start();
    int newBytes = 0;

    final completer = Completer<void>();

    // Inactivity timer: cancel if no data received for 60s
    Timer? inactivityTimer;
    void resetInactivityTimer() {
      inactivityTimer?.cancel();
      inactivityTimer = Timer(const Duration(seconds: 60), () {
        inactivityTimer = null;
        if (!completer.isCompleted) {
          _downloadSubscription?.cancel();
          sink.close().catchError((e) { debugPrint('DownloadService: sink close on stall: $e'); });
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
          _downloadSubscription = null;
          sink.close().catchError((e) { debugPrint('DownloadService: sink close on cancel: $e'); });
          if (!completer.isCompleted) completer.complete();
          return;
        }

        sink.add(chunk);
        downloadedBytes += chunk.length;
        newBytes += chunk.length;
        resetInactivityTimer();

        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - lastUpdateTime >= _progressIntervalMs) {
          lastUpdateTime = now;
          _emitResumeProgress(downloadedBytes, effectiveTotalBytes, newBytes, stopwatch);
        }
      },
      onDone: () async {
        inactivityTimer?.cancel();
        if (_isCancelled) {
          try { await sink.close(); } catch (e) {
            debugPrint('DownloadService: sink close on cancel done: $e');
          }
          if (!completer.isCompleted) completer.complete();
          return;
        }
        try {
          await sink.close();
          _emitResumeProgress(downloadedBytes, effectiveTotalBytes, newBytes, stopwatch);
          if (!completer.isCompleted) completer.complete();
        } catch (e) {
          if (!completer.isCompleted) completer.completeError(e);
        }
      },
      onError: (e) async {
        inactivityTimer?.cancel();
        try { await sink.close(); } catch (e2) {
          debugPrint('DownloadService: sink close on error: $e2');
        }
        if (!completer.isCompleted) completer.completeError(e);
      },
      cancelOnError: true,
    );

    try {
      await completer.future;
    } finally {
      inactivityTimer?.cancel();
    }
  }

  /// Emit progress accounting for resumed downloads.
  /// [downloadedBytes] is total (existing + new), speed is based on [newBytes] only.
  void _emitResumeProgress(int downloadedBytes, int? totalBytes, int newBytes, Stopwatch stopwatch) {
    if (_progressController?.isClosed != false) return;

    double progress = 0;
    if (totalBytes != null && totalBytes > 0) {
      progress = downloadedBytes / totalBytes;
    }
    final elapsedMs = stopwatch.elapsedMilliseconds;
    final speed = elapsedMs > 0
        ? (newBytes * 1000) / (elapsedMs * 1024)
        : 0.0;

    _progressController?.add(DownloadProgress(
      status: DownloadStatus.downloading,
      progress: progress,
      receivedBytes: downloadedBytes,
      totalBytes: totalBytes,
      downloadSpeed: speed,
    ));
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

      final completer = Completer<void>();

      // Inactivity timer: cancel if no data received for 60s
      Timer? inactivityTimer;
      void resetInactivityTimer() {
        inactivityTimer?.cancel();
        inactivityTimer = Timer(const Duration(seconds: 60), () {
          inactivityTimer = null;
          if (!completer.isCompleted) {
            _downloadSubscription?.cancel();
            sink.close().catchError((e) { debugPrint('DownloadService: SMB sink close on stall: $e'); });
            completer.completeError(
                Exception('Download stalled — no data received for 60 seconds'));
          }
        });
      }

      resetInactivityTimer();

      _downloadSubscription = reader.stream.listen(
        (chunk) {
          if (_isCancelled) {
            inactivityTimer?.cancel();
            _downloadSubscription?.cancel();
            _downloadSubscription = null;
            sink.close().catchError((e) { debugPrint('DownloadService: SMB sink close on cancel: $e'); });
            if (!completer.isCompleted) completer.complete();
            return;
          }

          sink.add(chunk);
          downloadedBytes += chunk.length;
          resetInactivityTimer();

          final now = DateTime.now().millisecondsSinceEpoch;
          if (now - lastUpdateTime >= _progressIntervalMs) {
            lastUpdateTime = now;
            _emitProgress(downloadedBytes, totalBytes, stopwatch);
          }
        },
        onDone: () async {
          inactivityTimer?.cancel();
          if (_isCancelled) {
            try { await sink.close(); } catch (e) {
              debugPrint('DownloadService: SMB sink close on cancel done: $e');
            }
            if (!completer.isCompleted) completer.complete();
            return;
          }
          try {
            await sink.close();
            _emitProgress(downloadedBytes, totalBytes, stopwatch);
            if (!completer.isCompleted) completer.complete();
          } catch (e) {
            if (!completer.isCompleted) completer.completeError(e);
          }
        },
        onError: (e) async {
          inactivityTimer?.cancel();
          try { await sink.close(); } catch (e2) {
            debugPrint('DownloadService: SMB sink close on error: $e2');
          }
          if (!completer.isCompleted) completer.completeError(e);
        },
        cancelOnError: true,
      );

      try {
        await completer.future;
      } finally {
        inactivityTimer?.cancel();
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
    _activeConnectionCleanup = () async { try { await handle.disconnect?.call(); } catch (e) { debugPrint('DownloadService: FTP disconnect cleanup: $e'); } };
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

      // Inactivity timer: force-disconnect if no progress for 60s
      Timer? inactivityTimer;
      bool inactivityFired = false;
      void resetInactivityTimer() {
        inactivityTimer?.cancel();
        inactivityTimer = Timer(const Duration(seconds: 60), () {
          inactivityTimer = null;
          inactivityFired = true;
          try { handle.disconnect?.call(); } catch (e) { debugPrint('DownloadService: FTP inactivity disconnect: $e'); }
        });
      }

      resetInactivityTimer();

      try {
        await handle.downloadToFile(tempFile, onProgress: (percent, received, total) {
          if (_isCancelled) return;
          resetInactivityTimer();
          final now = DateTime.now().millisecondsSinceEpoch;
          if (now - lastUpdateTime >= _progressIntervalMs) {
            lastUpdateTime = now;
            _emitProgress(received, total, stopwatch);
          }
        });
      } catch (e) {
        if (inactivityFired) {
          throw Exception('Download stalled — no data received for 60 seconds');
        }
        rethrow;
      } finally {
        inactivityTimer?.cancel();
      }

      // FTP library doesn't support mid-transfer cancel from callback,
      // so clean up after it finishes if user cancelled during transfer
      if (_isCancelled) {
        await _cleanupTempFile(tempFile);
      }
    } finally {
      _activeConnectionCleanup = null;
    }
  }

  void _emitProgress(int downloadedBytes, int? totalBytes, Stopwatch stopwatch) {
    if (_progressController?.isClosed != false) return;

    double progress = 0;
    if (totalBytes != null && totalBytes > 0) {
      progress = downloadedBytes / totalBytes;
    }
    final elapsedMs = stopwatch.elapsedMilliseconds;
    final speed = elapsedMs > 0
        ? (downloadedBytes * 1000) / (elapsedMs * 1024)
        : 0.0;

    _progressController?.add(DownloadProgress(
      status: DownloadStatus.downloading,
      progress: progress,
      receivedBytes: downloadedBytes,
      totalBytes: totalBytes,
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
    } catch (e) {
      debugPrint('DownloadService: temp file cleanup failed: $e');
    }
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
      try { if (await tempFile.exists()) await tempFile.delete(); } catch (e) { debugPrint('DownloadService: zip temp delete: $e'); }
    } else if (extension.endsWith('.7z')) {
      if (_progressController?.isClosed == false) {
        _progressController?.add(DownloadProgress(
          status: DownloadStatus.moving,
          progress: 1.0,
        ));
      }
      await _moveToTarget(tempFile, targetFolder);
      if (_isCancelled) { _cleanupTempFile(tempFile); _emitCancelled(); return; }
      try { if (await tempFile.exists()) await tempFile.delete(); } catch (e) { debugPrint('DownloadService: 7z temp delete: $e'); }
    } else {
      if (_progressController?.isClosed == false) {
        _progressController?.add(DownloadProgress(
          status: DownloadStatus.moving,
          progress: 1.0,
        ));
      }
      final targetPath = RomManager.safePath(targetFolder, game.filename);
      final targetFile = File(targetPath);
      try {
        if (await targetFile.exists()) {
          await targetFile.delete();
        }
        await tempFile.copy(targetFile.path);
      } on FileSystemException catch (e) {
        // Clean up partial target on copy failure
        try { if (await targetFile.exists()) await targetFile.delete(); } catch (e2) { debugPrint('DownloadService: target cleanup on copy fail: $e2'); }
        throw Exception('Failed to copy file to target: $e');
      }
      if (_isCancelled) { _cleanupTempFile(tempFile); _emitCancelled(); return; }
      try { if (await tempFile.exists()) await tempFile.delete(); } catch (e) { debugPrint('DownloadService: rom temp delete: $e'); }
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

  /// Maximum total size of extracted files (8 GB). Protects against zip bombs.
  static const int _maxExtractedBytes = 8 * 1024 * 1024 * 1024;

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
    _extractTempDir = extractTempDir;

    try {
      await _extractZipNative(zipFile, extractTempDir.path);

      if (_isCancelled) return;

      final files = _listFilesRecursively(extractTempDir);

      // Guard against zip bombs: check total extracted size (async)
      int totalSize = 0;
      for (final file in files) {
        if (_isCancelled) return;
        try {
          final stat = await file.stat();
          totalSize += stat.size;
        } catch (e) {
          debugPrint('DownloadService: stat failed: $e');
          continue;
        }
        if (totalSize > _maxExtractedBytes) {
          throw Exception(
            'Extracted archive exceeds 8 GB safety limit — aborting',
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
          if (_isCancelled) return;
          final fileName = p.basename(file.path);
          final targetPath = RomManager.safePath(subFolder.path, fileName);
          try {
            await file.copy(targetPath);
          } on FileSystemException catch (e) {
            try { if (await File(targetPath).exists()) await File(targetPath).delete(); } catch (e2) { debugPrint('DownloadService: extract cleanup: $e2'); }
            throw Exception('Failed to extract file $fileName: $e');
          }
        }
      } else {
        for (final file in files) {
          if (_isCancelled) return;
          final fileName = p.basename(file.path);
          final targetPath = RomManager.safePath(targetFolder, fileName);
          try {
            await file.copy(targetPath);
          } on FileSystemException catch (e) {
            try { if (await File(targetPath).exists()) await File(targetPath).delete(); } catch (e2) { debugPrint('DownloadService: extract cleanup: $e2'); }
            throw Exception('Failed to extract file $fileName: $e');
          }
        }
      }
    } finally {
      _extractTempDir = null;
      try {
        if (await extractTempDir.exists()) {
          await extractTempDir.delete(recursive: true);
        }
      } catch (e) {
        debugPrint('DownloadService: extract temp dir cleanup: $e');
      }
    }
  }

  List<File> _listFilesRecursively(Directory dir) {
    try {
      return dir.listSync(recursive: true).whereType<File>().toList();
    } on FileSystemException catch (e) {
      debugPrint('DownloadService: cannot list extracted files: $e');
      return [];
    }
  }

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
    } catch (e) {
      debugPrint('DownloadService: URL encode failed for "$url": $e');
      return url;
    }
  }
}
