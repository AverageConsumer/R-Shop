import '../models/system_model.dart';

class ImageHelper {
  static final _gameExtensions = SystemModel.allGameExtensions;
  static const String _baseUrl =
      'https://raw.githubusercontent.com/libretro-thumbnails/';

  static const _fallbackRegions = ['(USA)', '(Europe)', '(Japan)'];

  static List<String> getCoverUrls(SystemModel system, List<String> filenames) {
    if (system.libretroId.isEmpty) return [];

    final urls = <String>[];
    final seen = <String>{};

    void addUrl(String name) {
      if (name.isEmpty) return;
      final encoded = Uri.encodeComponent(name);
      final url =
          '$_baseUrl${system.libretroId}/master/Named_Boxarts/$encoded.png';
      if (seen.add(url)) urls.add(url);
    }

    if (filenames.isNotEmpty) {
      final naive = _getNaiveCleanName(filenames.first);
      addUrl(naive);
      addUrl(_getRegionCleanName(filenames.first));
      addUrl(_getPrimaryRegionName(filenames.first));

      // For filenames without region info, try common region suffixes
      if (!_hasParens(filenames.first)) {
        for (final region in _fallbackRegions) {
          addUrl('$naive $region');
        }
      }
    }

    for (final filename in filenames) {
      addUrl(_removeExtension(filename));
    }

    return urls;
  }

  static List<String> getCoverUrlsForSingle(
      SystemModel system, String gameFilename) {
    if (system.libretroId.isEmpty) return [];

    final urls = <String>[];
    final seen = <String>{};

    void addUrl(String name) {
      if (name.isEmpty) return;
      final encoded = Uri.encodeComponent(name);
      final url =
          '$_baseUrl${system.libretroId}/master/Named_Boxarts/$encoded.png';
      if (seen.add(url)) urls.add(url);
    }

    final naive = _getNaiveCleanName(gameFilename);
    addUrl(naive);
    addUrl(_getRegionCleanName(gameFilename));
    addUrl(_getPrimaryRegionName(gameFilename));
    addUrl(_removeExtension(gameFilename));

    if (!_hasParens(gameFilename)) {
      for (final region in _fallbackRegions) {
        addUrl('$naive $region');
      }
    }

    return urls;
  }

  static bool _hasParens(String filename) =>
      RegExp(r'\(').hasMatch(_removeExtension(filename));

  /// Keeps only the first parenthetical group (usually region like "(USA)"),
  /// strips all other parens and brackets.
  /// Normalizes comma spacing: "(USA,Europe)" → "(USA, Europe)".
  static String _getRegionCleanName(String filename) {
    var name = _removeExtension(filename);
    final match = RegExp(r'\(([^)]*)\)').firstMatch(name);
    if (match == null) return '';
    final baseName = name.substring(0, match.start).trim();
    var content = match.group(1)!;
    // Normalize: add space after commas if missing (libretro uses "USA, Europe")
    content = content.replaceAll(RegExp(r',(?!\s)'), ', ');
    return '$baseName ($content)';
  }

  /// For multi-region tags like "(USA,Europe)", extracts just the first region "(USA)".
  static String _getPrimaryRegionName(String filename) {
    var name = _removeExtension(filename);
    final match = RegExp(r'\(([^)]*)\)').firstMatch(name);
    if (match == null) return '';
    final content = match.group(1)!;
    if (!content.contains(',')) return '';
    final primaryRegion = content.split(',').first.trim();
    final baseName = name.substring(0, match.start).trim();
    return '$baseName ($primaryRegion)';
  }

  static String _getNaiveCleanName(String filename) {
    var name = _removeExtension(filename);

    name = name.replaceAll(RegExp(r'\s*\([^)]*\)'), '');
    name = name.replaceAll(RegExp(r'\s*\[[^\]]*\]'), '');
    name = name.replaceAll(RegExp(r'\s+'), ' ').trim();

    return name;
  }

  static String _removeExtension(String filename) {
    var name = filename;

    for (final ext in _gameExtensions) {
      if (name.toLowerCase().endsWith(ext)) {
        name = name.substring(0, name.length - ext.length);
        break;
      }
    }

    return name.trim();
  }
}
