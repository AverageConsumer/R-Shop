import '../models/config/provider_config.dart';
import 'game_item.dart';
import 'system_model.dart';

enum DownloadStatus {
  queued,
  downloading,
  extracting,
  moving,
  completed,
  cancelled,
  error,
}

class DownloadItem {
  final String id;
  final GameItem game;
  final SystemModel system;
  final String targetFolder;
  final bool autoExtract;
  final DateTime addedAt;

  final DownloadStatus status;
  final double progress;
  final int receivedBytes;
  final int? totalBytes;
  final double? downloadSpeed;
  final String? error;
  final int retryCount;
  final String? tempFilePath;

  DownloadItem({
    required this.id,
    required this.game,
    required this.system,
    required this.targetFolder,
    this.autoExtract = false,
    DateTime? addedAt,
    this.status = DownloadStatus.queued,
    this.progress = 0.0,
    this.receivedBytes = 0,
    this.totalBytes,
    this.downloadSpeed,
    this.error,
    this.retryCount = 0,
    this.tempFilePath,
  }) : addedAt = addedAt ?? DateTime.now();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DownloadItem && id == other.id;

  @override
  int get hashCode => id.hashCode;

  String get displayText {
    switch (status) {
      case DownloadStatus.queued:
        if (retryCount > 0) return 'Retrying ($retryCount/3)...';
        return 'Queued';
      case DownloadStatus.extracting:
        return 'Extracting...';
      case DownloadStatus.moving:
        return 'Moving...';
      case DownloadStatus.completed:
        return 'Completed';
      case DownloadStatus.cancelled:
        return 'Cancelled';
      case DownloadStatus.error:
        return error ?? 'Error';
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

  bool get isActive =>
      status == DownloadStatus.downloading ||
      status == DownloadStatus.extracting ||
      status == DownloadStatus.moving;

  bool get isComplete => status == DownloadStatus.completed;

  bool get isFailed => status == DownloadStatus.error;

  bool get isCancelled => status == DownloadStatus.cancelled;

  bool get isFinished => isComplete || isFailed || isCancelled;

  DownloadItem copyWith({
    GameItem? game,
    DownloadStatus? status,
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
    return DownloadItem(
      id: id,
      game: game ?? this.game,
      system: system,
      targetFolder: targetFolder,
      autoExtract: autoExtract,
      addedAt: addedAt,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadSpeed: clearSpeed ? null : (downloadSpeed ?? this.downloadSpeed),
      error: clearError ? null : (error ?? this.error),
      retryCount: retryCount ?? this.retryCount,
      tempFilePath: clearTempFilePath ? null : (tempFilePath ?? this.tempFilePath),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'gameFilename': game.filename,
      'gameUrl': game.url,
      'gameDisplayName': game.displayName,
      'gameCachedCoverUrl': game.cachedCoverUrl,
      'systemId': system.id,
      'targetFolder': targetFolder,
      'autoExtract': autoExtract,
      'addedAt': addedAt.toIso8601String(),
      'status': status.name,
      'progress': progress,
      'retryCount': retryCount,
      if (tempFilePath != null) 'tempFilePath': tempFilePath,
      if (game.isFolder) 'isFolder': true,
      if (game.providerConfig != null)
        'providerConfig': game.providerConfig!.toJsonWithoutAuth(),
    };
  }

  static DownloadStatus _parseStatus(dynamic value) {
    if (value is String) {
      return DownloadStatus.values.firstWhere(
        (e) => e.name == value,
        orElse: () => DownloadStatus.queued,
      );
    }
    if (value is int && value < DownloadStatus.values.length) {
      return DownloadStatus.values[value];
    }
    return DownloadStatus.queued;
  }

  factory DownloadItem.fromJson(Map<String, dynamic> json, SystemModel system) {
    final providerConfigJson = json['providerConfig'] as Map<String, dynamic>?;
    final providerConfig = providerConfigJson != null
        ? ProviderConfig.fromJson(providerConfigJson)
        : null;

    return DownloadItem(
      id: json['id'] as String,
      game: GameItem(
        filename: json['gameFilename'] as String,
        url: json['gameUrl'] as String,
        displayName: json['gameDisplayName'] as String,
        cachedCoverUrl: json['gameCachedCoverUrl'] as String?,
        providerConfig: providerConfig,
        isFolder: json['isFolder'] as bool? ?? false,
      ),
      system: system,
      targetFolder: (json['targetFolder'] ?? json['romPath']) as String,
      autoExtract: json['autoExtract'] as bool? ?? false,
      addedAt: DateTime.parse(json['addedAt'] as String),
      status: _parseStatus(json['status']),
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      retryCount: (json['retryCount'] as int?) ?? 0,
      tempFilePath: json['tempFilePath'] as String?,
    );
  }
}
