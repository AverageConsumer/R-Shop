import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/config/app_config.dart';
import '../models/config/provider_config.dart';
import '../models/download_item.dart';
import '../models/game_item.dart';
import '../models/system_model.dart';
import 'download_foreground_service.dart';
import 'disk_space_service.dart';
import 'download_service.dart';
import 'storage_service.dart';

class DownloadQueueState {
  final List<DownloadItem> queue;
  final int maxConcurrent;

  const DownloadQueueState({
    this.queue = const [],
    this.maxConcurrent = 2,
  });

  List<DownloadItem> get activeDownloads =>
      queue.where((item) => item.isActive).toList();

  List<DownloadItem> get queuedItems =>
      queue.where((item) => item.status == DownloadItemStatus.queued).toList();

  List<DownloadItem> get completedItems =>
      queue.where((item) => item.isComplete).toList();

  List<DownloadItem> get failedItems =>
      queue.where((item) => item.isFailed).toList();

  List<DownloadItem> get recentItems {
    final unfinished = queue.where((item) => !item.isFinished).toList();
    final finished = queue.where((item) => item.isFinished).toList();
    return [...unfinished, ...finished];
  }

  int get activeCount => activeDownloads.length;

  int get queuedCount => queuedItems.length;

  int get totalCount => queue.length;

  int get finishedCount => completedItems.length + failedItems.length;

  bool get hasActiveDownloads => activeDownloads.isNotEmpty;

  bool get hasQueuedItems => queuedItems.isNotEmpty;

  bool get isEmpty => queue.isEmpty;

  bool canStartNewDownload() => activeCount < maxConcurrent;

  DownloadItem? getDownloadById(String id) {
    for (final item in queue) {
      if (item.id == id) return item;
    }
    return null;
  }

  DownloadQueueState copyWith({
    List<DownloadItem>? queue,
    int? maxConcurrent,
  }) {
    return DownloadQueueState(
      queue: queue ?? this.queue,
      maxConcurrent: maxConcurrent ?? this.maxConcurrent,
    );
  }
}

class DownloadQueueManager extends ChangeNotifier {
  static const int _maxRetries = 3;
  static const int _maxQueueSize = 100;
  static final Random _jitterRandom = Random();

  DownloadQueueState _state = const DownloadQueueState();
  DownloadQueueState get state => _state;
  bool _disposed = false;
  bool _isProcessingQueue = false;

  final Map<String, StreamSubscription?> _subscriptions = {};
  final Map<String, DownloadService> _downloadServices = {};
  final Map<String, Timer> _retryTimers = {};
  final StorageService _storage;

