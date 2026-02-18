import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/download_item.dart';
import '../models/game_item.dart';
import '../models/system_model.dart';
import 'download_foreground_service.dart';
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
    try {
      return queue.firstWhere((item) => item.id == id);
    } catch (_) {
      return null;
    }
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

  DownloadQueueState _state = const DownloadQueueState();
  DownloadQueueState get state => _state;

  final Map<String, StreamSubscription?> _subscriptions = {};
  final Map<String, DownloadService> _downloadServices = {};
  final StorageService _storage;

  DownloadQueueManager(this._storage) {
    final maxConcurrent = _storage.getMaxConcurrentDownloads();
    _state = _state.copyWith(maxConcurrent: maxConcurrent);
  }

  void setMaxConcurrent(int value) {
    final clamped = value.clamp(1, 3);
    _state = _state.copyWith(maxConcurrent: clamped);
    _storage.setMaxConcurrentDownloads(clamped);
    notifyListeners();
    _processQueue();
  }

  static bool _isRetryableError(String? error) {
    if (error == null) return false;
    const nonRetryable = ['File not found (404)', 'SSL error'];
    return !nonRetryable.any((e) => error.contains(e));
  }

  void _scheduleRetry(String id, int retryCount) {
    // Exponential backoff: 5s, 15s, 45s
    const delays = [5, 15, 45];
    final delaySeconds = delays[retryCount.clamp(0, delays.length - 1)];

    Future.delayed(Duration(seconds: delaySeconds), () {
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

  String addToQueue(GameItem game, SystemModel system, String targetFolder) {
    final id = _generateId(game, system);

    final existing = _state.getDownloadById(id);
    if (existing != null && !existing.isFinished) {
      return id;
    }

    final item = DownloadItem(
      id: id,
      game: game,
      system: system,
      targetFolder: targetFolder,
    );

    final newQueue = List<DownloadItem>.from(_state.queue);

    if (existing != null) {
      newQueue.removeWhere((i) => i.id == id);
    }

    newQueue.insert(0, item);
    _state = _state.copyWith(queue: newQueue);
    notifyListeners();
    _persistQueue();

    _processQueue();

    return id;
  }

  Future<void> cancelDownload(String id) async {
    final item = _state.getDownloadById(id);
    if (item == null) return;

    _subscriptions[id]?.cancel();
    _subscriptions.remove(id);

    await _downloadServices[id]?.cancelDownload();
    _downloadServices.remove(id);

    _updateItem(id, status: DownloadItemStatus.cancelled);
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

    final newQueue = List<DownloadItem>.from(_state.queue)
      ..removeWhere((i) => i.id == id);
    _state = _state.copyWith(queue: newQueue);
    notifyListeners();
    _persistQueue();
  }

  void clearCompleted() {
    final newQueue = _state.queue.where((item) => !item.isFinished).toList();
    _state = _state.copyWith(queue: newQueue);
    notifyListeners();
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
    if (!_state.canStartNewDownload()) return;

    final queuedItems = _state.queuedItems;
    if (queuedItems.isEmpty) return;

    final availableSlots = _state.maxConcurrent - _state.activeCount;
    final itemsToStart = queuedItems.take(availableSlots);

    for (final item in itemsToStart) {
      _startDownload(item);
    }
  }

  void _startDownload(DownloadItem item) {
    _updateItem(item.id, status: DownloadItemStatus.downloading);
    _updateForegroundService();

    final targetFolder = item.targetFolder;

    _subscriptions[item.id]?.cancel();

    final downloadService = DownloadService();
    _downloadServices[item.id] = downloadService;

    final subscription = downloadService
        .downloadGameStream(
      item.game,
      targetFolder,
      item.system,
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
        _subscriptions.remove(item.id);
        final service = _downloadServices.remove(item.id);
        service?.dispose();
        final errorMsg = error.toString();
        _updateItem(
          item.id,
          status: DownloadItemStatus.error,
          error: errorMsg,
        );

        final currentItem = _state.getDownloadById(item.id);
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
      _updateItem(id, status: DownloadItemStatus.completed);
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
        );
      }
      return item;
    }).toList();

    _state = _state.copyWith(queue: newQueue);
    notifyListeners();
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

  DownloadItemStatus _mapStatus(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.downloading:
        return DownloadItemStatus.downloading;
      case DownloadStatus.extracting:
        return DownloadItemStatus.extracting;
      case DownloadStatus.moving:
        return DownloadItemStatus.moving;
      case DownloadStatus.completed:
        return DownloadItemStatus.completed;
      case DownloadStatus.cancelled:
        return DownloadItemStatus.cancelled;
      case DownloadStatus.error:
        return DownloadItemStatus.error;
      case DownloadStatus.idle:
        return DownloadItemStatus.queued;
    }
  }

  String _generateId(GameItem game, SystemModel system) {
    return '${system.name}_${game.filename}';
  }

  // --- Queue Persistence ---

  void _persistQueue() {
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
  }

  void restoreQueue(List<SystemModel> systems) {
    final json = _storage.getDownloadQueue();
    if (json == null) return;

    try {
      final List<dynamic> list = jsonDecode(json) as List<dynamic>;
      final systemMap = {for (final s in systems) s.name: s};

      final restored = <DownloadItem>[];
      for (final item in list) {
        final map = item as Map<String, dynamic>;
        final systemName = map['systemName'] as String?;
        final system = systemName != null ? systemMap[systemName] : null;
        if (system == null) continue;

        final downloadItem = DownloadItem.fromJson(map, system);
        // Reset to queued so they can be restarted
        restored.add(downloadItem.copyWith(
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
        notifyListeners();
        _processQueue();
      }
    } catch (_) {
      // Corrupted data — just clear it
      _storage.clearDownloadQueue();
    }
  }

  @override
  void dispose() {
    _notificationThrottle?.cancel();

    for (final sub in _subscriptions.values) {
      sub?.cancel();
    }
    _subscriptions.clear();

    for (final service in _downloadServices.values) {
      service.reset();
      service.dispose();
    }
    _downloadServices.clear();

    DownloadForegroundService.stop();
    super.dispose();
  }
}
