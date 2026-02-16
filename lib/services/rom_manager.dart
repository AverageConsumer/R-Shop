import 'dart:io';

import '../models/game_item.dart';
import '../models/system_model.dart';

class RomManager {
  static const _archiveExtensions = ['.zip', '.7z', '.rar'];

  static String _safePath(String baseDir, String filename) {
    final sanitized = filename.replaceAll(RegExp(r'\.\.[\\/]'), '');
    final resolved = File('$baseDir/$sanitized').absolute.path;
    if (!resolved.startsWith(File(baseDir).absolute.path)) {
      throw Exception('Invalid filename: path traversal detected');
    }
    return resolved;
  }

  static String getTargetPath(
      GameItem game, SystemModel system, String romPath) {
    final folder = _safePath(romPath, system.esdeFolder);
    var filename = game.filename;

    for (final ext in _archiveExtensions) {
      if (filename.toLowerCase().endsWith(ext)) {
        filename = filename.substring(0, filename.length - ext.length);
        filename =
            '$filename${system.romExtensions.isNotEmpty ? system.romExtensions.first : ''}';
        break;
      }
    }

    return _safePath(folder, filename);
  }

  static String getTargetFolder(SystemModel system, String romPath) {
    return _safePath(romPath, system.esdeFolder);
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

    final parenIndex = name.indexOf('(');
    if (parenIndex > 0) {
      name = name.substring(0, parenIndex).trim();
    }

    name = name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    name = name.replaceAll(RegExp(r'\s+'), ' ').trim();

    return name.isEmpty ? null : name;
  }

  Future<bool> exists(GameItem game, SystemModel system, String romPath) async {
    final directPath = getTargetPath(game, system, romPath);
    if (await File(directPath).exists()) {
      return true;
    }

    if (system.multiFileExtensions != null &&
        system.multiFileExtensions!.isNotEmpty) {
      final gameName = extractGameName(game.filename);
      if (gameName != null) {
        final subfolderPath =
            _safePath(getTargetFolder(system, romPath), gameName);
        final subfolder = Directory(subfolderPath);
        if (await subfolder.exists()) {
          final files = subfolder.listSync();
          for (final file in files) {
            if (file is File) {
              final ext = '.${file.path.split('.').last.toLowerCase()}';
              if (system.multiFileExtensions!
                  .map((e) => e.toLowerCase())
                  .contains(ext)) {
                return true;
              }
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
    String romPath,
  ) async {
    final result = <int, bool>{};
    for (int i = 0; i < variants.length; i++) {
      result[i] = await exists(variants[i], system, romPath);
    }
    return result;
  }

  Future<void> delete(GameItem game, SystemModel system, String romPath) async {
    final path = getTargetPath(game, system, romPath);
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
      return;
    }

    if (system.multiFileExtensions != null &&
        system.multiFileExtensions!.isNotEmpty) {
      final gameName = extractGameName(game.filename);
      if (gameName != null) {
        final subfolderPath =
            _safePath(getTargetFolder(system, romPath), gameName);
        final subfolder = Directory(subfolderPath);
        if (await subfolder.exists()) {
          await subfolder.delete(recursive: true);
        }
      }
    }
  }

  Future<Set<String>> getInstalledFilenames(
    List<GameItem> variants,
    SystemModel system,
    String romPath,
  ) async {
    final installed = <String>{};
    for (final variant in variants) {
      if (await exists(variant, system, romPath)) {
        installed.add(variant.filename);
      }
    }
    return installed;
  }

  Future<bool> isAnyVariantInstalled(
    List<GameItem> variants,
    SystemModel system,
    String romPath,
  ) async {
    for (final variant in variants) {
      if (await exists(variant, system, romPath)) {
        return true;
      }
    }
    return false;
  }
}
