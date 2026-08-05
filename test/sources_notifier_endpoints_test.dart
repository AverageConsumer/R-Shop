import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:retro_eshop/models/config/provider_config.dart';
import 'package:retro_eshop/models/config/source.dart';
import 'package:retro_eshop/services/config_storage_service.dart';
import 'package:retro_eshop/services/database_service.dart';
import 'package:retro_eshop/services/endpoint_probe_service.dart';
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
    Set<String> protectedOwnerIds = const {},
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

    test('switching to ordered clears the pin too', () async {
      // A pin outranks the order — it is the one mode with no failover — so a
      // source left pinned while claiming to follow the list would sit on a
      // dead route and look as if the order were being honoured.
      final (notifier, _) = await _seeded();
      await notifier.switchEndpoint('s1', 'ep-remote'); // pins by default

      await notifier.setEndpointSelection('s1', EndpointSelection.ordered);

      final src = notifier.state.sources.single;
      expect(src.endpointSelection, EndpointSelection.ordered);
      expect(src.pinnedEndpointId, isNull);
      expect(src.liveEndpoint?.id, 'ep-remote',
          reason: 'releasing the pin does not itself move the route');
    });
  });

  group('order as a setting', () {
    test('ordered takes the first route that answers, not the fastest',
        () async {
      final (notifier, _) = await _seeded();

      await notifier.useOrderedSelection(
        's1',
        probe: _probe(fast: _remoteAddress, slow: _lanAddress),
      );

      // The LAN route is listed first and it did answer, so it wins even
      // though the remote one answered quicker.
      final src = notifier.state.sources.single;
      expect(src.endpointSelection, EndpointSelection.ordered);
      expect(src.liveEndpoint?.id, 'ep-lan');
    });

    test('ordered walks past a route that is down', () async {
      final (notifier, _) = await _seeded();

      await notifier.useOrderedSelection(
        's1',
        probe: _probe(fast: _remoteAddress, down: {_lanAddress}),
      );

      expect(notifier.state.sources.single.liveEndpoint?.id, 'ep-remote');
    });

    test('reordering re-resolves, because the order is the setting', () async {
      final (notifier, _) = await _seeded();
      await notifier.useOrderedSelection(
        's1',
        probe: _probe(fast: _lanAddress, slow: _remoteAddress),
      );
      expect(notifier.state.sources.single.liveEndpoint?.id, 'ep-lan');

      await notifier.reorderEndpoints(
        's1',
        ['ep-remote', 'ep-lan'],
        probe: _probe(fast: _lanAddress, slow: _remoteAddress),
      );

      final src = notifier.state.sources.single;
      expect(src.endpoints.map((e) => e.id), ['ep-remote', 'ep-lan']);
      expect(src.liveEndpoint?.id, 'ep-remote');
    });

    test('reordering in auto mode moves nothing on its own', () async {
      final (notifier, _) = await _seeded();

      await notifier.reorderEndpoints(
        's1',
        ['ep-remote', 'ep-lan'],
        probe: _probe(fast: _lanAddress, slow: _remoteAddress),
      );

      final src = notifier.state.sources.single;
      expect(src.endpoints.map((e) => e.id), ['ep-remote', 'ep-lan']);
      expect(src.liveEndpoint?.id, 'ep-lan');
    });

    test('moveEndpointTo is the button form and keeps the cache', () async {
      final (notifier, db) = await _seeded();

      await notifier.moveEndpointTo(
        's1',
        'ep-remote',
        0,
        probe: _probe(fast: _lanAddress, slow: _remoteAddress),
      );

      expect(notifier.state.sources.single.endpoints.map((e) => e.id),
          ['ep-remote', 'ep-lan']);
      expect(db.purged, isEmpty);
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

  group('autoSelectEndpoint', () {
    test('moves to the fastest route without recording an override', () async {
      final (notifier, db) = await _seeded();

      final chosen = await notifier.autoSelectEndpoint(
        's1',
        probe: _probe(fast: _remoteAddress, slow: _lanAddress),
      );

      final src = notifier.state.sources.single;
      expect(chosen, 'ep-remote');
      expect(src.liveEndpoint?.id, 'ep-remote');
      expect(src.endpointSelection, EndpointSelection.auto);
      expect(src.pinnedEndpointId, isNull);
      // The reason auto-selection can run as often as it likes.
      expect(db.purged, isEmpty);
    });

    test('leaves a route the user overrode exactly where it is', () async {
      final (notifier, _) = await _seeded();
      await notifier.switchEndpoint('s1', 'ep-remote'); // pins by default

      final chosen = await notifier.autoSelectEndpoint(
        's1',
        probe: _probe(fast: _lanAddress, slow: _remoteAddress),
      );

      expect(chosen, 'ep-remote');
      expect(notifier.state.sources.single.liveEndpoint?.id, 'ep-remote');
    });

    test('ignores a route that did not answer, however it is listed', () async {
      final (notifier, _) = await _seeded();

      await notifier.autoSelectEndpoint(
        's1',
        probe: _probe(fast: _remoteAddress, down: {_lanAddress}),
      );

      expect(notifier.state.sources.single.liveEndpoint?.id, 'ep-remote');
    });

    test('stays put when nothing answers — a real error beats a silent move',
        () async {
      final (notifier, _) = await _seeded();

      await notifier.autoSelectEndpoint(
        's1',
        probe: _probe(down: {_lanAddress, _remoteAddress}),
      );

      expect(notifier.state.sources.single.liveEndpoint?.id, 'ep-lan');
    });

    test('a single-route source is not worth a probe', () async {
      final (notifier, _) = await _seeded();
      await notifier.removeEndpoint('s1', 'ep-remote');
      final net = _FakeNet(const {});

      await notifier.autoSelectEndpoint(
        's1',
        probe: EndpointProbeService(connect: net.connect),
      );

      expect(net.asked, isEmpty);
    });

    test('clearEndpointOverride releases the pin and re-picks in one call',
        () async {
      final (notifier, _) = await _seeded();
      await notifier.switchEndpoint('s1', 'ep-remote');

      await notifier.clearEndpointOverride(
        's1',
        probe: _probe(fast: _lanAddress, slow: _remoteAddress),
      );

      final src = notifier.state.sources.single;
      expect(src.endpointSelection, EndpointSelection.auto);
      expect(src.pinnedEndpointId, isNull);
      expect(src.liveEndpoint?.id, 'ep-lan');
    });

    test('autoSelectAllEndpoints skips disabled sources', () async {
      final (notifier, _) = await _seeded();
      await notifier.addSource(_rommWithRoutes(id: 's2'));
      await notifier.setEnabled('s2', false);

      await notifier.autoSelectAllEndpoints(
        probe: _probe(fast: _remoteAddress, slow: _lanAddress),
      );

      final byId = {for (final s in notifier.state.sources) s.id: s};
      expect(byId['s1']!.liveEndpoint?.id, 'ep-remote');
      expect(byId['s2']!.liveEndpoint?.id, 'ep-lan');
    });
  });

  group('bootstrap realigns stored overrides', () {
    test('a pin naming a deleted route is not an override any more', () async {
      final storage = _storageInTempDir();
      final (notifier, _) = await _seeded(storage: storage);
      await notifier.switchEndpoint('s1', 'ep-remote');
      // Rewrite the config the way a hand-edit or an older build could leave
      // it: pinned at a route the source no longer has.
      await notifier.updateSource(
        notifier.state.sources.single.copyWith(
          pinnedEndpointId: 'ep-gone',
        ),
      );

      final reloaded = SourcesNotifier(storage, db: _SpyDb());
      await reloaded.ready;

      final src = reloaded.state.sources.single;
      expect(src.endpointSelection, EndpointSelection.auto);
      expect(src.pinnedEndpointId, isNull);
    });

    test('the connection fields are made to agree with the pin', () async {
      // Invariant: the top-level url *is* the live route. A stored config
      // where they disagree would show "已釘選 遠端" while every provider
      // talked to the LAN.
      final storage = _storageInTempDir();
      final (notifier, _) = await _seeded(storage: storage);
      await notifier.updateSource(
        notifier.state.sources.single.copyWith(
          endpointSelection: EndpointSelection.pinned,
          pinnedEndpointId: 'ep-remote',
        ),
      );
      expect(notifier.state.sources.single.liveEndpoint?.id, 'ep-lan');

      final reloaded = SourcesNotifier(storage, db: _SpyDb());
      await reloaded.ready;

      final src = reloaded.state.sources.single;
      expect(src.liveEndpoint?.id, 'ep-remote');
      expect(src.url, 'https://roms.example.org');
      expect(src.endpointSelection, EndpointSelection.pinned);
    });

    test('an auto source is left alone — startup never waits on a probe',
        () async {
      final storage = _storageInTempDir();
      final (notifier, _) = await _seeded(storage: storage);
      await notifier.switchEndpoint('s1', 'ep-remote', pin: false);

      final reloaded = SourcesNotifier(storage, db: _SpyDb());
      await reloaded.ready;

      expect(reloaded.state.sources.single.liveEndpoint?.id, 'ep-remote');
    });
  });
}

const _lanAddress = '192.168.1.50:8090';
const _remoteAddress = 'roms.example.org:443';

/// Fake connector so no test opens a socket. [down] never answers; [fast] and
/// [slow] answer far enough apart that the ranking does not depend on how busy
/// the machine is.
class _FakeNet {
  _FakeNet(this.down, {this.fast, this.slow});

  final Set<String> down;
  final String? fast;
  final String? slow;
  final asked = <String>[];

  Future<void> connect(String host, int port, Duration timeout) async {
    final address = '$host:$port';
    asked.add(address);
    if (address == slow) {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    } else if (address == fast) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    if (down.contains(address)) throw Exception('down');
  }
}

EndpointProbeService _probe({
  String? fast,
  String? slow,
  Set<String> down = const {},
}) {
  final net = _FakeNet(down, fast: fast, slow: slow);
  return EndpointProbeService(connect: net.connect);
}
