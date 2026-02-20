import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/game_item.dart';
import '../models/system_model.dart';

class RomManager {
  static const _archiveExtensions = ['.zip', '.rar'];

  static String _safePath(String baseDir, String filename) {
    final sanitized = p.basename(filename);
    if (sanitized.isEmpty || sanitized == '.' || sanitized == '..') {
      throw Exception('Invalid filename: path traversal detected');
    }
    return '$baseDir/$sanitized';
  }

  static String getTargetPath(
      GameItem game, SystemModel system, String targetFolder) {
    return _safePath(targetFolder, getTargetFilename(game, system));
  }

  /// Returns the filename a game would have after download (archive → ROM extension).
  static String getTargetFilename(GameItem game, SystemModel system) {
    var filename = p.basename(game.filename);

    for (final ext in _archiveExtensions) {
      if (filename.toLowerCase().endsWith(ext)) {
        filename = filename.substring(0, filename.length - ext.length);
        filename =
            '$filename${system.romExtensions.isNotEmpty ? system.romExtensions.first : ''}';
        break;
      }
    }

    return filename;
  }

  static String? extractGameName(String filename) {
    var name = filename;

    final archiveExts = ['.zip', '.7z', '.rar'];
    for (final ext in archiveExts) {
      if (name.toLowerCase().endsWith(ext)) {
        name = name.substring(0, name.length - ext.length);
        break;
      }
    }

    name = name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    name = name.replaceAll(RegExp(r'\s+'), ' ').trim();

    return name.isEmpty ? null : name;
  }

  static Future<List<GameItem>> scanLocalGames(
    SystemModel system,
    String targetFolder,
  ) async {
    final dir = Directory(targetFolder);
    if (!await dir.exists()) return [];

    final allExtensions = [
      ...system.romExtensions.map((e) => e.toLowerCase()),
      ..._archiveExtensions,
    ];
    final multiExts =
        system.multiFileExtensions?.map((e) => e.toLowerCase()).toList() ?? [];

    final dirNames = <String>{};
    final games = <GameItem>[];
    final entities = await dir.list().toList();

    // Pass 1: Directories containing ROM files (multi-file or single ROM in subfolder)
    final subDirExts = {
      ...system.romExtensions.map((e) => e.toLowerCase()),
      ...multiExts,
    };
    for (final entity in entities) {
      if (entity is! Directory) continue;
      final name = p.basename(entity.path);
      final subFiles = entity.listSync();
      final hasMatchingFile = subFiles.any((f) =>
          f is File && subDirExts.contains(p.extension(f.path).toLowerCase()));
      if (hasMatchingFile) {
        dirNames.add(name);
        games.add(GameItem(
          filename: name,
          displayName: GameItem.cleanDisplayName(name),
          url: '',
        ));
      }
    }

    // Pass 2: Individual files (skip if a multi-file dir with same base name exists)
    for (final entity in entities) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      final ext = p.extension(name).toLowerCase();
      if (!allExtensions.contains(ext)) continue;
      if (dirNames.contains(p.basenameWithoutExtension(name))) continue;
      games.add(GameItem(
        filename: name,
        displayName: GameItem.cleanDisplayName(name),
        url: '',
      ));
    }

    games.sort((a, b) =>
        a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    return games;
  }

  Future<bool> exists(
      GameItem game, SystemModel system, String targetFolder) async {
    final directPath = getTargetPath(game, system, targetFolder);
    if (await File(directPath).exists()) {
      return true;
    }

    final gameName = extractGameName(game.filename);
    if (gameName != null) {
      final subfolderPath = _safePath(targetFolder, gameName);
      final subfolder = Directory(subfolderPath);
      if (await subfolder.exists()) {
        final validExts = {
          ...system.romExtensions.map((e) => e.toLowerCase()),
          ...?system.multiFileExtensions?.map((e) => e.toLowerCase()),
        };
        final files = subfolder.listSync();
        for (final file in files) {
          if (file is File) {
            final ext = p.extension(file.path).toLowerCase();
            if (validExts.contains(ext)) {
              return true;
            }
          }
        }
      }
    }

    return false;
  }

  Future<Map<int, bool>> checkMultipleExists(
    List<GameItem> variants,
    SystemModel system,
    String targetFolder,
  ) async {
    final result = <int, bool>{};
    for (int i = 0; i < variants.length; i++) {
      result[i] = await exists(variants[i], system, targetFolder);
    }
    return result;
  }

  Future<void> delete(
      GameItem game, SystemModel system, String targetFolder) async {
    final path = getTargetPath(game, system, targetFolder);
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
      return;
    }

    final gameName = extractGameName(game.filename);
    if (gameName != null) {
      final subfolderPath = _safePath(targetFolder, gameName);
      final subfolder = Directory(subfolderPath);
      if (await subfolder.exists()) {
        await subfolder.delete(recursive: true);
      }
    }
  }

  Future<Set<String>> getInstalledFilenames(
    List<GameItem> variants,
    SystemModel system,
    String targetFolder,
  ) async {
    final installed = <String>{};
    for (final variant in variants) {
      if (await exists(variant, system, targetFolder)) {
        installed.add(variant.filename);
      }
    }
    return installed;
  }

  Future<bool> isAnyVariantInstalled(
    List<GameItem> variants,
    SystemModel system,
    String targetFolder,
  ) async {
    for (final variant in variants) {
      if (await exists(variant, system, targetFolder)) {
        return true;
      }
    }
    return false;
  }
}
