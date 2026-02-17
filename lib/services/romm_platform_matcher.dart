import 'romm_api_service.dart';

class RommPlatformMatcher {
  RommPlatformMatcher._();

  static const Map<String, int> _igdbIdMap = {
    'nes': 18,
    'snes': 19,
    'n64': 4,
    'gb': 33,
    'gbc': 22,
    'gba': 24,
    'nds': 20,
    'n3ds': 37,
    'gc': 21,
    'wii': 5,
    'psx': 7,
    'ps2': 8,
    'psp': 38,
    'mastersystem': 64,
    'megadrive': 29,
    'gamegear': 35,
    'dreamcast': 23,
    'saturn': 32,
  };

  static String _normalize(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[-_]'), '');
  }

  static RommPlatform? findMatch(
    String esdeFolder,
    List<RommPlatform> platforms,
  ) {
    // 1. Exact match on slug
    for (final p in platforms) {
      if (esdeFolder == p.slug) return p;
    }

    // 2. Exact match on fsSlug
    for (final p in platforms) {
      if (esdeFolder == p.fsSlug) return p;
    }

    // 3. Normalized match
    final normalizedFolder = _normalize(esdeFolder);
    for (final p in platforms) {
      if (normalizedFolder == _normalize(p.slug) ||
          normalizedFolder == _normalize(p.fsSlug)) {
        return p;
      }
    }

    // 4. IGDB ID fallback
    final igdbId = _igdbIdMap[esdeFolder];
    if (igdbId != null) {
      for (final p in platforms) {
        if (p.igdbId == igdbId) return p;
      }
    }

    return null;
  }
}
