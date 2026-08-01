import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:retro_eshop/models/config/app_config.dart';
import 'package:retro_eshop/models/config/source.dart';
import 'package:retro_eshop/models/config/system_config.dart';
import 'package:retro_eshop/services/config_storage_service.dart';
import 'package:retro_eshop/services/database_service.dart';
import 'package:retro_eshop/services/source_resolver.dart';
import 'package:retro_eshop/services/sources_notifier.dart';

/// Two sources are two independent libraries — **even when they point at the
/// same server**. The user's model, not an inference from the URLs. Switching
/// changes which one is in view and which one a sync talks to, and must never
/// discard the other one's cached games.
class _SpyDb extends DatabaseService {
  final purged = <String>[];

  @override
  Future<({int detached, int deleted})> purgeOrDetachSource(
    String sourceId, {
    required Map<String, String> systemTargetFolders,
  }) async {
    purged.add(sourceId);
    return (detached: 0, deleted: 0);
  }
}

Source _romm(String id, String url) => Source(
      id: id,
      name: id,
      type: SourceType.romm,
      url: url,
      autoMap: true,
      knownPlatforms: const {'snes': 4},
    );

Future<ConfigStorageService> _storageWithSystem() async {
  final dir = Directory.systemTemp.createTempSync('rshop_active_src_');
  addTearDown(() async {
    try {
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
  });
  final storage = ConfigStorageService(directoryProvider: () async => dir);
  await storage.saveConfig(jsonEncode(AppConfig(
    version: AppConfig.currentVersion,
    systems: [
      const SystemConfig(
        id: 'snes',
        name: 'SNES',
        targetFolder: '/roms/snes',
        providers: [],
      ),
    ],
    sources: const [],
  ).toJson()));
  return storage;
}

void main() {
  group('SourceResolver.providersFor — active source', () {
    const system = SystemConfig(
      id: 'snes',
      name: 'SNES',
      targetFolder: '/roms/snes',
      providers: [],
    );
    final all = [
      _romm('a', 'http://192.168.0.20:9080'),
      _romm('b', 'http://home.example.org:9080'),
    ];

    test('null means every enabled source, as before', () {
      expect(SourceResolver.providersFor(system, all), hasLength(2));
    });

    test('an active id narrows to that one source', () {
      final providers =
          SourceResolver.providersFor(system, all, activeSourceId: 'b');

      expect(providers, hasLength(1));
      expect(providers.single.sourceId, 'b');
    });

    test('an unknown id shows everything rather than nothing', () {
      // A source deleted while selected must not leave an empty library.
      expect(
        SourceResolver.providersFor(system, all, activeSourceId: 'deleted'),
        hasLength(2),
      );
    });

    test('disabled beats active — an off source stays off', () {
      final withDisabled = [
        all.first,
        _romm('b', 'http://home.example.org:9080').copyWith(enabled: false),
      ];

      expect(
        SourceResolver.providersFor(system, withDisabled, activeSourceId: 'b'),
        isEmpty,
      );
    });
  });

  group('SourcesNotifier.setActiveSource', () {
    test('narrows the systems providers to the chosen source', () async {
      final storage = await _storageWithSystem();
      final notifier = SourcesNotifier(storage, db: _SpyDb());
      await notifier.ready;
      await notifier.addSource(_romm('a', 'http://192.168.0.20:9080'));
      await notifier.addSource(_romm('b', 'http://home.example.org:9080'));

      await notifier.setActiveSource('b');

      final reloaded = await storage.loadConfig();
      expect(reloaded!.activeSourceId, 'b');
      final providers = reloaded.systems.single.providers;
      expect(providers.map((p) => p.sourceId), ['b']);
    });

    test('NEVER purges — switching back must be instant, not a re-sync',
        () async {
      final storage = await _storageWithSystem();
      final db = _SpyDb();
      final notifier = SourcesNotifier(storage, db: db);
      await notifier.ready;
      await notifier.addSource(_romm('a', 'http://192.168.0.20:9080'));
      await notifier.addSource(_romm('b', 'http://home.example.org:9080'));

      await notifier.setActiveSource('b');
      await notifier.setActiveSource('a');

      expect(db.purged, isEmpty);
    });

    test('but disabling a source still purges it', () async {
      // Guards the boundary: "not in view" and "turned off" stay different.
      final storage = await _storageWithSystem();
      final db = _SpyDb();
      final notifier = SourcesNotifier(storage, db: db);
      await notifier.ready;
      await notifier.addSource(_romm('a', 'http://192.168.0.20:9080'));

      await notifier.setEnabled('a', false);

      expect(db.purged, ['a']);
    });

    test('null puts every source back in view', () async {
      final storage = await _storageWithSystem();
      final notifier = SourcesNotifier(storage, db: _SpyDb());
      await notifier.ready;
      await notifier.addSource(_romm('a', 'http://192.168.0.20:9080'));
      await notifier.addSource(_romm('b', 'http://home.example.org:9080'));
      await notifier.setActiveSource('b');

      await notifier.setActiveSource(null);

      final reloaded = await storage.loadConfig();
      expect(reloaded!.activeSourceId, isNull);
      expect(reloaded.systems.single.providers, hasLength(2));
    });

    test('survives a reload', () async {
      final storage = await _storageWithSystem();
      final notifier = SourcesNotifier(storage, db: _SpyDb());
      await notifier.ready;
      await notifier.addSource(_romm('a', 'http://192.168.0.20:9080'));
      await notifier.addSource(_romm('b', 'http://home.example.org:9080'));
      await notifier.setActiveSource('b');

      final reopened = SourcesNotifier(storage, db: _SpyDb());
      await reopened.ready;

      final cfg = await storage.loadConfig();
      expect(cfg!.activeSourceId, 'b');
    });

    test('rejects an unknown source id', () async {
      final notifier = SourcesNotifier(await _storageWithSystem(), db: _SpyDb());
      await notifier.ready;

      expect(
        () => notifier.setActiveSource('ghost'),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('AppConfig.activeSource', () {
    test('resolves the selected source', () {
      final cfg = AppConfig(
        systems: const [],
        sources: [_romm('a', 'http://a'), _romm('b', 'http://b')],
        activeSourceId: 'b',
      );

      expect(cfg.activeSource?.id, 'b');
    });

    test('a dangling id resolves to null, not a crash', () {
      final cfg = AppConfig(
        systems: const [],
        sources: [_romm('a', 'http://a')],
        activeSourceId: 'deleted',
      );

      expect(cfg.activeSource, isNull);
    });

    test('round-trips through JSON', () {
      final cfg = AppConfig(
        systems: const [],
        sources: [_romm('a', 'http://a')],
        activeSourceId: 'a',
      );

      expect(AppConfig.fromJson(cfg.toJson()).activeSourceId, 'a');
    });
  });
}
