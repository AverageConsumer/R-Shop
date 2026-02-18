import 'package:flutter_test/flutter_test.dart';
import 'package:retro_eshop/models/system_model.dart';
import 'package:retro_eshop/services/local_folder_matcher.dart';
import 'package:retro_eshop/services/romm_api_service.dart';

const _allSystems = SystemModel.supportedSystems;

RommPlatform _platform({
  required String slug,
  String fsSlug = '',
  String name = 'Test',
}) {
  return RommPlatform(
    id: 1,
    slug: slug,
    fsSlug: fsSlug,
    name: name,
    romCount: 0,
  );
}

void main() {
  group('LocalFolderMatcher.matchFolder', () {
    test('exact match on system.id', () {
      final result =
          LocalFolderMatcher.matchFolder('nes', _allSystems, const []);
      expect(result, 'nes');
    });

    test('exact match is case-sensitive for step 1', () {
      // 'NES' doesn't exactly match 'nes', but step 2 catches it
      final result =
          LocalFolderMatcher.matchFolder('NES', _allSystems, const []);
      expect(result, 'nes');
    });

    test('case-insensitive match on system.id', () {
      final result =
          LocalFolderMatcher.matchFolder('GBA', _allSystems, const []);
      expect(result, 'gba');
    });

    test('alias: Genesis → megadrive', () {
      final result =
          LocalFolderMatcher.matchFolder('Genesis', _allSystems, const []);
      expect(result, 'megadrive');
    });

    test('alias: PSX → psx', () {
      final result =
          LocalFolderMatcher.matchFolder('PSX', _allSystems, const []);
      expect(result, 'psx');
    });

    test('alias: PS1 → psx', () {
      final result =
          LocalFolderMatcher.matchFolder('PS1', _allSystems, const []);
      expect(result, 'psx');
    });

    test('alias: GameBoy → gb', () {
      final result =
          LocalFolderMatcher.matchFolder('GameBoy', _allSystems, const []);
      expect(result, 'gb');
    });

    test('alias: GameBoyAdvance → gba', () {
      final result = LocalFolderMatcher.matchFolder(
          'GameBoyAdvance', _allSystems, const []);
      expect(result, 'gba');
    });

    test('alias: SuperFamicom → snes', () {
      final result = LocalFolderMatcher.matchFolder(
          'SuperFamicom', _allSystems, const []);
      expect(result, 'snes');
    });

    test('alias: sfc → snes', () {
      final result =
          LocalFolderMatcher.matchFolder('sfc', _allSystems, const []);
      expect(result, 'snes');
    });

    test('alias: mame → arcade', () {
      final result =
          LocalFolderMatcher.matchFolder('mame', _allSystems, const []);
      expect(result, 'arcade');
    });

    test('alias: 3ds → n3ds', () {
      final result =
          LocalFolderMatcher.matchFolder('3ds', _allSystems, const []);
      expect(result, 'n3ds');
    });

    test('alias: GameCube → gc', () {
      final result =
          LocalFolderMatcher.matchFolder('GameCube', _allSystems, const []);
      expect(result, 'gc');
    });

    test('alias: sms → mastersystem', () {
      final result =
          LocalFolderMatcher.matchFolder('sms', _allSystems, const []);
      expect(result, 'mastersystem');
    });

    test('alias: dc → dreamcast', () {
      final result =
          LocalFolderMatcher.matchFolder('dc', _allSystems, const []);
      expect(result, 'dreamcast');
    });

    test('system.name match: Nintendo Entertainment System → nes', () {
      final result = LocalFolderMatcher.matchFolder(
          'Nintendo Entertainment System', _allSystems, const []);
      expect(result, 'nes');
    });

    test('system.name match: Game Boy Advance → gba', () {
      final result = LocalFolderMatcher.matchFolder(
          'Game Boy Advance', _allSystems, const []);
      expect(result, 'gba');
    });

    test('system.name match normalized: gameboy advance → gba', () {
      final result = LocalFolderMatcher.matchFolder(
          'gameboyadvance', _allSystems, const []);
      expect(result, 'gba');
    });

    test('RomM slug match', () {
      final platforms = [_platform(slug: 'gba', name: 'Game Boy Advance')];
      final result =
          LocalFolderMatcher.matchFolder('gba', _allSystems, platforms);
      expect(result, 'gba');
    });

    test('no match returns null', () {
      final result =
          LocalFolderMatcher.matchFolder('movies', _allSystems, const []);
      expect(result, isNull);
    });

    test('no match for random string', () {
      final result = LocalFolderMatcher.matchFolder(
          'my_random_folder_123', _allSystems, const []);
      expect(result, isNull);
    });

    test('empty folder name returns null', () {
      final result =
          LocalFolderMatcher.matchFolder('', _allSystems, const []);
      expect(result, isNull);
    });

    test('works with subset of systems', () {
      final subset = _allSystems.where((s) => s.id == 'nes').toList();
      // 'snes' shouldn't match if only nes is in the list
      final result =
          LocalFolderMatcher.matchFolder('snes', subset, const []);
      expect(result, isNull);
    });

    test('alias only matches if system is in provided list', () {
      final subset = _allSystems.where((s) => s.id == 'nes').toList();
      // 'Genesis' alias → megadrive, but megadrive not in subset
      final result =
          LocalFolderMatcher.matchFolder('Genesis', subset, const []);
      expect(result, isNull);
    });
  });
}
