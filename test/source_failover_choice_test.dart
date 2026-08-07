import 'package:flutter_test/flutter_test.dart';
import 'package:retro_eshop/models/config/source.dart';
import 'package:retro_eshop/services/source_failover.dart';

Source _src(
  String id, {
  List<String> fallbacks = const [],
  bool autoSelect = false,
  bool enabled = true,
}) =>
    Source(
      id: id,
      name: id,
      type: SourceType.romm,
      url: 'http://$id:9080',
      enabled: enabled,
      fallbackSourceIds: fallbacks,
      fallbackAutoSelect: autoSelect,
      autoMap: true,
    );

void main() {
  final lan = _src('lan', fallbacks: ['wan1', 'wan2']);
  final wan1 = _src('wan1');
  final wan2 = _src('wan2');
  final all = [lan, wan1, wan2];

  group('chooseSource multi-entry ordered mode', () {
    test('uses preferred source when it answers', () {
      final c = chooseSource(
        sources: all,
        activeSourceId: 'lan',
        reachable: const ['lan', 'wan1', 'wan2'],
      );

      expect(c.source?.id, 'lan');
      expect(c.isFallback, isFalse);
    });

    test('substitutes first reachable fallback in order when preferred is silent', () {
      final c = chooseSource(
        sources: all,
        activeSourceId: 'lan',
        reachable: const ['wan2', 'wan1'], // wan1 is probed first in ordered list
      );

      expect(c.source?.id, 'wan1');
      expect(c.preferred?.id, 'lan');
      expect(c.isFallback, isTrue);
    });

    test('skips unreachable fallback and takes next available fallback', () {
      final c = chooseSource(
        sources: all,
        activeSourceId: 'lan',
        reachable: const ['wan2'],
      );

      expect(c.source?.id, 'wan2');
      expect(c.isFallback, isTrue);
    });

    test('stays on preferred when no fallback answers', () {
      final c = chooseSource(
        sources: all,
        activeSourceId: 'lan',
        reachable: const [],
      );

      expect(c.source?.id, 'lan');
      expect(c.isFallback, isFalse);
    });
  });

  group('chooseSource auto-select mode', () {
    final lanAuto = _src('lan', fallbacks: ['wan1', 'wan2'], autoSelect: true);
    final allAuto = [lanAuto, wan1, wan2];

    test('picks first responding fallback when primary is silent', () {
      final c = chooseSource(
        sources: allAuto,
        activeSourceId: 'lan',
        reachable: const ['wan2', 'wan1'], // wan2 responded first in network probe
      );

      expect(c.source?.id, 'wan2');
      expect(c.preferred?.id, 'lan');
      expect(c.isFallback, isFalse, reason: 'isFallback is false in auto-select mode');
    });
  });
}
