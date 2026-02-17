import 'package:flutter_test/flutter_test.dart';
import 'package:retro_eshop/services/romm_api_service.dart';
import 'package:retro_eshop/services/romm_platform_matcher.dart';

RommPlatform _platform({
  required String slug,
  String fsSlug = '',
  int? igdbId,
}) {
  return RommPlatform(
    id: 1,
    slug: slug,
    fsSlug: fsSlug,
    name: 'Test',
    igdbId: igdbId,
    romCount: 0,
  );
}

void main() {
  group('findMatch', () {
    test('exact slug match', () {
      final platforms = [_platform(slug: 'gba')];
      final result = RommPlatformMatcher.findMatch('gba', platforms);
      expect(result, isNotNull);
      expect(result!.slug, 'gba');
    });

    test('exact fsSlug match', () {
      final platforms = [_platform(slug: 'other', fsSlug: 'gba')];
      final result = RommPlatformMatcher.findMatch('gba', platforms);
      expect(result, isNotNull);
      expect(result!.fsSlug, 'gba');
    });

    test('slug match takes priority over fsSlug match', () {
      final platforms = [
        _platform(slug: 'other', fsSlug: 'gba'),
        _platform(slug: 'gba'),
      ];
      final result = RommPlatformMatcher.findMatch('gba', platforms);
      expect(result!.slug, 'gba');
    });

    test('normalized match ignores case', () {
      final platforms = [_platform(slug: 'GBA')];
      final result = RommPlatformMatcher.findMatch('gba', platforms);
      expect(result, isNotNull);
    });

    test('normalized match ignores hyphens and underscores', () {
      final platforms = [_platform(slug: 'mega-drive')];
      final result = RommPlatformMatcher.findMatch('mega_drive', platforms);
      expect(result, isNotNull);
    });

    test('normalized match works on fsSlug', () {
      final platforms = [_platform(slug: 'other', fsSlug: 'Super_NES')];
      final result = RommPlatformMatcher.findMatch('supernes', platforms);
      expect(result, isNotNull);
    });

    test('IGDB ID fallback for gba', () {
      final platforms = [_platform(slug: 'game-boy-advance', igdbId: 24)];
      final result = RommPlatformMatcher.findMatch('gba', platforms);
      expect(result, isNotNull);
      expect(result!.igdbId, 24);
    });

    test('IGDB ID fallback for nes', () {
      final platforms = [_platform(slug: 'nintendo-nes', igdbId: 18)];
      final result = RommPlatformMatcher.findMatch('nes', platforms);
      expect(result, isNotNull);
    });

    test('no match returns null', () {
      final platforms = [_platform(slug: 'snes', igdbId: 19)];
      final result = RommPlatformMatcher.findMatch('atari2600', platforms);
      expect(result, isNull);
    });

    test('empty platform list returns null', () {
      final result = RommPlatformMatcher.findMatch('gba', []);
      expect(result, isNull);
    });
  });
}
