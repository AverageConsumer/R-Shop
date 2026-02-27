import 'package:flutter_test/flutter_test.dart';
import 'package:retro_eshop/models/ra_models.dart';

void main() {
  group('RaGame', () {
    test('fromJson parses all fields', () {
      final json = {
        'ID': 1234,
        'Title': 'Super Mario World',
        'ConsoleID': 3,
        'NumAchievements': 42,
        'Points': 500,
        'ImageIcon': '/Images/01234.png',
        'Hashes': ['abc123', 'def456'],
      };
      final game = RaGame.fromJson(json);
      expect(game.raGameId, 1234);
      expect(game.title, 'Super Mario World');
      expect(game.consoleId, 3);
      expect(game.numAchievements, 42);
      expect(game.points, 500);
      expect(game.imageIcon, '/Images/01234.png');
      expect(game.hashes, ['abc123', 'def456']);
    });

    test('fromJson handles missing optional fields', () {
      final json = {
        'ID': 1,
        'ConsoleID': 7,
      };
      final game = RaGame.fromJson(json);
      expect(game.title, '');
      expect(game.numAchievements, 0);
      expect(game.points, 0);
      expect(game.imageIcon, isNull);
      expect(game.hashes, isEmpty);
    });

    test('fromJson handles non-list Hashes', () {
      final json = {
        'ID': 1,
        'Title': 'Test',
        'ConsoleID': 7,
        'Hashes': 'not a list',
      };
      final game = RaGame.fromJson(json);
      expect(game.hashes, isEmpty);
    });

    test('toJson roundtrip', () {
      const game = RaGame(
        raGameId: 42,
        title: 'Test Game',
        consoleId: 3,
        numAchievements: 10,
        points: 100,
        imageIcon: '/img.png',
        hashes: ['h1', 'h2'],
      );
      final json = game.toJson();
      final restored = RaGame.fromJson(json);
      expect(restored.raGameId, game.raGameId);
      expect(restored.title, game.title);
      expect(restored.consoleId, game.consoleId);
      expect(restored.numAchievements, game.numAchievements);
      expect(restored.points, game.points);
      expect(restored.imageIcon, game.imageIcon);
      expect(restored.hashes, game.hashes);
    });
  });

  group('RaHashEntry', () {
    test('fromJson parses all fields', () {
      final json = {
        'MD5': 'abc123',
        'Name': 'SuperMario.smc',
        'Labels': ['USA', 'v1.0'],
      };
      final entry = RaHashEntry.fromJson(json);
      expect(entry.md5, 'abc123');
      expect(entry.name, 'SuperMario.smc');
      expect(entry.labels, ['USA', 'v1.0']);
    });

    test('fromJson handles missing fields', () {
      final entry = RaHashEntry.fromJson({});
      expect(entry.md5, '');
      expect(entry.name, isNull);
      expect(entry.labels, isEmpty);
    });
  });

  group('RaAchievement', () {
    test('fromJson parses all fields', () {
      final json = {
        'ID': 1,
        'Title': 'First Steps',
        'Description': 'Complete level 1',
        'Points': 10,
        'TrueRatio': 25,
        'BadgeName': '12345',
        'DisplayOrder': 1,
        'type': 'progression',
        'NumAwarded': 1000,
        'NumAwardedHardcore': 500,
        'DateEarned': '2024-01-15 12:00:00',
        'DateEarnedHardcore': '2024-01-15 13:00:00',
      };
      final ach = RaAchievement.fromJson(json);
      expect(ach.id, 1);
      expect(ach.title, 'First Steps');
      expect(ach.description, 'Complete level 1');
      expect(ach.points, 10);
      expect(ach.trueRatio, 25);
      expect(ach.badgeName, '12345');
      expect(ach.displayOrder, 1);
      expect(ach.type, 'progression');
      expect(ach.numAwarded, 1000);
      expect(ach.numAwardedHardcore, 500);
      expect(ach.isEarned, true);
      expect(ach.isEarnedHardcore, true);
    });

    test('isEarned is false when dateEarned is null', () {
      const ach = RaAchievement(id: 1, title: 'Test');
      expect(ach.isEarned, false);
      expect(ach.isEarnedHardcore, false);
    });

    test('handles empty/null date strings', () {
      final json = {
        'ID': 1,
        'Title': 'Test',
        'DateEarned': '',
        'DateEarnedHardcore': null,
      };
      final ach = RaAchievement.fromJson(json);
      expect(ach.dateEarned, isNull);
      expect(ach.dateEarnedHardcore, isNull);
    });
  });

  group('RaMatchResult', () {
    test('nameMatch constructor sets correct fields', () {
      const game = RaGame(
        raGameId: 42,
        title: 'Test',
        consoleId: 3,
        numAchievements: 10,
        points: 100,
        imageIcon: '/img.png',
      );
      final result = RaMatchResult.nameMatch(game);
      expect(result.type, RaMatchType.nameMatch);
      expect(result.raGameId, 42);
      expect(result.raTitle, 'Test');
      expect(result.achievementCount, 10);
      expect(result.points, 100);
      expect(result.imageIcon, '/img.png');
      expect(result.hasMatch, true);
      expect(result.isVerified, false);
    });

    test('hashVerified constructor', () {
      const game = RaGame(
        raGameId: 42,
        title: 'Test',
        consoleId: 3,
        numAchievements: 10,
      );
      final result = RaMatchResult.hashVerified(game);
      expect(result.type, RaMatchType.hashVerified);
      expect(result.isVerified, true);
      expect(result.hasMatch, true);
    });

    test('hashIncompatible constructor', () {
      const result = RaMatchResult.hashIncompatible(
        raGameId: 42,
        raTitle: 'Test',
      );
      expect(result.type, RaMatchType.hashIncompatible);
      expect(result.hasMatch, true);
      expect(result.isVerified, false);
    });

    test('none constructor', () {
      const result = RaMatchResult.none();
      expect(result.type, RaMatchType.none);
      expect(result.hasMatch, false);
      expect(result.raGameId, isNull);
    });

    test('JSON roundtrip', () {
      const game = RaGame(
        raGameId: 99,
        title: 'Zelda',
        consoleId: 7,
        numAchievements: 25,
        points: 300,
        imageIcon: '/z.png',
      );
      final original = RaMatchResult.nameMatch(game);
      final json = original.toJson();
      final restored = RaMatchResult.fromJson(json);
      expect(restored.type, original.type);
      expect(restored.raGameId, original.raGameId);
      expect(restored.raTitle, original.raTitle);
      expect(restored.achievementCount, original.achievementCount);
      expect(restored.points, original.points);
      expect(restored.imageIcon, original.imageIcon);
    });

    test('fromJson handles unknown type gracefully', () {
      final json = {'type': 'unknown_type'};
      final result = RaMatchResult.fromJson(json);
      expect(result.type, RaMatchType.none);
    });

    test('isMastered defaults to false', () {
      const result = RaMatchResult(type: RaMatchType.nameMatch);
      expect(result.isMastered, false);
    });

    test('isMastered can be set to true', () {
      const result = RaMatchResult(
        type: RaMatchType.hashVerified,
        isMastered: true,
      );
      expect(result.isMastered, true);
    });

    test('JSON roundtrip preserves isMastered', () {
      const original = RaMatchResult(
        type: RaMatchType.hashVerified,
        raGameId: 42,
        isMastered: true,
      );
      final json = original.toJson();
      final restored = RaMatchResult.fromJson(json);
      expect(restored.isMastered, true);
    });

    test('fromJson defaults isMastered to false when missing', () {
      final json = {'type': 'hashVerified'};
      final result = RaMatchResult.fromJson(json);
      expect(result.isMastered, false);
    });

    test('named constructors default isMastered to false', () {
      const game = RaGame(
        raGameId: 1,
        title: 'Test',
        consoleId: 3,
      );
      expect(RaMatchResult.nameMatch(game).isMastered, false);
      expect(RaMatchResult.hashVerified(game).isMastered, false);
      expect(const RaMatchResult.hashIncompatible().isMastered, false);
      expect(const RaMatchResult.none().isMastered, false);
    });
  });

  group('RaGameProgress', () {
    test('earnedCount counts earned achievements', () {
      const progress = RaGameProgress(
        raGameId: 1,
        title: 'Test',
        numAchievements: 3,
        achievements: [
          RaAchievement(
              id: 1,
              title: 'A',
              points: 5,
              dateEarned: null),
          RaAchievement(
              id: 2,
              title: 'B',
              points: 10,
              dateEarned: null),
          RaAchievement(
              id: 3,
              title: 'C',
              points: 15,
              dateEarned: null),
        ],
      );
      expect(progress.earnedCount, 0);
      expect(progress.earnedPoints, 0);
      expect(progress.completionPercent, 0.0);
      expect(progress.isCompleted, false);
    });

    test('completionPercent correct with earned achievements', () {
      final progress = RaGameProgress(
        raGameId: 1,
        title: 'Test',
        numAchievements: 2,
        points: 30,
        achievements: [
          RaAchievement(
            id: 1,
            title: 'A',
            points: 10,
            dateEarned: DateTime(2024, 1, 1),
          ),
          const RaAchievement(id: 2, title: 'B', points: 20),
        ],
      );
      expect(progress.earnedCount, 1);
      expect(progress.earnedPoints, 10);
      expect(progress.completionPercent, 0.5);
      expect(progress.isCompleted, false);
    });

    test('isCompleted when all earned', () {
      final progress = RaGameProgress(
        raGameId: 1,
        title: 'Test',
        numAchievements: 1,
        achievements: [
          RaAchievement(
            id: 1,
            title: 'A',
            points: 5,
            dateEarned: DateTime(2024, 1, 1),
          ),
        ],
      );
      expect(progress.isCompleted, true);
      expect(progress.completionPercent, 1.0);
    });

    test('completionPercent is 0 when no achievements', () {
      const progress = RaGameProgress(
        raGameId: 1,
        title: 'Test',
        numAchievements: 0,
      );
      expect(progress.completionPercent, 0.0);
      expect(progress.isCompleted, false);
    });
  });
}
