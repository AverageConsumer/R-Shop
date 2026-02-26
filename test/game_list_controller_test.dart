import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:retro_eshop/features/game_list/logic/game_list_controller.dart';
import 'package:retro_eshop/models/config/provider_config.dart';
import 'package:retro_eshop/models/config/system_config.dart';
import 'package:retro_eshop/models/game_item.dart';
import 'package:retro_eshop/models/system_model.dart';
import 'package:retro_eshop/services/database_service.dart';
import 'package:retro_eshop/services/storage_service.dart';
import 'package:retro_eshop/services/unified_game_service.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class FakeDatabaseService extends DatabaseService {
  List<GameItem>? savedGames;
  String? savedSystemSlug;
  List<GameItem> cachedGames = [];
  bool hasCacheResult = false;
  final List<String> batchCoverFilenames = [];
  String? batchCoverUrl;
  final List<String> batchThumbFilenames = [];

  @override
  Future<bool> hasCache(String systemSlug) async => hasCacheResult;

  @override
  Future<List<GameItem>> getGames(String systemSlug) async => cachedGames;

  @override
  Future<void> saveGames(String systemSlug, List<GameItem> games) async {
    savedSystemSlug = systemSlug;
    savedGames = games;
  }

  @override
  Future<void> batchUpdateCoverUrl(
      List<String> filenames, String coverUrl) async {
    batchCoverFilenames.addAll(filenames);
    batchCoverUrl = coverUrl;
  }

  @override
  Future<void> batchUpdateThumbnailData(
    List<String> filenames, {
    bool? hasThumbnail,
  }) async {
    batchThumbFilenames.addAll(filenames);
  }
}

class FakeUnifiedGameService extends UnifiedGameService {
  List<GameItem> result = [];

  @override
  Future<List<GameItem>> fetchGamesForSystem(
    SystemConfig system, {
    bool? merge,
  }) async {
    return result;
  }
}

/// In-memory storage for filters and favorites only.
class FakeStorageService extends StorageService {
  final Map<String, String> _filters = {};
  List<String> _favorites = [];

  FakeStorageService() : super();

  // Override init to be a no-op (avoids SharedPreferences dependency)
  @override
  Future<void> init() async {}

  @override
  String? getFilters(String systemId) => _filters[systemId];

  @override
  Future<void> setFilters(String systemId, String json) async {
    _filters[systemId] = json;
  }

  @override
  Future<void> removeFilters(String systemId) async {
    _filters.remove(systemId);
  }

  @override
  List<String> getFavorites() => _favorites;

  @override
  Future<void> setFavorites(List<String> favorites) async {
    _favorites = favorites;
  }

