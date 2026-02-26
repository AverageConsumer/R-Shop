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
    'wiiu': 41,
    'switch': 130,
    'psx': 7,
    'ps2': 8,
    'ps3': 9,
    'psp': 38,
    'psvita': 46,
    'mastersystem': 64,
    'megadrive': 29,
    'gamegear': 35,
    'dreamcast': 23,
    'saturn': 32,
    'segacd': 78,
    'sega32x': 30,
    'atari2600': 59,
    'atari5200': 66,
    'atari7800': 60,
    'lynx': 61,
  };

  static String _normalize(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[-_]'), '');
  }

  static RommPlatform? findMatch(
    String systemId,
    List<RommPlatform> platforms,
  ) {
    // 1. Exact match on slug
    for (final p in platforms) {
      if (systemId == p.slug) return p;
    }

    // 2. Exact match on fsSlug
    for (final p in platforms) {
      if (systemId == p.fsSlug) return p;
    }

    // 3. Normalized match
    final normalizedId = _normalize(systemId);
    for (final p in platforms) {
      if (normalizedId == _normalize(p.slug) ||
          normalizedId == _normalize(p.fsSlug)) {
        return p;
      }
    }

    // 4. IGDB ID fallback
    final igdbId = _igdbIdMap[systemId];
    if (igdbId != null) {
      for (final p in platforms) {
        if (p.igdbId == igdbId) return p;
      }
    }

    return null;
  }
}
