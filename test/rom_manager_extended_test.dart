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
}
