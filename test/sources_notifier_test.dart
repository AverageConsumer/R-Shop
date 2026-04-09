import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:retro_eshop/models/config/app_config.dart';
import 'package:retro_eshop/models/config/provider_config.dart';
import 'package:retro_eshop/models/config/source.dart';
import 'package:retro_eshop/models/config/system_config.dart';
import 'package:retro_eshop/services/config_storage_service.dart';
import 'package:retro_eshop/services/romm_pairing_service.dart';
import 'package:retro_eshop/services/sources_notifier.dart';

ConfigStorageService _storageInTempDir() {
  final dir = Directory.systemTemp.createTempSync('rshop_sources_test_');
  addTearDown(() async {
    try {
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
  });
  return ConfigStorageService(directoryProvider: () async => dir);
}

/// Pre-seeds storage with a v3 AppConfig so the notifier bootstrap has
/// systems to operate on.
Future<ConfigStorageService> _storageWithSystem({
  required String systemId,
}) async {
  final storage = _storageInTempDir();
  final config = AppConfig(
    version: AppConfig.currentVersion,
    systems: [
      SystemConfig(
        id: systemId,
        name: systemId.toUpperCase(),
        targetFolder: '/roms/$systemId',
        providers: const [],
      ),
    ],
    sources: const [],
  );
  await storage.saveConfig(jsonEncode(config.toJson()));
  return storage;
}

Source _romm({
  String id = 's1',
  String url = 'http://romm.local:8090',
  Map<String, int> platforms = const {'snes': 4},
  bool enabled = true,
}) {
  return Source(
    id: id,
    name: id,
    type: SourceType.romm,
    url: url,
    autoMap: true,
    enabled: enabled,
    knownPlatforms: platforms,
  );
}

void main() {
  group('SourcesNotifier — bootstrap', () {
    test('starts in loading state and resolves to empty list when no config',
        () async {
      final notifier = SourcesNotifier(_storageInTempDir());
      expect(notifier.state.loading, isTrue);
      await notifier.ready;
      expect(notifier.state.loading, isFalse);
      expect(notifier.state.sources, isEmpty);
      expect(notifier.state.error, isNull);
    });
  });

  group('SourcesNotifier — addSource', () {
    test('persists a new source and refreshes state', () async {
      final storage = _storageInTempDir();
      final notifier = SourcesNotifier(storage);
      await notifier.ready;

      await notifier.addSource(_romm());
      expect(notifier.state.sources, hasLength(1));
      expect(notifier.state.sources.single.id, 's1');

      // Re-read from disk via a fresh notifier to confirm persistence.
      final reloaded = SourcesNotifier(storage);
      await reloaded.ready;
      expect(reloaded.state.sources, hasLength(1));
      expect(reloaded.state.sources.single.url, 'http://romm.local:8090');
      expect(reloaded.state.sources.single.knownPlatforms, {'snes': 4});
    });

    test('addSource with duplicate id is a no-op', () async {
      final notifier = SourcesNotifier(_storageInTempDir());
      await notifier.ready;
      await notifier.addSource(_romm(id: 'a'));
      await notifier.addSource(_romm(id: 'a', url: 'http://other'));
      expect(notifier.state.sources, hasLength(1));
      expect(notifier.state.sources.single.url, 'http://romm.local:8090');
    });
  });

  group('SourcesNotifier — updateSource', () {
    test('replaces fields by id', () async {
      final notifier = SourcesNotifier(_storageInTempDir());
      await notifier.ready;
      await notifier.addSource(_romm(id: 'a', url: 'http://old'));
      await notifier.updateSource(_romm(id: 'a', url: 'http://new'));
      expect(notifier.state.sources.single.url, 'http://new');
    });

    test('throws StateError on unknown id', () async {
      final notifier = SourcesNotifier(_storageInTempDir());
      await notifier.ready;
      expect(
        () => notifier.updateSource(_romm(id: 'ghost')),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('SourcesNotifier — removeSource', () {
    test('removes by id and persists', () async {
      final storage = _storageInTempDir();
      final notifier = SourcesNotifier(storage);
      await notifier.ready;
      await notifier.addSource(_romm(id: 'a'));
      await notifier.addSource(_romm(id: 'b', url: 'http://b'));
      await notifier.removeSource('a');
      expect(notifier.state.sources, hasLength(1));
      expect(notifier.state.sources.single.id, 'b');

      final reloaded = SourcesNotifier(storage);
      await reloaded.ready;
      expect(reloaded.state.sources.single.id, 'b');
    });

    test('removeSource with unknown id is a no-op', () async {
      final notifier = SourcesNotifier(_storageInTempDir());
      await notifier.ready;
      await notifier.addSource(_romm(id: 'a'));
      await notifier.removeSource('ghost');
      expect(notifier.state.sources, hasLength(1));
    });
  });

  group('SourcesNotifier — setEnabled', () {
    test('toggles the enabled flag', () async {
      final notifier = SourcesNotifier(_storageInTempDir());
      await notifier.ready;
      await notifier.addSource(_romm(id: 'a'));
      await notifier.setEnabled('a', false);
      expect(notifier.state.sources.single.enabled, isFalse);
      await notifier.setEnabled('a', true);
      expect(notifier.state.sources.single.enabled, isTrue);
    });

    test('setEnabled with same value is a no-op', () async {
      final notifier = SourcesNotifier(_storageInTempDir());
      await notifier.ready;
      await notifier.addSource(_romm(id: 'a'));
      final before = notifier.state.sources;
      await notifier.setEnabled('a', true); // already true
      expect(identical(notifier.state.sources, before), isTrue);
    });
  });

  group('SourcesNotifier — updateKnownPlatforms', () {
    test('replaces the platform map and persists', () async {
      final storage = _storageInTempDir();
      final notifier = SourcesNotifier(storage);
      await notifier.ready;
      await notifier.addSource(_romm(id: 'a', platforms: const {'snes': 4}));
      await notifier.updateKnownPlatforms('a', const {
        'snes': 4,
        'nds': 8,
        'gba': 5,
      });
      expect(notifier.state.sources.single.knownPlatforms, hasLength(3));

      final reloaded = SourcesNotifier(storage);
      await reloaded.ready;
      expect(reloaded.state.sources.single.knownPlatforms['gba'], 5);
    });
  });

  group('SourcesNotifier — dual-write to legacy providers', () {
    test('addSource for an auto-mapped RomM rebuilds system.providers',
        () async {
      final storage = await _storageWithSystem(systemId: 'snes');
      final notifier = SourcesNotifier(storage);
      await notifier.ready;

      // Initially the system has no providers.
      expect(notifier.debugCachedConfig.systems.single.providers, isEmpty);

      await notifier.addSource(_romm(id: 'a', platforms: const {'snes': 4}));

      final providers = notifier.debugCachedConfig.systems.single.providers;
      expect(providers, hasLength(1));
      expect(providers.single.type, ProviderType.romm);
      expect(providers.single.platformId, 4);
      expect(providers.single.url, 'http://romm.local:8090');
    });

    test('removeSource removes the managed provider but keeps unmanaged ones',
        () async {
      // Pre-seed the system with an unmanaged legacy provider.
      final dir = Directory.systemTemp.createTempSync('rshop_remove_');
      addTearDown(() async {
        try {
          await dir.delete(recursive: true);
        } catch (_) {}
      });
      final storage =
          ConfigStorageService(directoryProvider: () async => dir);
      final initial = AppConfig(
        version: AppConfig.currentVersion,
        systems: const [
          SystemConfig(
            id: 'snes',
            name: 'SNES',
            targetFolder: '/roms/snes',
            providers: [
              ProviderConfig(
                type: ProviderType.smb,
                priority: 5,
                host: 'nas',
                share: 'r',
                path: '/snes',
              ),
            ],
          ),
        ],
        sources: const [],
      );
      await storage.saveConfig(jsonEncode(initial.toJson()));

      final notifier = SourcesNotifier(storage);
      await notifier.ready;
      await notifier.addSource(_romm(id: 'a', platforms: const {'snes': 4}));
      // Now: SNES has 2 providers (1 SMB legacy + 1 RomM managed).
      expect(notifier.debugCachedConfig.systems.single.providers, hasLength(2));

      await notifier.removeSource('a');
      // RomM (managed) is gone, SMB (legacy) survives.
      final providers = notifier.debugCachedConfig.systems.single.providers;
      expect(providers, hasLength(1));
      expect(providers.single.type, ProviderType.smb);
      expect(providers.single.managedBySource, isFalse);
    });

    test('setEnabled(false) drops the managed provider but keeps unmanaged',
        () async {
      final dir = Directory.systemTemp.createTempSync('rshop_disable_');
      addTearDown(() async {
        try {
          await dir.delete(recursive: true);
        } catch (_) {}
      });
      final storage =
          ConfigStorageService(directoryProvider: () async => dir);
      final initial = AppConfig(
        version: AppConfig.currentVersion,
        systems: const [
          SystemConfig(
            id: 'snes',
            name: 'SNES',
            targetFolder: '/roms/snes',
            providers: [
              ProviderConfig(
                type: ProviderType.smb,
                priority: 5,
                host: 'nas',
                share: 'r',
                path: '/snes',
              ),
            ],
          ),
        ],
        sources: const [],
      );
      await storage.saveConfig(jsonEncode(initial.toJson()));

      final notifier = SourcesNotifier(storage);
      await notifier.ready;
      await notifier.addSource(_romm(id: 'a', platforms: const {'snes': 4}));
      await notifier.setEnabled('a', false);
      final providers = notifier.debugCachedConfig.systems.single.providers;
      expect(providers, hasLength(1));
      expect(providers.single.type, ProviderType.smb);
    });

    test('updateKnownPlatforms with new system slug grows that systems list',
        () async {
      // Two systems: snes + nds. Source initially only knows snes.
      final dir = Directory.systemTemp.createTempSync('rshop_dual_');
      addTearDown(() async {
        try {
          await dir.delete(recursive: true);
        } catch (_) {}
      });
      final storage =
          ConfigStorageService(directoryProvider: () async => dir);
      final config = AppConfig(
        version: AppConfig.currentVersion,
        systems: const [
          SystemConfig(
            id: 'snes',
            name: 'SNES',
            targetFolder: '/roms/snes',
            providers: [],
          ),
          SystemConfig(
            id: 'nds',
            name: 'NDS',
            targetFolder: '/roms/nds',
            providers: [],
          ),
        ],
        sources: const [],
      );
      await storage.saveConfig(jsonEncode(config.toJson()));

      final notifier = SourcesNotifier(storage);
      await notifier.ready;
      await notifier.addSource(_romm(id: 'a', platforms: const {'snes': 4}));
      var systems = notifier.debugCachedConfig.systems;
      expect(systems.firstWhere((s) => s.id == 'snes').providers, hasLength(1));
      expect(systems.firstWhere((s) => s.id == 'nds').providers, isEmpty);

      await notifier.updateKnownPlatforms('a', {'snes': 4, 'nds': 8});
      systems = notifier.debugCachedConfig.systems;
      expect(systems.firstWhere((s) => s.id == 'snes').providers, hasLength(1));
      expect(systems.firstWhere((s) => s.id == 'nds').providers, hasLength(1));
      expect(
        systems.firstWhere((s) => s.id == 'nds').providers.single.platformId,
        8,
      );
    });
  });

  group('SourcesNotifier — regression: pairing must not wipe other systems',
      () {
    test(
        'addSource for a new RomM does NOT clear systems the source does not '
        'advertise', () async {
      final dir = Directory.systemTemp.createTempSync('rshop_regress_');
      addTearDown(() async {
        try {
          await dir.delete(recursive: true);
        } catch (_) {}
      });
      final storage =
          ConfigStorageService(directoryProvider: () async => dir);

      // Pre-existing config: two systems, each with a configured legacy
      // provider (e.g. set up by the onboarding flow). The user has NOT
      // paired anything yet — sources is empty.
      final initial = AppConfig(
        version: AppConfig.currentVersion,
        systems: const [
          SystemConfig(
            id: 'snes',
            name: 'SNES',
            targetFolder: '/roms/snes',
            providers: [
              ProviderConfig(
                type: ProviderType.smb,
                priority: 1,
                host: 'nas',
                share: 'roms',
                path: '/snes',
              ),
            ],
          ),
          SystemConfig(
            id: 'nds',
            name: 'NDS',
            targetFolder: '/roms/nds',
            providers: [
              ProviderConfig(
                type: ProviderType.smb,
                priority: 1,
                host: 'nas',
                share: 'roms',
                path: '/nds',
              ),
            ],
          ),
        ],
        sources: const [],
      );
      await storage.saveConfig(jsonEncode(initial.toJson()));

      // Now the user pairs a brand-new RomM that only knows SNES.
      final notifier = SourcesNotifier(storage);
      await notifier.ready;
      await notifier.addSource(_romm(id: 'pair', platforms: const {'snes': 4}));

      // Expectation:
      // - SNES has BOTH the legacy SMB AND the new managed RomM (multi-
      //   source merge — user gets games from both).
      // - NDS keeps only its existing SMB; the source had nothing to say
      //   about NDS, so the managed list for NDS is empty and the
      //   unmanaged SMB survives untouched.
      final systems = notifier.debugCachedConfig.systems;
      final snes = systems.firstWhere((s) => s.id == 'snes');
      final nds = systems.firstWhere((s) => s.id == 'nds');

      expect(snes.providers, hasLength(2));
      expect(snes.providers.where((p) => p.managedBySource), hasLength(1));
      expect(snes.providers.where((p) => !p.managedBySource), hasLength(1));
      expect(nds.providers, hasLength(1));
      expect(nds.providers.single.type, ProviderType.smb);
      expect(nds.providers.single.path, '/nds');
      expect(nds.providers.single.managedBySource, isFalse);
    });

    test('addSource picks up systems written to disk after bootstrap',
        () async {
      // Simulates the user finishing the onboarding (which writes to
      // config.json directly via ConfigStorageService) AFTER the
      // SourcesNotifier has already loaded an empty cache, then pairing
      // through the notifier.
      final dir = Directory.systemTemp.createTempSync('rshop_stale_');
      addTearDown(() async {
        try {
          await dir.delete(recursive: true);
        } catch (_) {}
      });
      final storage =
          ConfigStorageService(directoryProvider: () async => dir);

      // Bootstrap with an empty config.
      final notifier = SourcesNotifier(storage);
      await notifier.ready;
      expect(notifier.debugCachedConfig.systems, isEmpty);

      // Onboarding writes a system to disk *behind the notifier's back*.
      final externalUpdate = AppConfig(
        version: AppConfig.currentVersion,
        systems: const [
          SystemConfig(
            id: 'gba',
            name: 'GBA',
            targetFolder: '/roms/gba',
            providers: [],
          ),
        ],
        sources: const [],
      );
      await storage.saveConfig(jsonEncode(externalUpdate.toJson()));

      // Now pair a RomM. The write must NOT clobber the GBA system.
      await notifier.addSource(_romm(id: 'a', platforms: const {'gba': 5}));

      final reloaded = SourcesNotifier(storage);
      await reloaded.ready;
      expect(reloaded.debugCachedConfig.systems, hasLength(1));
      expect(reloaded.debugCachedConfig.systems.single.id, 'gba');
      expect(reloaded.state.sources, hasLength(1));
      // GBA's provider list reflects the new source.
      expect(reloaded.debugCachedConfig.systems.single.providers, hasLength(1));
    });
  });

  group('SourcesNotifier — refreshTokenFromPair', () {
    test('updates token + expiry while preserving id, name, borrowed',
        () async {
      final storage = _storageInTempDir();
      final notifier = SourcesNotifier(storage);
      await notifier.ready;
      await notifier.addSource(Source(
        id: 'tims-romm',
        name: 'Tims RomM',
        type: SourceType.romm,
        url: 'http://old.example.com',
        autoMap: true,
        enabled: true,
        borrowed: true,
        knownPlatforms: const {'snes': 4, 'gba': 5},
        tokenExpiresAt: DateTime.utc(2026, 1, 1),
      ));

      final newExpiry = DateTime.utc(2026, 6, 1);
      await notifier.refreshTokenFromPair(
        'tims-romm',
        RommPairResult(
          serverUrl: 'http://new.example.com',
          token: 'fresh-bearer-token',
          tokenId: 99,
          name: 'ignored — name comes from existing source',
          scopes: const ['roms.read'],
          userId: 7,
          expiresAt: newExpiry,
        ),
      );

      final updated = notifier.state.sources.single;
      expect(updated.id, 'tims-romm');
      expect(updated.name, 'Tims RomM'); // unchanged
      expect(updated.borrowed, isTrue); // unchanged
      expect(updated.url, 'http://new.example.com'); // refreshed
      expect(updated.auth?.clientToken, 'fresh-bearer-token');
      expect(updated.auth?.clientTokenId, 99);
      expect(updated.tokenExpiresAt, newExpiry);
      // knownPlatforms preserved when not passed.
      expect(updated.knownPlatforms, {'snes': 4, 'gba': 5});
    });

    test('replaces knownPlatforms when caller passes a fresh map', () async {
      final storage = _storageInTempDir();
      final notifier = SourcesNotifier(storage);
      await notifier.ready;
      await notifier.addSource(_romm(id: 's1', platforms: const {'snes': 4}));

      await notifier.refreshTokenFromPair(
        's1',
        RommPairResult(
          serverUrl: 'http://romm.local:8090',
          token: 't',
          tokenId: 1,
          name: 'r-shop',
          scopes: const [],
          userId: 1,
          expiresAt: null,
        ),
        knownPlatforms: const {'nds': 8, 'gba': 5},
      );

      expect(notifier.state.sources.single.knownPlatforms,
          {'nds': 8, 'gba': 5});
    });

    test('throws StateError when source id is unknown', () async {
      final storage = _storageInTempDir();
      final notifier = SourcesNotifier(storage);
      await notifier.ready;
      expect(
        () => notifier.refreshTokenFromPair(
          'nope',
          RommPairResult(
            serverUrl: 'http://x',
            token: 't',
            tokenId: 1,
            name: 'n',
            scopes: const [],
            userId: 1,
          ),
        ),
        throwsStateError,
      );
    });
  });

  group('SourcesNotifier — replaceAll', () {
    test('replaces the whole list and persists', () async {
      final storage = _storageInTempDir();
      final notifier = SourcesNotifier(storage);
      await notifier.ready;
      await notifier.addSource(_romm(id: 'a'));
      await notifier.replaceAll([
        _romm(id: 'b', url: 'http://b'),
        _romm(id: 'c', url: 'http://c'),
      ]);
      expect(notifier.state.sources.map((s) => s.id), ['b', 'c']);

      final reloaded = SourcesNotifier(storage);
      await reloaded.ready;
      expect(reloaded.state.sources.map((s) => s.id), ['b', 'c']);
    });
  });
}
