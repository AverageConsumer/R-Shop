import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../../../models/config/system_config.dart';
import '../../../models/game_item.dart';
import '../../../models/system_model.dart';
import '../../../services/database_service.dart';
import '../../../services/rom_manager.dart';
import '../../../services/storage_service.dart';
import '../../../services/unified_game_service.dart';
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

  GameListState _state = const GameListState();
  GameListState get state => _state;

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
      final games = await _unifiedService.fetchGamesForSystem(systemConfig);
      _state = _state.copyWith(allGames: games);
      _groupGames();
      _restoreFilters();
      await _checkInstalledStatus();
    } catch (e) {
      _state = _state.copyWith(error: e.toString(), isLoading: false);
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
