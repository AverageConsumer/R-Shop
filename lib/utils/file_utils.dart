import 'dart:io';

import 'package:flutter/foundation.dart';

/// Staging suffix used for crash-safe cross-filesystem copies.
/// If a file with this suffix exists, it's a leftover from a crashed move.
const stagingSuffix = '.rshop_staging';

/// Moves a file from [source] to [targetPath] using rename (O(1) on same
/// filesystem). Falls back to a crash-safe staging pattern when source and
/// target are on different filesystems:
///
/// 1. Delete any leftover staging file from a previous crash
/// 2. Copy source → {targetPath}.rshop_staging
/// 3. Verify staging file size == source file size
/// 4. Rename staging → target (atomic, same filesystem)
/// 5. Delete source
///
/// If the process dies at any point, the final target path either doesn't
/// exist or is complete — never partial.
Future<void> moveFile(File source, String targetPath) async {
  // Always clean up leftover staging file from a previous crash,
  // regardless of whether this move uses rename or copy.
  await _cleanLeftoverStaging(targetPath);

  try {
    await source.rename(targetPath);
  } on FileSystemException {
    // Cross-filesystem (e.g. internal storage → SD card)
    await _moveFileViaStagingCopy(source, targetPath);
  }
}

Future<void> _cleanLeftoverStaging(String targetPath) async {
  try {
    final stagingFile = File('$targetPath$stagingSuffix');
    if (await stagingFile.exists()) {
      await stagingFile.delete();
      debugPrint('moveFile: cleaned leftover staging file for $targetPath');
    }
  } catch (e) {
    debugPrint('moveFile: leftover staging cleanup failed: $e');
  }
}

Future<void> _moveFileViaStagingCopy(File source, String targetPath) async {
  final stagingPath = '$targetPath$stagingSuffix';
  final stagingFile = File(stagingPath);

  try {
    // 2. Copy to staging path
    await source.copy(stagingPath);

    // 3. Verify: staging size must match source size
    final sourceSize = await source.length();
    final stagingSize = await stagingFile.length();
    if (stagingSize != sourceSize) {
      throw FileSystemException(
        'Size mismatch after copy: source=$sourceSize, staging=$stagingSize',
        stagingPath,
      );
    }

    // 4. Atomic rename: staging → final target (same filesystem)
    await stagingFile.rename(targetPath);

    // 5. Delete source
    await source.delete();
  } catch (e) {
    // Clean up staging file on any failure
    try {
      if (await stagingFile.exists()) {
        await stagingFile.delete();
      }
    } catch (e2) {
      debugPrint('moveFile: staging cleanup on error failed: $e2');
    }
    rethrow;
  }
}
