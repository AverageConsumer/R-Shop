import 'package:flutter_test/flutter_test.dart';
import 'package:retro_eshop/models/ra_models.dart';
import 'package:retro_eshop/utils/ra_name_matcher.dart';

void main() {
  group('RaNameMatcher.normalize', () {
    test('strips file extension and normalizes', () {
      expect(
        RaNameMatcher.normalize('Super Mario World (USA).sfc'),
        'super mario world',
      );
    });

    test('lowercases and collapses spaces', () {
      expect(
        RaNameMatcher.normalize('The  Legend__Of-Zelda'),
        'legend of zelda',
      );
    });

    test('removes "the" noise word', () {
      expect(
        RaNameMatcher.normalize('The Legend of Zelda'),
        'legend of zelda',
      );
    });

    test('replaces separators with spaces', () {
      expect(
        RaNameMatcher.normalize('Mega.Man-X_2'),
        'mega man x 2',
      );
    });

    test('handles empty string', () {
      expect(RaNameMatcher.normalize(''), '');
    });

    test('strips region tags', () {
      expect(
        RaNameMatcher.normalize('Donkey Kong Country (USA) (Rev 1).smc'),
        'donkey kong country',
      );
    });
  });

  group('RaNameMatcher.normalizeRomName', () {
    test('strips extension and region tags from No-Intro name', () {
      expect(
        RaNameMatcher.normalizeRomName(
            'Super Mario Bros. (World) (Rev A).nes'),
        'super mario bros',
      );
    });

    test('removes bracketed content', () {
      expect(
        RaNameMatcher.normalizeRomName('Castlevania [!].nes'),
        'castlevania',
      );
    });

    test('removes parenthesized and bracketed content together', () {
      expect(
        RaNameMatcher.normalizeRomName(
            'Final Fantasy III (USA) [T-Eng].sfc'),
        'final fantasy iii',
      );
    });
  });

  group('RaNameMatcher.levenshteinDistance', () {
    test('returns 0 for identical strings', () {
      expect(RaNameMatcher.levenshteinDistance('abc', 'abc'), 0);
    });

    test('returns length for empty vs non-empty', () {
      expect(RaNameMatcher.levenshteinDistance('', 'abc'), 3);
      expect(RaNameMatcher.levenshteinDistance('abc', ''), 3);
    });

    test('returns correct distance for simple edits', () {
      expect(RaNameMatcher.levenshteinDistance('kitten', 'sitting'), 3);
    });

    test('handles single character difference', () {
      expect(RaNameMatcher.levenshteinDistance('cat', 'bat'), 1);
    });
  });

  group('RaNameMatcher.findBestMatch', () {
    final games = [
      const RaGame(
        raGameId: 1,
        title: 'Super Mario World',
        consoleId: 3,
        numAchievements: 42,
        points: 500,
      ),
      const RaGame(
        raGameId: 2,
        title: 'Super Mario Bros.',
        consoleId: 7,
        numAchievements: 20,
        points: 200,
      ),
      const RaGame(
        raGameId: 3,
        title: 'Zelda',
        consoleId: 7,
        numAchievements: 0, // no achievements
        points: 0,
      ),
      const RaGame(
        raGameId: 4,
        title: 'Donkey Kong Country',
        consoleId: 3,
        numAchievements: 30,
        points: 350,
      ),
    ];

    test('exact match on normalized title', () {
      final result =
          RaNameMatcher.findBestMatch('Super Mario World (USA).sfc', games);
      expect(result, isNotNull);
      expect(result!.raGameId, 1);
      expect(result.type, RaMatchType.nameMatch);
      expect(result.achievementCount, 42);
    });

    test('skips games with 0 achievements', () {
      final result = RaNameMatcher.findBestMatch('Zelda.nes', games);
      expect(result, isNull);
    });

    test('contains match for partial names', () {
      final result = RaNameMatcher.findBestMatch(
          'Donkey Kong Country (USA) (Rev 1).smc', games);
      expect(result, isNotNull);
      expect(result!.raGameId, 4);
    });

    test('returns null for no match', () {
      final result =
          RaNameMatcher.findBestMatch('Totally Unknown Game.rom', games);
      expect(result, isNull);
    });

    test('returns null for empty filename', () {
      final result = RaNameMatcher.findBestMatch('', games);
      expect(result, isNull);
    });

    test('fuzzy match for close names', () {
      // "super mario wrold" is close to "super mario world" (edit distance 2)
      final result =
          RaNameMatcher.findBestMatch('Super Mario Wrold.sfc', games);
      expect(result, isNotNull);
      expect(result!.raGameId, 1);
    });

    test('ROM name match via romNames map', () {
      final romNames = {
        2: ['Super Mario Bros. (World).nes'],
      };
      final result = RaNameMatcher.findBestMatch(
        'Super Mario Bros. (World).nes',
        games,
        romNames: romNames,
      );
      expect(result, isNotNull);
      expect(result!.raGameId, 2);
    });

    test('prefers exact match over fuzzy', () {
      final result =
          RaNameMatcher.findBestMatch('Super Mario World.sfc', games);
      expect(result, isNotNull);
      expect(result!.raGameId, 1);
    });

    test('returns null for empty game list', () {
      final result =
          RaNameMatcher.findBestMatch('Super Mario World.sfc', []);
      expect(result, isNull);
    });
  });
}
