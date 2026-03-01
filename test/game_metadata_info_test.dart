import 'package:flutter_test/flutter_test.dart';
import 'package:retro_eshop/models/game_metadata_info.dart';

void main() {
  group('GameMetadataInfo', () {
    test('hasContent returns true when summary is set', () {
      final info = GameMetadataInfo(
        filename: 'game.rom',
        systemSlug: 'nes',
        summary: 'A fun game',
        lastUpdated: 0,
      );
      expect(info.hasContent, isTrue);
    });

    test('hasContent returns true when genres is set', () {
      final info = GameMetadataInfo(
        filename: 'game.rom',
        systemSlug: 'nes',
        genres: 'Platformer',
        lastUpdated: 0,
      );
      expect(info.hasContent, isTrue);
    });

    test('hasContent returns true when developer is set', () {
      final info = GameMetadataInfo(
        filename: 'game.rom',
        systemSlug: 'nes',
        developer: 'Nintendo',
        lastUpdated: 0,
      );
      expect(info.hasContent, isTrue);
    });

    test('hasContent returns true when releaseYear is set', () {
      final info = GameMetadataInfo(
        filename: 'game.rom',
        systemSlug: 'nes',
        releaseYear: 1988,
        lastUpdated: 0,
      );
      expect(info.hasContent, isTrue);
    });

    test('hasContent returns false when all fields null', () {
      final info = GameMetadataInfo(
        filename: 'game.rom',
        systemSlug: 'nes',
        lastUpdated: 0,
      );
      expect(info.hasContent, isFalse);
    });

    test('genreList splits comma-separated genres', () {
      final info = GameMetadataInfo(
        filename: 'game.rom',
        systemSlug: 'nes',
        genres: 'Platformer, Action, Adventure',
        lastUpdated: 0,
      );
      expect(info.genreList, ['Platformer', 'Action', 'Adventure']);
    });

    test('genreList returns empty list when null', () {
      final info = GameMetadataInfo(
        filename: 'game.rom',
        systemSlug: 'nes',
        lastUpdated: 0,
      );
      expect(info.genreList, isEmpty);
    });

    test('genreList filters empty entries', () {
      final info = GameMetadataInfo(
        filename: 'game.rom',
        systemSlug: 'nes',
        genres: 'Platformer, , Action',
        lastUpdated: 0,
      );
      expect(info.genreList, ['Platformer', 'Action']);
    });

    test('gameModeList splits comma-separated modes', () {
      final info = GameMetadataInfo(
        filename: 'game.rom',
        systemSlug: 'nes',
        gameModes: 'Single Player, Multiplayer',
        lastUpdated: 0,
      );
      expect(info.gameModeList, ['Single Player', 'Multiplayer']);
    });

    test('gameModeList returns empty list when null', () {
      final info = GameMetadataInfo(
        filename: 'game.rom',
        systemSlug: 'nes',
        lastUpdated: 0,
      );
      expect(info.gameModeList, isEmpty);
    });

    test('toDbRow produces correct map', () {
      final info = GameMetadataInfo(
        filename: 'game.rom',
        systemSlug: 'nes',
        summary: 'A fun game',
        genres: 'Platformer',
        developer: 'Nintendo',
        releaseYear: 1988,
        gameModes: 'Single Player',
        rating: 85.5,
        lastUpdated: 1000,
      );
      final row = info.toDbRow();
      expect(row['filename'], 'game.rom');
      expect(row['system_slug'], 'nes');
      expect(row['summary'], 'A fun game');
      expect(row['genres'], 'Platformer');
      expect(row['developer'], 'Nintendo');
      expect(row['release_year'], 1988);
      expect(row['game_modes'], 'Single Player');
      expect(row['rating'], 85.5);
      expect(row['last_updated'], 1000);
    });

    test('fromDbRow round-trips correctly', () {
      final original = GameMetadataInfo(
        filename: 'game.rom',
        systemSlug: 'nes',
        summary: 'A fun game',
        genres: 'Platformer, Action',
        developer: 'Nintendo',
        releaseYear: 1988,
        gameModes: 'Single Player',
        rating: 85.5,
        lastUpdated: 1000,
      );
      final restored = GameMetadataInfo.fromDbRow(original.toDbRow());
      expect(restored.filename, original.filename);
      expect(restored.systemSlug, original.systemSlug);
      expect(restored.summary, original.summary);
      expect(restored.genres, original.genres);
      expect(restored.developer, original.developer);
      expect(restored.releaseYear, original.releaseYear);
      expect(restored.gameModes, original.gameModes);
      expect(restored.rating, original.rating);
      expect(restored.lastUpdated, original.lastUpdated);
    });

    test('fromDbRow handles all null optional fields', () {
      final info = GameMetadataInfo.fromDbRow({
        'filename': 'game.rom',
        'system_slug': 'nes',
        'summary': null,
        'genres': null,
        'developer': null,
        'release_year': null,
        'game_modes': null,
        'rating': null,
        'last_updated': 0,
      });
      expect(info.hasContent, isFalse);
      expect(info.summary, isNull);
      expect(info.genres, isNull);
      expect(info.developer, isNull);
      expect(info.releaseYear, isNull);
    });
  });
}
