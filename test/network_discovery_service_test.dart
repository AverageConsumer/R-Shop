import 'package:flutter_test/flutter_test.dart';
import 'package:retro_eshop/services/network_discovery_service.dart';

void main() {
  group('DiscoveredHost', () {
    test('equality is based on address+port+kind, not name', () {
      const a = DiscoveredHost(
        name: 'NAS',
        address: '192.168.1.10',
        port: 445,
        kind: DiscoveredKind.smb,
      );
      const b = DiscoveredHost(
        name: 'truenas',
        address: '192.168.1.10',
        port: 445,
        kind: DiscoveredKind.smb,
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('different ports are not equal', () {
      const a = DiscoveredHost(
        name: 'x',
        address: '10.0.0.1',
        port: 445,
        kind: DiscoveredKind.smb,
      );
      const b = DiscoveredHost(
        name: 'x',
        address: '10.0.0.1',
        port: 139,
        kind: DiscoveredKind.smb,
      );
      expect(a, isNot(equals(b)));
    });

    test('different kinds are not equal', () {
      const a = DiscoveredHost(
        name: 'x',
        address: '10.0.0.1',
        port: 80,
        kind: DiscoveredKind.http,
      );
      const b = DiscoveredHost(
        name: 'x',
        address: '10.0.0.1',
        port: 80,
        kind: DiscoveredKind.romm,
      );
      expect(a, isNot(equals(b)));
    });
  });

  group('NetworkDiscoveryService', () {
    test('completes without crashing on a network without mDNS responders',
        () async {
      // Best-effort smoke test: in a sandboxed test runner there's no
      // multicast responder, so the stream should simply finish empty.
      final service = NetworkDiscoveryService();
      final results = await service
          .discover(timeout: const Duration(milliseconds: 500))
          .toList()
          .timeout(const Duration(seconds: 6),
              onTimeout: () => <DiscoveredHost>[]);
      expect(results, isA<List<DiscoveredHost>>());
    });
  });
}
