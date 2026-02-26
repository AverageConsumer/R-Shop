import 'package:flutter_test/flutter_test.dart';
import 'package:retro_eshop/models/system_model.dart';
import 'package:retro_eshop/utils/image_helper.dart';

final _nes = SystemModel.supportedSystems.firstWhere((s) => s.id == 'nes');
final _pico8 = SystemModel.supportedSystems.firstWhere((s) => s.id == 'pico8');

const _base = 'https://raw.githubusercontent.com/libretro-thumbnails/';

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
      // Should contain "Super Mario Bros (USA)", "(Europe)", "(Japan)" fallbacks
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
      // Should NOT have fallback "(Europe)" or "(Japan)" appended to naive name
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
      // Region clean should normalize to "Game (USA, Europe)"
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
      // All URLs should point to NES libretro thumbnails
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
      // Apostrophe should be encoded
      expect(
          urls.any((u) => u.contains(Uri.encodeComponent("Kirby's Adventure"))),
          true);
    });
  });

  group('name cleaning (via getCoverUrls)', () {
    test('naive clean removes all parens and brackets', () {
      final urls =
          ImageHelper.getCoverUrls(_nes, ['Game (USA) [!].nes']);
      // First URL should be the naive clean name "Game"
      final naiveUrl =
          '$_base${_nes.libretroId}/master/Named_Boxarts/${Uri.encodeComponent('Game')}.png';
      expect(urls.first, naiveUrl);
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
      // Should produce "Game", not "Game.nes"
      final naiveUrl =
          '$_base${_nes.libretroId}/master/Named_Boxarts/${Uri.encodeComponent('Game')}.png';
      expect(urls.contains(naiveUrl), true);
    });
  });

  group('region clean (via getCoverUrls)', () {
    test('keeps first paren group only', () {
      final urls =
          ImageHelper.getCoverUrls(_nes, ['Game (USA) (Rev 1).nes']);
      // Region clean: "Game (USA)" — keeps first paren, strips "(Rev 1)"
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
      // Region clean returns '' for no-parens → not added
      // All URLs should be: naive "Game", raw "Game", then fallbacks
      // No URL should have parens other than the fallback region ones
      final regionOnlyUrls = urls.where(
          (u) => u.contains('(') && !u.contains('(USA)') &&
              !u.contains('(Europe)') && !u.contains('(Japan)'));
      expect(regionOnlyUrls, isEmpty);
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

    test('single region: no primary URL generated', () {
      final urls =
          ImageHelper.getCoverUrls(_nes, ['Game (USA).nes']);
      // primary region returns '' for single region → not added as separate URL
      // But "Game (USA)" still present via region clean
      final usaUrls = urls
          .where((u) => u.contains(Uri.encodeComponent('Game (USA)')))
          .toList();
      // Should have exactly one "(USA)" URL (from region clean)
      expect(usaUrls.length, 1);
    });
  });

  group('extension removal (via getCoverUrlsForSingle)', () {
    test('removes known game extensions', () {
      for (final ext in ['.nes', '.sfc', '.zip', '.gba']) {
        final urls =
            ImageHelper.getCoverUrlsForSingle(_nes, 'Game$ext');
        // raw filename URL should be "Game" (extension stripped)
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
}