  DownloadQueueManager(this._storage) {
    final maxConcurrent = _storage.getMaxConcurrentDownloads();
    _state = _state.copyWith(maxConcurrent: maxConcurrent);
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  void setMaxConcurrent(int value) {
    final clamped = value.clamp(1, 3);
    _state = _state.copyWith(maxConcurrent: clamped);
    _storage.setMaxConcurrentDownloads(clamped);
    _safeNotify();
    _processQueue();
  }

  static bool _isRetryableError(String? error) {
    if (error == null) return false;
    const nonRetryable = ['File not found (404)', 'SSL error'];
    return !nonRetryable.any((e) => error.contains(e));
  }

  void _scheduleRetry(String id, int retryCount) {
    // Exponential backoff: 5s, 15s, 45s + random jitter to prevent thundering herd
    const delays = [5, 15, 45];
    final baseDelaySeconds = delays[retryCount.clamp(0, delays.length - 1)];
    final jitterMs = _jitterRandom.nextInt(3000); // 0–3s jitter
    final delay = Duration(seconds: baseDelaySeconds, milliseconds: jitterMs);

    _retryTimers[id]?.cancel();
    _retryTimers[id] = Timer(delay, () {
      _retryTimers.remove(id);
      if (_disposed) return;
      final item = _state.getDownloadById(id);
      if (item == null || item.status != DownloadItemStatus.error) return;

      _updateItem(
        id,
        status: DownloadItemStatus.queued,
        progress: 0,
        receivedBytes: 0,
        retryCount: retryCount + 1,
        clearError: true,
        clearSpeed: true,
      );
      _processQueue();
    });
  }

  Future<void> _switchToAlternativeSource(String id) async {
    final item = _state.getDownloadById(id);
    if (item == null) return;

    final alts = item.game.alternativeSources;
    if (alts.isEmpty) return;

    final next = alts.first;
    final remaining = alts.skip(1).toList();

    // Delete temp file from failed source
    if (item.tempFilePath != null) {
      try {
        await File(item.tempFilePath!).delete();
      } catch (e) {
        debugPrint('DownloadQueue: temp file cleanup failed: $e');
      }
      _updateItem(id, clearTempFilePath: true);
    }

    final updatedGame = item.game.copyWith(
      url: next.url,
      providerConfig: next.providerConfig,
      alternativeSources: remaining,
    );

    _updateItem(
      id,
      status: DownloadItemStatus.queued,
      progress: 0,
      receivedBytes: 0,
      retryCount: 0,
      clearError: true,
      clearSpeed: true,
    );

    // Replace the game on the item
    final newQueue = _state.queue.map((i) {
      if (i.id == id) return i.copyWith(game: updatedGame);
      return i;
    }).toList();
    _state = _state.copyWith(queue: newQueue);
    _safeNotify();

    debugPrint('DownloadQueue: switched to alternative source '
        '${next.providerConfig.detailLabel} for ${item.game.filename}');
    _processQueue();
  }

  String addToQueue(GameItem game, SystemModel system, String targetFolder) {
    final id = _generateId(game, system);

    final existing = _state.getDownloadById(id);
    if (existing != null && !existing.isFinished) {
      return id;
    }

    if (existing == null && _state.queue.length >= _maxQueueSize) {
      // Auto-clear finished items before rejecting
      final unfinished = _state.queue.where((item) => !item.isFinished).toList();
      if (unfinished.length < _state.queue.length) {
        _state = _state.copyWith(queue: unfinished);
        _safeNotify();
        _persistQueue();
      }
      if (_state.queue.length >= _maxQueueSize) {
        debugPrint('DownloadQueue: queue full ($_maxQueueSize items), rejecting');
        return id;
      }
    }

    final item = DownloadItem(
      id: id,
      game: game,
      system: system,
      targetFolder: targetFolder,
    );

    // Cancel any pending retry timer for this item
    _retryTimers[id]?.cancel();
    _retryTimers.remove(id);

    final newQueue = List<DownloadItem>.from(_state.queue);

    if (existing != null) {
      newQueue.removeWhere((i) => i.id == id);
    }

    newQueue.insert(0, item);
    _state = _state.copyWith(queue: newQueue);
    _safeNotify();
    _persistQueue();

    _processQueue();

    return id;
  }

  Future<void> cancelDownload(String id) async {
    final item = _state.getDownloadById(id);
    if (item == null) return;

    _retryTimers[id]?.cancel();
    _retryTimers.remove(id);

    _subscriptions[id]?.cancel();
    _subscriptions.remove(id);

    await _downloadServices[id]?.cancelDownload(preserveTempFile: false);
    _downloadServices.remove(id);

    _updateItem(id, status: DownloadItemStatus.cancelled, clearTempFilePath: true);
    _persistQueue();
    _stopForegroundServiceIfIdle();
    _processQueue();
  }

  Future<void> removeDownload(String id) async {
    final item = _state.getDownloadById(id);
    if (item == null) return;

    if (item.isActive) {
      await cancelDownload(id);
    }

    _retryTimers[id]?.cancel();
    _retryTimers.remove(id);

    final newQueue = List<DownloadItem>.from(_state.queue)
      ..removeWhere((i) => i.id == id);
    _state = _state.copyWith(queue: newQueue);
    _safeNotify();
    _persistQueue();
  }

  void clearCompleted() {
    final newQueue = _state.queue.where((item) => !item.isFinished).toList();
    _state = _state.copyWith(queue: newQueue);
    _safeNotify();
    _persistQueue();
  }

  void retryDownload(String id) {
    final item = _state.getDownloadById(id);
    if (item == null || item.isActive) return;

    _updateItem(
      id,
      status: DownloadItemStatus.queued,
      progress: 0,
      receivedBytes: 0,
      retryCount: 0,
      clearError: true,
      clearSpeed: true,
    );

    _processQueue();
  }

  void _processQueue() {
    if (_disposed || _isProcessingQueue) return;
    if (!_state.canStartNewDownload()) return;

    _isProcessingQueue = true;
    try {
      final queuedItems = _state.queuedItems;
      if (queuedItems.isEmpty) return;

      final availableSlots = _state.maxConcurrent - _state.activeCount;
      final itemsToStart = queuedItems.take(availableSlots);

      for (final item in itemsToStart) {
        // Re-check item is still queued before starting
        final current = _state.getDownloadById(item.id);
        if (current == null || current.status != DownloadItemStatus.queued) continue;
        _startDownload(item);
      }
    } finally {
      _isProcessingQueue = false;
    }
  }

  Future<void> _startDownload(DownloadItem item) async {
    _updateItem(item.id, status: DownloadItemStatus.downloading);
    _updateForegroundService();

    // Check disk space before starting actual download
    try {
      final storageInfo = await DiskSpaceService.getFreeSpace(item.targetFolder);
      if (_disposed) return;
      if (storageInfo != null && storageInfo.isLow) {
        _updateItem(
          item.id,
          status: DownloadItemStatus.error,
          error: 'Not enough disk space (${storageInfo.freeSpaceText})',
        );
        _stopForegroundServiceIfIdle();
        _processQueue();
        return;
      }
    } catch (e) {
      debugPrint('DownloadQueue: disk space check failed (proceeding): $e');
    }

    final targetFolder = item.targetFolder;

    _subscriptions[item.id]?.cancel();
    _subscriptions.remove(item.id);

    final oldService = _downloadServices.remove(item.id);
    oldService?.dispose();

    final downloadService = DownloadService();
    _downloadServices[item.id] = downloadService;

    final subscription = downloadService
        .downloadGameStream(
      item.game,
      targetFolder,
      item.system,
      existingTempFilePath: item.tempFilePath,
    )
        .listen(
      (progress) {
        _updateItem(
          item.id,
          status: _mapStatus(progress.status),
          progress: progress.progress,
          receivedBytes: progress.receivedBytes,
          totalBytes: progress.totalBytes,
          downloadSpeed: progress.downloadSpeed,
          tempFilePath: downloadService.currentTempFilePath,
        );
        _throttledNotificationUpdate();
      },
      onDone: () {
        _subscriptions.remove(item.id);
        final service = _downloadServices.remove(item.id);
        service?.dispose();
        _onDownloadComplete(item.id);
      },
      onError: (error) {
        final tempPath = downloadService.currentTempFilePath;
        _subscriptions.remove(item.id);
        final service = _downloadServices.remove(item.id);
        service?.dispose();
        final errorMsg = error.toString();
        _updateItem(
          item.id,
          status: DownloadItemStatus.error,
          error: errorMsg,
          tempFilePath: tempPath,
        );

        final currentItem = _state.getDownloadById(item.id);
        if (currentItem != null &&
            currentItem.game.alternativeSources.isNotEmpty &&
            _isRetryableError(errorMsg)) {
          _switchToAlternativeSource(item.id);
          return;
        }
        if (currentItem != null &&
            currentItem.retryCount < _maxRetries &&
            _isRetryableError(errorMsg)) {
          _scheduleRetry(item.id, currentItem.retryCount);
        } else {
          _stopForegroundServiceIfIdle();
        }
        _processQueue();
      },
      cancelOnError: true,
    );

    _subscriptions[item.id] = subscription;
  }

  void _onDownloadComplete(String id) {
    final item = _state.getDownloadById(id);
    if (item == null) return;

    if (item.status == DownloadItemStatus.error) {
      if (item.retryCount < _maxRetries && _isRetryableError(item.error)) {
        _scheduleRetry(id, item.retryCount);
        return; // Keep foreground service alive for pending retry
      }
    }

    if (item.status != DownloadItemStatus.completed &&
        item.status != DownloadItemStatus.error) {
      _updateItem(id, status: DownloadItemStatus.completed, clearTempFilePath: true);
    }

    _persistQueue();
    _stopForegroundServiceIfIdle();
    _processQueue();
  }

  void _updateItem(
    String id, {
    DownloadItemStatus? status,
    double? progress,
    int? receivedBytes,
    int? totalBytes,
    double? downloadSpeed,
    String? error,
    bool clearError = false,
    bool clearSpeed = false,
    int? retryCount,
    String? tempFilePath,
    bool clearTempFilePath = false,
  }) {
    final newQueue = _state.queue.map((item) {
      if (item.id == id) {
        return item.copyWith(
          status: status,
          progress: progress,
          receivedBytes: receivedBytes,
          totalBytes: totalBytes,
          downloadSpeed: downloadSpeed,
          error: error,
          clearError: clearError,
          clearSpeed: clearSpeed,
          retryCount: retryCount,
          tempFilePath: tempFilePath,
          clearTempFilePath: clearTempFilePath,
        );
      }
      return item;
    }).toList();

    _state = _state.copyWith(queue: newQueue);
    _safeNotify();
  }

  // --- Foreground service helpers ---

  Timer? _notificationThrottle;

  void _updateForegroundService() {
    DownloadForegroundService.startIfNeeded(
      activeCount: _state.activeCount,
      queuedCount: _state.queuedCount,
    );
  }

  void _throttledNotificationUpdate() {
    if (_notificationThrottle?.isActive ?? false) return;
    _notificationThrottle = Timer(const Duration(seconds: 2), () {
      if (_disposed) return;
      final active = _state.activeDownloads;
      String? detail;
      if (active.length == 1) {
        detail = active.first.displayText;
      }
      DownloadForegroundService.updateProgress(
        activeCount: _state.activeCount,
        queuedCount: _state.queuedCount,
        progressDetail: detail,
      );
    });
  }

  void _stopForegroundServiceIfIdle() {
    // Check after current state update: any active or queued left?
    if (!_state.hasActiveDownloads && !_state.hasQueuedItems) {
      _notificationThrottle?.cancel();
      DownloadForegroundService.stop();
    }
  }

  DownloadItemStatus _mapStatus(DownloadStatus status) => switch (status) {
    DownloadStatus.downloading => DownloadItemStatus.downloading,
    DownloadStatus.extracting => DownloadItemStatus.extracting,
    DownloadStatus.moving => DownloadItemStatus.moving,
    DownloadStatus.completed => DownloadItemStatus.completed,
    DownloadStatus.cancelled => DownloadItemStatus.cancelled,
    DownloadStatus.error => DownloadItemStatus.error,
    DownloadStatus.idle => DownloadItemStatus.queued,
  };

  String _generateId(GameItem game, SystemModel system) {
    return '${system.name}_${game.filename}';
  }

  // --- Queue Persistence ---

  bool _isPersisting = false;
  bool _persistAgain = false;

  void _persistQueue() {
    if (_isPersisting) {
      _persistAgain = true;
      return;
    }
    _isPersisting = true;
    try {
      final persistable = _state.queue
          .where((item) =>
              item.status == DownloadItemStatus.queued ||
              item.status == DownloadItemStatus.error)
          .map((item) => item.toJson())
          .toList();
      if (persistable.isEmpty) {
        _storage.clearDownloadQueue();
      } else {
        _storage.setDownloadQueue(jsonEncode(persistable));
      }
    } catch (e) {
      debugPrint('DownloadQueue: failed to persist queue: $e');
    } finally {
      _isPersisting = false;
      if (_persistAgain) {
        _persistAgain = false;
        _persistQueue();
      }
    }
  }

  void restoreQueue(List<SystemModel> systems, {AppConfig? appConfig}) {
    final json = _storage.getDownloadQueue();
    if (json == null) return;

    try {
      final List<dynamic> list = jsonDecode(json) as List<dynamic>;
      final systemMapById = {for (final s in systems) s.id: s};
      // Legacy fallback: older persisted queues used system.name
      final systemMapByName = {for (final s in systems) s.name: s};

      final restored = <DownloadItem>[];
      for (final item in list) {
        final map = item as Map<String, dynamic>;
        final systemId = map['systemId'] as String?;
        final systemName = map['systemName'] as String?;
        final system = (systemId != null ? systemMapById[systemId] : null)
            ?? (systemName != null ? systemMapByName[systemName] : null);
        if (system == null) {
          debugPrint('DownloadQueue: skipping restore item with unknown system '
              '(id=$systemId, name=$systemName)');
          continue;
        }

        final downloadItem = DownloadItem.fromJson(map, system);
        if (downloadItem.game.providerConfig == null) {
          debugPrint('DownloadQueue: skipping restore item with null providerConfig');
          continue;
        }

        // Re-inject auth credentials from AppConfig (stripped during persist)
        final restoredItem = _rehydrateAuth(downloadItem, appConfig);

        // Reset to queued so they can be restarted
        restored.add(restoredItem.copyWith(
          status: DownloadItemStatus.queued,
          progress: 0,
          receivedBytes: 0,
          clearError: true,
          clearSpeed: true,
        ));
      }

      if (restored.isNotEmpty) {
        final newQueue = List<DownloadItem>.from(_state.queue)..addAll(restored);
        _state = _state.copyWith(queue: newQueue);
        _safeNotify();
        _processQueue();
      }
    } catch (e) {
      debugPrint('DownloadQueue: failed to restore queue (clearing): $e');
      _storage.clearDownloadQueue();
    }
  }

  /// Re-injects auth credentials from AppConfig into a restored DownloadItem.
  /// The persisted queue strips auth via toJsonWithoutAuth() — this matches
  /// the item's provider back to the current AppConfig and restores auth.
  DownloadItem _rehydrateAuth(DownloadItem item, AppConfig? appConfig) {
    if (appConfig == null) return item;
    final pc = item.game.providerConfig;
    if (pc == null || pc.auth != null) return item;

    final systemConfig = appConfig.systemById(item.system.id);
    if (systemConfig == null) return item;

    final match = _findMatchingProvider(pc, systemConfig.providers);
    if (match?.auth == null) return item;

    final rehydrated = pc.copyWith(auth: match!.auth);
    final updatedGame = item.game.copyWith(providerConfig: rehydrated);
    return item.copyWith(game: updatedGame);
  }

  /// Finds a ProviderConfig in [providers] that matches [target] by type and
  /// connection details (host/url/share), ignoring auth.
  static ProviderConfig? _findMatchingProvider(
    ProviderConfig target,
    List<ProviderConfig> providers,
  ) {
    for (final p in providers) {
      if (p.type != target.type) continue;
      switch (target.type) {
        case ProviderType.web:
        case ProviderType.romm:
          if (p.url == target.url) return p;
        case ProviderType.smb:
          if (p.host == target.host && p.share == target.share) return p;
        case ProviderType.ftp:
          if (p.host == target.host) return p;
      }
    }
    return null;
  }

  @override
  void dispose() {
    _disposed = true;
    _notificationThrottle?.cancel();

    for (final timer in _retryTimers.values) {
      timer.cancel();
    }
    _retryTimers.clear();

    for (final sub in _subscriptions.values) {
      sub?.cancel();
    }
    _subscriptions.clear();

    for (final service in _downloadServices.values) {
      try { service.reset(); } catch (e) {
        debugPrint('DownloadQueue: service reset failed during dispose: $e');
      }
      service.dispose();
    }
    _downloadServices.clear();

    DownloadForegroundService.stop();
    super.dispose();
  }
}
