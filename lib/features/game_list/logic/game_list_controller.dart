import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../../../models/config/system_config.dart';
import '../../../models/game_item.dart';
import '../../../models/system_model.dart';
import '../../../services/database_service.dart';
import '../../../services/rom_manager.dart';
import '../../../services/storage_service.dart';
import '../../../services/unified_game_service.dart';
import '../../../utils/friendly_error.dart';
import '../../../utils/game_metadata.dart';
import 'filter_state.dart';

class GameListState {
  final List<GameItem> allGames;
  final Map<String, List<GameItem>> groupedGames;
  final List<String> allGroups;
  final List<String> filteredGroups;
  final Map<String, bool> installedCache;
  final bool isLoading;
  final String? error;
  final String searchQuery;
  final ActiveFilters activeFilters;
  final Map<String, RegionInfo> regionCache;
  final Map<String, List<LanguageInfo>> languageCache;
  final List<FilterOption> availableRegions;
  final List<FilterOption> availableLanguages;
  final Map<String, List<GameItem>> filteredGroupedGames;
  final bool isLocalOnly;

  const GameListState({
    this.allGames = const [],
    this.groupedGames = const {},
    this.allGroups = const [],
    this.filteredGroups = const [],
    this.installedCache = const {},
    this.isLoading = true,
    this.error,
    this.searchQuery = '',
    this.activeFilters = const ActiveFilters(),
    this.regionCache = const {},
    this.languageCache = const {},
    this.availableRegions = const [],
    this.availableLanguages = const [],
    this.filteredGroupedGames = const {},
    this.isLocalOnly = false,
  });

  GameListState copyWith({
    List<GameItem>? allGames,
    Map<String, List<GameItem>>? groupedGames,
    List<String>? allGroups,
    List<String>? filteredGroups,
    Map<String, bool>? installedCache,
    bool? isLoading,
    String? error,
    String? searchQuery,
    ActiveFilters? activeFilters,
    Map<String, RegionInfo>? regionCache,
    Map<String, List<LanguageInfo>>? languageCache,
    List<FilterOption>? availableRegions,
    List<FilterOption>? availableLanguages,
    Map<String, List<GameItem>>? filteredGroupedGames,
    bool? isLocalOnly,
  }) {
    return GameListState(
      allGames: allGames ?? this.allGames,
      groupedGames: groupedGames ?? this.groupedGames,
      allGroups: allGroups ?? this.allGroups,
      filteredGroups: filteredGroups ?? this.filteredGroups,
      installedCache: installedCache ?? this.installedCache,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      searchQuery: searchQuery ?? this.searchQuery,
      activeFilters: activeFilters ?? this.activeFilters,
      regionCache: regionCache ?? this.regionCache,
      languageCache: languageCache ?? this.languageCache,
      availableRegions: availableRegions ?? this.availableRegions,
      availableLanguages: availableLanguages ?? this.availableLanguages,
      filteredGroupedGames: filteredGroupedGames ?? this.filteredGroupedGames,
      isLocalOnly: isLocalOnly ?? this.isLocalOnly,
    );
  }
}

class GameListController extends ChangeNotifier {
  final SystemModel system;
  final String targetFolder;
  final SystemConfig systemConfig;
  final UnifiedGameService _unifiedService;
  final DatabaseService _databaseService;
  final StorageService? _storage;
  bool _disposed = false;

  GameListState _state = const GameListState();
  GameListState get state => _state;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  GameListController({
    required this.system,
    required this.targetFolder,
    required this.systemConfig,
    UnifiedGameService? unifiedService,
    DatabaseService? databaseService,
    StorageService? storage,
  })  : _unifiedService = unifiedService ?? UnifiedGameService(),
        _databaseService = databaseService ?? DatabaseService(),
        _storage = storage {
    loadGames();
  }

  Future<void> loadGames({bool forceRefresh = false}) async {
    _state = _state.copyWith(isLoading: true, error: null);
    notifyListeners();

    try {
      final List<GameItem> games;
      if (systemConfig.providers.isEmpty) {
        games = await RomManager.scanLocalGames(system, targetFolder);
        _state = _state.copyWith(allGames: games, isLocalOnly: true);
      } else {
        final remoteGames = await _unifiedService.fetchGamesForSystem(systemConfig);
        final localGames = await RomManager.scanLocalGames(system, targetFolder);

        // Compute local filenames that remote archives would produce after extraction
        // (e.g. "Game.zip" → "Game.iso"), so we can skip redundant local entries.
        final remoteTargetNames = <String>{};
        for (final game in remoteGames) {
          final targetName = RomManager.getTargetFilename(game, system);
          if (targetName != game.filename) {
            remoteTargetNames.add(targetName);
          }
        }

        // Merge: remote wins on filename collision (has URL, cover, provider info)
        final byFilename = <String, GameItem>{};
        for (final game in remoteGames) {
          byFilename[game.filename] = game;
        }
        for (final game in localGames) {
          if (remoteTargetNames.contains(game.filename)) continue;
          byFilename.putIfAbsent(game.filename, () => game);
        }

        games = byFilename.values.toList()
          ..sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
        _state = _state.copyWith(allGames: games, isLocalOnly: false);
      }
      _groupGames();
      _restoreFilters();
      await _checkInstalledStatus();
      // Populate global search database
      _databaseService.saveGames(system.id, _state.allGames);
    } catch (e) {
      _state = _state.copyWith(error: getUserFriendlyError(e), isLoading: false);
      notifyListeners();
    }
  }

