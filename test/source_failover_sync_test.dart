import 'package:flutter_test/flutter_test.dart';
import 'package:retro_eshop/models/config/app_config.dart';
import 'package:retro_eshop/models/config/source.dart';
import 'package:retro_eshop/models/config/system_config.dart';
import 'package:retro_eshop/services/endpoint_probe_service.dart';
import 'package:retro_eshop/services/source_failover.dart';

class _FakeNet {
  _FakeNet(this.up);
  final Set<String> up;
  final asked = <String>[];

  Future<void> connect(String host, int port, Duration timeout) async {
    asked.add(host);
    if (!up.contains(host)) throw const _Down();
  }
}

class _Down implements Exception {
  const _Down();
}

Source _romm(String id, String host, {List<String> fallbacks = const [], bool autoSelect = false}) => Source(
      id: id,
      name: id,
      type: SourceType.romm,
      url: 'http://$host:9080',
      autoMap: true,
      fallbackSourceIds: fallbacks,
      fallbackAutoSelect: autoSelect,
      knownPlatforms: const {'snes': 4},
    );

AppConfig _config({String? active, String? primary}) => AppConfig(
      systems: const [
        SystemConfig(
          id: 'snes',
          name: 'SNES',
          targetFolder: '/roms/snes',
          providers: [],
        ),
      ],
      sources: sources,
      activeSourceId: active,
      primarySourceId: primary,
    );

final sources = [
  _romm('lan', 'lan.local', fallbacks: ['wan']),
  _romm('wan', 'wan.example.org'),
];

void main() {
  group('withEffectiveSource', () {
    test('rebuilds providers around the given source', () {
      final out = withEffectiveSource(_config(active: 'lan'), 'wan');

      expect(out.systems.single.providers.map((p) => p.sourceId), ['wan']);
    });

    test('leaves the stored preference untouched', () {
      final out = withEffectiveSource(_config(active: 'lan'), 'wan');

      expect(out.activeSourceId, 'lan');
    });

    test('null puts every source back in the providers list', () {
      final out = withEffectiveSource(_config(active: 'lan'), null);

      expect(out.systems.single.providers, hasLength(2));
    });
  });

  group('resolveForSync — which source a sync is for', () {
    test('the one in use, not the one on screen', () async {
      final net = _FakeNet({'lan.local', 'wan.example.org'});
      final r = await resolveForSync(
        config: _config(active: 'wan', primary: 'lan'),
        probe: EndpointProbeService(connect: net.connect),
      );

      expect(r.choice.source?.id, 'lan');
      expect(r.config.systems.single.providers.map((p) => p.sourceId), ['lan']);
    });

    test('falls back to active source when primary is null', () async {
      final net = _FakeNet({'lan.local'});
      final r = await resolveForSync(
        config: _config(active: 'lan'),
        probe: EndpointProbeService(connect: net.connect),
      );

      expect(r.choice.source?.id, 'lan');
    });

    test('the stand-in covers for the one in use, not the one shown', () async {
      final net = _FakeNet({'wan.example.org'});
      final r = await resolveForSync(
        config: _config(active: 'wan', primary: 'lan'),
        probe: EndpointProbeService(connect: net.connect),
      );

      expect(r.choice.isFallback, isTrue);
      expect(r.choice.preferred?.id, 'lan');
      expect(r.config.primarySourceId, 'lan');
    });
  });

  group('resolveForSync multi-entry fallback chain', () {
    test('keeps the preferred source when it answers', () async {
      final net = _FakeNet({'lan.local', 'wan.example.org'});
      final r = await resolveForSync(
        config: _config(active: 'lan'),
        probe: EndpointProbeService(connect: net.connect),
      );

      expect(r.choice.source?.id, 'lan');
      expect(r.choice.isFallback, isFalse);
      expect(r.config.systems.single.providers.map((p) => p.sourceId), ['lan']);
    });

    test('syncs against the fallback when primary is silent', () async {
      final net = _FakeNet({'wan.example.org'});
      final r = await resolveForSync(
        config: _config(active: 'lan'),
        probe: EndpointProbeService(connect: net.connect),
      );

      expect(r.choice.isFallback, isTrue);
      expect(r.choice.preferred?.id, 'lan');
      expect(r.choice.source?.id, 'wan');
      expect(r.config.systems.single.providers.map((p) => p.sourceId), ['wan']);
    });

    test('stays on preferred when neither answers', () async {
      final net = _FakeNet(const {});
      final r = await resolveForSync(
        config: _config(active: 'lan'),
        probe: EndpointProbeService(connect: net.connect),
      );

      expect(r.config.systems.single.providers.map((p) => p.sourceId), ['lan']);
      expect(r.choice.isFallback, isFalse);
    });

    test('no selection means no probing at all', () async {
      final net = _FakeNet({'lan.local'});
      final r = await resolveForSync(
        config: _config(),
        probe: EndpointProbeService(connect: net.connect),
      );

      expect(net.asked, isEmpty);
      expect(r.choice.source, isNull);
    });
  });
}
