import '../models/system_model.dart';
import 'romm_api_service.dart';

class LocalFolderMatcher {
  LocalFolderMatcher._();

  static const Map<String, List<String>> _aliasMap = {
    'nes': ['famicom', 'fc'],
    'snes': ['superfamicom', 'sfc', 'supernintendo'],
    'n64': ['nintendo64'],
    'gb': ['gameboy'],
    'gbc': ['gameboycolor'],
    'gba': ['gameboyadvance'],
    'nds': ['ds', 'nintendods'],
    'n3ds': ['3ds', 'nintendo3ds'],
    'gc': ['gamecube', 'ngc'],
    'wii': [],
    'wiiu': [],
    'switch': ['nsp'],
    'psx': ['ps1', 'playstation', 'playstation1'],
    'ps2': ['playstation2'],
    'ps3': ['playstation3'],
    'psp': ['playstationportable'],
    'psvita': ['vita'],
    'mastersystem': ['sms', 'segamastersystem'],
    'megadrive': ['genesis', 'md', 'segagenesis', 'segamegadrive'],
    'gamegear': ['gg', 'segagamegear'],
    'dreamcast': ['dc', 'segadreamcast'],
    'saturn': ['segasaturn'],
    'segacd': ['megacd', 'scd'],
    'sega32x': ['32x'],
    'atari2600': ['2600', 'vcs'],
    'atari5200': ['5200'],
    'atari7800': ['7800'],
    'lynx': ['atarilynx'],
    'pico8': ['pico-8'],
  };

  // Reverse lookup: alias → system.id
  static final Map<String, String> _reverseLookup = _buildReverseLookup();

  static Map<String, String> _buildReverseLookup() {
    final map = <String, String>{};
    for (final entry in _aliasMap.entries) {
      for (final alias in entry.value) {
        map[_normalize(alias)] = entry.key;
      }
    }
    return map;
  }

  static String _normalize(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[-_\s]'), '');
  }

  /// Matches a local folder name to a system ID.
  ///
  /// Strategy (in order):
  /// 1. Exact match on system.id
  /// 2. Case-insensitive match on system.id
  /// 3. Alias map lookup
  /// 4. Normalized match on system.name
  /// 5. Normalized match on RomM platform.slug / platform.fsSlug / platform.name
  static String? matchFolder(
    String folderName,
    List<SystemModel> systems,
    List<RommPlatform> platforms,
  ) {
    final systemIds = {for (final s in systems) s.id};

    // 1. Exact match on system.id
    if (systemIds.contains(folderName)) return folderName;

    // 2. Case-insensitive match on system.id
    final lower = folderName.toLowerCase();
    for (final id in systemIds) {
      if (id.toLowerCase() == lower) return id;
    }

    // 2.5 Normalized match on system.id (strips _-spaces)
    final normalized = _normalize(folderName);
    if (systemIds.contains(normalized)) return normalized;

    // 3. Alias map
    final aliasMatch = _reverseLookup[normalized];
    if (aliasMatch != null && systemIds.contains(aliasMatch)) return aliasMatch;

    // 4. Normalized match on system.name
    for (final system in systems) {
      if (_normalize(system.name) == normalized) return system.id;
    }

    // 5. Normalized match on RomM platform slug/fsSlug/name
    // Build a platform-slug → system.id map from the provided platforms
    // We need the RommPlatformMatcher's matching logic in reverse:
    // find which system each platform belongs to, then check folder name
    for (final platform in platforms) {
      final slugNorm = _normalize(platform.slug);
      final fsSlugNorm = _normalize(platform.fsSlug);
      final nameNorm = _normalize(platform.name);

      if (normalized == slugNorm ||
          normalized == fsSlugNorm ||
          normalized == nameNorm) {
        // Find which system this platform is matched to
        for (final system in systems) {
          if (system.id == platform.slug ||
              system.id == platform.fsSlug ||
              _normalize(system.id) == slugNorm ||
              _normalize(system.id) == fsSlugNorm) {
            return system.id;
          }
        }
      }
    }

    return null;
  }
}
