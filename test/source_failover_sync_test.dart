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
      // The LAN/WAN pairing is a group now. A stored config gets one on load
      // ([sourceGroupsFromFallbacks]); a config built in a test has to run the
      // same migration, because the selection path stopped reading
      // `fallbackSourceId` when groups replaced it.
      sourceGroups: sourceGroupsFromFallbacks(sources),
      activeSourceId: active,
      primarySourceId: primary,
    );

final sources = [
  _romm('lan', 'lan.local', fallback: 'wan'),
  _romm('wan', 'wan.example.org'),
];

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

  group('resolveForSync — which source a sync is for', () {
    test('the one in use, not the one on screen', () async {
      // Browsing the WAN library with the home triggers must not send the
      // next sync there. The LAN is what is in use, so the LAN is what syncs.
      final net = _FakeNet({'lan.local', 'wan.example.org'});
      final r = await resolveForSync(
        config: _config(active: 'wan', primary: 'lan'),
        probe: EndpointProbeService(connect: net.connect),
      );

      expect(r.choice.source?.id, 'lan');
      expect(r.config.systems.single.providers.map((p) => p.sourceId), ['lan']);
    });

    test('falls back to the shown source when none is designated', () async {
      // Configs written before the two were separated, and single-source
      // setups that never designate anything.
      final net = _FakeNet({'lan.local'});
      final r = await resolveForSync(
        config: _config(active: 'lan'),
        probe: EndpointProbeService(connect: net.connect),
      );

      expect(r.choice.source?.id, 'lan');
    });

    test('the stand-in covers for the one in use, not the one shown',
        () async {
      final net = _FakeNet({'wan.example.org'});
      final r = await resolveForSync(
        config: _config(active: 'wan', primary: 'lan'),
        probe: EndpointProbeService(connect: net.connect),
      );

      expect(r.choice.isFallback, isTrue);
      expect(r.choice.preferred?.id, 'lan');
      expect(r.config.primarySourceId, 'lan', reason: 'preference survives');
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

    test('a source in no group does not probe a second time', () async {
      // A grouped source races its whole group, so the one that proves this
      // has to stand alone. It used to be the WAN one: the old pairing was
      // one-way, so "the source nobody falls back from" and "the source with
      // nothing to fall back to" were the same source. A group is symmetric,
      // and both of its members probe the pair.
      final net = _FakeNet(const {});
      await resolveForSync(
        config: AppConfig(
          systems: const [
            SystemConfig(
              id: 'snes',
              name: 'SNES',
              targetFolder: '/roms/snes',
              providers: [],
            ),
          ],
          sources: [_romm('solo', 'solo.local')],
          activeSourceId: 'solo',
        ),
        probe: EndpointProbeService(connect: net.connect),
      );

      expect(net.asked, ['solo.local']);
    });
  });
}
