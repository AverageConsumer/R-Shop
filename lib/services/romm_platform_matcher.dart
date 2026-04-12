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
    // New systems
    'tg16': 86,
    'tgcd': 150,
    'ngp': 119,
    'neogeocd': 136,
    'wonderswan': 57,
    'virtualboy': 87,
    'fds': 51,
    'dsi': 159,
    'sg1000': 84,
    'colecovision': 68,
    'intellivision': 67,
    'vectrex': 70,
    'msx': 27,
    'amstradcpc': 25,
    'channelf': 127,
    'odyssey2': 133,
    'jaguar': 62,
    'jaguarcd': 410,
    'c64': 15,
    'vic20': 71,
    'amiga': 16,
    'atarist': 63,
    'appleii': 75,
    'cdi': 117,
    '3do': 50,
    'pcfx': 274,
    'x68000': 121,
    'fmtowns': 118,
    'zxspectrum': 26,
    'gameandwatch': 307,
    'ngage': 42,
    'x1': 77,
    'arcadia2001': 473,
    'arcade': 52,
    'dos': 13,
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

  /// Builds the `knownPlatforms` map for a freshly-paired RomM source.
  ///
  /// For every R-Shop system slug in [systemIds], looks for a matching
  /// [RommPlatform] in [platforms] and records its numeric id. Systems
  /// the server doesn't ship are silently dropped — they will not be
  /// fetched on sync.
  static Map<String, int> buildKnownPlatforms(
    Iterable<String> systemIds,
    List<RommPlatform> platforms,
  ) {
    final result = <String, int>{};
    for (final id in systemIds) {
      final match = findMatch(id, platforms);
      if (match != null) result[id] = match.id;
    }
    return result;
  }
}
