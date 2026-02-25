import 'package:flutter_test/flutter_test.dart';
import 'package:retro_eshop/utils/game_metadata.dart';

void main() {
  group('removeDiacritics', () {
    test('ASCII passthrough (zero alloc)', () {
      const input = 'Super Mario Bros';
      expect(GameMetadata.removeDiacritics(input), input);
    });

    test('empty string', () {
      expect(GameMetadata.removeDiacritics(''), '');
    });

    test('numbers and symbols unchanged', () {
      expect(GameMetadata.removeDiacritics('R-Type 2 [!]'), 'R-Type 2 [!]');
    });

    test('e-acute → e', () {
      expect(GameMetadata.removeDiacritics('é'), 'e');
    });

    test('u-umlaut → u', () {
      expect(GameMetadata.removeDiacritics('ü'), 'u');
    });

    test('n-tilde → n', () {
      expect(GameMetadata.removeDiacritics('ñ'), 'n');
    });

    test('Pokémon → Pokemon', () {
      expect(GameMetadata.removeDiacritics('Pokémon'), 'Pokemon');
    });

    test('mixed diacritics', () {
      expect(
        GameMetadata.removeDiacritics('À la café résumé'),
        'A la cafe resume',
      );
    });

    test('German umlauts', () {
      expect(GameMetadata.removeDiacritics('über Ärger Öl'), 'uber Arger Ol');
    });

    test('ligatures', () {
      expect(GameMetadata.removeDiacritics('Ænigma œuvre straße'),
          'AEnigma oeuvre strasse');
    });

    test('all uppercase accented', () {
      expect(GameMetadata.removeDiacritics('ÉÈÊË'), 'EEEE');
    });
  });

  group('normalizeForSearch', () {
    test('lowercases and removes diacritics', () {
      expect(GameMetadata.normalizeForSearch('Pokémon'), 'pokemon');
    });

    test('pure ASCII just lowercased', () {
      expect(GameMetadata.normalizeForSearch('MARIO'), 'mario');
    });

    test('mixed case and diacritics', () {
      expect(GameMetadata.normalizeForSearch('Ünreal Toürnament'),
          'unreal tournament');
    });
  });

  group('search integration', () {
    bool searchMatches(String query, String gameName) {
      final normalizedQuery = GameMetadata.normalizeForSearch(query);
      final normalizedName = GameMetadata.normalizeForSearch(gameName);
      return normalizedName.contains(normalizedQuery);
    }

    test('"pokemon" finds "Pokémon"', () {
      expect(searchMatches('pokemon', 'Pokémon Fire Red'), isTrue);
    });

    test('"pokémon" finds "Pokemon"', () {
      expect(searchMatches('pokémon', 'Pokemon Fire Red'), isTrue);
    });

    test('partial "poke" finds "Pokémon"', () {
      expect(searchMatches('poke', 'Pokémon'), isTrue);
    });

    test('"uber" finds "Über"', () {
      expect(searchMatches('uber', 'Über Alles'), isTrue);
    });

    test('case insensitive with diacritics', () {
      expect(searchMatches('POKEMON', 'pokémon'), isTrue);
    });

    test('no false positive', () {
      expect(searchMatches('zelda', 'Pokémon'), isFalse);
    });
  });
}
