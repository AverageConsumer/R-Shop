import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/system_model.dart';
import '../utils/image_helper.dart';
import 'database_service.dart';
import 'image_cache_service.dart';
import 'thumbnail_service.dart';

class CoverPreloadState {
  final bool isRunning;
  final int total;
  final int completed;
  final int succeeded;
  final int failed;

  const CoverPreloadState({
    this.isRunning = false,
    this.total = 0,
    this.completed = 0,
    this.succeeded = 0,
    this.failed = 0,
  });

  double get progress => total > 0 ? completed / total : 0;

  CoverPreloadState copyWith({
    bool? isRunning,
    int? total,
    int? completed,
    int? succeeded,
    int? failed,
  }) {
    return CoverPreloadState(
      isRunning: isRunning ?? this.isRunning,
      total: total ?? this.total,
      completed: completed ?? this.completed,
      succeeded: succeeded ?? this.succeeded,
      failed: failed ?? this.failed,
    );
  }
}

final coverPreloadServiceProvider =
    StateNotifierProvider<CoverPreloadService, CoverPreloadState>((ref) {
  return CoverPreloadService();
});

class CoverPreloadService extends StateNotifier<CoverPreloadState> {
  CoverPreloadService() : super(const CoverPreloadState());

  bool _cancelled = false;

  Future<void> preloadAll(DatabaseService db) async {
    if (state.isRunning) return;
    state = state.copyWith(isRunning: true);
    _cancelled = false;

    final rows = await db.getGamesNeedingCovers();
    if (rows.isEmpty) {
      state = const CoverPreloadState();
      return;
    }

    // Split into Phase 1 (has cover_url) and Phase 2 (needs URL resolution)
    final phase1 = <Map<String, dynamic>>[];
    final phase2 = <Map<String, dynamic>>[];
    for (final row in rows) {
      if (row['cover_url'] != null &&
          (row['cover_url'] as String).isNotEmpty) {
        phase1.add(row);
      } else {
        phase2.add(row);
      }
    }

    state = state.copyWith(
      total: rows.length,
    );

    // Build system lookup map for Phase 2
    final systemMap = <String, SystemModel>{};
    for (final s in SystemModel.supportedSystems) {
      systemMap[s.id] = s;
    }

    // Phase 1 — Games with cover_url (batch 3, 100ms pause)
    await _processBatches(
      items: phase1,
      batchSize: 3,
      pauseMs: 100,
      processItem: (row) => _processWithCoverUrl(
        db: db,
        filename: row['filename'] as String,
        coverUrl: row['cover_url'] as String,
      ),
    );

    // Phase 2 — Games without cover_url (batch 2, 200ms pause)
    if (!_cancelled) {
      await _processBatches(
        items: phase2,
        batchSize: 2,
        pauseMs: 200,
        processItem: (row) => _processWithoutCoverUrl(
          db: db,
          filename: row['filename'] as String,
          systemSlug: row['systemSlug'] as String,
          systemMap: systemMap,
        ),
      );
    }

    state = state.copyWith(isRunning: false);
  }

  Future<void> _processBatches({
    required List<Map<String, dynamic>> items,
    required int batchSize,
    required int pauseMs,
    required Future<bool> Function(Map<String, dynamic>) processItem,
  }) async {
    for (int i = 0; i < items.length; i += batchSize) {
      if (_cancelled) return;

      final end = (i + batchSize).clamp(0, items.length);
      final batch = items.sublist(i, end);

      final results = await Future.wait(
        batch.map((row) => processItem(row)),
      );

      int batchSucceeded = 0;
      int batchFailed = 0;
      for (final ok in results) {
        if (ok) {
          batchSucceeded++;
        } else {
          batchFailed++;
        }
      }

      state = state.copyWith(
        completed: state.completed + batch.length,
        succeeded: state.succeeded + batchSucceeded,
        failed: state.failed + batchFailed,
      );

      if (i + batchSize < items.length && !_cancelled) {
        await Future.delayed(Duration(milliseconds: pauseMs));
      }
    }
  }

  Future<bool> _processWithCoverUrl({
    required DatabaseService db,
    required String filename,
    required String coverUrl,
  }) async {
    try {
      if (FailedUrlsCache.instance.hasFailed(coverUrl)) return false;

      final file =
          await GameCoverCacheManager.instance.getSingleFile(coverUrl);
      if (!isValidImageFile(file)) {
        await GameCoverCacheManager.instance.removeFile(coverUrl);
        FailedUrlsCache.instance.markFailed(coverUrl);
        return false;
      }

      final result = await ThumbnailService.generateThumbnail(coverUrl);
      if (!result.success) return false;

      await db.updateGameThumbnailData(
        filename,
        hasThumbnail: true,
      );
      return true;
    } catch (e) {
      debugPrint('Cover preload failed for $filename: $e');
      return false;
    }
  }

  Future<bool> _processWithoutCoverUrl({
    required DatabaseService db,
    required String filename,
    required String systemSlug,
    required Map<String, SystemModel> systemMap,
  }) async {
    try {
      final system = systemMap[systemSlug];
      if (system == null || system.libretroId.isEmpty) return false;

      final urls = ImageHelper.getCoverUrlsForSingle(system, filename);
      if (urls.isEmpty) return false;

      for (final url in urls) {
        if (_cancelled) return false;
        if (FailedUrlsCache.instance.hasFailed(url)) continue;

        try {
          final file =
              await GameCoverCacheManager.instance.getSingleFile(url);
          if (!isValidImageFile(file)) {
            await GameCoverCacheManager.instance.removeFile(url);
            FailedUrlsCache.instance.markFailed(url);
            continue;
          }

          // Found a valid cover — persist URL
          await db.updateGameCover(filename, url);

          // Generate thumbnail
          final result = await ThumbnailService.generateThumbnail(url);
          if (result.success) {
            await db.updateGameThumbnailData(
              filename,
              hasThumbnail: true,
            );
          }
          return true;
        } catch (e) {
          debugPrint('CoverPreload: URL fetch failed for $url: $e');
          FailedUrlsCache.instance.markFailed(url);
          continue;
        }
      }
      return false;
    } catch (e) {
      debugPrint('Cover URL resolution failed for $filename: $e');
      return false;
    }
  }

  void cancel() {
    _cancelled = true;
  }
}
