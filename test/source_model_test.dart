import 'package:flutter_test/flutter_test.dart';
import 'package:retro_eshop/models/config/app_config.dart';
import 'package:retro_eshop/models/config/provider_config.dart';
import 'package:retro_eshop/models/config/source.dart';
import 'package:retro_eshop/models/config/system_config.dart';

void main() {
  group('Source serialization', () {
    test('round-trips a RomM source with auth and known platforms', () {
      const source = Source(
        id: 'src-romm-1',
        name: 'My RomM',
        type: SourceType.romm,
        url: 'http://192.168.1.50:8090',
        auth: AuthConfig(clientToken: 'tok', clientTokenId: 7),
        autoMap: true,
        priority: 1,
        knownPlatforms: {'snes': 4, 'nds': 8, 'gba': 5},
      );

      final json = source.toJson();
      final back = Source.fromJson(json);

      expect(back.id, 'src-romm-1');
      expect(back.type, SourceType.romm);
      expect(back.url, 'http://192.168.1.50:8090');
      expect(back.autoMap, isTrue);
      expect(back.priority, 1);
      expect(back.knownPlatforms, {'snes': 4, 'nds': 8, 'gba': 5});
      expect(back.auth?.clientToken, 'tok');
      expect(back.auth?.clientTokenId, 7);
    });

    test('toJsonWithoutAuth strips credentials', () {
      const source = Source(
        id: 'a',
        name: 'a',
        type: SourceType.romm,
        url: 'http://x',
        auth: AuthConfig(clientToken: 'secret'),
      );
      final stripped = source.toJsonWithoutAuth();
      expect(stripped.containsKey('auth'), isFalse);
    });

    test('borrowed flag and tokenExpiresAt round-trip', () {
      final exp = DateTime.utc(2026, 5, 9, 12);
      final source = Source(
        id: 'borrowed',
        name: 'Tims RomM',
        type: SourceType.romm,
        url: 'https://tim.duckdns.org',
        borrowed: true,
        tokenExpiresAt: exp,
      );
      final back = Source.fromJson(source.toJson());
      expect(back.borrowed, isTrue);
      expect(back.tokenExpiresAt, exp);
    });
  });

  group('Source.connectionKey', () {
    test('two RomMs at the same URL collide regardless of name/auth', () {
      const a = Source(
        id: 'a',
        name: 'A',
        type: SourceType.romm,
        url: 'http://romm.local:8090',
      );
      const b = Source(
        id: 'b',
        name: 'B',
        type: SourceType.romm,
        url: 'http://romm.local:8090/',
        auth: AuthConfig(clientToken: 'different'),
      );
      expect(a.connectionKey, b.connectionKey);
    });

    test('SMB key includes share', () {
      const a = Source(
        id: '1',
        name: 'NAS',
        type: SourceType.smb,
        host: 'nas',
        share: 'roms',
      );
      const b = Source(
        id: '2',
        name: 'NAS',
        type: SourceType.smb,
        host: 'nas',
        share: 'movies',
      );
      expect(a.connectionKey == b.connectionKey, isFalse);
    });

    test('SMB and FTP with the same host are distinct', () {
      const smb = Source(
        id: '1',
        name: 'A',
        type: SourceType.smb,
        host: 'nas',
        share: 'roms',
      );
      const ftp = Source(
        id: '2',
        name: 'A',
        type: SourceType.ftp,
        host: 'nas',
      );
      expect(smb.connectionKey == ftp.connectionKey, isFalse);
    });
  });

  group('SystemSourceMapping serialization', () {
    test('round-trip with priority override', () {
      const m = SystemSourceMapping(
        sourceId: 'src-smb-3',
        remotePath: '/roms/snes',
        priorityOverride: 0,
      );
      final back = SystemSourceMapping.fromJson(m.toJson());
      expect(back.sourceId, 'src-smb-3');
      expect(back.remotePath, '/roms/snes');
      expect(back.priorityOverride, 0);
    });

    test('drops priority_override key when null', () {
      const m = SystemSourceMapping(sourceId: 'a', remotePath: '/x');
      expect(m.toJson().containsKey('priority_override'), isFalse);
    });
  });

  group('SystemConfig new fields', () {
    test('enabledSourceIds and manualMappings round-trip', () {
      const s = SystemConfig(
        id: 'snes',
        name: 'SNES',
        targetFolder: '/roms/snes',
        providers: [],
        enabledSourceIds: ['src-a', 'src-b'],
        manualMappings: [
          SystemSourceMapping(sourceId: 'src-a', remotePath: '/share/snes'),
        ],
      );
      final back = SystemConfig.fromJson(s.toJson());
      expect(back.enabledSourceIds, ['src-a', 'src-b']);
      expect(back.manualMappings.single.sourceId, 'src-a');
      expect(back.manualMappings.single.remotePath, '/share/snes');
    });

    test('absent enabledSourceIds means "all sources"', () {
      final s = SystemConfig.fromJson({
        'id': 'snes',
        'name': 'SNES',
        'target_folder': '/roms/snes',
        'providers': const [],
      });
      expect(s.enabledSourceIds, isNull);
      expect(s.manualMappings, isEmpty);
    });

    test('copyWith clearEnabledSourceIds resets to null', () {
      const s = SystemConfig(
        id: 'snes',
        name: 'SNES',
        targetFolder: '/x',
        providers: [],
        enabledSourceIds: ['a'],
      );
      final cleared = s.copyWith(clearEnabledSourceIds: true);
      expect(cleared.enabledSourceIds, isNull);
    });
  });

  group('AppConfig v2 → v3 migration', () {
    test('single RomM provider becomes one auto-mapped Source', () {
      final json = {
        'version': 2,
        'systems': [
          {
            'id': 'snes',
            'name': 'SNES',
            'target_folder': '/roms/snes',
            'providers': [
              {
                'type': 'romm',
                'priority': 1,
                'url': 'http://192.168.1.50:8090',
                'platform_id': 4,
                'platform_name': 'snes',
                'auth': {'client_token': 'tok'},
              }
            ],
          }
        ],
      };
      final cfg = AppConfig.fromJson(json);

      expect(cfg.version, AppConfig.currentVersion);
      expect(cfg.sources, hasLength(1));
      final src = cfg.sources.single;
      expect(src.type, SourceType.romm);
      expect(src.autoMap, isTrue);
      expect(src.url, 'http://192.168.1.50:8090');
      expect(src.knownPlatforms, {'snes': 4});
      expect(src.auth?.clientToken, 'tok');
      // Legacy provider list is preserved unchanged.
      expect(cfg.systems.single.providers, hasLength(1));
    });

    test('two systems sharing one RomM URL collapse to one Source', () {
      final json = {
        'version': 2,
        'systems': [
          {
            'id': 'snes',
            'name': 'SNES',
            'target_folder': '/roms/snes',
            'providers': [
              {
                'type': 'romm',
                'priority': 1,
                'url': 'http://192.168.1.50:8090',
              }
            ],
          },
          {
            'id': 'nds',
            'name': 'NDS',
            'target_folder': '/roms/nds',
            'providers': [
              {
                'type': 'romm',
                'priority': 1,
                'url': 'http://192.168.1.50:8090/',
              }
            ],
          }
        ],
      };
      final cfg = AppConfig.fromJson(json);
      expect(cfg.sources, hasLength(1));
      // Both systems advertised the same RomM URL but neither legacy
      // entry carried a platform_id, so the merged source has an empty
      // map (the resolver will need to repopulate it via /api/platforms).
      expect(cfg.sources.single.knownPlatforms, isEmpty);
    });

    test('SMB provider yields a manual source + per-system mapping', () {
      final json = {
        'version': 2,
        'systems': [
          {
            'id': 'snes',
            'name': 'SNES',
            'target_folder': '/roms/snes',
            'providers': [
              {
                'type': 'smb',
                'priority': 2,
                'host': 'nas.local',
                'share': 'media',
                'path': '/Roms/SNES',
              }
            ],
          }
        ],
      };
      final cfg = AppConfig.fromJson(json);
      expect(cfg.sources, hasLength(1));
      final src = cfg.sources.single;
      expect(src.type, SourceType.smb);
      expect(src.autoMap, isFalse);
      expect(src.host, 'nas.local');
      expect(src.share, 'media');

      final mappings = cfg.systems.single.manualMappings;
      expect(mappings, hasLength(1));
      expect(mappings.single.sourceId, src.id);
      expect(mappings.single.remotePath, '/Roms/SNES');
      expect(mappings.single.priorityOverride, 2);
    });

    test('mixed RomM + SMB on one system migrates both correctly', () {
      final json = {
        'version': 2,
        'systems': [
          {
            'id': 'snes',
            'name': 'SNES',
            'target_folder': '/roms/snes',
            'providers': [
              {
                'type': 'romm',
                'priority': 1,
                'url': 'http://romm:8090',
              },
              {
                'type': 'smb',
                'priority': 2,
                'host': 'nas',
                'share': 'roms',
                'path': '/snes',
              }
            ],
          }
        ],
      };
      final cfg = AppConfig.fromJson(json);
      expect(cfg.sources, hasLength(2));
      expect(
        cfg.sources.where((s) => s.type == SourceType.romm).single.autoMap,
        isTrue,
      );
      expect(
        cfg.sources.where((s) => s.type == SourceType.smb).single.autoMap,
        isFalse,
      );
      expect(cfg.systems.single.manualMappings, hasLength(1));
    });

    test('v3 JSON is read back verbatim without re-running migration', () {
      const original = AppConfig(
        systems: [
          SystemConfig(
            id: 'snes',
            name: 'SNES',
            targetFolder: '/roms/snes',
            providers: [],
            manualMappings: [
              SystemSourceMapping(sourceId: 'src-a', remotePath: '/snes'),
            ],
          ),
        ],
        sources: [
          Source(
            id: 'src-a',
            name: 'NAS',
            type: SourceType.smb,
            host: 'nas',
            share: 'roms',
          ),
        ],
      );
      final back = AppConfig.fromJson(original.toJson());
      expect(back.version, 3);
      expect(back.sources.single.id, 'src-a');
      expect(back.systems.single.manualMappings.single.sourceId, 'src-a');
    });

    test('empty legacy config produces empty sources list', () {
      final cfg = AppConfig.fromJson({'version': 2, 'systems': const []});
      expect(cfg.sources, isEmpty);
      expect(cfg.systems, isEmpty);
      expect(cfg.version, AppConfig.currentVersion);
    });
  });
}
