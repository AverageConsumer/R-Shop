import '../models/system_model.dart';

class ImageHelper {
  static const String _baseUrl =
      'https://raw.githubusercontent.com/libretro-thumbnails/';

  static List<String> getCoverUrls(SystemModel system, List<String> filenames) {
    if (system.libretroId.isEmpty) return [];

    final urls = <String>[];
    final seen = <String>{};

    if (filenames.isNotEmpty) {
      final naiveName = _getNaiveCleanName(filenames.first);
      if (naiveName.isNotEmpty) {
        final encodedName = Uri.encodeComponent(naiveName);
        final url =
            '$_baseUrl${system.libretroId}/master/Named_Boxarts/$encodedName.png';
        if (!seen.contains(url)) {
          urls.add(url);
          seen.add(url);
        }
      }
    }

    for (final filename in filenames) {
      final cleanedName = _removeExtension(filename);
      if (cleanedName.isEmpty) continue;

      final encodedName = Uri.encodeComponent(cleanedName);
      final url =
          '$_baseUrl${system.libretroId}/master/Named_Boxarts/$encodedName.png';

      if (!seen.contains(url)) {
        urls.add(url);
        seen.add(url);
      }
    }

    return urls;
  }

  static String? getCoverUrl(SystemModel system, String gameFilename) {
    if (system.libretroId.isEmpty) return null;

    final cleanedName = _removeExtension(gameFilename);
    if (cleanedName.isEmpty) return null;

    final encodedName = Uri.encodeComponent(cleanedName);
    return '$_baseUrl${system.libretroId}/master/Named_Boxarts/$encodedName.png';
  }

  static List<String> getCoverUrlsForSingle(
      SystemModel system, String gameFilename) {
    if (system.libretroId.isEmpty) return [];

    final urls = <String>[];
    final seen = <String>{};

    final naiveName = _getNaiveCleanName(gameFilename);
    if (naiveName.isNotEmpty) {
      final encodedName = Uri.encodeComponent(naiveName);
      final url =
          '$_baseUrl${system.libretroId}/master/Named_Boxarts/$encodedName.png';
      urls.add(url);
      seen.add(url);
    }

    final cleanedName = _removeExtension(gameFilename);
    if (cleanedName.isNotEmpty) {
      final encodedName = Uri.encodeComponent(cleanedName);
      final url =
          '$_baseUrl${system.libretroId}/master/Named_Boxarts/$encodedName.png';
      if (!seen.contains(url)) {
        urls.add(url);
      }
    }

    return urls;
  }

  static String _getNaiveCleanName(String filename) {
    var name = _removeExtension(filename);

    name = name.replaceAll(RegExp(r'\s*\([^)]*\)'), '');
    name = name.replaceAll(RegExp(r'\s*\[[^\]]*\]'), '');
    name = name.replaceAll(RegExp(r'\s+'), ' ').trim();

    return name;
  }

  static String _removeExtension(String filename) {
    final extensions = [
      '.zip',
      '.7z',
      '.rvz',
      '.3ds',
      '.cia',
      '.iso',
      '.rar',
      '.chd',
      '.gdi',
      '.cue',
      '.pbp',
      '.cso',
      '.z64',
      '.n64',
      '.nds',
      '.gba',
      '.gbc',
      '.gb',
      '.sfc',
      '.nes',
      '.sms',
      '.md',
      '.gen',
      '.gg',
      '.pce'
    ];
    var name = filename;

    for (final ext in extensions) {
      if (name.toLowerCase().endsWith(ext)) {
        name = name.substring(0, name.length - ext.length);
        break;
      }
    }

    return name.trim();
  }
}
