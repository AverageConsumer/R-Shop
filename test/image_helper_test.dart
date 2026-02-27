import 'package:flutter_test/flutter_test.dart';
import 'package:retro_eshop/models/system_model.dart';
import 'package:retro_eshop/utils/image_helper.dart';

final _nes = SystemModel.supportedSystems.firstWhere((s) => s.id == 'nes');
final _pico8 = SystemModel.supportedSystems.firstWhere((s) => s.id == 'pico8');

const _base = 'https://raw.githubusercontent.com/libretro-thumbnails/';

String _url(String name) =>
    '$_base${_nes.libretroId}/master/Named_Boxarts/${Uri.encodeComponent(name)}.png';

void main() {
  group('getCoverUrls', () {
    test('standard filename produces naive, region, and primary URLs', () {
      final urls = ImageHelper.getCoverUrls(_nes, ['Mario (USA, Europe).zip']);
      expect(urls, isNotEmpty);
      // naive clean: "Mario"
      expect(urls.any((u) => u.contains(Uri.encodeComponent('Mario'))), true);
      // region clean: "Mario (USA, Europe)"
      expect(
          urls.any(
              (u) => u.contains(Uri.encodeComponent('Mario (USA, Europe)'))),
          true);
      // primary region: "Mario (USA)"
      expect(
          urls.any((u) => u.contains(Uri.encodeComponent('Mario (USA)'))),
          true);
    });

    test('filename without parens adds fallback regions', () {
      final urls = ImageHelper.getCoverUrls(_nes, ['Super Mario Bros.zip']);
      expect(
          urls.any(
              (u) => u.contains(Uri.encodeComponent('Super Mario Bros (USA)'))),
          true);
      expect(
          urls.any((u) =>
              u.contains(Uri.encodeComponent('Super Mario Bros (Europe)'))),
          true);
      expect(
          urls.any((u) =>
              u.contains(Uri.encodeComponent('Super Mario Bros (Japan)'))),
          true);
    });

    test('filename with region does not add fallbacks', () {
      final urls = ImageHelper.getCoverUrls(_nes, ['Mario (USA).zip']);
      final naiveName = 'Mario';
      expect(
          urls.any(
              (u) => u.contains(Uri.encodeComponent('$naiveName (Europe)'))),
          false);
      expect(
          urls.any(
              (u) => u.contains(Uri.encodeComponent('$naiveName (Japan)'))),
          false);
    });

    test('multi-region normalizes comma spacing', () {
      final urls = ImageHelper.getCoverUrls(_nes, ['Game (USA,Europe).nes']);
      expect(
          urls.any(
              (u) => u.contains(Uri.encodeComponent('Game (USA, Europe)'))),
          true);
    });

    test('empty libretroId returns empty list', () {
      final urls = ImageHelper.getCoverUrls(_pico8, ['game.p8']);
      expect(urls, isEmpty);
    });

    test('empty filenames returns empty list', () {
      final urls = ImageHelper.getCoverUrls(_nes, []);
      expect(urls, isEmpty);
    });
  });

  group('getCoverUrlsForSingle', () {
    test('produces correct URLs for a single filename', () {
      final urls = ImageHelper.getCoverUrlsForSingle(_nes, 'Zelda (USA).nes');
      expect(urls, isNotEmpty);
      expect(urls.every((u) => u.startsWith(_base)), true);
      expect(
          urls.every((u) => u.contains(_nes.libretroId)),
          true);
    });

    test('filename without parens adds fallback regions', () {
      final urls = ImageHelper.getCoverUrlsForSingle(_nes, 'Zelda.nes');
      expect(
          urls.any((u) => u.contains(Uri.encodeComponent('Zelda (USA)'))),
          true);
    });

    test('URL-encodes special characters', () {
      final urls =
          ImageHelper.getCoverUrlsForSingle(_nes, "Kirby's Adventure (USA).nes");
      expect(
          urls.any((u) => u.contains(Uri.encodeComponent("Kirby's Adventure"))),
          true);
    });
  });

  group('name cleaning (via getCoverUrls)', () {
    test('naive clean removes all parens and brackets', () {
      final urls =
          ImageHelper.getCoverUrls(_nes, ['Game (USA) [!].nes']);
      // Naive clean "Game" should be present (region clean "Game (USA)" comes first)
      expect(urls.contains(_url('Game')), true);
    });

    test('naive clean normalizes whitespace', () {
      final urls =
          ImageHelper.getCoverUrls(_nes, ['Super  Game  (USA).nes']);
      expect(
          urls.any((u) => u.contains(Uri.encodeComponent('Super Game'))),
          true);
    });

    test('naive clean removes extension before cleanup', () {
      final urls = ImageHelper.getCoverUrls(_nes, ['Game.nes']);
      expect(urls.contains(_url('Game')), true);
    });
  });

  group('region clean (via getCoverUrls)', () {
    test('keeps first paren group only', () {
      final urls =
          ImageHelper.getCoverUrls(_nes, ['Game (USA) (Rev 1).nes']);
      expect(
          urls.any((u) => u.contains(Uri.encodeComponent('Game (USA)'))),
          true);
    });

    test('normalizes comma spacing in region', () {
      final urls =
          ImageHelper.getCoverUrls(_nes, ['Game (USA,Japan).nes']);
      expect(
          urls.any(
              (u) => u.contains(Uri.encodeComponent('Game (USA, Japan)'))),
          true);
    });

    test('no parens produces no region-clean URL', () {
      final urls = ImageHelper.getCoverUrls(_nes, ['Game.nes']);
      final regionOnlyUrls = urls.where(
          (u) => u.contains('(') && !u.contains('(USA)') &&
              !u.contains('(Europe)') && !u.contains('(Japan)'));
      expect(regionOnlyUrls, isEmpty);
    });

    test('region clean is first URL for filename with region', () {
      final urls = ImageHelper.getCoverUrls(_nes, ['Zelda (USA).nes']);
      expect(urls.first, _url('Zelda (USA)'));
    });
  });

  group('primary region (via getCoverUrls)', () {
    test('multi-region extracts first region', () {
      final urls =
          ImageHelper.getCoverUrls(_nes, ['Game (Europe,USA).nes']);
      expect(
          urls.any((u) => u.contains(Uri.encodeComponent('Game (Europe)'))),
          true);
    });

    test('single region: no separate primary URL generated', () {
      final urls =
          ImageHelper.getCoverUrls(_nes, ['Game (USA).nes']);
      // "Game (USA)" present from region clean, but no separate primary
      // (primary returns '' for single-region)
      final usaUrls = urls
          .where((u) => u.contains(Uri.encodeComponent('Game (USA)')) &&
              !u.contains(Uri.encodeComponent('Game (USA, ')))
          .toList();
      expect(usaUrls.length, 1);
    });
  });

  group('extension removal (via getCoverUrlsForSingle)', () {
    test('removes known game extensions', () {
      for (final ext in ['.nes', '.sfc', '.zip', '.gba']) {
        final urls =
            ImageHelper.getCoverUrlsForSingle(_nes, 'Game$ext');
        expect(
            urls.any((u) => u.contains(Uri.encodeComponent('Game'))),
            true,
            reason: 'Should strip $ext');
      }
    });
  });

  group('deduplication', () {
    test('no duplicate URLs in result', () {
      final urls =
          ImageHelper.getCoverUrls(_nes, ['Game (USA).nes', 'Game (USA).nes']);
      final unique = urls.toSet();
      expect(urls.length, unique.length);
    });
  });

  // =========================================================================
  // New tests for enhanced name normalization
  // =========================================================================

  group('RetroArch sanitization', () {
    test('ampersand is replaced with underscore', () {
      final urls = ImageHelper.getCoverUrlsForSingle(
          _nes, 'Sonic & Knuckles (USA).nes');
      expect(urls.contains(_url('Sonic _ Knuckles (USA)')), true);
    });

    test('asterisk and other special chars sanitized', () {
      final urls = ImageHelper.getCoverUrlsForSingle(
          _nes, 'Game*Special: Edition (USA).nes');
      // Sanitized: "Game_Special_ Edition (USA)"
      expect(
          urls.any((u) => u.contains(Uri.encodeComponent('Game_Special'))),
          true);
    });

    test('no sanitized variant when name has no special chars', () {
      final urls = ImageHelper.getCoverUrlsForSingle(
          _nes, 'Super Mario Bros (USA).nes');
      // All URLs should be distinct — no extra sanitized duplicates
      final unique = urls.toSet();
      expect(urls.length, unique.length);
    });

    test('backtick is sanitized', () {
      final urls = ImageHelper.getCoverUrlsForSingle(
          _nes, 'Game`s World (USA).nes');
      expect(
          urls.any((u) => u.contains(Uri.encodeComponent('Game_s World (USA)'))),
          true);
    });
  });

  group('article inversion', () {
    test('The is moved to end of title', () {
      final urls = ImageHelper.getCoverUrlsForSingle(
          _nes, 'The Legend of Zelda (USA).nes');
      expect(urls.contains(_url('Legend of Zelda, The (USA)')), true);
    });

    test('A is moved to end of title', () {
      final urls = ImageHelper.getCoverUrlsForSingle(
          _nes, 'A Boy and His Blob (USA).nes');
      expect(urls.contains(_url('Boy and His Blob, A (USA)')), true);
    });

    test('An is moved to end of title', () {
      final urls = ImageHelper.getCoverUrlsForSingle(
          _nes, 'An Example Game (USA).nes');
      expect(urls.contains(_url('Example Game, An (USA)')), true);
    });

    test('article inversion works on naive name without region', () {
      final urls = ImageHelper.getCoverUrlsForSingle(
          _nes, 'The Legend of Zelda (USA).nes');
      // Naive clean: "The Legend of Zelda" → inverted: "Legend of Zelda, The"
      expect(urls.contains(_url('Legend of Zelda, The')), true);
    });

    test('no inversion when article is not at start', () {
      final urls = ImageHelper.getCoverUrlsForSingle(
          _nes, 'Into The Wild (USA).nes');
      // Should NOT produce "The Wild, Into" or similar
      expect(
          urls.any((u) => u.contains(Uri.encodeComponent('The Wild, Into'))),
          false);
    });

    test('no inversion for short names matching article exactly', () {
      // "The" alone should not produce an empty inverted name
      final urls = ImageHelper.getCoverUrlsForSingle(_nes, 'The (USA).nes');
      // "The" is the complete title — no inversion possible
      expect(
          urls.every((u) => !u.contains(Uri.encodeComponent(', The'))),
          true);
    });
  });

  group('colon to hyphen', () {
    test('colon with space becomes hyphen', () {
      final urls = ImageHelper.getCoverUrlsForSingle(
          _nes, 'Castlevania: Symphony of the Night (USA).nes');
      expect(
          urls.contains(
              _url('Castlevania - Symphony of the Night (USA)')),
          true);
    });

    test('colon without space becomes hyphen with space', () {
      final urls = ImageHelper.getCoverUrlsForSingle(
          _nes, 'Game:Subtitle (USA).nes');
      expect(urls.contains(_url('Game - Subtitle (USA)')), true);
    });

    test('no colon variant when name has no colons', () {
      final urls = ImageHelper.getCoverUrlsForSingle(
          _nes, 'Simple Game (USA).nes');
      // Should not produce any extra variant
      final unique = urls.toSet();
      expect(urls.length, unique.length);
    });

    test('colon + article combined variant', () {
      final urls = ImageHelper.getCoverUrlsForSingle(
          _nes, 'The Game: Subtitle (USA).nes');
      // Should have: colonToHyphen + invertArticle combined
      expect(
          urls.contains(_url('Game - Subtitle, The (USA)')),
          true);
    });
  });

  group('extended region combinations', () {
    test('USA region adds USA, Europe variant', () {
      final urls = ImageHelper.getCoverUrlsForSingle(
          _nes, 'Game (USA).nes');
      expect(urls.contains(_url('Game (USA, Europe)')), true);
    });

    test('Europe region adds USA, Europe variant', () {
      final urls = ImageHelper.getCoverUrlsForSingle(
          _nes, 'Game (Europe).nes');
      expect(urls.contains(_url('Game (USA, Europe)')), true);
    });

    test('Japan region does not add extended variant', () {
      final urls = ImageHelper.getCoverUrlsForSingle(
          _nes, 'Game (Japan).nes');
      expect(
          urls.any(
              (u) => u.contains(Uri.encodeComponent('Game (USA, Europe)'))),
          false);
    });

    test('multi-region does not add extended variant', () {
      final urls = ImageHelper.getCoverUrlsForSingle(
          _nes, 'Game (USA, Europe).nes');
      // Already multi-region, no extended combo needed
      // Count occurrences of "USA, Europe"
      final comboUrls = urls
          .where((u) => u.contains(Uri.encodeComponent('Game (USA, Europe)')))
          .toList();
      // Should have exactly one (from region clean)
      expect(comboUrls.length, 1);
    });
  });

  group('URL ordering', () {
    test('region clean comes before naive for filename with region', () {
      final urls = ImageHelper.getCoverUrlsForSingle(
          _nes, 'Super Mario Bros (USA).nes');
      final regionIdx = urls.indexOf(_url('Super Mario Bros (USA)'));
      final naiveIdx = urls.indexOf(_url('Super Mario Bros'));
      expect(regionIdx, lessThan(naiveIdx));
    });

    test('all variants present for complex filename', () {
      final urls = ImageHelper.getCoverUrlsForSingle(
          _nes, 'The Game: Subtitle (USA).nes');
      // Region clean
      expect(urls.contains(_url('The Game: Subtitle (USA)')), true);
      // Article inverted
      expect(urls.contains(_url('Game: Subtitle, The (USA)')), true);
      // Colon to hyphen
      expect(urls.contains(_url('The Game - Subtitle (USA)')), true);
      // Both combined
      expect(urls.contains(_url('Game - Subtitle, The (USA)')), true);
      // Naive clean
      expect(urls.contains(_url('The Game: Subtitle')), true);
      // Naive article inverted
      expect(urls.contains(_url('Game: Subtitle, The')), true);
      // Naive colon to hyphen
      expect(urls.contains(_url('The Game - Subtitle')), true);
      // Naive both combined
      expect(urls.contains(_url('Game - Subtitle, The')), true);
    });
  });

  group('real-world problem cases', () {
    test('Sonic & Knuckles matches after sanitization', () {
      final urls = ImageHelper.getCoverUrlsForSingle(
          _nes, 'Sonic & Knuckles (USA).nes');
      expect(urls.contains(_url('Sonic _ Knuckles (USA)')), true);
    });

    test('The Legend of Zelda matches after article inversion', () {
      final urls = ImageHelper.getCoverUrlsForSingle(
          _nes, 'The Legend of Zelda - A Link to the Past (USA).sfc');
      expect(
          urls.contains(
              _url('Legend of Zelda - A Link to the Past, The (USA)')),
          true);
    });

    test('Castlevania: Symphony matches after colon transform', () {
      final urls = ImageHelper.getCoverUrlsForSingle(
          _nes, 'Castlevania: Symphony of the Night (USA).nes');
      expect(
          urls.contains(
              _url('Castlevania - Symphony of the Night (USA)')),
          true);
    });
  });
}
