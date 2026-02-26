import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:retro_eshop/services/rom_folder_service.dart';

void main() {
  late Directory tmpDir;
  late RomFolderService service;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('rom_folder_test_');
    service = RomFolderService();
  });

  tearDown(() {
    if (tmpDir.existsSync()) {
      tmpDir.deleteSync(recursive: true);
    }
  });

  group('FolderAnalysisResult model', () {
    test('existingFolders filters correctly', () {
      const result = FolderAnalysisResult(
        folders: [
          FolderInfo(folderName: 'nes', systemName: 'NES', exists: true, gameCount: 5, accentColor: Color(0xFFFF0000)),
          FolderInfo(folderName: 'snes', systemName: 'SNES', exists: false, gameCount: 0, accentColor: Color(0xFF00FF00)),
          FolderInfo(folderName: 'gba', systemName: 'GBA', exists: true, gameCount: 3, accentColor: Color(0xFF0000FF)),
        ],
        totalGames: 8,
        existingFoldersCount: 2,
        missingFoldersCount: 1,
      );
      final existing = result.existingFolders;
      expect(existing.length, 2);
      expect(existing.map((f) => f.folderName), ['nes', 'gba']);
    });

    test('missingFolders filters correctly', () {
      const result = FolderAnalysisResult(
        folders: [
          FolderInfo(folderName: 'nes', systemName: 'NES', exists: true, gameCount: 5, accentColor: Color(0xFFFF0000)),
          FolderInfo(folderName: 'snes', systemName: 'SNES', exists: false, gameCount: 0, accentColor: Color(0xFF00FF00)),
        ],
        totalGames: 5,
        existingFoldersCount: 1,
        missingFoldersCount: 1,
      );
      final missing = result.missingFolders;
      expect(missing.length, 1);
      expect(missing.first.folderName, 'snes');
    });

    test('totalGames aggregates correctly', () {
      const result = FolderAnalysisResult(
        folders: [],
        totalGames: 42,
        existingFoldersCount: 3,
        missingFoldersCount: 7,
      );
      expect(result.totalGames, 42);
      expect(result.existingFoldersCount, 3);
      expect(result.missingFoldersCount, 7);
    });
  });

  group('analyze', () {
    test('returns result when no system folders exist', () async {
      final result = await service.analyze(tmpDir.path);
      expect(result.existingFoldersCount, 0);
      expect(result.totalGames, 0);
      expect(result.missingFoldersCount, greaterThan(0));
      expect(result.folders, isNotEmpty);
    });

    test('counts games with valid ROM extensions', () async {
      final nesDir = Directory('${tmpDir.path}/nes')..createSync();
      File('${nesDir.path}/mario.nes').writeAsStringSync('');
      File('${nesDir.path}/zelda.nes').writeAsStringSync('');

      final result = await service.analyze(tmpDir.path);
      final nesFolder = result.folders.firstWhere((f) => f.folderName == 'nes');
      expect(nesFolder.exists, true);
      expect(nesFolder.gameCount, 2);
    });

    test('counts .zip and .7z files as games', () async {
      final nesDir = Directory('${tmpDir.path}/nes')..createSync();
      File('${nesDir.path}/game1.zip').writeAsStringSync('');
      File('${nesDir.path}/game2.7z').writeAsStringSync('');

      final result = await service.analyze(tmpDir.path);
      final nesFolder = result.folders.firstWhere((f) => f.folderName == 'nes');
      expect(nesFolder.gameCount, 2);
    });

    test('ignores non-ROM files', () async {
      final nesDir = Directory('${tmpDir.path}/nes')..createSync();
      File('${nesDir.path}/readme.txt').writeAsStringSync('');
      File('${nesDir.path}/cover.jpg').writeAsStringSync('');
      File('${nesDir.path}/game.nes').writeAsStringSync('');

      final result = await service.analyze(tmpDir.path);
      final nesFolder = result.folders.firstWhere((f) => f.folderName == 'nes');
      expect(nesFolder.gameCount, 1);
    });

    test('reports existing vs missing folder counts', () async {
      Directory('${tmpDir.path}/nes').createSync();
      Directory('${tmpDir.path}/snes').createSync();

      final result = await service.analyze(tmpDir.path);
      expect(result.existingFoldersCount, 2);
      expect(result.missingFoldersCount, result.folders.length - 2);
    });
  });

  group('scanAllSubfolders', () {
    test('returns empty list for non-existent directory', () async {
      final result = await service.scanAllSubfolders('${tmpDir.path}/nope');
      expect(result, isEmpty);
    });

    test('lists subfolders sorted alphabetically', () async {
      Directory('${tmpDir.path}/Zelda').createSync();
      Directory('${tmpDir.path}/Arcade').createSync();
      Directory('${tmpDir.path}/Mario').createSync();

      final result = await service.scanAllSubfolders(tmpDir.path);
      expect(result.map((r) => r.name).toList(), ['Arcade', 'Mario', 'Zelda']);
    });

    test('counts ROM files in each subfolder', () async {
      final nesDir = Directory('${tmpDir.path}/NES')..createSync();
      File('${nesDir.path}/game1.nes').writeAsStringSync('');
      File('${nesDir.path}/game2.zip').writeAsStringSync('');
      File('${nesDir.path}/readme.txt').writeAsStringSync('');

      final gbaDir = Directory('${tmpDir.path}/GBA')..createSync();
      File('${gbaDir.path}/game.gba').writeAsStringSync('');

      final result = await service.scanAllSubfolders(tmpDir.path);
      final nes = result.firstWhere((r) => r.name == 'NES');
      final gba = result.firstWhere((r) => r.name == 'GBA');
      expect(nes.fileCount, 2);
      expect(gba.fileCount, 1);
    });

    test('skips hidden folders', () async {
      Directory('${tmpDir.path}/.hidden').createSync();
      Directory('${tmpDir.path}/Visible').createSync();

      final result = await service.scanAllSubfolders(tmpDir.path);
      expect(result.length, 1);
      expect(result.first.name, 'Visible');
    });
  });

  group('createMissingFolders', () {
    test('creates folders that do not exist', () async {
      final created = await service.createMissingFolders(tmpDir.path);
      expect(created, isNotEmpty);
      for (final name in created) {
        expect(Directory('${tmpDir.path}/$name').existsSync(), true);
      }
    });

    test('skips folders that already exist', () async {
      // Create all system folders first
      final firstRun = await service.createMissingFolders(tmpDir.path);
      expect(firstRun, isNotEmpty);

      // Second run should create nothing
      final secondRun = await service.createMissingFolders(tmpDir.path);
      expect(secondRun, isEmpty);
    });

    test('returns list of created folder names', () async {
      // Pre-create one known folder
      Directory('${tmpDir.path}/nes').createSync();

      final created = await service.createMissingFolders(tmpDir.path);
      expect(created, isNot(contains('nes')));
      expect(created, isNotEmpty);
    });
  });
}
