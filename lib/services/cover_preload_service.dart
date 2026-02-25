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

  Future<void> preloadAll(DatabaseService db, {int phase1Pool = 6, int phase2Pool = 4}) async {
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

    // Phase 1 — Games with cover_url
    await _processPool(
      items: phase1,
      poolSize: phase1Pool,
      processItem: (row) => _processWithCoverUrl(
        db: db,
        filename: row['filename'] as String,
        coverUrl: row['cover_url'] as String,
      ),
    );

    // Phase 2 — Games without cover_url (needs URL resolution)
    if (!_cancelled) {
      await _processPool(
        items: phase2,
        poolSize: phase2Pool,
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

  Future<void> _processPool({
    required List<Map<String, dynamic>> items,
    required int poolSize,
    required Future<bool> Function(Map<String, dynamic>) processItem,
  }) async {
    int nextIndex = 0;

    Future<void> worker() async {
      while (!_cancelled) {
        final index = nextIndex++;
        if (index >= items.length) return;

        final ok = await processItem(items[index]);

        state = state.copyWith(
          completed: state.completed + 1,
          succeeded: state.succeeded + (ok ? 1 : 0),
          failed: state.failed + (ok ? 0 : 1),
        );
      }
    }

    final workerCount = poolSize.clamp(1, items.length);
    await Future.wait(List.generate(workerCount, (_) => worker()));
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

      // Fire-and-forget: thumbnail generation runs async in worker isolate
      ThumbnailService.generateThumbnail(coverUrl).then((result) {
        if (result.success) {
          db.updateGameThumbnailData(filename, hasThumbnail: true);
        }
      }).catchError((e) {
        debugPrint('Thumbnail generation failed for $filename: $e');
      });
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

          // Fire-and-forget: thumbnail generation runs async in worker isolate
          ThumbnailService.generateThumbnail(url).then((result) {
            if (result.success) {
              db.updateGameThumbnailData(filename, hasThumbnail: true);
            }
          }).catchError((e) {
            debugPrint('Thumbnail generation failed for $filename: $e');
          });
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
