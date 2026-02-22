import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'database_service.dart';
import 'thumbnail_service.dart';

class ThumbnailMigrationService {
  static const _currentVersion = 2;
  static const _versionKey = 'thumbnail_version';

  /// Generates thumbnails for games that have cached cover URLs but no
  /// thumbnail yet. Runs as a background fire-and-forget task at startup.
  static Future<void> migrateIfNeeded(DatabaseService db) async {
    try {
      // Check if thumbnails need regeneration due to quality upgrade
      final prefs = await SharedPreferences.getInstance();
      final storedVersion = prefs.getInt(_versionKey) ?? 0;
      if (storedVersion < _currentVersion) {
        debugPrint('Thumbnail version upgrade: $storedVersion → $_currentVersion');
        await ThumbnailService.clearAll();
        await db.clearThumbnailData();
        await prefs.setInt(_versionKey, _currentVersion);
        debugPrint('Cleared old thumbnails — will regenerate at higher quality');
      }

      final rows = await db.getGamesNeedingThumbnails();
      if (rows.isEmpty) return;

      debugPrint('Thumbnail migration: ${rows.length} games to process');

      // Process in batches of 3 with delay between batches
      for (var i = 0; i < rows.length; i += 3) {
        final batch = rows.skip(i).take(3).toList();
        await Future.wait(
          batch.map((row) async {
            final filename = row['filename'] as String;
            final coverUrl = row['cover_url'] as String;
            try {
              final result =
                  await ThumbnailService.generateThumbnail(coverUrl);
              if (result.success) {
                await db.updateGameThumbnailData(
                  filename,
                  hasThumbnail: true,
                );
              }
            } catch (e) {
              // Skip failures — they'll get thumbnails on next view
            }
          }),
        );
        await Future.delayed(const Duration(milliseconds: 100));
      }

      debugPrint('Thumbnail migration complete');
    } catch (e) {
      debugPrint('Thumbnail migration failed: $e');
    }
  }
}
