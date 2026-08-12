import 'package:flutter_test/flutter_test.dart';
import 'package:retro_eshop/models/config/source.dart';
import 'package:retro_eshop/services/endpoint_probe_service.dart';

Source _romm({
  required String id,
  required String url,
}) {
  return Source(
    id: id,
    name: id,
    type: SourceType.romm,
    url: url,
    autoMap: true,
  );
}

class _FakeNet {
  _FakeNet(this.up);
  final Set<String> up;
  final asked = <String>[];

  Future<void> connect(String host, int port, Duration timeout) async {
    final address = '$host:$port';
    asked.add(address);
    if (!up.contains(address)) {
      throw const SocketFailure();
    }
  }
}

class SocketFailure implements Exception {
  const SocketFailure();
}

void main() {
  group('targetFor — where to knock', () {
    test('uses explicit port from url', () {
      final s = _romm(id: 'lan', url: 'http://192.168.1.50:8090');
      expect(
        EndpointProbeService.targetFor(s),
        const ProbeTarget('192.168.1.50', 8090),
      );
    });

    test('defaults https to 443 and http to 80', () {
      final sRemote = _romm(id: 'remote', url: 'https://roms.example.org');
      final sHttp = _romm(id: 'plain', url: 'http://plain.local');
      expect(
        EndpointProbeService.targetFor(sRemote),
        const ProbeTarget('roms.example.org', 443),
      );
      expect(
        EndpointProbeService.targetFor(sHttp),
        const ProbeTarget('plain.local', 80),
      );
    });

    test('defaults SMB to 445 and FTP to 21', () {
      final smb = Source(
        id: 'smb',
        name: 'SMB',
        type: SourceType.smb,
        host: 'nas.local',
        autoMap: true,
      );
      final ftp = Source(
        id: 'ftp',
        name: 'FTP',
        type: SourceType.ftp,
        host: 'ftp.local',
        autoMap: true,
      );

      expect(
        EndpointProbeService.targetFor(smb),
        const ProbeTarget('nas.local', 445),
      );
      expect(
        EndpointProbeService.targetFor(ftp),
        const ProbeTarget('ftp.local', 21),
      );
    });
  });

  group('reachableFor — probing source', () {
    test('returns set containing source.id when reachable', () async {
      final net = _FakeNet({'192.168.1.50:8090'});
      final probe = EndpointProbeService(connect: net.connect);
      final src = _romm(id: 'lan', url: 'http://192.168.1.50:8090');

      final res = await probe.reachableFor(src);
      expect(res, {'lan'});
    });

    test('returns empty set when unreachable', () async {
      final net = _FakeNet(const {});
      final probe = EndpointProbeService(connect: net.connect);
      final src = _romm(id: 'lan', url: 'http://192.168.1.50:8090');

      final res = await probe.reachableFor(src);
      expect(res, isEmpty);
    });

    test('local source is always reachable', () async {
      final net = _FakeNet(const {});
      final probe = EndpointProbeService(connect: net.connect);
      final local = Source(
        id: 'loc',
        name: 'Local',
        type: SourceType.local,
        autoMap: true,
      );

      final res = await probe.reachableFor(local);
      expect(res, {'loc'});
      expect(net.asked, isEmpty);
    });
  });
}
