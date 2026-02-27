import 'package:flutter_test/flutter_test.dart';
import 'package:retro_eshop/services/thumbnail_index_service.dart';

void main() {
  group('parseDirectoryListing', () {
    test('extracts .png filenames from Apache listing', () {
      const html = '''
<html><body>
<a href="Super%20Mario%20Bros.png">Super Mario Bros.png</a>
<a href="Zelda%20(USA).png">Zelda (USA).png</a>
<a href="Metroid%20(Japan).png">Metroid (Japan).png</a>
</body></html>''';
      final names = ThumbnailIndexService.parseDirectoryListing(html);
      expect(names, ['Super Mario Bros', 'Zelda (USA)', 'Metroid (Japan)']);
    });

    test('ignores non-png hrefs', () {
      const html = '''
<a href="readme.txt">readme.txt</a>
<a href="Game.png">Game.png</a>
<a href="style.css">style.css</a>''';
      final names = ThumbnailIndexService.parseDirectoryListing(html);
      expect(names, ['Game']);
    });

    test('skips directory traversal attempts', () {
      const html = '''
<a href="../parent.png">parent.png</a>
<a href="sub/child.png">child.png</a>
<a href="Valid%20Game.png">Valid Game.png</a>''';
      final names = ThumbnailIndexService.parseDirectoryListing(html);
      expect(names, ['Valid Game']);
    });

    test('skips control characters', () {
      const html = '''
<a href="Bad%00Name.png">bad</a>
<a href="Good%20Name.png">good</a>''';
      final names = ThumbnailIndexService.parseDirectoryListing(html);
      expect(names, ['Good Name']);
    });

    test('skips oversized hrefs', () {
      final longName = 'A' * 300;
      final html = '<a href="$longName.png">long</a><a href="Short.png">ok</a>';
      final names = ThumbnailIndexService.parseDirectoryListing(html);
      expect(names, ['Short']);
    });

    test('handles empty listing', () {
      const html = '<html><body><h1>Index of /</h1></body></html>';
      final names = ThumbnailIndexService.parseDirectoryListing(html);
      expect(names, isEmpty);
    });

    test('handles URL-encoded special characters', () {
      const html =
          '<a href="Kirby%27s%20Adventure%20(USA).png">Kirby</a>';
      final names = ThumbnailIndexService.parseDirectoryListing(html);
      expect(names, ["Kirby's Adventure (USA)"]);
    });
  });

  group('normalizeForMatching', () {
    test('strips region tags', () {
      expect(
          ThumbnailIndexService.normalizeForMatching('Game (USA)'), 'game');
    });

    test('strips brackets', () {
      expect(
          ThumbnailIndexService.normalizeForMatching('Game [!]'), 'game');
    });

    test('lowercases', () {
      expect(
          ThumbnailIndexService.normalizeForMatching('Super Mario'), 'super mario');
    });

    test('removes diacritics', () {
      expect(
          ThumbnailIndexService.normalizeForMatching('Pokémon'), 'pokemon');
    });

    test('sanitizes libretro special chars to space', () {
      expect(
          ThumbnailIndexService.normalizeForMatching('Sonic & Knuckles'),
          'sonic knuckles');
    });

    test('collapses whitespace', () {
      expect(
          ThumbnailIndexService.normalizeForMatching('Game  Name   Here'),
          'game name here');
    });
  });

  group('Levenshtein distance', () {
    test('identical strings → ratio 1.0', () {
      expect(ThumbnailIndexService.levenshteinRatio('hello', 'hello'), 1.0);
    });

    test('empty strings → ratio 1.0', () {
      expect(ThumbnailIndexService.levenshteinRatio('', ''), 1.0);
    });

    test('one empty string → ratio 0.0', () {
      expect(ThumbnailIndexService.levenshteinRatio('hello', ''), 0.0);
    });

    test('single character difference', () {
      final ratio = ThumbnailIndexService.levenshteinRatio('cat', 'bat');
      // Distance 1, max length 3 → ratio 2/3
      expect(ratio, closeTo(0.667, 0.001));
    });

    test('completely different strings', () {
      final ratio = ThumbnailIndexService.levenshteinRatio('abc', 'xyz');
      // Distance 3, max length 3 → ratio 0
      expect(ratio, 0.0);
    });
  });

  group('tokenSetRatio', () {
    test('identical strings → 1.0', () {
      expect(
          ThumbnailIndexService.tokenSetRatio(
              'super mario bros', 'super mario bros'),
          1.0);
    });

    test('reordered tokens still high score', () {
      final ratio = ThumbnailIndexService.tokenSetRatio(
          'mario super bros', 'super mario bros');
      expect(ratio, 1.0);
    });

    test('subset tokens produce high score', () {
      final ratio = ThumbnailIndexService.tokenSetRatio(
          'pokemon emerald', 'pokemon emerald version');
      expect(ratio, greaterThan(0.85));
    });

    test('different games with some shared tokens → moderate score', () {
      final ratio = ThumbnailIndexService.tokenSetRatio(
          'mega man x', 'mega man battle network');
      // Shares "mega man" but rest differs significantly
      expect(ratio, lessThan(0.90));
    });

    test('completely different → low score', () {
      final ratio = ThumbnailIndexService.tokenSetRatio(
          'zelda', 'metroid');
      expect(ratio, lessThan(0.5));
    });

    test('empty strings → 1.0', () {
      expect(ThumbnailIndexService.tokenSetRatio('', ''), 1.0);
    });

    test('one empty → 0.0', () {
      expect(ThumbnailIndexService.tokenSetRatio('hello', ''), 0.0);
    });
  });

  group('findBestMatch', () {
    late ThumbnailIndexService service;

    setUp(() {
      service = ThumbnailIndexService();
    });

    tearDown(() {
      service.dispose();
    });

    test('returns null when no index loaded', () {
      final match = service.findBestMatch('SomeSystem', 'Game');
      expect(match, isNull);
    });

    test('returns null for empty game name', () {
      final match = service.findBestMatch('SomeSystem', '');
      expect(match, isNull);
    });
  });

  group('buildUrl', () {
    test('constructs correct libretro-thumbnails URL', () {
      final url = ThumbnailIndexService.buildUrl(
          'Nintendo_-_NES', 'Super Mario Bros (USA)');
      expect(
          url,
          'https://raw.githubusercontent.com/libretro-thumbnails/'
          'Nintendo_-_NES/master/Named_Boxarts/'
          '${Uri.encodeComponent('Super Mario Bros (USA)')}.png');
    });

    test('encodes special characters', () {
      final url = ThumbnailIndexService.buildUrl(
          'Nintendo_-_NES', "Kirby's Adventure (USA)");
      expect(url, contains(Uri.encodeComponent("Kirby's Adventure (USA)")));
    });
  });
}
