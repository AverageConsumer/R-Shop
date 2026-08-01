import 'package:flutter_test/flutter_test.dart';
import 'package:retro_eshop/models/config/source.dart';
import 'package:retro_eshop/services/endpoint_probe_service.dart';

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

Source _romm({
  List<SourceEndpoint> endpoints = const [_lan, _remote],
  EndpointSelection selection = EndpointSelection.auto,
  String? pinned,
  String? url,
}) {
  return Source(
    id: 's1',
    name: 'RomM',
    type: SourceType.romm,
    url: url ?? endpoints.first.url,
    endpoints: endpoints,
    endpointSelection: selection,
    pinnedEndpointId: pinned,
    autoMap: true,
  );
}

/// Fake connector: succeeds only for the addresses in [up], and records every
/// address it was asked about so tests can assert what was and was not probed.
class _FakeNet {
  _FakeNet(this.up);

  final Set<String> up;
  final asked = <String>[];
  Duration delay = Duration.zero;

  Future<void> connect(String host, int port, Duration timeout) async {
    asked.add('$host:$port');
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (!up.contains('$host:$port')) {
      throw const SocketFailure();
    }
  }
}

class SocketFailure implements Exception {
  const SocketFailure();
}

void main() {
  group('targetFor — where to knock', () {
    test('uses the explicit port from a url', () {
      expect(
        EndpointProbeService.targetFor(_lan, SourceType.romm),
        const ProbeTarget('192.168.1.50', 8090),
      );
    });

    test('defaults https to 443 and http to 80', () {
      expect(
        EndpointProbeService.targetFor(_remote, SourceType.romm),
        const ProbeTarget('roms.example.org', 443),
      );
      expect(
        EndpointProbeService.targetFor(
          const SourceEndpoint(id: 'x', label: '', url: 'http://plain.local'),
          SourceType.web,
        ),
        const ProbeTarget('plain.local', 80),
      );
    });

    test('defaults SMB to 445 and FTP to 21', () {
      const smb = SourceEndpoint(id: 'x', label: '', host: 'nas.local');
      const ftp = SourceEndpoint(id: 'y', label: '', host: 'ftp.local');

      expect(
        EndpointProbeService.targetFor(smb, SourceType.smb),
        const ProbeTarget('nas.local', 445),
      );
      expect(
        EndpointProbeService.targetFor(ftp, SourceType.ftp),
        const ProbeTarget('ftp.local', 21),
      );
    });

    test('an explicit port beats the default', () {
      const smb =
          SourceEndpoint(id: 'x', label: '', host: 'nas.local', port: 4450);
      expect(
        EndpointProbeService.targetFor(smb, SourceType.smb),
        const ProbeTarget('nas.local', 4450),
      );
    });

    test('returns null for local sources and for empty addresses', () {
      expect(
        EndpointProbeService.targetFor(_lan, SourceType.local),
        isNull,
      );
      expect(
        EndpointProbeService.targetFor(
          const SourceEndpoint(id: 'x', label: ''),
          SourceType.romm,
        ),
        isNull,
      );
    });

    test('returns null for a scheme with no known default port', () {
      expect(
        EndpointProbeService.targetFor(
          const SourceEndpoint(id: 'x', label: '', url: 'gopher://old.local'),
          SourceType.web,
        ),
        isNull,
      );
    });
  });

  group('reachableFor', () {
    test('reports only the routes that answered', () async {
      final net = _FakeNet({'192.168.1.50:8090'});
      final svc = EndpointProbeService(connect: net.connect);

      expect(await svc.reachableFor(_romm()), {'ep-lan'});
    });

    test('probes every route, not just the first', () async {
      // Concurrent probing is what keeps the wall-clock at one timeout
      // instead of the sum, and it is what lets the UI show every route's
      // status at once.
      final net = _FakeNet({});
      final svc = EndpointProbeService(connect: net.connect);

      await svc.reachableFor(_romm());

      expect(net.asked, containsAll(['192.168.1.50:8090', 'roms.example.org:443']));
    });

    test('an address-less route is unreachable, never a silent winner',
        () async {
      final net = _FakeNet({});
      final svc = EndpointProbeService(connect: net.connect);
      final src = _romm(
        endpoints: const [SourceEndpoint(id: 'ep-blank', label: '空的')],
      );

      expect(await svc.reachableFor(src), isEmpty);
      expect(net.asked, isEmpty);
    });

    test('a source with no routes probes nothing', () async {
      final net = _FakeNet({'anything:1'});
      final svc = EndpointProbeService(connect: net.connect);
      final src = Source(
        id: 's1',
        name: 'local',
        type: SourceType.local,
        path: '/roms',
      );

      expect(await svc.reachableFor(src), isEmpty);
      expect(net.asked, isEmpty);
    });

    test('keeps whatever answered when the overall budget runs out', () async {
      // Failing the whole probe because one route is slow would throw away a
      // perfectly good answer from another.
      final net = _FakeNet({'192.168.1.50:8090'})
        ..delay = const Duration(milliseconds: 200);
      final svc = EndpointProbeService(
        connect: net.connect,
        overallBudget: const Duration(milliseconds: 20),
      );

      final reachable = await svc.reachableFor(_romm());

      expect(reachable, isEmpty); // nothing finished in time — but no throw
    });
  });

  group('cache', () {
    test('a second call inside the TTL does not re-probe', () async {
      final net = _FakeNet({'192.168.1.50:8090'});
      var clock = DateTime(2026, 8, 1, 12);
      final svc = EndpointProbeService(
        connect: net.connect,
        now: () => clock,
        cacheTtl: const Duration(minutes: 2),
      );

      await svc.reachableFor(_romm());
      final firstCount = net.asked.length;
      clock = clock.add(const Duration(seconds: 30));
      await svc.reachableFor(_romm());

      expect(net.asked, hasLength(firstCount));
    });

    test('re-probes once the TTL has passed', () async {
      final net = _FakeNet({'192.168.1.50:8090'});
      var clock = DateTime(2026, 8, 1, 12);
      final svc = EndpointProbeService(
        connect: net.connect,
        now: () => clock,
        cacheTtl: const Duration(minutes: 2),
      );

      await svc.reachableFor(_romm());
      final firstCount = net.asked.length;
      clock = clock.add(const Duration(minutes: 3));
      await svc.reachableFor(_romm());

      expect(net.asked.length, greaterThan(firstCount));
    });

    test('invalidate forces a re-probe — the LAN comes back when you walk in',
        () async {
      final net = _FakeNet({'192.168.1.50:8090'});
      final svc = EndpointProbeService(connect: net.connect);

      await svc.reachableFor(_romm());
      final firstCount = net.asked.length;
      svc.invalidate();
      await svc.reachableFor(_romm());

      expect(net.asked.length, greaterThan(firstCount));
    });
  });

  group('resolve', () {
    test('auto picks the reachable route even when it is not first', () async {
      final net = _FakeNet({'roms.example.org:443'});
      final svc = EndpointProbeService(connect: net.connect);

      final ep = await svc.resolve(_romm());

      expect(ep?.id, 'ep-remote');
    });

    test('auto prefers the LAN when both answer — list order is preference',
        () async {
      final net = _FakeNet({'192.168.1.50:8090', 'roms.example.org:443'});
      final svc = EndpointProbeService(connect: net.connect);

      expect((await svc.resolve(_romm()))?.id, 'ep-lan');
    });

    test('auto with nothing reachable still returns the first route',
        () async {
      // So the sync surfaces a real connection error instead of doing nothing.
      final net = _FakeNet({});
      final svc = EndpointProbeService(connect: net.connect);

      expect((await svc.resolve(_romm()))?.id, 'ep-lan');
    });

    test('pinned skips probing entirely — the answer cannot change it',
        () async {
      final net = _FakeNet({'192.168.1.50:8090'});
      final svc = EndpointProbeService(connect: net.connect);
      final src = _romm(
        selection: EndpointSelection.pinned,
        pinned: 'ep-remote',
      );

      final ep = await svc.resolve(src);

      expect(ep?.id, 'ep-remote');
      expect(net.asked, isEmpty, reason: 'pinned must not cost a probe');
    });

    test('a pin pointing at a deleted route falls back to probing', () async {
      final net = _FakeNet({'roms.example.org:443'});
      final svc = EndpointProbeService(connect: net.connect);
      final src = _romm(
        selection: EndpointSelection.pinned,
        pinned: 'ep-deleted',
      );

      expect((await svc.resolve(src))?.id, 'ep-remote');
      expect(net.asked, isNotEmpty);
    });
  });
}
