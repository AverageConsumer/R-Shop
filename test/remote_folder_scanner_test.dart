import 'package:flutter_test/flutter_test.dart';

import 'package:retro_eshop/models/config/provider_config.dart';
import 'package:retro_eshop/models/system_model.dart';
import 'package:retro_eshop/services/local_folder_matcher.dart';
import 'package:retro_eshop/services/remote_folder_scanner.dart';

void main() {
  group('RemoteFolderEntry', () {
    test('stores name', () {
      const entry = RemoteFolderEntry(name: 'snes');
      expect(entry.name, 'snes');
    });
  });

  group('RemoteFolderScanner', () {
    test('throws for RomM provider type', () {
      const config = ProviderConfig(
        type: ProviderType.romm,
        priority: 0,
        url: 'https://example.com',
      );
      expect(
        () => RemoteFolderScanner.scanTopLevel(config),
        throwsStateError,
      );
    });

    test('throws for web provider with empty URL', () {
      const config = ProviderConfig(
        type: ProviderType.web,
        priority: 0,
        url: '',
      );
      expect(
        () => RemoteFolderScanner.scanTopLevel(config),
        throwsStateError,
      );
    });

    test('throws for FTP provider with empty host', () {
      const config = ProviderConfig(
        type: ProviderType.ftp,
        priority: 0,
        host: '',
      );
      expect(
        () => RemoteFolderScanner.scanTopLevel(config),
        throwsStateError,
      );
    });
  });

  group('LocalFolderMatcher with remote folder names', () {
    final systems = SystemModel.supportedSystems;

    test('matches exact system IDs', () {
      expect(LocalFolderMatcher.matchFolder('snes', systems, const []), 'snes');
      expect(LocalFolderMatcher.matchFolder('gba', systems, const []), 'gba');
      expect(LocalFolderMatcher.matchFolder('psx', systems, const []), 'psx');
      expect(LocalFolderMatcher.matchFolder('n64', systems, const []), 'n64');
    });

    test('matches case-insensitive system IDs', () {
      expect(LocalFolderMatcher.matchFolder('SNES', systems, const []), 'snes');
      expect(LocalFolderMatcher.matchFolder('GBA', systems, const []), 'gba');
      expect(LocalFolderMatcher.matchFolder('PSX', systems, const []), 'psx');
    });

    test('matches common aliases', () {
      expect(LocalFolderMatcher.matchFolder('Genesis', systems, const []), 'megadrive');
      expect(LocalFolderMatcher.matchFolder('PS1', systems, const []), 'psx');
      expect(LocalFolderMatcher.matchFolder('3ds', systems, const []), 'n3ds');
      expect(LocalFolderMatcher.matchFolder('GameBoy', systems, const []), 'gb');
      expect(LocalFolderMatcher.matchFolder('GameBoyAdvance', systems, const []), 'gba');
      expect(LocalFolderMatcher.matchFolder('SuperFamicom', systems, const []), 'snes');
      expect(LocalFolderMatcher.matchFolder('SFC', systems, const []), 'snes');
      expect(LocalFolderMatcher.matchFolder('Vita', systems, const []), 'psvita');
      expect(LocalFolderMatcher.matchFolder('dc', systems, const []), 'dreamcast');
    });

    test('matches normalized folder names with separators', () {
      expect(LocalFolderMatcher.matchFolder('PS_Vita', systems, const []), 'psvita');
      expect(LocalFolderMatcher.matchFolder('Sega-Genesis', systems, const []), 'megadrive');
      expect(LocalFolderMatcher.matchFolder('Game Boy Advance', systems, const []), 'gba');
    });

    test('returns null for unknown folder names', () {
      expect(LocalFolderMatcher.matchFolder('movies', systems, const []), null);
      expect(LocalFolderMatcher.matchFolder('photos', systems, const []), null);
      expect(LocalFolderMatcher.matchFolder('music', systems, const []), null);
      expect(LocalFolderMatcher.matchFolder('.hidden', systems, const []), null);
    });

    test('matches system display names', () {
      expect(LocalFolderMatcher.matchFolder('Nintendo 64', systems, const []), 'n64');
      expect(LocalFolderMatcher.matchFolder('Dreamcast', systems, const []), 'dreamcast');
    });
  });
}
