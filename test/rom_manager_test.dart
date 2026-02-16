import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retro_eshop/models/game_item.dart';
import 'package:retro_eshop/models/system_model.dart';
import 'package:retro_eshop/services/rom_manager.dart';

void main() {
  group('RomManager.getTargetPath', () {
    late SystemModel testSystem;
    const testRomPath = '/storage/emulated/0/ROMs';

    setUp(() {
      testSystem = const SystemModel(
        name: 'Game Boy Advance',
        manufacturer: 'Nintendo',
        releaseYear: 2001,
        sourceSlug: 'No-Intro/Nintendo - Game Boy Advance',
        esdeFolder: 'gba',
        extensions: ['.zip', '.gba'],
        gridRatio: 1.0,
        romExtensions: ['.gba'],
        accentColor: Color(0xFF4CAF50),
      );
    });

    test('Archive extension is replaced with system romExtensions.first', () {
      final game = GameItem(
        filename: 'Pokemon Emerald (USA).zip',
        displayName: 'Pokemon Emerald',
        url: 'https://example.com/pokemon.zip',
      );

      final path = RomManager.getTargetPath(game, testSystem, testRomPath);

      expect(path,
          equals('/storage/emulated/0/ROMs/gba/Pokemon Emerald (USA).gba'));
    });

    test('7z archive extension is replaced', () {
      final game = GameItem(
        filename: 'Game Name (Japan).7z',
        displayName: 'Game Name',
        url: 'https://example.com/game.7z',
      );

      final path = RomManager.getTargetPath(game, testSystem, testRomPath);

      expect(
          path, equals('/storage/emulated/0/ROMs/gba/Game Name (Japan).gba'));
    });

    test('RAR archive extension is replaced', () {
      final game = GameItem(
        filename: 'Another Game.rar',
        displayName: 'Another Game',
        url: 'https://example.com/game.rar',
      );

      final path = RomManager.getTargetPath(game, testSystem, testRomPath);

      expect(path, equals('/storage/emulated/0/ROMs/gba/Another Game.gba'));
    });

    test('Non-archive extension is preserved', () {
      final game = GameItem(
        filename: 'Direct Game.gba',
        displayName: 'Direct Game',
        url: 'https://example.com/game.gba',
      );

      final path = RomManager.getTargetPath(game, testSystem, testRomPath);

      expect(path, equals('/storage/emulated/0/ROMs/gba/Direct Game.gba'));
    });

    test('ISO file extension is preserved', () {
      const ps2System = SystemModel(
        name: 'PlayStation 2',
        manufacturer: 'Sony',
        releaseYear: 2000,
        sourceSlug: 'Redump/Sony - PlayStation 2',
        esdeFolder: 'ps2',
        extensions: ['.iso', '.chd'],
        gridRatio: 1.33,
        romExtensions: ['.iso', '.chd'],
        accentColor: Color(0xFF2196F3),
      );

      final game = GameItem(
        filename: 'Final Fantasy X (USA).iso',
        displayName: 'Final Fantasy X',
        url: 'https://example.com/ffx.iso',
      );

      final path = RomManager.getTargetPath(game, ps2System, testRomPath);

      expect(path,
          equals('/storage/emulated/0/ROMs/ps2/Final Fantasy X (USA).iso'));
    });

    test('Case insensitive archive detection', () {
      final game = GameItem(
        filename: 'Game Name.ZIP',
        displayName: 'Game Name',
        url: 'https://example.com/game.ZIP',
      );

      final path = RomManager.getTargetPath(game, testSystem, testRomPath);

      expect(path, equals('/storage/emulated/0/ROMs/gba/Game Name.gba'));
    });

    test('getTargetFolder returns correct folder path', () {
      final folder = RomManager.getTargetFolder(testSystem, testRomPath);

      expect(folder, equals('/storage/emulated/0/ROMs/gba'));
    });
  });

  group('RomManager path consistency', () {
    test('Same game produces same path regardless of call location', () {
      final game = GameItem(
        filename: 'Test Game (USA).zip',
        displayName: 'Test Game',
        url: 'https://example.com/test.zip',
      );

      const system = SystemModel(
        name: 'Game Boy Advance',
        manufacturer: 'Nintendo',
        releaseYear: 2001,
        sourceSlug: 'No-Intro/Nintendo - Game Boy Advance',
        esdeFolder: 'gba',
        extensions: ['.zip', '.gba'],
        gridRatio: 1.0,
        romExtensions: ['.gba'],
        accentColor: Color(0xFF4CAF50),
      );

      const romPath = '/test/path';

      final path1 = RomManager.getTargetPath(game, system, romPath);
      final path2 = RomManager.getTargetPath(game, system, romPath);

      expect(path1, equals(path2));
      expect(path1, equals('/test/path/gba/Test Game (USA).gba'));
    });
  });
}
