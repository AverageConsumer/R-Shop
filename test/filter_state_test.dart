import 'package:flutter_test/flutter_test.dart';
import 'package:retro_eshop/features/game_list/logic/filter_state.dart';
import 'package:retro_eshop/features/game_list/logic/game_list_controller.dart';
import 'package:retro_eshop/models/game_item.dart';
import 'package:retro_eshop/utils/game_metadata.dart';

void main() {
  // ─── ActiveFilters ─────────────────────────────────────────────

  group('ActiveFilters', () {
    group('construction', () {
      test('default is empty', () {
        const filters = ActiveFilters();
        expect(filters.selectedRegions, isEmpty);
        expect(filters.selectedLanguages, isEmpty);
        expect(filters.favoritesOnly, isFalse);
        expect(filters.localOnly, isFalse);
      });

      test('custom values preserved', () {
        const filters = ActiveFilters(
          selectedRegions: {'USA', 'Japan'},
          selectedLanguages: {'En'},
          favoritesOnly: true,
          localOnly: true,
        );
        expect(filters.selectedRegions, {'USA', 'Japan'});
        expect(filters.selectedLanguages, {'En'});
        expect(filters.favoritesOnly, isTrue);
        expect(filters.localOnly, isTrue);
      });
    });

    group('isEmpty / isNotEmpty', () {
      test('default is empty', () {
        const filters = ActiveFilters();
        expect(filters.isEmpty, isTrue);
        expect(filters.isNotEmpty, isFalse);
      });

      test('region makes it non-empty', () {
        const filters = ActiveFilters(selectedRegions: {'USA'});
        expect(filters.isEmpty, isFalse);
        expect(filters.isNotEmpty, isTrue);
      });

      test('language makes it non-empty', () {
        const filters = ActiveFilters(selectedLanguages: {'En'});
        expect(filters.isEmpty, isFalse);
      });

      test('favoritesOnly makes it non-empty', () {
        const filters = ActiveFilters(favoritesOnly: true);
        expect(filters.isEmpty, isFalse);
      });

      test('localOnly makes it non-empty', () {
        const filters = ActiveFilters(localOnly: true);
        expect(filters.isEmpty, isFalse);
      });
    });

    group('activeCount', () {
      test('0 for empty', () {
        const filters = ActiveFilters();
        expect(filters.activeCount, 0);
      });

      test('sums regions + languages + booleans', () {
        const filters = ActiveFilters(
          selectedRegions: {'USA', 'Japan'},
          selectedLanguages: {'En', 'Fr', 'De'},
          favoritesOnly: true,
          localOnly: true,
        );
        expect(filters.activeCount, 7); // 2 + 3 + 1 + 1
      });

      test('booleans false do not count', () {
        const filters = ActiveFilters(selectedRegions: {'USA'});
        expect(filters.activeCount, 1);
      });
    });

    group('toggleRegion', () {
      test('adds when absent', () {
        const filters = ActiveFilters();
        final result = filters.toggleRegion('USA');
        expect(result.selectedRegions, {'USA'});
      });

      test('removes when present', () {
        const filters = ActiveFilters(selectedRegions: {'USA', 'Japan'});
        final result = filters.toggleRegion('USA');
        expect(result.selectedRegions, {'Japan'});
      });

      test('returns new instance', () {
        const filters = ActiveFilters();
        final result = filters.toggleRegion('USA');
        expect(identical(filters, result), isFalse);
      });

      test('preserves other fields', () {
        const filters = ActiveFilters(
          favoritesOnly: true,
          localOnly: true,
        );
        final result = filters.toggleRegion('USA');
        expect(result.favoritesOnly, isTrue);
        expect(result.localOnly, isTrue);
        expect(result.selectedLanguages, isEmpty);
      });
    });

    group('toggleLanguage', () {
      test('adds when absent', () {
        const filters = ActiveFilters();
        final result = filters.toggleLanguage('En');
        expect(result.selectedLanguages, {'En'});
      });

      test('removes when present', () {
        const filters = ActiveFilters(selectedLanguages: {'En', 'Fr'});
        final result = filters.toggleLanguage('En');
        expect(result.selectedLanguages, {'Fr'});
      });

      test('preserves other fields', () {
        const filters = ActiveFilters(selectedRegions: {'USA'});
        final result = filters.toggleLanguage('En');
        expect(result.selectedRegions, {'USA'});
      });
    });

    group('toggleFavoritesOnly', () {
      test('toggles false to true', () {
        const filters = ActiveFilters();
        expect(filters.toggleFavoritesOnly().favoritesOnly, isTrue);
      });

      test('toggles true to false', () {
        const filters = ActiveFilters(favoritesOnly: true);
        expect(filters.toggleFavoritesOnly().favoritesOnly, isFalse);
      });

      test('preserves other fields', () {
        const filters = ActiveFilters(
          selectedRegions: {'USA'},
          localOnly: true,
        );
        final result = filters.toggleFavoritesOnly();
        expect(result.selectedRegions, {'USA'});
        expect(result.localOnly, isTrue);
      });
    });

    group('toggleLocalOnly', () {
      test('toggles false to true', () {
        const filters = ActiveFilters();
        expect(filters.toggleLocalOnly().localOnly, isTrue);
      });

      test('toggles true to false', () {
        const filters = ActiveFilters(localOnly: true);
        expect(filters.toggleLocalOnly().localOnly, isFalse);
      });
    });

    group('clearAll', () {
      test('resets everything', () {
        const filters = ActiveFilters(
          selectedRegions: {'USA', 'Japan'},
          selectedLanguages: {'En'},
          favoritesOnly: true,
          localOnly: true,
        );
        final cleared = filters.clearAll();
        expect(cleared.isEmpty, isTrue);
        expect(cleared.selectedRegions, isEmpty);
        expect(cleared.selectedLanguages, isEmpty);
        expect(cleared.favoritesOnly, isFalse);
        expect(cleared.localOnly, isFalse);
      });
    });
  });

  // ─── buildFilterOptions ────────────────────────────────────────

  group('buildFilterOptions', () {
    GameItem makeGame(String filename) => GameItem(
          filename: filename,
          displayName: GameItem.cleanDisplayName(filename),
          url: 'http://example.com/$filename',
        );

    Map<String, RegionInfo> regionCacheFor(List<GameItem> games) {
      return {for (final g in games) g.filename: GameMetadata.extractRegion(g.filename)};
    }

    Map<String, List<LanguageInfo>> languageCacheFor(List<GameItem> games) {
      return {for (final g in games) g.filename: GameMetadata.extractLanguages(g.filename)};
    }

    test('single group with one region', () {
      final games = [makeGame('Zelda (USA).zip')];
      final grouped = {'Zelda': games};
      final result = buildFilterOptions(
        groupedGames: grouped,
        regionCache: regionCacheFor(games),
        languageCache: languageCacheFor(games),
      );
      expect(result.regions.length, 1);
      expect(result.regions.first.id, 'USA');
      expect(result.regions.first.count, 1);
    });

    test('multi-variant group counts region once per group', () {
      final games = [
        makeGame('Zelda (USA).zip'),
        makeGame('Zelda (USA) (Rev 1).zip'),
      ];
      final grouped = {'Zelda': games};
      final result = buildFilterOptions(
        groupedGames: grouped,
        regionCache: regionCacheFor(games),
        languageCache: languageCacheFor(games),
      );
      // Both are USA in the same group -> count = 1
      expect(result.regions.length, 1);
      expect(result.regions.first.count, 1);
    });

    test('multiple groups accumulate counts', () {
      final game1 = makeGame('Zelda (USA).zip');
      final game2 = makeGame('Mario (USA).zip');
      final grouped = {
        'Zelda': [game1],
        'Mario': [game2],
      };
      final allGames = [game1, game2];
      final result = buildFilterOptions(
        groupedGames: grouped,
        regionCache: regionCacheFor(allGames),
        languageCache: languageCacheFor(allGames),
      );
      expect(result.regions.first.count, 2);
    });

    test('sorted by count descending', () {
      final game1 = makeGame('Zelda (USA).zip');
      final game2 = makeGame('Mario (USA).zip');
      final game3 = makeGame('Sonic (Japan).zip');
      final grouped = {
        'Zelda': [game1],
        'Mario': [game2],
        'Sonic': [game3],
      };
      final allGames = [game1, game2, game3];
      final result = buildFilterOptions(
        groupedGames: grouped,
        regionCache: regionCacheFor(allGames),
        languageCache: languageCacheFor(allGames),
      );
      expect(result.regions.first.id, 'USA');
      expect(result.regions.first.count, 2);
      expect(result.regions.last.id, 'Japan');
      expect(result.regions.last.count, 1);
    });

    test('Unknown regions excluded', () {
      final games = [makeGame('NoRegion.zip')];
      final grouped = {'NoRegion': games};
      final result = buildFilterOptions(
        groupedGames: grouped,
        regionCache: regionCacheFor(games),
        languageCache: languageCacheFor(games),
      );
      expect(result.regions, isEmpty);
    });

    test('empty input returns empty output', () {
      final result = buildFilterOptions(
        groupedGames: {},
        regionCache: {},
        languageCache: {},
      );
      expect(result.regions, isEmpty);
      expect(result.languages, isEmpty);
    });
  });

  // ─── GameListState.copyWith ────────────────────────────────────

  group('GameListState.copyWith', () {
    test('preserves unmodified fields', () {
      const original = GameListState(
        searchQuery: 'zelda',
        isLoading: false,
        error: 'some error',
      );
      final copied = original.copyWith(searchQuery: 'mario');
      expect(copied.searchQuery, 'mario');
      expect(copied.isLoading, isFalse);
    });

    test('replaces single field only', () {
      const original = GameListState();
      final copied = original.copyWith(isLoading: false);
      expect(copied.isLoading, isFalse);
      expect(copied.searchQuery, '');
      expect(copied.allGames, isEmpty);
    });

    test('error: null clears existing error', () {
      const original = GameListState(error: 'old error');
      final copied = original.copyWith();
      // error parameter defaults to null, which clears the error
      expect(copied.error, isNull);
    });

    test('multiple fields simultaneously', () {
      const original = GameListState();
      final copied = original.copyWith(
        isLoading: false,
        searchQuery: 'test',
        error: 'new error',
      );
      expect(copied.isLoading, isFalse);
      expect(copied.searchQuery, 'test');
      expect(copied.error, 'new error');
    });
  });
}
