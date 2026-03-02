import 'package:flutter_test/flutter_test.dart';

import 'package:retro_eshop/features/onboarding/onboarding_state.dart';
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

  group('RemoteSetupState.buildConfig', () {
    test('builds FTP config', () {
      const state = RemoteSetupState(
        providerType: ProviderType.ftp,
        host: '192.168.1.100',
        port: '21',
        path: '/roms',
        user: 'admin',
        pass: 'secret',
      );
      final config = state.buildConfig();
      expect(config.type, ProviderType.ftp);
      expect(config.host, '192.168.1.100');
      expect(config.port, 21);
      expect(config.path, '/roms');
      expect(config.auth?.user, 'admin');
      expect(config.auth?.pass, 'secret');
      expect(config.url, null);
    });

    test('builds SMB config', () {
      const state = RemoteSetupState(
        providerType: ProviderType.smb,
        host: '192.168.1.100',
        port: '445',
        share: 'roms',
        path: '',
        user: 'guest',
      );
      final config = state.buildConfig();
      expect(config.type, ProviderType.smb);
      expect(config.host, '192.168.1.100');
      expect(config.port, 445);
      expect(config.share, 'roms');
      expect(config.path, null); // empty → null
      expect(config.auth?.user, 'guest');
    });

    test('builds Web config', () {
      const state = RemoteSetupState(
        providerType: ProviderType.web,
        url: 'https://myserver.com/roms',
      );
      final config = state.buildConfig();
      expect(config.type, ProviderType.web);
      expect(config.url, 'https://myserver.com/roms');
      expect(config.host, null);
      expect(config.auth, null);
    });

    test('omits auth when no credentials', () {
      const state = RemoteSetupState(
        providerType: ProviderType.ftp,
        host: '192.168.1.100',
      );
      final config = state.buildConfig();
      expect(config.auth, null);
    });
  });

  group('RemoteSetupState.hasConnection', () {
    test('FTP needs host', () {
      const empty = RemoteSetupState(providerType: ProviderType.ftp);
      expect(empty.hasConnection, false);

      const withHost = RemoteSetupState(
        providerType: ProviderType.ftp,
        host: '192.168.1.100',
      );
      expect(withHost.hasConnection, true);
    });

    test('SMB needs host and share', () {
      const hostOnly = RemoteSetupState(
        providerType: ProviderType.smb,
        host: '192.168.1.100',
      );
      expect(hostOnly.hasConnection, false);

      const complete = RemoteSetupState(
        providerType: ProviderType.smb,
        host: '192.168.1.100',
        share: 'roms',
      );
      expect(complete.hasConnection, true);
    });

    test('Web needs URL', () {
      const empty = RemoteSetupState(providerType: ProviderType.web);
      expect(empty.hasConnection, false);

      const withUrl = RemoteSetupState(
        providerType: ProviderType.web,
        url: 'https://example.com',
      );
      expect(withUrl.hasConnection, true);
    });
  });
}
