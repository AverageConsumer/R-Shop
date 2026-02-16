import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/download_item.dart';
import '../models/game_item.dart';
import '../models/system_model.dart';
import 'download_service.dart';
import 'rom_manager.dart';

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
  DownloadQueueState _state = const DownloadQueueState();
  DownloadQueueState get state => _state;

  final Map<String, StreamSubscription?> _subscriptions = {};
  final Map<String, DownloadService> _downloadServices = {};

  DownloadQueueManager();

  String addToQueue(GameItem game, SystemModel system, String romPath) {
    final id = _generateId(game, system);

    final existing = _state.getDownloadById(id);
    if (existing != null && !existing.isFinished) {
      return id;
    }

    final item = DownloadItem(
      id: id,
      game: game,
      system: system,
      romPath: romPath,
    );

    final newQueue = List<DownloadItem>.from(_state.queue);

    if (existing != null) {
      newQueue.removeWhere((i) => i.id == id);
    }

    newQueue.insert(0, item);
    _state = _state.copyWith(queue: newQueue);
    notifyListeners();

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
  }

  void clearCompleted() {
    final newQueue = _state.queue.where((item) => !item.isFinished).toList();
    _state = _state.copyWith(queue: newQueue);
    notifyListeners();
  }

  void retryDownload(String id) {
    final item = _state.getDownloadById(id);
    if (item == null || item.isActive) return;

    _updateItem(
      id,
      status: DownloadItemStatus.queued,
      progress: 0,
      receivedBytes: 0,
      clearError: true,
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

    final targetFolder = RomManager.getTargetFolder(item.system, item.romPath);

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
      },
      onDone: () {
        _subscriptions.remove(item.id);
        _downloadServices.remove(item.id);
        _onDownloadComplete(item.id);
      },
      onError: (error) {
        _subscriptions.remove(item.id);
        _downloadServices.remove(item.id);
        _updateItem(
          item.id,
          status: DownloadItemStatus.error,
          error: error.toString(),
        );
        _processQueue();
      },
      cancelOnError: true,
    );

    _subscriptions[item.id] = subscription;
  }

  void _onDownloadComplete(String id) {
    final item = _state.getDownloadById(id);
    if (item == null) return;

    if (item.status == DownloadItemStatus.extracting ||
        item.status == DownloadItemStatus.moving) {
      _updateItem(id, status: DownloadItemStatus.completed);
    }

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
        );
      }
      return item;
    }).toList();

    _state = _state.copyWith(queue: newQueue);
    notifyListeners();
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

  @override
  void dispose() {
    for (final sub in _subscriptions.values) {
      sub?.cancel();
    }
    _subscriptions.clear();

    for (final service in _downloadServices.values) {
      service.cancelDownload();
    }
    _downloadServices.clear();

    super.dispose();
  }
}
