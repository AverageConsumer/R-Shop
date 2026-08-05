import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:retro_eshop/models/config/provider_config.dart';
import 'package:retro_eshop/models/config/source.dart';
import 'package:retro_eshop/services/config_storage_service.dart';
import 'package:retro_eshop/services/database_service.dart';
import 'package:retro_eshop/services/sources_notifier.dart';

/// Records purge calls so the tests can assert the one invariant that makes
/// route switching cheap: **switching routes must never drop cached games.**
/// If it did, every switch would cost a full re-sync and the feature would be
/// pointless. Only `removeSource` and `setEnabled(false)` may purge.
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

ConfigStorageService _storageInTempDir() {
  final dir = Directory.systemTemp.createTempSync('rshop_endpoints_test_');
  addTearDown(() async {
    try {
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
  });
  return ConfigStorageService(directoryProvider: () async => dir);
}

const _lan = SourceEndpoint(
  id: 'ep-lan',
  label: '區網',
  url: 'http://192.168.1.50:8090',
);
const _remote = SourceEndpoint(
  id: 'ep-remote',
  label: '遠端',
  url: 'https://roms.example.org',
);

Source _rommWithRoutes({String id = 's1'}) => Source(
      id: id,
      name: id,
      type: SourceType.romm,
      url: _lan.url,
      auth: const AuthConfig(clientToken: 'tok', clientTokenId: 7),
      endpoints: const [_lan, _remote],
      autoMap: true,
      knownPlatforms: const {'snes': 4},
    );

Future<(SourcesNotifier, _SpyDb)> _seeded({
  ConfigStorageService? storage,
}) async {
  final db = _SpyDb();
  final notifier = SourcesNotifier(storage ?? _storageInTempDir(), db: db);
  await notifier.ready;
  await notifier.addSource(_rommWithRoutes());
  return (notifier, db);
}

void main() {
  group('switchEndpoint', () {
    test('moves the live route and mirrors its address onto the source',
        () async {
      final (notifier, _) = await _seeded();

      await notifier.switchEndpoint('s1', 'ep-remote');

      final src = notifier.state.sources.single;
      expect(src.url, 'https://roms.example.org');
      expect(src.liveEndpoint?.id, 'ep-remote');
    });

    test('persists across a reload', () async {
      final storage = _storageInTempDir();
      final (notifier, _) = await _seeded(storage: storage);
      await notifier.switchEndpoint('s1', 'ep-remote');

      final reloaded = SourcesNotifier(storage, db: _SpyDb());
      await reloaded.ready;

      final src = reloaded.state.sources.single;
      expect(src.url, 'https://roms.example.org');
      expect(src.endpoints, hasLength(2));
      expect(src.endpointSelection, EndpointSelection.pinned);
      expect(src.pinnedEndpointId, 'ep-remote');
    });

    test('keeps credentials and cached platforms', () async {
      // Two routes to one server share one account and one library.
      final (notifier, _) = await _seeded();
      await notifier.switchEndpoint('s1', 'ep-remote');

      final src = notifier.state.sources.single;
      expect(src.auth?.clientToken, 'tok');
      expect(src.knownPlatforms, {'snes': 4});
    });

    test('pin: false leaves auto-selection in charge', () async {
      final (notifier, _) = await _seeded();
      await notifier.switchEndpoint('s1', 'ep-remote', pin: false);

      final src = notifier.state.sources.single;
      expect(src.liveEndpoint?.id, 'ep-remote');
      expect(src.endpointSelection, EndpointSelection.auto);
      expect(src.pinnedEndpointId, isNull);
    });

    test('throws on an unknown endpoint', () async {
      final (notifier, _) = await _seeded();
      expect(
        () => notifier.switchEndpoint('s1', 'ep-ghost'),
        throwsA(isA<StateError>()),
      );
    });

    test('NEVER purges cached games — this is the whole point', () async {
      final (notifier, db) = await _seeded();

      await notifier.switchEndpoint('s1', 'ep-remote');
      await notifier.switchEndpoint('s1', 'ep-lan');

      expect(db.purged, isEmpty);
    });

    test('and neither does turning the source off', () async {
      // Guards the boundary from the other side: since the read path filters
      // on the enabled sources, disabling one no longer needs its cache gone —
      // only removeSource discards a library.
      final (notifier, db) = await _seeded();

      await notifier.setEnabled('s1', false);

      expect(db.purged, isEmpty);
    });

    test('but removing the source does purge', () async {
      final (notifier, db) = await _seeded();

      await notifier.removeSource('s1');

      expect(db.purged, ['s1']);
    });
  });

  group('setEndpointSelection', () {
    test('switching to auto clears the pin', () async {
      final (notifier, _) = await _seeded();
      await notifier.switchEndpoint('s1', 'ep-remote');

      await notifier.setEndpointSelection('s1', EndpointSelection.auto);

      final src = notifier.state.sources.single;
      expect(src.endpointSelection, EndpointSelection.auto);
      expect(src.pinnedEndpointId, isNull);
      // The live route does not move just because the pin was released.
      expect(src.liveEndpoint?.id, 'ep-remote');
    });

    test('pinning with nothing chosen pins whatever is live', () async {
      // What the user sees is what they mean.
      final (notifier, _) = await _seeded();

      await notifier.setEndpointSelection('s1', EndpointSelection.pinned);

      expect(notifier.state.sources.single.pinnedEndpointId, 'ep-lan');
    });
  });

  group('addEndpoint', () {
    test('appends a new route', () async {
      final (notifier, _) = await _seeded();

      final added = await notifier.addEndpoint(
        's1',
        const SourceEndpoint(id: 'ep-vpn', label: 'VPN', url: 'http://10.8.0.5'),
      );

      expect(added, isTrue);
      expect(notifier.state.sources.single.endpoints, hasLength(3));
    });

    test('refuses a duplicate address regardless of label', () async {
      // Two entries for one address make liveEndpoint arbitrary.
      final (notifier, _) = await _seeded();

      final added = await notifier.addEndpoint(
        's1',
        const SourceEndpoint(
          id: 'ep-dup',
          label: 'Home',
          url: 'http://192.168.1.50:8090/',
        ),
      );

      expect(added, isFalse);
      expect(notifier.state.sources.single.endpoints, hasLength(2));
    });

    test('refuses a duplicate id', () async {
      final (notifier, _) = await _seeded();

      final added = await notifier.addEndpoint(
        's1',
        const SourceEndpoint(id: 'ep-lan', label: 'x', url: 'http://other'),
      );

      expect(added, isFalse);
    });

    test('does not purge', () async {
      final (notifier, db) = await _seeded();
      await notifier.addEndpoint(
        's1',
        const SourceEndpoint(id: 'ep-vpn', label: 'VPN', url: 'http://10.8.0.5'),
      );
      expect(db.purged, isEmpty);
    });
  });

  group('updateEndpoint', () {
    test('editing the live route takes effect immediately', () async {
      final (notifier, _) = await _seeded();

      await notifier.updateEndpoint(
        's1',
        const SourceEndpoint(
          id: 'ep-lan',
          label: '區網',
          url: 'http://192.168.1.77:9000',
        ),
      );

      expect(notifier.state.sources.single.url, 'http://192.168.1.77:9000');
    });

    test('editing a dormant route leaves the live address alone', () async {
      final (notifier, _) = await _seeded();

      await notifier.updateEndpoint(
        's1',
        const SourceEndpoint(
          id: 'ep-remote',
          label: '遠端',
          url: 'https://new.example.org',
        ),
      );

      final src = notifier.state.sources.single;
      expect(src.url, 'http://192.168.1.50:8090');
      expect(src.endpointById('ep-remote')?.url, 'https://new.example.org');
    });

    test('throws on an unknown endpoint', () async {
      final (notifier, _) = await _seeded();
      expect(
        () => notifier.updateEndpoint(
          's1',
          const SourceEndpoint(id: 'ghost', label: 'x', url: 'http://x'),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('refuses to move a route onto another route\'s address', () async {
      // Two routes at one address make liveEndpoint — and so which token is
      // sent — depend on list order.
      final (notifier, _) = await _seeded();

      final ok = await notifier.updateEndpoint(
        's1',
        const SourceEndpoint(
          id: 'ep-remote',
          label: '遠端',
          url: 'http://192.168.1.50:8090',
        ),
      );

      expect(ok, isFalse);
      expect(
        notifier.state.sources.single.endpointById('ep-remote')?.url,
        'https://roms.example.org',
      );
    });
  });

  group('per-route credentials', () {
    const proxyAuth = AuthConfig(clientToken: 'proxy-token');

    test('a route can be added with a login of its own', () async {
      final (notifier, _) = await _seeded();

      await notifier.addEndpoint(
        's1',
        const SourceEndpoint(
          id: 'ep-ddns',
          label: 'DDNS',
          url: 'https://roms.duckdns.org',
          auth: proxyAuth,
        ),
      );

      final src = notifier.state.sources.single;
      expect(src.endpointById('ep-ddns')?.auth?.clientToken, 'proxy-token');
      // Adding it does not change who is live, so the source login still wins.
      expect(src.auth?.clientToken, 'tok');
    });

    test('switching to it sends that login and switching back sends the '
        'source\'s', () async {
      final (notifier, _) = await _seeded();
      await notifier.setEndpointAuth('s1', 'ep-remote', proxyAuth);

      await notifier.switchEndpoint('s1', 'ep-remote');
      expect(notifier.state.sources.single.auth?.clientToken, 'proxy-token');

      await notifier.switchEndpoint('s1', 'ep-lan');
      expect(notifier.state.sources.single.auth?.clientToken, 'tok');
    });

    test('credentials survive a reload', () async {
      final storage = _storageInTempDir();
      final (notifier, _) = await _seeded(storage: storage);
      await notifier.setEndpointAuth('s1', 'ep-remote', proxyAuth);

      final reloaded = SourcesNotifier(storage, db: _SpyDb());
      await reloaded.ready;

      final src = reloaded.state.sources.single;
      expect(src.endpointById('ep-remote')?.auth?.clientToken, 'proxy-token');
      expect(src.defaultAuth?.clientToken, 'tok');
    });

    test('null clears the route\'s login and hands it back to the source',
        () async {
      final (notifier, _) = await _seeded();
      await notifier.setEndpointAuth('s1', 'ep-remote', proxyAuth);

      await notifier.setEndpointAuth('s1', 'ep-remote', null);

      final src = notifier.state.sources.single;
      expect(src.endpointById('ep-remote')?.auth, isNull);
      await notifier.switchEndpoint('s1', 'ep-remote');
      expect(notifier.state.sources.single.auth?.clientToken, 'tok');
    });

    test('editing the live route\'s login takes effect immediately', () async {
      final (notifier, _) = await _seeded();

      await notifier.setEndpointAuth('s1', 'ep-lan', proxyAuth);

      expect(notifier.state.sources.single.auth?.clientToken, 'proxy-token');
    });

    test('throws on an unknown route rather than inventing one', () async {
      final (notifier, _) = await _seeded();
      expect(
        () => notifier.setEndpointAuth('s1', 'ep-ghost', proxyAuth),
        throwsA(isA<StateError>()),
      );
    });

    test('NEVER purges — a rotated token is not a changed library', () async {
      final (notifier, db) = await _seeded();

      await notifier.setEndpointAuth('s1', 'ep-remote', proxyAuth);
      await notifier.switchEndpoint('s1', 'ep-remote');
      await notifier.setEndpointAuth('s1', 'ep-remote', null);

      expect(db.purged, isEmpty);
    });
  });

  group('removeEndpoint', () {
    test('refuses to remove the last route', () async {
      // A source with no route has no address at all.
      final (notifier, _) = await _seeded();
      await notifier.removeEndpoint('s1', 'ep-remote');

      final removed = await notifier.removeEndpoint('s1', 'ep-lan');

      expect(removed, isFalse);
      expect(notifier.state.sources.single.endpoints, hasLength(1));
    });

    test('removing the live route hands over to the first remaining', () async {
      final (notifier, _) = await _seeded();

      await notifier.removeEndpoint('s1', 'ep-lan');

      final src = notifier.state.sources.single;
      expect(src.endpoints.single.id, 'ep-remote');
      expect(src.url, 'https://roms.example.org');
      expect(src.liveEndpoint?.id, 'ep-remote');
    });

    test('removing the pinned route clears the pin instead of dangling',
        () async {
      final (notifier, _) = await _seeded();
      await notifier.switchEndpoint('s1', 'ep-remote');

      await notifier.removeEndpoint('s1', 'ep-remote');

      final src = notifier.state.sources.single;
      expect(src.pinnedEndpointId, isNull);
      expect(src.endpointSelection, EndpointSelection.auto);
      expect(src.liveEndpoint?.id, 'ep-lan');
    });

    test('does not purge — the source still exists', () async {
      final (notifier, db) = await _seeded();
      await notifier.removeEndpoint('s1', 'ep-remote');
      expect(db.purged, isEmpty);
    });

    test('unknown endpoint is a no-op', () async {
      final (notifier, _) = await _seeded();
      final removed = await notifier.removeEndpoint('s1', 'ghost');
      expect(removed, isFalse);
      expect(notifier.state.sources.single.endpoints, hasLength(2));
    });
  });
}