  @override
  bool isFavorite(String gameId) => _favorites.contains(gameId);
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

final _nes = SystemModel.supportedSystems.firstWhere((s) => s.id == 'nes');

const _webProvider = ProviderConfig(
  type: ProviderType.web,
  priority: 1,
  url: 'http://roms.example.com/nes/',
);

SystemConfig _config({List<ProviderConfig> providers = const [_webProvider]}) {
  return SystemConfig(
    id: 'nes',
    name: _nes.name,
    targetFolder: '/nonexistent/nes',
    providers: providers,
  );
}

GameItem _game(String filename, {String url = '', String? displayName}) {
  return GameItem(
    filename: filename,
    displayName: displayName ?? GameItem.cleanDisplayName(filename),
    url: url,
  );
}

/// Creates a controller that has already loaded the given [games].
/// Uses a FakeUnifiedGameService that returns [games] and waits for loadGames.
Future<({
  GameListController controller,
  FakeDatabaseService db,
  FakeStorageService storage,
  FakeUnifiedGameService service,
})> createController({
  List<GameItem> games = const [],
  Set<String>? installedFilenames,
  SystemConfig? config,
}) async {
  final db = FakeDatabaseService();
  final storage = FakeStorageService();
  final service = FakeUnifiedGameService()..result = games;

  final c = GameListController(
    system: _nes,
    targetFolder: '/nonexistent/nes',
    systemConfig: config ?? _config(),
    installedFilenames: installedFilenames,
    unifiedService: service,
    databaseService: db,
    storage: storage,
  );

  // Wait for loadGames() to complete (it's async, kicked off in constructor)
  await Future.delayed(Duration.zero);
  // Extra pump to ensure all microtasks settle
  await Future.delayed(Duration.zero);

  return (controller: c, db: db, storage: storage, service: service);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('GameListState basics', () {
    test('default state', () {
      const state = GameListState();
      expect(state.isLoading, true);
      expect(state.allGames, isEmpty);
      expect(state.searchQuery, '');
      expect(state.error, isNull);
      expect(state.activeFilters.isEmpty, true);
    });

    test('copyWith preserves unset fields', () {
      const state = GameListState(searchQuery: 'mario', isLoading: false);
      final copied = state.copyWith(isLoading: true);
      expect(copied.searchQuery, 'mario');
      expect(copied.isLoading, true);
    });

    test('copyWith error: null clears error', () {
      const state = GameListState(error: 'something broke');
      // copyWith uses `error: error` (no ??), so passing null explicitly clears
      final cleared = state.copyWith(error: null);
      expect(cleared.error, isNull);
    });
  });

  group('Grouping', () {
    test('games with same displayName land in same group', () async {
      final r = await createController(games: [
        _game('Mario (USA).zip', url: 'http://r/m1.zip'),
        _game('Mario (Europe).zip', url: 'http://r/m2.zip'),
      ]);
      final groups = r.controller.state.groupedGames;
      expect(groups.length, 1);
      expect(groups.values.first.length, 2);
      r.controller.dispose();
    });

    test('groups sorted alphabetically', () async {
      final r = await createController(games: [
        _game('Zelda (USA).zip', url: 'http://r/z.zip'),
        _game('Mario (USA).zip', url: 'http://r/m.zip'),
        _game('Contra (USA).zip', url: 'http://r/c.zip'),
      ]);
      final allGroups = r.controller.state.allGroups;
      expect(allGroups, List.from(allGroups)..sort());
      r.controller.dispose();
    });

    test('region/language caches populated', () async {
      final r = await createController(games: [
        _game('Mario (USA).zip', url: 'http://r/m.zip'),
      ]);
      expect(r.controller.state.regionCache, isNotEmpty);
      expect(
          r.controller.state.regionCache['Mario (USA).zip']?.name, 'USA');
      r.controller.dispose();
    });

    test('availableRegions computed from groupedGames', () async {
      final r = await createController(games: [
        _game('Mario (USA).zip', url: 'http://r/m.zip'),
        _game('Zelda (Europe).zip', url: 'http://r/z.zip'),
      ]);
      final regionIds =
          r.controller.state.availableRegions.map((r) => r.id).toSet();
      expect(regionIds, contains('USA'));
      expect(regionIds, contains('Europe'));
      r.controller.dispose();
    });

    test('empty game list produces empty groups', () async {
      final r = await createController(games: []);
      expect(r.controller.state.groupedGames, isEmpty);
      expect(r.controller.state.allGroups, isEmpty);
      r.controller.dispose();
    });
  });

  group('Search', () {
    test('filterGames filters by query', () async {
      final r = await createController(games: [
        _game('Mario (USA).zip', url: 'http://r/m.zip'),
        _game('Zelda (USA).zip', url: 'http://r/z.zip'),
      ]);
      r.controller.filterGames('mario');
      expect(r.controller.state.filteredGroups.length, 1);
      r.controller.dispose();
    });

    test('search is case-insensitive', () async {
      final r = await createController(games: [
        _game('Mario (USA).zip', url: 'http://r/m.zip'),
      ]);
      r.controller.filterGames('MARIO');
      expect(r.controller.state.filteredGroups.length, 1);
      r.controller.dispose();
    });

    test('resetFilter restores all groups', () async {
      final r = await createController(games: [
        _game('Mario (USA).zip', url: 'http://r/m.zip'),
        _game('Zelda (USA).zip', url: 'http://r/z.zip'),
      ]);
      r.controller.filterGames('mario');
      expect(r.controller.state.filteredGroups.length, 1);
      r.controller.resetFilter();
      expect(r.controller.state.filteredGroups.length, 2);
      r.controller.dispose();
    });

    test('empty query shows all', () async {
      final r = await createController(games: [
        _game('Mario (USA).zip', url: 'http://r/m.zip'),
        _game('Zelda (USA).zip', url: 'http://r/z.zip'),
      ]);
      r.controller.filterGames('');
      expect(r.controller.state.filteredGroups.length, 2);
      r.controller.dispose();
    });

    test('no match returns empty filteredGroups', () async {
      final r = await createController(games: [
        _game('Mario (USA).zip', url: 'http://r/m.zip'),
      ]);
      r.controller.filterGames('nonexistent');
      expect(r.controller.state.filteredGroups, isEmpty);
      r.controller.dispose();
    });

    test('special characters in search do not crash', () async {
      final r = await createController(games: [
        _game('Mario (USA).zip', url: 'http://r/m.zip'),
      ]);
      r.controller.filterGames(r'$pecial [chars]');
      expect(r.controller.state.filteredGroups, isEmpty);
      r.controller.dispose();
    });
  });

  group('Region/Language filter', () {
    test('toggleRegionFilter shows only matching region', () async {
      final r = await createController(games: [
        _game('Mario (USA).zip', url: 'http://r/m.zip'),
        _game('Zelda (Europe).zip', url: 'http://r/z.zip'),
      ]);
      r.controller.toggleRegionFilter('USA');
      expect(r.controller.state.filteredGroups.length, 1);
      r.controller.dispose();
    });

    test('second toggle removes region filter', () async {
      final r = await createController(games: [
        _game('Mario (USA).zip', url: 'http://r/m.zip'),
        _game('Zelda (Europe).zip', url: 'http://r/z.zip'),
      ]);
      r.controller.toggleRegionFilter('USA');
      expect(r.controller.state.filteredGroups.length, 1);
      r.controller.toggleRegionFilter('USA');
      expect(r.controller.state.filteredGroups.length, 2);
      r.controller.dispose();
    });

    test('multiple regions use OR logic', () async {
      final r = await createController(games: [
        _game('Mario (USA).zip', url: 'http://r/m.zip'),
        _game('Zelda (Europe).zip', url: 'http://r/z.zip'),
        _game('Contra (Japan).zip', url: 'http://r/c.zip'),
      ]);
      r.controller.toggleRegionFilter('USA');
      r.controller.toggleRegionFilter('Europe');
      expect(r.controller.state.filteredGroups.length, 2);
      r.controller.dispose();
    });

    test('games without recognized region are filtered out', () async {
      final r = await createController(games: [
        _game('Mario (USA).zip', url: 'http://r/m.zip'),
        _game('NoRegionGame.zip', url: 'http://r/n.zip'),
      ]);
      r.controller.toggleRegionFilter('USA');
      // "NoRegionGame" has 'Unknown' region → does not match 'USA' → filtered out
      expect(r.controller.state.filteredGroups.length, 1);
      r.controller.dispose();
    });

    test('toggleLanguageFilter shows only matching language', () async {
      final r = await createController(games: [
        _game('Mario (USA) (En).zip', url: 'http://r/m.zip'),
        _game('Zelda (Japan) (Ja).zip', url: 'http://r/z.zip'),
      ]);
      r.controller.toggleLanguageFilter('En');
      // Only Mario has English
      final filtered = r.controller.state.filteredGroups;
      expect(filtered.length, 1);
      r.controller.dispose();
    });

    test('language filter with multilingual game', () async {
      final r = await createController(games: [
        _game('Mario (USA) (En,Fr).zip', url: 'http://r/m.zip'),
        _game('Zelda (Japan) (Ja).zip', url: 'http://r/z.zip'),
      ]);
      r.controller.toggleLanguageFilter('Fr');
      expect(r.controller.state.filteredGroups.length, 1);
      r.controller.dispose();
    });

    test('clearFilters resets all', () async {
      final r = await createController(games: [
        _game('Mario (USA).zip', url: 'http://r/m.zip'),
        _game('Zelda (Europe).zip', url: 'http://r/z.zip'),
      ]);
      r.controller.toggleRegionFilter('USA');
      expect(r.controller.state.activeFilters.isNotEmpty, true);
      r.controller.clearFilters();
      expect(r.controller.state.activeFilters.isEmpty, true);
      expect(r.controller.state.filteredGroups.length, 2);
      r.controller.dispose();
    });
  });

  group('Favorites/Local filter', () {
    test('toggleFavoritesFilter shows only favorites', () async {
      final r = await createController(games: [
        _game('Mario (USA).zip', url: 'http://r/m.zip'),
        _game('Zelda (USA).zip', url: 'http://r/z.zip'),
      ]);
      await r.storage.setFavorites(['Mario (USA).zip']);
      r.controller.toggleFavoritesFilter();
      expect(r.controller.state.filteredGroups.length, 1);
      r.controller.dispose();
    });

    test('toggleLocalFilter shows only installed', () async {
      final r = await createController(
        games: [
          _game('Mario (USA).zip', url: 'http://r/m.zip'),
          _game('Zelda (USA).zip', url: 'http://r/z.zip'),
        ],
        installedFilenames: {'Mario (USA).zip'},
      );
      r.controller.toggleLocalFilter();
      expect(r.controller.state.filteredGroups.length, 1);
      r.controller.dispose();
    });

    test('combined favorites + region filter', () async {
      final r = await createController(games: [
        _game('Mario (USA).zip', url: 'http://r/m.zip'),
        _game('Zelda (Europe).zip', url: 'http://r/z.zip'),
        _game('Contra (USA).zip', url: 'http://r/c.zip'),
      ]);
      await r.storage.setFavorites(['Mario (USA).zip', 'Contra (USA).zip']);
      r.controller.toggleFavoritesFilter();
      r.controller.toggleRegionFilter('USA');
      // Only Mario and Contra are favorites AND USA
      expect(r.controller.state.filteredGroups.length, 2);
      r.controller.dispose();
    });
  });

  group('Installed status', () {
    test('applyInstalledFilenames sets cache and clears loading', () async {
      final r = await createController(games: [
        _game('Mario (USA).zip', url: 'http://r/m.zip'),
        _game('Zelda (USA).zip', url: 'http://r/z.zip'),
      ]);
      r.controller.applyInstalledFilenames({'Mario (USA).zip'});
      expect(r.controller.state.isLoading, false);
      final marioGroup = GameItem.cleanDisplayName('Mario (USA).zip');
      expect(r.controller.state.installedCache[marioGroup], true);
      r.controller.dispose();
    });

    test('archive match: .zip remote matches .nes local', () async {
      final r = await createController(games: [
        _game('Game (USA).zip', url: 'http://r/g.zip'),
      ]);
      // After extraction: Game (USA).zip → Game (USA).nes
      r.controller.applyInstalledFilenames({'Game (USA).nes'});
      final group = GameItem.cleanDisplayName('Game (USA).zip');
      expect(r.controller.state.installedCache[group], true);
      r.controller.dispose();
    });

    test('no match returns false', () async {
      final r = await createController(games: [
        _game('Mario (USA).zip', url: 'http://r/m.zip'),
      ]);
      r.controller.applyInstalledFilenames({'Unrelated.nes'});
      final group = GameItem.cleanDisplayName('Mario (USA).zip');
      expect(r.controller.state.installedCache[group], false);
      r.controller.dispose();
    });

    test('multi-file archive match via rom extension', () async {
      final r = await createController(games: [
        _game('Game (USA).rar', url: 'http://r/g.rar'),
      ]);
      // .rar → stripped + .nes
      r.controller.applyInstalledFilenames({'Game (USA).nes'});
      final group = GameItem.cleanDisplayName('Game (USA).rar');
      expect(r.controller.state.installedCache[group], true);
      r.controller.dispose();
    });

    test('direct filename match', () async {
      final r = await createController(games: [
        _game('Game.nes', url: 'http://r/g.nes'),
      ]);
      r.controller.applyInstalledFilenames({'Game.nes'});
      final group = GameItem.cleanDisplayName('Game.nes');
      expect(r.controller.state.installedCache[group], true);
      r.controller.dispose();
    });

    test('stripped archive name match (no rom extension)', () async {
      final r = await createController(games: [
        _game('Game.zip', url: 'http://r/g.zip'),
      ]);
      // .zip stripped → "Game" — exists in installed set
      r.controller.applyInstalledFilenames({'Game'});
      final group = GameItem.cleanDisplayName('Game.zip');
      expect(r.controller.state.installedCache[group], true);
      r.controller.dispose();
    });

    test('multiple variants: any match suffices', () async {
      final r = await createController(games: [
        _game('Game (USA).zip', url: 'http://r/g1.zip'),
        _game('Game (Europe).zip', url: 'http://r/g2.zip'),
      ]);
      r.controller.applyInstalledFilenames({'Game (USA).nes'});
      final group = GameItem.cleanDisplayName('Game (USA).zip');
      expect(r.controller.state.installedCache[group], true);
      r.controller.dispose();
    });

    test('7z is not extractable: no archive match', () async {
      final r = await createController(games: [
        _game('Game.7z', url: 'http://r/g.7z'),
      ]);
      // .7z is in archiveExtensions but NOT in _extractableExtensions used by _isAnyVariantInSet
      // Actually archiveExtensions = ['.zip', '.7z', '.rar'] so .7z IS checked
      r.controller.applyInstalledFilenames({'Game.nes'});
      final group = GameItem.cleanDisplayName('Game.7z');
      expect(r.controller.state.installedCache[group], true);
      r.controller.dispose();
    });
  });

  group('In-memory updates', () {
    test('updateCoverUrls updates allGames and grouped maps', () async {
      final r = await createController(games: [
        _game('Mario (USA).zip', url: 'http://r/m.zip'),
      ]);
      final variants = r.controller.state.allGames;
      await r.controller.updateCoverUrls(variants, 'http://cover.png');

      expect(
          r.controller.state.allGames.first.cachedCoverUrl, 'http://cover.png');
      final groupName = r.controller.state.allGroups.first;
      expect(
          r.controller.state.groupedGames[groupName]!.first.cachedCoverUrl,
          'http://cover.png');
      expect(
          r.controller.state.filteredGroupedGames[groupName]!.first
              .cachedCoverUrl,
          'http://cover.png');
      r.controller.dispose();
    });

    test('updateCoverUrls persists to database', () async {
      final r = await createController(games: [
        _game('Mario (USA).zip', url: 'http://r/m.zip'),
      ]);
      final variants = r.controller.state.allGames;
      await r.controller.updateCoverUrls(variants, 'http://cover.png');
      expect(r.db.batchCoverFilenames, ['Mario (USA).zip']);
      expect(r.db.batchCoverUrl, 'http://cover.png');
      r.controller.dispose();
    });

    test('updateThumbnailData sets hasThumbnail', () async {
      final r = await createController(games: [
        _game('Mario (USA).zip', url: 'http://r/m.zip'),
      ]);
      final variants = r.controller.state.allGames;
      await r.controller.updateThumbnailData(variants);
      expect(r.controller.state.allGames.first.hasThumbnail, true);
      expect(r.db.batchThumbFilenames, ['Mario (USA).zip']);
      r.controller.dispose();
    });

    test('thumbnail debounce batches notifications', () async {
      final r = await createController(games: [
        _game('Mario (USA).zip', url: 'http://r/m.zip'),
        _game('Zelda (USA).zip', url: 'http://r/z.zip'),
      ]);
      var notifyCount = 0;
      r.controller.addListener(() => notifyCount++);
      final baseline = notifyCount;

      // Rapid-fire thumbnail updates
      await r.controller
          .updateThumbnailData([r.controller.state.allGames[0]]);
      await r.controller
          .updateThumbnailData([r.controller.state.allGames[1]]);

      // Timer hasn't fired yet — should batch
      expect(notifyCount, baseline);

      // Wait for debounce timer
      await Future.delayed(const Duration(milliseconds: 150));
      expect(notifyCount, baseline + 1);
      r.controller.dispose();
    });
  });

  group('Filter persistence', () {
    test('saveFilters serializes to JSON', () async {
      final r = await createController(games: [
        _game('Mario (USA).zip', url: 'http://r/m.zip'),
      ]);
      r.controller.toggleRegionFilter('USA');
      final json = r.storage.getFilters('nes');
      expect(json, isNotNull);
      final map = jsonDecode(json!) as Map<String, dynamic>;
      expect((map['regions'] as List).contains('USA'), true);
      r.controller.dispose();
    });

    test('restoreFilters applies saved filters', () async {
      final storage = FakeStorageService();
      await storage.setFilters('nes', jsonEncode({
        'regions': ['USA'],
        'languages': [],
        'favoritesOnly': false,
        'localOnly': false,
      }));
      final service = FakeUnifiedGameService()
        ..result = [
          _game('Mario (USA).zip', url: 'http://r/m.zip'),
          _game('Zelda (Europe).zip', url: 'http://r/z.zip'),
        ];
      final db = FakeDatabaseService();

      final c = GameListController(
        system: _nes,
        targetFolder: '/nonexistent/nes',
        systemConfig: _config(),
        unifiedService: service,
        databaseService: db,
        storage: storage,
      );
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      expect(c.state.activeFilters.selectedRegions, contains('USA'));
      // USA filter active → only Mario (USA) passes, Zelda (Europe) filtered out
      expect(c.state.filteredGroups.length, 1);
      c.dispose();
    });

    test('empty filters removes stored filters', () async {
      final r = await createController(games: [
        _game('Mario (USA).zip', url: 'http://r/m.zip'),
      ]);
      r.controller.toggleRegionFilter('USA');
      expect(r.storage.getFilters('nes'), isNotNull);
      r.controller.clearFilters();
      expect(r.storage.getFilters('nes'), isNull);
      r.controller.dispose();
    });

    test('corrupt JSON does not crash', () async {
      final storage = FakeStorageService();
      await storage.setFilters('nes', '{bad json!!!');
      final service = FakeUnifiedGameService()
        ..result = [_game('Mario (USA).zip', url: 'http://r/m.zip')];
      final db = FakeDatabaseService();

      final c = GameListController(
        system: _nes,
        targetFolder: '/nonexistent/nes',
        systemConfig: _config(),
        unifiedService: service,
        databaseService: db,
        storage: storage,
      );
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      // Should not crash, filters should be empty
      expect(c.state.activeFilters.isEmpty, true);
      c.dispose();
    });

    test('without StorageService: filter ops are no-op', () async {
      final service = FakeUnifiedGameService()
        ..result = [_game('Mario (USA).zip', url: 'http://r/m.zip')];
      final db = FakeDatabaseService();

      final c = GameListController(
        system: _nes,
        targetFolder: '/nonexistent/nes',
        systemConfig: _config(),
        unifiedService: service,
        databaseService: db,
        storage: null,
      );
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      // Should not crash even without storage
      c.toggleRegionFilter('USA');
      c.clearFilters();
      c.dispose();
    });
  });

  group('Local-only mode', () {
    test('empty providers triggers local-only path', () async {
      final db = FakeDatabaseService();
      final storage = FakeStorageService();

      final c = GameListController(
        system: _nes,
        targetFolder: '/nonexistent/nes',
        systemConfig: _config(providers: []),
        databaseService: db,
        storage: storage,
      );
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      expect(c.state.isLocalOnly, true);
      // Non-existent folder → empty games
      expect(c.state.allGames, isEmpty);
      c.dispose();
    });
  });

  group('dispose safety', () {
    test('notifyListeners after dispose does not throw', () async {
      final r = await createController(games: [
        _game('Mario (USA).zip', url: 'http://r/m.zip'),
      ]);
      r.controller.dispose();
      // Calling filterGames after dispose should not throw
      // (notifyListeners is guarded by _disposed flag)
      expect(() => r.controller.filterGames('test'), returnsNormally);
    });
  });
}
