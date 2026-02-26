import 'package:flutter/material.dart';

class SystemModel {
  final String id;
  final String name;
  final String manufacturer;
  final int releaseYear;
  final bool isZipped;
  final String libretroId;
  final List<String> romExtensions;
  final String iconName;
  final Color accentColor;
  final List<String>? multiFileExtensions;

  const SystemModel({
    required this.id,
    required this.name,
    required this.manufacturer,
    required this.releaseYear,
    this.isZipped = true,
    this.libretroId = '',
    this.romExtensions = const [],
    this.iconName = '',
    this.accentColor = Colors.redAccent,
    this.multiFileExtensions,
  });

  /// Returns the local asset path for this system's icon.
  String get iconAssetPath => 'assets/platform_icons/$iconName';

  /// Returns a color suitable for icon tinting on dark backgrounds.
  /// Ensures minimum luminance so icons stay visible.
  Color get iconColor {
    final luminance = accentColor.computeLuminance();
    if (luminance >= 0.15) return accentColor;
    final hsl = HSLColor.fromColor(accentColor);
    return hsl.withLightness(hsl.lightness.clamp(0.45, 1.0)).toColor();
  }

  static const List<SystemModel> supportedSystems = [
    // ===== NINTENDO =====
    SystemModel(
      id: 'nes',
      name: 'Nintendo Entertainment System',
      manufacturer: 'Nintendo',
      releaseYear: 1983,
      isZipped: true,
      libretroId: 'Nintendo_-_Nintendo_Entertainment_System',
      romExtensions: ['.nes'],
      iconName: 'nintendo_nes.svg',
      accentColor: Color(0xFFE11D48),
    ),
    SystemModel(
      id: 'snes',
      name: 'Super Nintendo',
      manufacturer: 'Nintendo',
      releaseYear: 1990,
      isZipped: true,
      libretroId: 'Nintendo_-_Super_Nintendo_Entertainment_System',
      romExtensions: ['.sfc', '.smc'],
      iconName: 'nintendo_snes.svg',
      accentColor: Color(0xFF9333EA),
    ),
    SystemModel(
      id: 'n64',
      name: 'Nintendo 64',
      manufacturer: 'Nintendo',
      releaseYear: 1996,
      isZipped: true,
      libretroId: 'Nintendo_-_Nintendo_64',
      romExtensions: ['.z64', '.n64', '.v64'],
      iconName: 'nintendo_64.svg',
      accentColor: Color(0xFFF97316),
    ),
    SystemModel(
      id: 'gc',
      name: 'Nintendo GameCube',
      manufacturer: 'Nintendo',
      releaseYear: 2001,
      isZipped: false,
      libretroId: 'Nintendo_-_GameCube',
      romExtensions: ['.rvz', '.iso', '.gcm', '.ciso'],
      iconName: 'nintendo_gamecube.svg',
      accentColor: Color(0xFF7C3AED),
    ),
    SystemModel(
      id: 'wii',
      name: 'Nintendo Wii',
      manufacturer: 'Nintendo',
      releaseYear: 2006,
      isZipped: false,
      libretroId: 'Nintendo_-_Wii',
      romExtensions: ['.rvz', '.wbfs', '.iso', '.wia', '.ciso'],
      iconName: 'nintendo_wii.svg',
      accentColor: Color(0xFF0EA5E9),
    ),
    SystemModel(
      id: 'wiiu',
      name: 'Nintendo Wii U',
      manufacturer: 'Nintendo',
      releaseYear: 2012,
      isZipped: false,
      libretroId: 'Nintendo_-_Wii_U',
      romExtensions: ['.wua', '.wud', '.wux', '.rpx'],
      iconName: 'nintendo_wiiu.svg',
      accentColor: Color(0xFF0284C7),
    ),
    SystemModel(
      id: 'switch',
      name: 'Nintendo Switch',
      manufacturer: 'Nintendo',
      releaseYear: 2017,
      isZipped: false,
      libretroId: 'Nintendo_-_Switch',
      romExtensions: ['.nsp', '.xci'],
      iconName: 'nintendo_switch.svg',
      accentColor: Color(0xFFE60012),
    ),
    SystemModel(
      id: 'gb',
      name: 'Game Boy',
      manufacturer: 'Nintendo',
      releaseYear: 1989,
      isZipped: true,
      libretroId: 'Nintendo_-_Game_Boy',
      romExtensions: ['.gb'],
      iconName: 'nintendo_gameboy.svg',
      accentColor: Color(0xFF8BAC0F),
    ),
    SystemModel(
      id: 'gbc',
      name: 'Game Boy Color',
      manufacturer: 'Nintendo',
      releaseYear: 1998,
      isZipped: true,
      libretroId: 'Nintendo_-_Game_Boy_Color',
      romExtensions: ['.gbc', '.gb'],
      iconName: 'nintendo_gameboy_color.svg',
      accentColor: Color(0xFF06B6D4),
    ),
    SystemModel(
      id: 'gba',
      name: 'Game Boy Advance',
      manufacturer: 'Nintendo',
      releaseYear: 2001,
      isZipped: true,
      libretroId: 'Nintendo_-_Game_Boy_Advance',
      romExtensions: ['.gba'],
      iconName: 'nintendo_gameboy_advance.svg',
      accentColor: Color(0xFF4F46E5),
    ),
    SystemModel(
      id: 'nds',
      name: 'Nintendo DS',
      manufacturer: 'Nintendo',
      releaseYear: 2004,
      isZipped: true,
      libretroId: 'Nintendo_-_Nintendo_DS',
      romExtensions: ['.nds'],
      iconName: 'nintendo_ds.svg',
      accentColor: Color(0xFF6B7280),
    ),
    SystemModel(
      id: 'n3ds',
      name: 'Nintendo 3DS',
      manufacturer: 'Nintendo',
      releaseYear: 2011,
      isZipped: false,
      libretroId: 'Nintendo_-_Nintendo_3DS',
      romExtensions: ['.3ds', '.cia'],
      iconName: 'nintendo_3ds.svg',
      accentColor: Color(0xFFDC2626),
    ),
    // ===== SONY =====
    SystemModel(
      id: 'psx',
      name: 'PlayStation',
      manufacturer: 'Sony',
      releaseYear: 1994,
      isZipped: false,
      libretroId: 'Sony_-_PlayStation',
      romExtensions: ['.chd', '.pbp', '.cue', '.iso', '.img'],
      iconName: 'playstation_flat.svg',
      accentColor: Color(0xFF5B21B6),
      multiFileExtensions: ['.bin', '.cue'],
    ),
    SystemModel(
      id: 'ps2',
      name: 'PlayStation 2',
      manufacturer: 'Sony',
      releaseYear: 2000,
      isZipped: false,
      libretroId: 'Sony_-_PlayStation_2',
      romExtensions: ['.iso', '.chd', '.cso'],
      iconName: 'playstation_ps2.svg',
      accentColor: Color(0xFF1E3A8A),
      multiFileExtensions: ['.bin', '.cue'],
    ),
    SystemModel(
      id: 'ps3',
      name: 'PlayStation 3',
      manufacturer: 'Sony',
      releaseYear: 2006,
      isZipped: false,
      libretroId: 'Sony_-_PlayStation_3',
      romExtensions: ['.iso', '.pkg'],
      iconName: 'playstation3_flat.svg',
      accentColor: Color(0xFF1E293B),
    ),
    SystemModel(
      id: 'psp',
      name: 'PlayStation Portable',
      manufacturer: 'Sony',
      releaseYear: 2004,
      isZipped: false,
      libretroId: 'Sony_-_PlayStation_Portable',
      romExtensions: ['.iso', '.cso', '.pbp', '.chd'],
      iconName: 'playstation_psp.svg',
      accentColor: Color(0xFF475569),
    ),
    SystemModel(
      id: 'psvita',
      name: 'PlayStation Vita',
      manufacturer: 'Sony',
      releaseYear: 2011,
      isZipped: false,
      libretroId: 'Sony_-_PlayStation_Vita',
      romExtensions: ['.vpk'],
      iconName: 'playstation_vita.svg',
      accentColor: Color(0xFF1E40AF),
    ),
    // ===== SEGA =====
    SystemModel(
      id: 'mastersystem',
      name: 'Master System',
      manufacturer: 'Sega',
      releaseYear: 1985,
      isZipped: true,
      libretroId: 'Sega_-_Master_System_-_Mark_III',
      romExtensions: ['.sms'],
      iconName: 'sega_master_system.svg',
      accentColor: Color(0xFF1D4ED8),
    ),
    SystemModel(
      id: 'megadrive',
      name: 'Mega Drive',
      manufacturer: 'Sega',
      releaseYear: 1988,
      isZipped: true,
      libretroId: 'Sega_-_Mega_Drive_-_Genesis',
      romExtensions: ['.md', '.gen', '.bin', '.smd'],
      iconName: 'sega_megadrive.svg',
      accentColor: Color(0xFF374151),
    ),
    SystemModel(
      id: 'gamegear',
      name: 'Game Gear',
      manufacturer: 'Sega',
      releaseYear: 1990,
      isZipped: true,
      libretroId: 'Sega_-_Game_Gear',
      romExtensions: ['.gg'],
      iconName: 'sega_gamegear.svg',
      accentColor: Color(0xFF0F766E),
    ),
    SystemModel(
      id: 'segacd',
      name: 'Sega CD',
      manufacturer: 'Sega',
      releaseYear: 1991,
      isZipped: false,
      libretroId: 'Sega_-_Mega-CD_-_Sega_CD',
      romExtensions: ['.chd', '.cue', '.iso'],
      iconName: 'sega_cd.svg',
      accentColor: Color(0xFF0369A1),
      multiFileExtensions: ['.bin', '.cue'],
    ),
    SystemModel(
      id: 'sega32x',
      name: 'Sega 32X',
      manufacturer: 'Sega',
      releaseYear: 1994,
      isZipped: true,
      libretroId: 'Sega_-_32X',
      romExtensions: ['.32x'],
      iconName: 'sega_32x.svg',
      accentColor: Color(0xFF991B1B),
    ),
    SystemModel(
      id: 'dreamcast',
      name: 'Dreamcast',
      manufacturer: 'Sega',
      releaseYear: 1998,
      isZipped: false,
      libretroId: 'Sega_-_Dreamcast',
      romExtensions: ['.chd', '.cdi', '.gdi'],
      iconName: 'sega_dreamcast.svg',
      accentColor: Color(0xFFDC2626),
    ),
    SystemModel(
      id: 'saturn',
      name: 'Saturn',
      manufacturer: 'Sega',
      releaseYear: 1994,
      isZipped: false,
      libretroId: 'Sega_-_Saturn',
      romExtensions: ['.chd', '.cue', '.iso'],
      iconName: 'sega_saturn.svg',
      accentColor: Color(0xFF64748B),
      multiFileExtensions: ['.bin', '.cue'],
    ),
    // ===== ATARI =====
    SystemModel(
      id: 'atari2600',
      name: 'Atari 2600',
      manufacturer: 'Atari',
      releaseYear: 1977,
      isZipped: true,
      libretroId: 'Atari_-_2600',
      romExtensions: ['.a26', '.bin'],
      iconName: 'atari_2600.svg',
      accentColor: Color(0xFFD97706),
    ),
    SystemModel(
      id: 'atari5200',
      name: 'Atari 5200',
      manufacturer: 'Atari',
      releaseYear: 1982,
      isZipped: true,
      libretroId: 'Atari_-_5200',
      romExtensions: ['.a52', '.bin'],
      iconName: 'atari_5200.svg',
      accentColor: Color(0xFF78716C),
    ),
    SystemModel(
      id: 'atari7800',
      name: 'Atari 7800',
      manufacturer: 'Atari',
      releaseYear: 1986,
      isZipped: true,
      libretroId: 'Atari_-_7800',
      romExtensions: ['.a78', '.bin'],
      iconName: 'atari_7800.svg',
      accentColor: Color(0xFF6B7280),
    ),
    SystemModel(
      id: 'lynx',
      name: 'Atari Lynx',
      manufacturer: 'Atari',
      releaseYear: 1989,
      isZipped: true,
      libretroId: 'Atari_-_Lynx',
      romExtensions: ['.lnx'],
      iconName: 'atari_lynx.svg',
      accentColor: Color(0xFF059669),
    ),
    // ===== OTHER =====
    SystemModel(
      id: 'pico8',
      name: 'PICO-8',
      manufacturer: 'Lexaloffle',
      releaseYear: 2015,
      isZipped: false,
      libretroId: '',
      romExtensions: ['.p8'],
      iconName: 'pico-8.svg',
      accentColor: Color(0xFFEC4899),
    ),
  ];

  /// Archive formats that may wrap ROM files.
  static const archiveExtensions = ['.zip', '.7z', '.rar'];

  /// Union of all romExtensions across every supported system.
  static final Set<String> allRomExtensions = {
    for (final s in supportedSystems) ...s.romExtensions,
  };

  /// All file extensions that represent game files (ROMs + archives + multi-file parts).
  static final Set<String> allGameExtensions = {
    ...archiveExtensions,
    ...allRomExtensions,
    for (final s in supportedSystems)
      if (s.multiFileExtensions != null) ...s.multiFileExtensions!,
  };

  /// Whether [name] ends with a known game file extension.
  static bool isGameFile(String name) {
    return allGameExtensions.any((ext) => name.endsWith(ext));
  }
}
