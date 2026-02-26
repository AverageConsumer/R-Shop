import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retro_eshop/models/game_item.dart';
import 'package:retro_eshop/models/system_model.dart';
import 'package:retro_eshop/services/rom_manager.dart';

void main() {
  group('RomManager.extractGameName', () {
    test('removes .zip extension', () {
      expect(RomManager.extractGameName('Pokemon.zip'), 'Pokemon');
    });

    test('removes .7z extension', () {
      expect(RomManager.extractGameName('Game.7z'), 'Game');
    });

    test('removes .rar extension', () {
      expect(RomManager.extractGameName('Game.rar'), 'Game');
    });

    test('replaces special characters with underscore', () {
      expect(
        RomManager.extractGameName('Game<>:"/\\|?*Name'),
        'Game_________Name',
      );
    });

    test('collapses multiple spaces', () {
      expect(RomManager.extractGameName('Game   Name   Here'), 'Game Name Here');
    });

    test('returns null for empty name', () {
      expect(RomManager.extractGameName('.zip'), isNull);
    });

    test('returns name without extension unchanged', () {
      expect(RomManager.extractGameName('Pokemon Emerald (USA)'),
          'Pokemon Emerald (USA)');
    });

    test('case-insensitive extension matching', () {
      expect(RomManager.extractGameName('Game.ZIP'), 'Game');
      expect(RomManager.extractGameName('Game.Rar'), 'Game');
    });
  });

  group('RomManager.safePath', () {
    test('normal filename returns baseDir/filename', () {
      expect(
        RomManager.safePath('/roms/gba', 'pokemon.gba'),
        '/roms/gba/pokemon.gba',
      );
    });

    test('path traversal is stripped to basename', () {
      // safePath uses p.basename(), so traversal becomes just the filename
      expect(
        RomManager.safePath('/roms/gba', '../../etc/passwd'),
        '/roms/gba/passwd',
      );
    });

    test('empty filename throws', () {
      expect(
        () => RomManager.safePath('/roms/gba', ''),
        throwsA(isA<Exception>()),
      );
    });

    test('"." throws', () {
      expect(
        () => RomManager.safePath('/roms/gba', '.'),
        throwsA(isA<Exception>()),
      );
    });

    test('".." throws', () {
      expect(
        () => RomManager.safePath('/roms/gba', '..'),
        throwsA(isA<Exception>()),
      );
    });

    test('nested path is flattened to basename', () {
      expect(
        RomManager.safePath('/roms/gba', 'subdir/game.gba'),
        '/roms/gba/game.gba',
      );
    });
  });

  group('RomManager filesystem operations', () {
    late Directory tempDir;
    late RomManager romManager;
    const testSystem = SystemModel(
      id: 'gba',
      name: 'Game Boy Advance',
      manufacturer: 'Nintendo',
      releaseYear: 2001,
      romExtensions: ['.gba'],
      accentColor: Color(0xFF4CAF50),
    );

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('rom_manager_test_');
      romManager = RomManager();
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('scanLocalGames finds .gba files', () async {
      File('${tempDir.path}/pokemon.gba').writeAsStringSync('rom data');
      File('${tempDir.path}/zelda.gba').writeAsStringSync('rom data');

      final games = await RomManager.scanLocalGames(testSystem, tempDir.path);
      expect(games.length, 2);
      expect(games.map((g) => g.filename), containsAll(['pokemon.gba', 'zelda.gba']));
    });

    test('scanLocalGames finds archive files', () async {
      File('${tempDir.path}/game.zip').writeAsStringSync('archive');
      File('${tempDir.path}/game2.7z').writeAsStringSync('archive');

      final games = await RomManager.scanLocalGames(testSystem, tempDir.path);
      expect(games.length, 2);
    });

    test('scanLocalGames finds ROMs in subfolders', () async {
      final subDir = Directory('${tempDir.path}/Pokemon Emerald');
      subDir.createSync();
      File('${subDir.path}/game.gba').writeAsStringSync('rom data');

      final games = await RomManager.scanLocalGames(testSystem, tempDir.path);
      expect(games.length, 1);
      expect(games.first.filename, 'Pokemon Emerald');
    });

    test('scanLocalGames returns empty for empty directory', () async {
      final games = await RomManager.scanLocalGames(testSystem, tempDir.path);
      expect(games, isEmpty);
    });

    test('scanLocalGames returns empty for non-existent directory', () async {
      final games = await RomManager.scanLocalGames(
        testSystem,
        '${tempDir.path}/does_not_exist',
      );
      expect(games, isEmpty);
    });

    test('scanLocalGames results are alphabetically sorted', () async {
      File('${tempDir.path}/zelda.gba').writeAsStringSync('rom');
      File('${tempDir.path}/advance_wars.gba').writeAsStringSync('rom');
      File('${tempDir.path}/metroid.gba').writeAsStringSync('rom');

      final games = await RomManager.scanLocalGames(testSystem, tempDir.path);
      final names = games.map((g) => g.displayName.toLowerCase()).toList();
      expect(names, orderedEquals([...names]..sort()));
    });

    test('scanLocalGames ignores non-ROM files', () async {
      File('${tempDir.path}/readme.txt').writeAsStringSync('text');
      File('${tempDir.path}/image.png').writeAsBytesSync([0x89, 0x50]);
      File('${tempDir.path}/game.gba').writeAsStringSync('rom');

      final games = await RomManager.scanLocalGames(testSystem, tempDir.path);
      expect(games.length, 1);
      expect(games.first.filename, 'game.gba');
    });

    test('exists() finds direct file', () async {
      const game = GameItem(
        filename: 'pokemon.gba',
        displayName: 'Pokemon',
        url: '',
      );
      File('${tempDir.path}/pokemon.gba').writeAsStringSync('rom');

      final result = await romManager.exists(game, testSystem, tempDir.path);
      expect(result, isTrue);
    });

    test('exists() finds subfolder with ROM', () async {
      const game = GameItem(
        filename: 'Pokemon Emerald.zip',
        displayName: 'Pokemon Emerald',
        url: '',
      );
      final subDir = Directory('${tempDir.path}/Pokemon Emerald');
      subDir.createSync();
      File('${subDir.path}/rom.gba').writeAsStringSync('rom');

      final result = await romManager.exists(game, testSystem, tempDir.path);
      expect(result, isTrue);
    });

    test('exists() returns false when not found', () async {
      const game = GameItem(
        filename: 'missing.gba',
        displayName: 'Missing',
        url: '',
      );

      final result = await romManager.exists(game, testSystem, tempDir.path);
      expect(result, isFalse);
    });

    test('delete() removes file', () async {
      const game = GameItem(
        filename: 'pokemon.gba',
        displayName: 'Pokemon',
        url: '',
      );
      final file = File('${tempDir.path}/pokemon.gba');
      file.writeAsStringSync('rom');
      expect(file.existsSync(), isTrue);

      await romManager.delete(game, testSystem, tempDir.path);
      expect(file.existsSync(), isFalse);
    });

    test('delete() removes subfolder', () async {
      const game = GameItem(
        filename: 'Multi Game.zip',
        displayName: 'Multi Game',
        url: '',
      );
      final subDir = Directory('${tempDir.path}/Multi Game');
      subDir.createSync();
      File('${subDir.path}/disc1.gba').writeAsStringSync('data');

      await romManager.delete(game, testSystem, tempDir.path);
      expect(subDir.existsSync(), isFalse);
    });
  });

  // ─── getTargetFilename edge cases ──────────────────────────────

  group('getTargetFilename edge cases', () {
    test('archive with empty romExtensions strips extension only', () {
      const noExtSystem = SystemModel(
        id: 'custom',
        name: 'Custom',
        manufacturer: 'Test',
        releaseYear: 2000,
        romExtensions: [],
        accentColor: Color(0xFF000000),
      );
      const game = GameItem(
        filename: 'Game.zip',
        displayName: 'Game',
        url: '',
      );
      // zip is stripped, but no replacement ext → just 'Game'
      expect(RomManager.getTargetFilename(game, noExtSystem), 'Game');
    });

    test('non-archive preserves original with empty romExts', () {
      const noExtSystem = SystemModel(
        id: 'custom',
        name: 'Custom',
        manufacturer: 'Test',
        releaseYear: 2000,
        romExtensions: [],
        accentColor: Color(0xFF000000),
      );
      const game = GameItem(
        filename: 'game.gba',
        displayName: 'game',
        url: '',
      );
      // Non-archive → filename unchanged
      expect(RomManager.getTargetFilename(game, noExtSystem), 'game.gba');
    });
  });

  // ─── checkMultipleExists ───────────────────────────────────────

  group('checkMultipleExists', () {
    late Directory tempDir;
    late RomManager romManager;
    const testSystem = SystemModel(
      id: 'gba',
      name: 'Game Boy Advance',
      manufacturer: 'Nintendo',
      releaseYear: 2001,
      romExtensions: ['.gba'],
      accentColor: Color(0xFF4CAF50),
    );

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('rom_manager_multi_');
      romManager = RomManager();
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('returns correct map {0: true, 1: false, 2: true}', () async {
      File('${tempDir.path}/game_a.gba').writeAsStringSync('rom');
      File('${tempDir.path}/game_c.gba').writeAsStringSync('rom');

      const variants = [
        GameItem(filename: 'game_a.gba', displayName: 'A', url: ''),
        GameItem(filename: 'game_b.gba', displayName: 'B', url: ''),
        GameItem(filename: 'game_c.gba', displayName: 'C', url: ''),
      ];

      final result =
          await romManager.checkMultipleExists(variants, testSystem, tempDir.path);

      expect(result, {0: true, 1: false, 2: true});
    });

    test('returns empty map for empty list', () async {
      final result =
          await romManager.checkMultipleExists([], testSystem, tempDir.path);
      expect(result, isEmpty);
    });

    test('all not found returns all false', () async {
      const variants = [
        GameItem(filename: 'x.gba', displayName: 'X', url: ''),
        GameItem(filename: 'y.gba', displayName: 'Y', url: ''),
      ];

      final result =
          await romManager.checkMultipleExists(variants, testSystem, tempDir.path);
      expect(result, {0: false, 1: false});
    });
  });

  // ─── getInstalledFilenames ─────────────────────────────────────

  group('getInstalledFilenames', () {
    late Directory tempDir;
    late RomManager romManager;
    const testSystem = SystemModel(
      id: 'gba',
      name: 'Game Boy Advance',
      manufacturer: 'Nintendo',
      releaseYear: 2001,
      romExtensions: ['.gba'],
      accentColor: Color(0xFF4CAF50),
    );

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('rom_manager_installed_');
      romManager = RomManager();
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('returns filenames of installed variants only', () async {
      File('${tempDir.path}/pokemon.gba').writeAsStringSync('rom');

      const variants = [
        GameItem(filename: 'pokemon.gba', displayName: 'Pokemon', url: ''),
        GameItem(filename: 'zelda.gba', displayName: 'Zelda', url: ''),
      ];

      final installed = await romManager.getInstalledFilenames(
          variants, testSystem, tempDir.path);
      expect(installed, {'pokemon.gba'});
    });

    test('returns empty set when none installed', () async {
      const variants = [
        GameItem(filename: 'missing_a.gba', displayName: 'A', url: ''),
        GameItem(filename: 'missing_b.gba', displayName: 'B', url: ''),
      ];

      final installed = await romManager.getInstalledFilenames(
          variants, testSystem, tempDir.path);
      expect(installed, isEmpty);
    });
  });

  // ─── isAnyVariantInstalled ─────────────────────────────────────

  group('isAnyVariantInstalled', () {
    late Directory tempDir;
    late RomManager romManager;
    const testSystem = SystemModel(
      id: 'gba',
      name: 'Game Boy Advance',
      manufacturer: 'Nintendo',
      releaseYear: 2001,
      romExtensions: ['.gba'],
      accentColor: Color(0xFF4CAF50),
    );

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('rom_manager_any_');
      romManager = RomManager();
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('returns true on first match', () async {
      File('${tempDir.path}/zelda.gba').writeAsStringSync('rom');

      const variants = [
        GameItem(filename: 'missing.gba', displayName: 'Missing', url: ''),
        GameItem(filename: 'zelda.gba', displayName: 'Zelda', url: ''),
      ];

      final result = await romManager.isAnyVariantInstalled(
          variants, testSystem, tempDir.path);
      expect(result, isTrue);
    });

    test('returns false when none installed', () async {
      const variants = [
        GameItem(filename: 'a.gba', displayName: 'A', url: ''),
        GameItem(filename: 'b.gba', displayName: 'B', url: ''),
      ];

      final result = await romManager.isAnyVariantInstalled(
          variants, testSystem, tempDir.path);
      expect(result, isFalse);
    });
  });

  // ─── delete edge cases ─────────────────────────────────────────

  group('delete edge cases', () {
    late Directory tempDir;
    late RomManager romManager;
    const testSystem = SystemModel(
      id: 'gba',
      name: 'Game Boy Advance',
      manufacturer: 'Nintendo',
      releaseYear: 2001,
      romExtensions: ['.gba'],
      accentColor: Color(0xFF4CAF50),
    );

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('rom_manager_del_');
      romManager = RomManager();
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('non-existent file/subfolder → no exception', () async {
      const game = GameItem(
        filename: 'does_not_exist.gba',
        displayName: 'Ghost',
        url: '',
      );

      // Should complete without throwing
      await romManager.delete(game, testSystem, tempDir.path);
    });
  });

  // ─── scanLocalGames with multiFileExtensions ───────────────────

  group('scanLocalGames with multiFileExtensions', () {
    late Directory tempDir;
    const ps1System = SystemModel(
      id: 'ps1',
      name: 'PlayStation',
      manufacturer: 'Sony',
      releaseYear: 1994,
      romExtensions: ['.chd', '.iso'],
      multiFileExtensions: ['.bin', '.cue'],
      accentColor: Color(0xFF2196F3),
    );

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('rom_manager_multi_ext_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('subfolder with .bin/.cue is detected as game', () async {
      final subDir = Directory('${tempDir.path}/Crash Bandicoot');
      subDir.createSync();
      File('${subDir.path}/game.bin').writeAsStringSync('data');
      File('${subDir.path}/game.cue').writeAsStringSync('cue sheet');

      final games = await RomManager.scanLocalGames(ps1System, tempDir.path);
      expect(games.length, 1);
      expect(games.first.filename, 'Crash Bandicoot');
    });

    test('individual .bin file without subfolder not detected (only in subDirExts)',
        () async {
      // A standalone .bin file should NOT be detected as a game
      // because .bin is only in multiFileExtensions (subDirExts), not in romExtensions
      File('${tempDir.path}/track01.bin').writeAsStringSync('data');

      final games = await RomManager.scanLocalGames(ps1System, tempDir.path);
      expect(games, isEmpty);
    });
  });
}
