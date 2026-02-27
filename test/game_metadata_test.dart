import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retro_eshop/utils/game_metadata.dart';

void main() {
  group('Region Extraction', () {
    test('Japan is correctly detected (not confused with Norway)', () {
      final testCases = [
        'Game Name (Japan).zip',
        'Game Name (J).zip',
        'Game Name (JP).zip',
        'Game Name [Japan].zip',
        'Game Name [J].zip',
        'Pokemon Emerald (Japan).gba',
        'Dragon Quest (J).nes',
      ];

      for (final filename in testCases) {
        final region = GameMetadata.extractRegion(filename);
        expect(region.name, equals('Japan'), reason: 'Failed for: $filename');
        expect(region.flag, equals('🇯🇵'));
      }
    });

    test('Norway is correctly detected', () {
      final testCases = [
        'Game Name (Norway).zip',
        'Game Name (NOR).zip',
        'Game Name [Norway].zip',
      ];

      for (final filename in testCases) {
        final region = GameMetadata.extractRegion(filename);
        expect(region.name, equals('Norway'), reason: 'Failed for: $filename');
        expect(region.flag, equals('🇳🇴'));
      }
    });

    test('USA is correctly detected', () {
      final testCases = [
        'Game Name (USA).zip',
        'Game Name (U).zip',
        'Game Name (US).zip',
        'Game Name [USA].zip',
        'Game Name [U].zip',
      ];

      for (final filename in testCases) {
        final region = GameMetadata.extractRegion(filename);
        expect(region.name, equals('USA'), reason: 'Failed for: $filename');
      }
    });

    test('Europe is correctly detected', () {
      final testCases = [
        'Game Name (Europe).zip',
        'Game Name (EUR).zip',
        'Game Name (E).zip',
        'Game Name (EU).zip',
        'Game Name [Europe].zip',
        'Game Name [EUR].zip',
      ];

      for (final filename in testCases) {
        final region = GameMetadata.extractRegion(filename);
        expect(region.name, equals('Europe'), reason: 'Failed for: $filename');
      }
    });

    test('All other regions are correctly detected', () {
      final testCases = {
        'Game (Germany).zip': 'Germany',
        'Game (DE).zip': 'Germany',
        'Game (France).zip': 'France',
        'Game (FR).zip': 'France',
        'Game (Spain).zip': 'Spain',
        'Game (ES).zip': 'Spain',
        'Game (Italy).zip': 'Italy',
        'Game (IT).zip': 'Italy',
        'Game (UK).zip': 'UK',
        'Game (Australia).zip': 'Australia',
        'Game (AU).zip': 'Australia',
        'Game (Canada).zip': 'Canada',
        'Game (CA).zip': 'Canada',
        'Game (Brazil).zip': 'Brazil',
        'Game (BR).zip': 'Brazil',
        'Game (Korea).zip': 'Korea',
        'Game (KR).zip': 'Korea',
        'Game (China).zip': 'China',
        'Game (CN).zip': 'China',
        'Game (Taiwan).zip': 'Taiwan',
        'Game (TW).zip': 'Taiwan',
        'Game (Hong Kong).zip': 'Hong Kong',
        'Game (HK).zip': 'Hong Kong',
        'Game (Sweden).zip': 'Sweden',
        'Game (SWE).zip': 'Sweden',
        'Game (Denmark).zip': 'Denmark',
        'Game (DK).zip': 'Denmark',
        'Game (Finland).zip': 'Finland',
        'Game (FI).zip': 'Finland',
        'Game (Netherlands).zip': 'Netherlands',
        'Game (NL).zip': 'Netherlands',
        'Game (World).zip': 'World',
      };

      testCases.forEach((filename, expectedRegion) {
        final region = GameMetadata.extractRegion(filename);
        expect(region.name, equals(expectedRegion),
            reason: 'Failed for: $filename');
      });
    });

    test('Unknown region returns Unknown', () {
      final region = GameMetadata.extractRegion('Game Name.zip');
      expect(region.name, equals('Unknown'));
    });

    test('Priority: Japan checked before ambiguous codes', () {
      const filename = 'Game (Japan) (No).zip';
      final region = GameMetadata.extractRegion(filename);
      expect(region.name, equals('Japan'));
    });
  });

  group('Language Extraction', () {
    test('Japanese language is detected', () {
      final languages = GameMetadata.extractLanguages('Game (Ja).zip');
      expect(languages.any((l) => l.code == 'Ja'), isTrue);
    });

    test('Multiple languages are detected', () {
      final languages = GameMetadata.extractLanguages('Game (En,Ja,Fr).zip');
      expect(languages.any((l) => l.code == 'En'), isTrue);
      expect(languages.any((l) => l.code == 'Ja'), isTrue);
      expect(languages.any((l) => l.code == 'Fr'), isTrue);
    });

    test('Norwegian language is detected', () {
      final languages = GameMetadata.extractLanguages('Game (No).zip');
      expect(languages.any((l) => l.code == 'No'), isTrue);
    });

    test('Default language based on Japan region', () {
      final languages = GameMetadata.extractLanguages('Game (Japan).zip');
      expect(languages.any((l) => l.code == 'Ja'), isTrue);
    });

    test('Default language based on USA region', () {
      final languages = GameMetadata.extractLanguages('Game (USA).zip');
      expect(languages.any((l) => l.code == 'En'), isTrue);
    });
  });

  group('Tag Extraction', () {
    test('All parentheses and brackets are extracted', () {
      final meta =
          GameMetadata.parse('Game (USA) (Beta 1) (SGB Enhanced) [b1].zip');

      expect(meta.allTags.length, equals(4));
      expect(meta.allTags.any((t) => t.raw == '(USA)'), isTrue);
      expect(meta.allTags.any((t) => t.raw == '(Beta 1)'), isTrue);
      expect(meta.allTags.any((t) => t.raw == '(SGB Enhanced)'), isTrue);
      expect(meta.allTags.any((t) => t.raw == '[b1]'), isTrue);
    });

    test('Region tags are hidden from visible tags', () {
      final meta = GameMetadata.parse('Game (USA) (Beta 1).zip');

      expect(meta.visibleTags.length, equals(1));
      expect(meta.visibleTags.first.raw, equals('(Beta 1)'));
    });

    test('Language tags are hidden from visible tags', () {
      final meta = GameMetadata.parse('Game (En,Ja) (Beta 1).zip');

      expect(meta.visibleTags.any((t) => t.raw == '(En,Ja)'), isFalse);
      expect(meta.visibleTags.any((t) => t.raw == '(Beta 1)'), isTrue);
    });

    test('Beta tag has build type', () {
      final meta = GameMetadata.parse('Game (Beta 1).zip');
      final betaTag = meta.allTags.firstWhere((t) => t.raw == '(Beta 1)');

      expect(betaTag.type, equals(TagType.build));
    });

    test('Demo tag has build type', () {
      final meta = GameMetadata.parse('Game (Demo).zip');
      final demoTag = meta.allTags.firstWhere((t) => t.raw == '(Demo)');

      expect(demoTag.type, equals(TagType.build));
    });

    test('Prototype tag has build type', () {
      final meta = GameMetadata.parse('Game (Prototype).zip');
      final protoTag = meta.allTags.firstWhere((t) => t.raw == '(Prototype)');

      expect(protoTag.type, equals(TagType.build));
    });

    test('Version tag has version type', () {
      final meta = GameMetadata.parse('Game (v1.0).zip');
      final vTag = meta.allTags.firstWhere((t) => t.raw == '(v1.0)');

      expect(vTag.type, equals(TagType.version));
    });

    test('Disc tag has disc type', () {
      final meta = GameMetadata.parse('Game (Disc 1).zip');
      final discTag = meta.allTags.firstWhere((t) => t.raw == '(Disc 1)');

      expect(discTag.type, equals(TagType.disc));
    });

    test('Quality markers have quality type', () {
      final meta = GameMetadata.parse('Game [!].zip');
      final qualityTag = meta.allTags.firstWhere((t) => t.raw == '[!]');

      expect(qualityTag.type, equals(TagType.quality));
    });

    test('Other tags have other type', () {
      final meta = GameMetadata.parse('Game (SGB Enhanced).zip');
      final otherTag =
          meta.allTags.firstWhere((t) => t.raw == '(SGB Enhanced)');

      expect(otherTag.type, equals(TagType.other));
    });

    test('Tag colors are assigned correctly', () {
      const betaTag =
          TagInfo(raw: '(Beta 1)', content: 'Beta 1', type: TagType.build);
      const versionTag =
          TagInfo(raw: '(v1.0)', content: 'v1.0', type: TagType.version);
      const discTag =
          TagInfo(raw: '(Disc 1)', content: 'Disc 1', type: TagType.disc);
      const qualityTag =
          TagInfo(raw: '[b1]', content: 'b1', type: TagType.quality);
      const secondaryTag = TagInfo(
          raw: '(trunk, 34356M)',
          content: 'trunk, 34356M',
          type: TagType.secondary);

      expect(betaTag.getColor(), equals(Colors.orange));
      expect(versionTag.getColor(), equals(Colors.blue));
      expect(discTag.getColor(), equals(Colors.purple));
      expect(qualityTag.getColor(), equals(Colors.redAccent));
      expect(secondaryTag.getColor(), equals(Colors.grey));
    });

    test('Branch patterns are secondary tags', () {
      final meta = GameMetadata.parse(
          'Game (Japan) (Beta) (branches-TPC20150716, 36474).zip');

      expect(meta.allTags.any((t) => t.raw == '(branches-TPC20150716, 36474)'),
          isTrue);
      final branchTag = meta.allTags
          .firstWhere((t) => t.raw == '(branches-TPC20150716, 36474)');
      expect(branchTag.type, equals(TagType.secondary));
    });

    test('Trunk patterns are secondary tags', () {
      final meta = GameMetadata.parse('Game (Japan) (trunk, 34356M).zip');

      final trunkTag =
          meta.allTags.firstWhere((t) => t.raw == '(trunk, 34356M)');
      expect(trunkTag.type, equals(TagType.secondary));
    });

    test('Build numbers are secondary tags', () {
      final meta = GameMetadata.parse('Game (Japan) (36474).zip');

      final buildTag = meta.allTags.firstWhere((t) => t.raw == '(36474)');
      expect(buildTag.type, equals(TagType.secondary));
    });

    test('primaryTags excludes secondary tags', () {
      final meta = GameMetadata.parse(
          'Game (Japan) (Beta) (branches-TPC20150716, 36474).zip');

      expect(meta.primaryTags.any((t) => t.type == TagType.secondary), isFalse);
      expect(meta.primaryTags.any((t) => t.raw == '(Beta)'), isTrue);
    });

    test('secondaryTags getter works', () {
      final meta = GameMetadata.parse(
          'Game (Japan) (Beta) (branches-TPC20150716, 36474).zip');

      expect(meta.secondaryTags.length, equals(1));
      expect(meta.secondaryTags.first.raw,
          equals('(branches-TPC20150716, 36474)'));
    });

    test('hasInfoDetails is true when secondary or hidden tags exist', () {
      final metaWithSecondary =
          GameMetadata.parse('Game (Japan) (trunk, 34356M).zip');
      final metaWithHidden = GameMetadata.parse('Game (USA).zip');
      final metaClean = GameMetadata.parse('Game (Beta).zip');

      expect(metaWithSecondary.hasInfoDetails, isTrue);
      expect(metaWithHidden.hasInfoDetails, isTrue);
      expect(metaClean.hasInfoDetails, isFalse);
    });
  });

  group('Title Cleaning', () {
    test('Extension is removed', () {
      expect(GameMetadata.cleanTitle('Game.zip'), equals('Game'));
      expect(GameMetadata.cleanTitle('Game.7z'), equals('Game'));
      expect(GameMetadata.cleanTitle('Game.rvz'), equals('Game'));
    });

    test('Parentheses content is removed', () {
      expect(GameMetadata.cleanTitle('Game (USA).zip'), equals('Game'));
      expect(
          GameMetadata.cleanTitle('Game (Japan) (v1.0).zip'), equals('Game'));
    });

    test('Bracket content is removed', () {
      expect(GameMetadata.cleanTitle('Game [!].zip'), equals('Game'));
      expect(GameMetadata.cleanTitle('Game [b].zip'), equals('Game'));
    });

    test('Underscores are replaced with spaces', () {
      expect(GameMetadata.cleanTitle('Game_Name.zip'), equals('Game Name'));
    });

    test('Multiple spaces are collapsed', () {
      expect(GameMetadata.cleanTitle('Game   Name.zip'), equals('Game Name'));
    });
  });

  group('File Title', () {
    test('Extension is removed', () {
      expect(GameMetadata.fileTitle('Game.zip'), equals('Game'));
      expect(GameMetadata.fileTitle('Game.7z'), equals('Game'));
      expect(GameMetadata.fileTitle('Game.rvz'), equals('Game'));
    });

    test('Tags in parentheses and brackets are preserved', () {
      expect(GameMetadata.fileTitle('Super Mario (USA).zip'),
          equals('Super Mario (USA)'));
      expect(GameMetadata.fileTitle('Game (Japan) (v1.0).zip'),
          equals('Game (Japan) (v1.0)'));
      expect(GameMetadata.fileTitle('Game [!].zip'), equals('Game [!]'));
    });

    test('Underscores are replaced with spaces', () {
      expect(GameMetadata.fileTitle('Game_Name_(USA).zip'),
          equals('Game Name (USA)'));
    });

    test('Multiple spaces are collapsed', () {
      expect(GameMetadata.fileTitle('Game   Name.zip'), equals('Game Name'));
    });

    test('Multiple variants are distinguishable', () {
      final usa = GameMetadata.fileTitle('Super Mario (USA).zip');
      final beta = GameMetadata.fileTitle('Super Mario (Beta).zip');
      final revA = GameMetadata.fileTitle('Super Mario (USA) (Rev A).zip');
      expect(usa, isNot(equals(beta)));
      expect(usa, isNot(equals(revA)));
    });
  });

  group('File Type', () {
    test('File type is correctly identified', () {
      expect(GameMetadata.getFileType('game.zip'), equals('ZIP'));
      expect(GameMetadata.getFileType('game.7z'), equals('7Z'));
      expect(GameMetadata.getFileType('game.iso'), equals('ISO'));
      expect(GameMetadata.getFileType('game.chd'), equals('CHD'));
      expect(GameMetadata.getFileType('game.3ds'), equals('3DS'));
      expect(GameMetadata.getFileType('game.nds'), equals('NDS'));
      expect(GameMetadata.getFileType('game.gba'), equals('GBA'));
      expect(GameMetadata.getFileType('game.gbc'), equals('GBC'));
      expect(GameMetadata.getFileType('game.gb'), equals('GB'));
      expect(GameMetadata.getFileType('game.sfc'), equals('SFC'));
      expect(GameMetadata.getFileType('game.z64'), equals('Z64'));
      expect(GameMetadata.getFileType('game.nsp'), equals('NSP'));
      expect(GameMetadata.getFileType('game.xci'), equals('XCI'));
      expect(GameMetadata.getFileType('game.cso'), equals('CSO'));
      expect(GameMetadata.getFileType('game.rvz'), equals('RVZ'));
    });
  });

  group('Full Parse', () {
    test('Full metadata is parsed correctly', () {
      final meta = GameMetadata.parse('Pokemon Emerald (USA) (En,Ja).zip');

      expect(meta.cleanTitle, equals('Pokemon Emerald'));
      expect(meta.region.name, equals('USA'));
      expect(meta.languages.any((l) => l.code == 'En'), isTrue);
      expect(meta.languages.any((l) => l.code == 'Ja'), isTrue);
      expect(meta.fileType, equals('ZIP'));
    });

    test('Complex filename with all tag types', () {
      final meta = GameMetadata.parse(
          'Final Fantasy VII (USA) (Disc 1 of 3) (v1.1) (Beta 2) [!] [b1].zip');

      expect(meta.cleanTitle, equals('Final Fantasy VII'));
      expect(meta.region.name, equals('USA'));
      expect(meta.allTags.length, equals(6));
      expect(meta.visibleTags.length, equals(5)); // USA is hidden
    });

    test('Japan region does not get confused with Norwegian language', () {
      final meta = GameMetadata.parse('Game (Japan).zip');

      expect(meta.region.name, equals('Japan'));
      expect(meta.region.flag, equals('🇯🇵'));
    });

    test('displayVersion shows all visible tags', () {
      final meta = GameMetadata.parse('Game (USA) (Beta 1) (SGB Enhanced).zip');

      expect(meta.displayVersion.contains('(Beta 1)'), isTrue);
      expect(meta.displayVersion.contains('(SGB Enhanced)'), isTrue);
      expect(meta.displayVersion.contains('(USA)'), isFalse);
    });

    test('displayVersion returns Standard when no visible tags', () {
      final meta = GameMetadata.parse('Game (USA).zip');

      expect(meta.displayVersion, equals('Standard'));
    });
  });

  group('Edge Cases', () {
    test('Case insensitive matching works', () {
      expect(
          GameMetadata.extractRegion('Game (japan).zip').name, equals('Japan'));
      expect(
          GameMetadata.extractRegion('Game (JAPAN).zip').name, equals('Japan'));
      expect(
          GameMetadata.extractRegion('Game (JaPaN).zip').name, equals('Japan'));
    });

    test('Mixed brackets and parentheses', () {
      final meta = GameMetadata.parse('Game [!] (USA) (v1.0).zip');
      expect(meta.region.name, equals('USA'));
      expect(meta.allTags.length, equals(3));
    });

    test('Duplicate tags are not repeated', () {
      final meta = GameMetadata.parse('Game (Beta) (Beta).zip');

      final betaTags = meta.allTags.where((t) => t.raw == '(Beta)');
      expect(betaTags.length, equals(1));
    });
  });
}