  void _groupGames() {
    final groupedGames = <String, List<GameItem>>{};
    for (final game in _state.allGames) {
      groupedGames.putIfAbsent(game.displayName, () => []).add(game);
    }
    final allGroups = groupedGames.keys.toList()..sort();

    // Build region/language caches
    final regionCache = <String, RegionInfo>{};
    final languageCache = <String, List<LanguageInfo>>{};
    for (final game in _state.allGames) {
      regionCache[game.filename] = GameMetadata.extractRegion(game.filename);
      languageCache[game.filename] = GameMetadata.extractLanguages(game.filename);
    }

    final options = buildFilterOptions(
      groupedGames: groupedGames,
      regionCache: regionCache,
      languageCache: languageCache,
    );

    _state = _state.copyWith(
      groupedGames: groupedGames,
      allGroups: allGroups,
      filteredGroups: List.from(allGroups),
      filteredGroupedGames: groupedGames,
      regionCache: regionCache,
      languageCache: languageCache,
      availableRegions: options.regions,
      availableLanguages: options.languages,
    );
    notifyListeners();
  }

  void _restoreFilters() {
    final storage = _storage;
    if (storage == null) return;
    final json = storage.getFilters(system.id);
    if (json == null) return;
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      final restored = ActiveFilters(
        selectedRegions: Set<String>.from(map['regions'] as List),
        selectedLanguages: Set<String>.from(map['languages'] as List),
      );
      if (restored.isNotEmpty) {
        _state = _state.copyWith(activeFilters: restored);
        _applyFilters();
      }
    } catch (_) {
      // Corrupted data — ignore
    }
  }

  void _saveFilters() {
    final storage = _storage;
    if (storage == null) return;
    final filters = _state.activeFilters;
    if (filters.isEmpty) {
      storage.removeFilters(system.id);
    } else {
      storage.setFilters(system.id, jsonEncode({
        'regions': filters.selectedRegions.toList(),
        'languages': filters.selectedLanguages.toList(),
      }));
    }
  }

  Future<void> _checkInstalledStatus() async {
    final installedCache = <String, bool>{};
    for (final entry in _state.groupedGames.entries) {
      installedCache[entry.key] = await _isAnyVariantInstalled(entry.value);
    }
    _state = _state.copyWith(
      installedCache: installedCache,
      isLoading: false,
    );
    notifyListeners();
  }

  Future<bool> _isAnyVariantInstalled(List<GameItem> variants) async {
    final romManager = RomManager();
    return romManager.isAnyVariantInstalled(variants, system, targetFolder);
  }

  void filterGames(String query) {
    _state = _state.copyWith(searchQuery: query.toLowerCase());
    _applyFilters();
  }

  void resetFilter() {
    _state = _state.copyWith(searchQuery: '');
    _applyFilters();
  }

  void toggleRegionFilter(String region) {
    _state = _state.copyWith(
      activeFilters: _state.activeFilters.toggleRegion(region),
    );
    _applyFilters();
    _saveFilters();
  }

  void toggleLanguageFilter(String language) {
    _state = _state.copyWith(
      activeFilters: _state.activeFilters.toggleLanguage(language),
    );
    _applyFilters();
    _saveFilters();
  }

  void clearFilters() {
    _state = _state.copyWith(activeFilters: _state.activeFilters.clearAll());
    _applyFilters();
    _saveFilters();
  }

  void _applyFilters() {
    var groups = List<String>.from(_state.allGroups);

    // 1. Search filter
    if (_state.searchQuery.isNotEmpty) {
      groups = groups
          .where((name) => name.toLowerCase().contains(_state.searchQuery))
          .toList();
    }

    // 2. Region/Language filter
    if (_state.activeFilters.isNotEmpty) {
      final filteredMap = <String, List<GameItem>>{};
      groups = groups.where((groupName) {
        final variants = _state.groupedGames[groupName];
        if (variants == null) return false;
        final matching = variants.where((game) => _matchesFilters(game)).toList();
        if (matching.isEmpty) return false;
        filteredMap[groupName] = matching;
        return true;
      }).toList();
      _state = _state.copyWith(filteredGroups: groups, filteredGroupedGames: filteredMap);
    } else {
      _state = _state.copyWith(filteredGroups: groups, filteredGroupedGames: _state.groupedGames);
    }
    notifyListeners();
  }

  bool _matchesFilters(GameItem game) {
    final filters = _state.activeFilters;

    // Region check: OR within regions
    if (filters.selectedRegions.isNotEmpty) {
      final region = _state.regionCache[game.filename];
      if (region == null || !filters.selectedRegions.contains(region.name)) {
        return false;
      }
    }

    // Language check: OR within languages
    if (filters.selectedLanguages.isNotEmpty) {
      final languages = _state.languageCache[game.filename];
      if (languages == null ||
          !languages.any((l) => filters.selectedLanguages.contains(l.code))) {
        return false;
      }
    }

    return true;
  }

  Future<void> updateInstalledStatus(String displayName) async {
    final variants = _state.groupedGames[displayName];
    if (variants == null) return;

    final isInstalled = await _isAnyVariantInstalled(variants);
    final newCache = Map<String, bool>.from(_state.installedCache);
    newCache[displayName] = isInstalled;

    _state = _state.copyWith(installedCache: newCache);
    notifyListeners();
  }

  Future<void> updateCoverUrl(String filename, String url) async {
    await _databaseService.updateGameCover(filename, url);
  }
}
