import 'package:flutter_test/flutter_test.dart';
import 'package:retro_eshop/models/config/app_config.dart';
import 'package:retro_eshop/models/config/source.dart';
import 'package:retro_eshop/models/config/system_config.dart';
import 'package:retro_eshop/services/endpoint_probe_service.dart';
import 'package:retro_eshop/services/source_failover.dart';

/// Failover as the sync actually sees it: the config handed to
/// LibrarySyncService is rewritten in memory so it talks to the stand-in,
/// while nothing on disk changes. That is what lets the preferred source
/// resume by itself the moment it answers again.
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

Source _romm(String id, String host, {String? fallback}) => Source(
      id: id,
      name: id,
      type: SourceType.romm,
      url: 'http://$host:9080',
      autoMap: true,
      fallbackSourceId: fallback,
      knownPlatforms: const {'snes': 4},
    );

AppConfig _config({String? active}) => AppConfig(
      systems: const [
        SystemConfig(
          id: 'snes',
          name: 'SNES',
          targetFolder: '/roms/snes',
          providers: [],
        ),
      ],
      sources: [
        _romm('lan', 'lan.local', fallback: 'wan'),
        _romm('wan', 'wan.example.org'),
      ],
      activeSourceId: active,
    );

void main() {
  group('withEffectiveSource', () {
    test('rebuilds providers around the given source', () {
      final out = withEffectiveSource(_config(active: 'lan'), 'wan');

      expect(out.systems.single.providers.map((p) => p.sourceId), ['wan']);
    });

    test('leaves the stored preference untouched', () {
      // The whole point: nothing persists, so the LAN resumes on its own.
      final out = withEffectiveSource(_config(active: 'lan'), 'wan');

      expect(out.activeSourceId, 'lan');
    });

    test('null puts every source back in the providers list', () {
      final out = withEffectiveSource(_config(active: 'lan'), null);

      expect(out.systems.single.providers, hasLength(2));
    });
  });

  group('resolveForSync', () {
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

    test('does not probe the stand-in when the preference answers', () async {
      // Two TCP connects is already the budget; spending one that cannot
      // change the outcome is waste on a handheld.
      final net = _FakeNet({'lan.local', 'wan.example.org'});
      await resolveForSync(
        config: _config(active: 'lan'),
        probe: EndpointProbeService(connect: net.connect),
      );

      expect(net.asked, ['lan.local']);
    });

    test('syncs against the stand-in when the preference is silent', () async {
      final net = _FakeNet({'wan.example.org'});
      final r = await resolveForSync(
        config: _config(active: 'lan'),
        probe: EndpointProbeService(connect: net.connect),
      );

      expect(r.choice.isFallback, isTrue);
      expect(r.choice.preferred?.id, 'lan');
      expect(r.config.systems.single.providers.map((p) => p.sourceId), ['wan']);
      expect(r.config.activeSourceId, 'lan', reason: 'preference survives');
    });

    test('stays on the preference when neither answers', () async {
      // So the sync fails against the server the user actually chose.
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
      expect(r.config.systems.single.providers, isEmpty,
          reason: 'untouched config still has its original empty list');
    });

    test('a source with no stand-in does not probe a second time', () async {
      final net = _FakeNet(const {});
      await resolveForSync(
        config: _config(active: 'wan'),
        probe: EndpointProbeService(connect: net.connect),
      );

      expect(net.asked, ['wan.example.org']);
    });
  });
}
