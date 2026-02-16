import 'package:flutter/foundation.dart';

import '../../../models/game_item.dart';
import '../../../models/system_model.dart';
import '../../../services/game_source_service.dart';
import '../../../services/rom_manager.dart';

class GameListState {
  final List<GameItem> allGames;
  final Map<String, List<GameItem>> groupedGames;
  final List<String> allGroups;
  final List<String> filteredGroups;
  final Map<String, bool> installedCache;
  final bool isLoading;
  final String? error;
  final String searchQuery;

  const GameListState({
    this.allGames = const [],
    this.groupedGames = const {},
    this.allGroups = const [],
    this.filteredGroups = const [],
    this.installedCache = const {},
    this.isLoading = true,
    this.error,
    this.searchQuery = '',
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
    );
  }
}

class GameListController extends ChangeNotifier {
  final SystemModel system;
  final String romPath;
  final GameSourceService _gameSourceService;

  GameListState _state = const GameListState();
  GameListState get state => _state;

  final String baseUrl;

  GameListController({
    required this.system,
    required this.romPath,
    required this.baseUrl,
    GameSourceService? gameSourceService,
  }) : _gameSourceService = gameSourceService ?? GameSourceService(baseUrl: baseUrl) {
    loadGames();
  }

  Future<void> loadGames({bool forceRefresh = false}) async {
    _state = _state.copyWith(isLoading: true, error: null);
    notifyListeners();

    try {
      final games = await _gameSourceService.fetchGames(
        system,
        forceRefresh: forceRefresh,
      );
      _state = _state.copyWith(allGames: games);
      _groupGames();
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

    _state = _state.copyWith(
      groupedGames: groupedGames,
      allGroups: allGroups,
      filteredGroups: List.from(allGroups),
    );
    notifyListeners();
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
    return romManager.isAnyVariantInstalled(variants, system, romPath);
  }

  void filterGames(String query) {
    final searchQuery = query.toLowerCase();
    final filteredGroups = searchQuery.isEmpty
        ? List<String>.from(_state.allGroups)
        : _state.allGroups
            .where((name) => name.toLowerCase().contains(searchQuery))
            .toList();

    _state = _state.copyWith(
      searchQuery: searchQuery,
      filteredGroups: filteredGroups,
    );
    notifyListeners();
  }

  void resetFilter() {
    _state = _state.copyWith(
      searchQuery: '',
      filteredGroups: List.from(_state.allGroups),
    );
    notifyListeners();
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
    await _gameSourceService.updateCoverUrl(filename, url);
  }
}
