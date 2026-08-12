import 'package:flutter_test/flutter_test.dart';
import 'package:retro_eshop/models/config/app_config.dart';
import 'package:retro_eshop/models/config/provider_config.dart';
import 'package:retro_eshop/models/config/source.dart';
import 'package:retro_eshop/models/config/system_config.dart';
import 'package:retro_eshop/services/source_resolver.dart';

void main() {
  group('SourceResolver — RomM auto-map', () {
    test('emits one ProviderConfig per advertised RomM source', () {
      const system = SystemConfig(
        id: 'snes',
        name: 'SNES',
        targetFolder: '/roms/snes',
        providers: [],
      );
      const sources = [
        Source(
          id: 's1',
          name: 'Mein RomM',
          type: SourceType.romm,
          url: 'http://romm.local:8090',
          autoMap: true,
          priority: 1,
          knownPlatforms: {'snes': 4, 'nds': 8},
        ),
      ];
      final providers = SourceResolver.providersFor(system, sources);
      expect(providers, hasLength(1));
      expect(providers.single.type, ProviderType.romm);
      expect(providers.single.url, 'http://romm.local:8090');
      expect(providers.single.platformId, 4);
      expect(providers.single.platformName, 'snes');
    });

    test('skips RomM source that does not advertise the system', () {
      const system = SystemConfig(
        id: 'ps1',
        name: 'PS1',
        targetFolder: '/roms/ps1',
        providers: [],
      );
      const sources = [
        Source(
          id: 's1',
          name: 'A',
          type: SourceType.romm,
          url: 'http://a',
          autoMap: true,
          knownPlatforms: {'snes': 4},
        ),
      ];
      expect(SourceResolver.providersFor(system, sources), isEmpty);
    });

    test('two RomMs advertising the same system both contribute', () {
      const system = SystemConfig(
        id: 'nds',
        name: 'NDS',
        targetFolder: '/roms/nds',
        providers: [],
      );
      const sources = [
        Source(
          id: 'mine',
          name: 'Mein',
          type: SourceType.romm,
          url: 'http://a',
          autoMap: true,
          priority: 1,
          knownPlatforms: {'nds': 8},
        ),
        Source(
          id: 'tims',
          name: 'Tims',
          type: SourceType.romm,
          url: 'http://b',
          autoMap: true,
          priority: 2,
          borrowed: true,
          knownPlatforms: {'nds': 8},
        ),
      ];
      final providers = SourceResolver.providersFor(system, sources);
      expect(providers, hasLength(2));
      expect(providers[0].url, 'http://a'); // priority 1 first
      expect(providers[1].url, 'http://b');
    });
  });

  group('SourceResolver — manual sources', () {
    test('SMB source contributes only via SystemSourceMapping', () {
      const system = SystemConfig(
        id: 'snes',
        name: 'SNES',
        targetFolder: '/roms/snes',
        providers: [],
        manualMappings: [
          SystemSourceMapping(sourceId: 'nas', remotePath: '/share/snes'),
        ],
      );
      const sources = [
        Source(
          id: 'nas',
          name: 'NAS',
          type: SourceType.smb,
          host: 'nas.local',
          share: 'media',
        ),
      ];
      final providers = SourceResolver.providersFor(system, sources);
      expect(providers, hasLength(1));
      expect(providers.single.type, ProviderType.smb);
      expect(providers.single.host, 'nas.local');
      expect(providers.single.share, 'media');
      expect(providers.single.path, '/share/snes');
    });

    test('SMB source without mapping is silently ignored', () {
      const system = SystemConfig(
        id: 'snes',
        name: 'SNES',
        targetFolder: '/x',
        providers: [],
      );
      const sources = [
        Source(
          id: 'nas',
          name: 'NAS',
          type: SourceType.smb,
          host: 'nas',
          share: 'r',
        ),
      ];
      expect(SourceResolver.providersFor(system, sources), isEmpty);
    });

    test('Web source joins base URL with mapping path', () {
      const system = SystemConfig(
        id: 'snes',
        name: 'SNES',
        targetFolder: '/x',
        providers: [],
        manualMappings: [
          SystemSourceMapping(
            sourceId: 'myrient',
            remotePath: '/files/No-Intro/Nintendo - SNES/',
          ),
        ],
      );
      const sources = [
        Source(
          id: 'myrient',
          name: 'Myrient',
          type: SourceType.web,
          url: 'https://myrient.erista.me',
        ),
      ];
      final providers = SourceResolver.providersFor(system, sources);
      expect(
        providers.single.url,
        'https://myrient.erista.me/files/No-Intro/Nintendo - SNES/',
      );
    });
  });

  group('SourceResolver — power-user overrides', () {
    test('enabledSourceIds restricts to allow-list', () {
      const system = SystemConfig(
        id: 'nds',
        name: 'NDS',
        targetFolder: '/x',
        providers: [],
        enabledSourceIds: ['mine'], // exclude tims
      );
      const sources = [
        Source(
          id: 'mine',
          name: 'Mein',
          type: SourceType.romm,
          url: 'http://a',
          autoMap: true,
          priority: 1,
          knownPlatforms: {'nds': 8},
        ),
        Source(
          id: 'tims',
          name: 'Tims',
          type: SourceType.romm,
          url: 'http://b',
          autoMap: true,
          priority: 2,
          knownPlatforms: {'nds': 8},
        ),
      ];
      final providers = SourceResolver.providersFor(system, sources);
      expect(providers, hasLength(1));
      expect(providers.single.url, 'http://a');
    });

    test('priorityOverride beats source priority', () {
      const system = SystemConfig(
        id: 'snes',
        name: 'SNES',
        targetFolder: '/x',
        providers: [],
        manualMappings: [
          SystemSourceMapping(
            sourceId: 'nas',
            remotePath: '/snes',
            priorityOverride: 0, // wins over priority 5
          ),
        ],
      );
      const sources = [
        Source(
          id: 'romm',
          name: 'RomM',
          type: SourceType.romm,
          url: 'http://r',
          autoMap: true,
          priority: 1,
          knownPlatforms: {'snes': 4},
        ),
        Source(
          id: 'nas',
          name: 'NAS',
          type: SourceType.smb,
          host: 'nas',
          share: 'r',
          priority: 5,
        ),
      ];
      final providers = SourceResolver.providersFor(system, sources);
      // NAS first (override 0), then RomM (priority 1)
      expect(providers[0].type, ProviderType.smb);
      expect(providers[1].type, ProviderType.romm);
    });

    test('disabled source is excluded', () {
      const system = SystemConfig(
        id: 'snes',
        name: 'SNES',
        targetFolder: '/x',
        providers: [],
      );
      const sources = [
        Source(
          id: 'off',
          name: 'Off',
          type: SourceType.romm,
          url: 'http://a',
          autoMap: true,
          enabled: false,
          knownPlatforms: {'snes': 4},
        ),
      ];
      expect(SourceResolver.providersFor(system, sources), isEmpty);
    });
  });

  group('SourceResolver — parity with legacy migration', () {
    test('after v2 → v3 migration, resolver yields the same provider count'
        ' as the original system.providers list', () {
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
                'platform_id': 4,
                'platform_name': 'snes',
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
      final providers =
          SourceResolver.providersFor(cfg.systems.single, cfg.sources);
      expect(providers, hasLength(2));
      expect(providers[0].type, ProviderType.romm);
      expect(providers[0].platformId, 4);
      expect(providers[1].type, ProviderType.smb);
      expect(providers[1].path, '/snes');
    });

    test('sourcesFor returns the contributing Source objects in order', () {
      const system = SystemConfig(
        id: 'nds',
        name: 'NDS',
        targetFolder: '/x',
        providers: [],
      );
      const sources = [
        Source(
          id: 'a',
          name: 'A',
          type: SourceType.romm,
          url: 'http://a',
          autoMap: true,
          priority: 2,
          knownPlatforms: {'nds': 8},
        ),
        Source(
          id: 'b',
          name: 'B',
          type: SourceType.romm,
          url: 'http://b',
          autoMap: true,
          priority: 1,
          knownPlatforms: {'nds': 8},
        ),
      ];
      final result = SourceResolver.sourcesFor(system, sources);
      expect(result.map((s) => s.id), ['b', 'a']);
    });
  });

  group('SourceResolver — the live route decides the credentials', () {
    // Invariant 4: the resolver reads the source's top-level fields and knows
    // nothing about routes. Per-route credentials must therefore arrive the
    // same way the address does.
    const system = SystemConfig(
      id: 'snes',
      name: 'SNES',
      targetFolder: '/roms/snes',
      providers: [],
    );
    const lan = SourceEndpoint(
      id: 'ep-lan',
      label: '區網',
      url: 'http://192.168.1.50:8090',
    );
    const gated = SourceEndpoint(
      id: 'ep-remote',
      label: '遠端',
      url: 'https://roms.example.org',
      auth: AuthConfig(clientToken: 'proxy-token'),
    );
    const source = Source(
      id: 's1',
      name: 'My RomM',
      type: SourceType.romm,
      url: 'http://192.168.1.50:8090',
      auth: AuthConfig(clientToken: 'tok'),
      endpoints: [lan, gated],
      autoMap: true,
      knownPlatforms: {'snes': 4},
    );

    test('a route without its own login gets the source\'s', () {
      final providers = SourceResolver.providersFor(system, const [source]);

      expect(providers.single.auth?.clientToken, 'tok');
      expect(providers.single.endpointId, 'ep-lan');
    });

    test('a gated route gets its own', () {
      final providers = SourceResolver.providersFor(
        system,
        [source.withLiveEndpoint(gated)],
      );

      expect(providers.single.url, 'https://roms.example.org');
      expect(providers.single.auth?.clientToken, 'proxy-token');
      expect(providers.single.endpointId, 'ep-remote');
    });
  });
}
