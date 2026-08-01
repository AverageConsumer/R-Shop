import 'package:flutter_test/flutter_test.dart';
import 'package:retro_eshop/models/config/provider_config.dart';
import 'package:retro_eshop/models/config/source.dart';

/// Routes ("endpoints") let one source be reached more than one way — the
/// same RomM server over the LAN and over the internet. Exactly one route is
/// live at a time; the live route's address is mirrored onto the source's
/// connection fields, which is what everything downstream reads.
void main() {
  const lan = SourceEndpoint(
    id: 'ep-lan',
    label: '區網',
    url: 'http://192.168.1.50:8090',
  );
  const remote = SourceEndpoint(
    id: 'ep-remote',
    label: '遠端',
    url: 'https://roms.example.org',
  );

  Source rommWithRoutes({
    EndpointSelection selection = EndpointSelection.auto,
    String? pinned,
    String? url,
  }) {
    return Source(
      id: 'src-romm-1',
      name: 'My RomM',
      type: SourceType.romm,
      url: url ?? lan.url,
      auth: const AuthConfig(clientToken: 'tok', clientTokenId: 7),
      endpoints: const [lan, remote],
      endpointSelection: selection,
      pinnedEndpointId: pinned,
      autoMap: true,
      knownPlatforms: const {'snes': 4},
    );
  }

  group('backfill from a pre-routes config', () {
    test('synthesizes one route from the legacy connection fields', () {
      // A config written before routes existed: no `endpoints` key at all.
      final back = Source.fromJson({
        'id': 'src-romm-1',
        'name': 'My RomM',
        'type': 'romm',
        'url': 'http://192.168.1.50:8090',
        'auto_map': true,
      });

      expect(back.endpoints, hasLength(1));
      expect(back.endpoints.single.url, 'http://192.168.1.50:8090');
      expect(back.endpoints.single.label, 'My RomM');
      // The backfilled route must be the live one, or the source would
      // point at an address it does not list.
      expect(back.liveEndpoint?.id, back.endpoints.single.id);
      expect(back.endpointSelection, EndpointSelection.auto);
    });

    test('backfills SMB host/port/share, not just url', () {
      final back = Source.fromJson({
        'id': 'src-smb-1',
        'name': 'NAS',
        'type': 'smb',
        'host': 'nas.local',
        'port': 445,
        'share': 'roms',
      });

      expect(back.endpoints, hasLength(1));
      expect(back.endpoints.single.host, 'nas.local');
      expect(back.endpoints.single.port, 445);
      expect(back.endpoints.single.share, 'roms');
      expect(back.liveEndpoint, isNotNull);
    });

    test('leaves local sources without routes — there is nothing to reach',
        () {
      final back = Source.fromJson({
        'id': 'src-local',
        'name': 'Internal storage',
        'type': 'local',
        'path': '/storage/emulated/0/Roms',
      });

      expect(back.endpoints, isEmpty);
      expect(back.liveEndpoint, isNull);
      expect(back.resolveEndpoint(), isNull);
    });
  });

  group('serialization', () {
    test('round-trips routes, selection mode and the pin', () {
      final source = rommWithRoutes(
        selection: EndpointSelection.pinned,
        pinned: 'ep-remote',
        url: remote.url,
      );

      final back = Source.fromJson(source.toJson());

      expect(back.endpoints.map((e) => e.id), ['ep-lan', 'ep-remote']);
      expect(back.endpoints.first.label, '區網');
      expect(back.endpointSelection, EndpointSelection.pinned);
      expect(back.pinnedEndpointId, 'ep-remote');
      expect(back.liveEndpoint?.id, 'ep-remote');
    });

    test('an explicit endpoints list is not overwritten by the backfill', () {
      final source = rommWithRoutes();
      final back = Source.fromJson(source.toJson());

      expect(back.endpoints, hasLength(2));
    });

    test('toJsonWithoutAuth keeps routes but drops credentials', () {
      final json = rommWithRoutes().toJsonWithoutAuth();

      expect(json.containsKey('auth'), isFalse);
      expect(json['endpoints'], hasLength(2));
    });
  });

  group('resolveEndpoint', () {
    test('auto picks the first reachable route in list order', () {
      final source = rommWithRoutes();

      // Both up: the LAN route is listed first, so it wins — this is what
      // makes "fast at home" fall out of ordering alone.
      expect(
        source.resolveEndpoint(reachable: {'ep-lan', 'ep-remote'})?.id,
        'ep-lan',
      );
    });

    test('auto skips an unreachable earlier route', () {
      final source = rommWithRoutes();

      expect(
        source.resolveEndpoint(reachable: {'ep-remote'})?.id,
        'ep-remote',
      );
    });

    test('auto falls back to the first route when nothing answers', () {
      // Deliberate: returning null would make the sync quietly do nothing.
      // Returning a route makes it fail with a real connection error.
      final source = rommWithRoutes();

      expect(source.resolveEndpoint(reachable: const {})?.id, 'ep-lan');
    });

    test('pinned wins even when that route is unreachable', () {
      // The whole point of pinning is that the route does not move on its
      // own. A failed sync is the honest outcome here.
      final source = rommWithRoutes(
        selection: EndpointSelection.pinned,
        pinned: 'ep-remote',
      );

      expect(
        source.resolveEndpoint(reachable: {'ep-lan'})?.id,
        'ep-remote',
      );
    });

    test('a pin pointing at a deleted route degrades to auto', () {
      final source = rommWithRoutes(
        selection: EndpointSelection.pinned,
        pinned: 'ep-deleted',
      );

      expect(
        source.resolveEndpoint(reachable: {'ep-remote'})?.id,
        'ep-remote',
      );
    });
  });

  group('withLiveEndpoint', () {
    test('mirrors the route address onto the connection fields', () {
      final switched = rommWithRoutes().withLiveEndpoint(remote);

      expect(switched.url, 'https://roms.example.org');
      expect(switched.liveEndpoint?.id, 'ep-remote');
      // Downstream reads `url`, so this is what actually reroutes traffic.
      expect(switched.connectionKey, contains('roms.example.org'));
    });

    test('keeps identity, credentials and cached platforms', () {
      // Two routes to one server share one account and one library. Losing
      // either on a switch would force a re-login or a full re-sync.
      final switched = rommWithRoutes().withLiveEndpoint(remote);

      expect(switched.id, 'src-romm-1');
      expect(switched.auth?.clientToken, 'tok');
      expect(switched.knownPlatforms, {'snes': 4});
      expect(switched.endpoints, hasLength(2));
    });

    test('switching without pinning leaves auto-selection in charge', () {
      final switched = rommWithRoutes().withLiveEndpoint(remote);

      expect(switched.endpointSelection, EndpointSelection.auto);
      expect(switched.pinnedEndpointId, isNull);
    });

    test('pin: true records the route as the user\'s explicit choice', () {
      final switched = rommWithRoutes().withLiveEndpoint(remote, pin: true);

      expect(switched.endpointSelection, EndpointSelection.pinned);
      expect(switched.pinnedEndpointId, 'ep-remote');
    });

    test('SMB switch carries host, port and share together', () {
      const nasLan = SourceEndpoint(
        id: 'ep-lan',
        label: '區網',
        host: '192.168.1.20',
        port: 445,
        share: 'roms',
      );
      const nasVpn = SourceEndpoint(
        id: 'ep-vpn',
        label: 'VPN',
        host: '10.8.0.5',
        port: 4450,
        share: 'games',
      );
      final source = Source(
        id: 'src-smb-1',
        name: 'NAS',
        type: SourceType.smb,
        host: nasLan.host,
        port: nasLan.port,
        share: nasLan.share,
        endpoints: const [nasLan, nasVpn],
      );

      final switched = source.withLiveEndpoint(nasVpn);

      expect(switched.host, '10.8.0.5');
      expect(switched.port, 4450);
      expect(switched.share, 'games');
      expect(switched.liveEndpoint?.id, 'ep-vpn');
    });
  });

  group('sameAddressAs', () {
    test('ignores the label — a route is its address', () {
      const a = SourceEndpoint(id: 'a', label: '區網', url: 'http://h:1/');
      const b = SourceEndpoint(id: 'b', label: 'Home', url: 'http://h:1');

      expect(a.sameAddressAs(b), isTrue);
    });

    test('distinguishes different ports on the same host', () {
      const a = SourceEndpoint(id: 'a', label: '', host: 'nas', port: 445);
      const b = SourceEndpoint(id: 'b', label: '', host: 'nas', port: 4450);

      expect(a.sameAddressAs(b), isFalse);
    });
  });

  group('addressLabel', () {
    test('shows host and port for a url route', () {
      expect(lan.addressLabel, '192.168.1.50:8090');
    });

    test('omits the port when the url does not carry one', () {
      expect(remote.addressLabel, 'roms.example.org');
    });

    test('falls back to the label when there is no address', () {
      const bare = SourceEndpoint(id: 'x', label: '未設定');
      expect(bare.addressLabel, '未設定');
    });
  });
}
