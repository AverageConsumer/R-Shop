import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:archive/archive_io.dart';

import '../models/game_item.dart';
import '../models/system_model.dart';
import '../services/rom_manager.dart';

/// Prefix for temporary ZIP files created for sharing.
const _sharePrefix = 'rshop_share_';

class RomShareHelper {
  /// Prepares ROM files for sharing via the system share sheet.
  ///
  /// For single-file ROMs, returns the file directly.
  /// For multi-file ROMs in subfolders, creates a ZIP and returns that.
  static Future<List<XFile>> prepareShareFiles({
    required GameItem game,
    required SystemModel system,
    required String targetFolder,
  }) async {
    final result = await RomManager.resolveSharePath(game, system, targetFolder);
    if (result == null) {
      throw StateError('Game is not installed');
    }

    if (!result.isDirectory) {
      return [XFile(result.path, mimeType: 'application/octet-stream')];
    }

    // Multi-file ROM: zip the subfolder
    final tempDir = await getTemporaryDirectory();
    final gameName = p.basename(result.path);
    final zipName = '$_sharePrefix$gameName.zip';
    final zipPath = '${tempDir.path}/$zipName';

    // Clean previous share ZIP for the same game
    final existing = File(zipPath);
    if (await existing.exists()) {
      await existing.delete();
    }

    await compute(_createZip, _ZipParams(result.path, zipPath));

    return [XFile(zipPath, mimeType: 'application/zip')];
  }

  /// Deletes leftover share ZIP files from the temp directory.
  static Future<void> cleanShareTempFiles() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final dir = Directory(tempDir.path);
      await for (final entity in dir.list()) {
        if (entity is File && p.basename(entity.path).startsWith(_sharePrefix)) {
          await entity.delete();
        }
      }
    } catch (e) {
      debugPrint('RomShareHelper: cleanup failed: $e');
    }
  }
}

class _ZipParams {
  final String directoryPath;
  final String outputPath;
  const _ZipParams(this.directoryPath, this.outputPath);
}

/// Runs in an isolate to avoid blocking the UI.
void _createZip(_ZipParams params) {
  final encoder = ZipFileEncoder();
  encoder.zipDirectory(
    Directory(params.directoryPath),
    filename: params.outputPath,
    level: ZipFileEncoder.STORE,
  );
}
