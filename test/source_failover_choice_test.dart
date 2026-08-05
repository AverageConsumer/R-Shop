import 'package:flutter_test/flutter_test.dart';
import 'package:retro_eshop/models/config/app_config.dart';
import 'package:retro_eshop/models/config/source.dart';
import 'package:retro_eshop/services/source_failover.dart';

/// Failover between a paired internal/external source.
///
/// The rule the whole thing hangs on: **a stand-in is temporary, never a
/// change of preference.** Being away from home does not mean the user stopped
/// wanting the LAN server, so the preference survives and the LAN source
/// resumes on its own once it answers again.
///
/// The pairing itself is now expressed as a [SourceGroup]. `chooseSource` no
/// longer reads `fallbackSourceId` — reading both would be two mechanisms
/// racing over one decision — so every call here runs the same migration a
/// stored config gets on load ([sourceGroupsFromFallbacks]).
Source _src(
  String id, {
  String? fallback,
  bool enabled = true,
}) =>
    Source(
      id: id,
      name: id,
      type: SourceType.romm,
      url: 'http://$id:9080',
      enabled: enabled,
      fallbackSourceId: fallback,
      autoMap: true,
    );

void main() {
  final lan = _src('lan', fallback: 'wan');
  final wan = _src('wan');
  final all = [lan, wan];

  group('chooseSource', () {
    test('uses the preferred source when it answers', () {
      final c = chooseSource(
        sources: all,
        groups: sourceGroupsFromFallbacks(all),
        activeSourceId: 'lan',
        reachable: const ['lan', 'wan'],
      );

      expect(c.source?.id, 'lan');
      expect(c.isFallback, isFalse);
    });

    test('substitutes the fallback when the preferred one is silent', () {
      final c = chooseSource(
        sources: all,
        groups: sourceGroupsFromFallbacks(all),
        activeSourceId: 'lan',
        reachable: const ['wan'],
      );

      expect(c.source?.id, 'wan');
      expect(c.preferred?.id, 'lan', reason: 'preference must survive');
      expect(c.isFallback, isTrue);
    });

    test('the preference is untouched, so the LAN resumes by itself', () {
      // Away from home.
      final away = chooseSource(
        sources: all,
        groups: sourceGroupsFromFallbacks(all),
        activeSourceId: 'lan',
        reachable: const ['wan'],
      );
      expect(away.source?.id, 'wan');

      // Back home — nothing was reassigned, so the same call returns the LAN.
      final home = chooseSource(
        sources: all,
        groups: sourceGroupsFromFallbacks(all),
        activeSourceId: 'lan',
        reachable: const ['lan', 'wan'],
      );
      expect(home.source?.id, 'lan');
      expect(home.isFallback, isFalse);
    });

    test('stays on the preferred source when neither answers', () {
      // So the sync error names the server the user actually asked for
      // instead of sending them to debug the wrong machine.
      final c = chooseSource(
        sources: all,
        groups: sourceGroupsFromFallbacks(all),
        activeSourceId: 'lan',
        reachable: const [],
      );

      expect(c.source?.id, 'lan');
      expect(c.isFallback, isFalse);
    });

    test('a source in no group stays put', () {
      final alone = [_src('wan')];

      final c = chooseSource(
        sources: alone,
        groups: sourceGroupsFromFallbacks(alone),
        activeSourceId: 'wan',
        reachable: const [],
      );

      expect(c.source?.id, 'wan');
      expect(c.isFallback, isFalse);
    });

    test('inside a group the head is the preference, whoever was selected', () {
      // The old pairing was one-way: picking the WAN source meant picking a
      // source with no fallback of its own. A group is not one-way — the
      // members are one server — so selecting either of them selects the
      // group, and the group's own order says which comes first.
      final c = chooseSource(
        sources: all,
        groups: sourceGroupsFromFallbacks(all),
        activeSourceId: 'wan',
        reachable: const [],
      );

      expect(c.preferred?.id, 'lan');
      expect(c.source?.id, 'lan');
    });

    test('a disabled fallback is not used', () {
      final withDisabled = [lan, _src('wan', enabled: false)];

      final c = chooseSource(
        sources: withDisabled,
        groups: sourceGroupsFromFallbacks(withDisabled),
        activeSourceId: 'lan',
        reachable: const ['wan'],
      );

      expect(c.source?.id, 'lan');
      expect(c.isFallback, isFalse);
    });

    test('a dangling fallback id is ignored', () {
      final c = chooseSource(
        sources: [_src('lan', fallback: 'deleted')],
        groups: sourceGroupsFromFallbacks([_src('lan', fallback: 'deleted')]),
        activeSourceId: 'lan',
        reachable: const [],
      );

      expect(c.source?.id, 'lan');
    });

    test('a source pointing at itself does not loop', () {
      final c = chooseSource(
        sources: [_src('lan', fallback: 'lan')],
        groups: sourceGroupsFromFallbacks([_src('lan', fallback: 'lan')]),
        activeSourceId: 'lan',
        reachable: const [],
      );

      expect(c.source?.id, 'lan');
      expect(c.isFallback, isFalse);
    });

    test('no selection means no failover — everything is in view', () {
      expect(
        chooseSource(sources: all, activeSourceId: null, reachable: const [])
            .source,
        isNull,
      );
    });

    test('a deleted selection degrades to no selection', () {
      expect(
        chooseSource(
          sources: all,
          groups: sourceGroupsFromFallbacks(all),
          activeSourceId: 'removed',
          reachable: const [],
        ).source,
        isNull,
      );
    });

    test('a disabled preference is an off-switch, not an outage', () {
      // Turning a source off should not quietly hand the library to another
      // server.
      final withDisabled = [_src('lan', fallback: 'wan', enabled: false), wan];

      final c = chooseSource(
        sources: withDisabled,
        groups: sourceGroupsFromFallbacks(withDisabled),
        activeSourceId: 'lan',
        reachable: const ['wan'],
      );

      expect(c.source, isNull);
    });
  });
}
