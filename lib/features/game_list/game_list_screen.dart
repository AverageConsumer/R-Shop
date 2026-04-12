import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/config/app_config.dart';
import '../../models/config/system_config.dart';

import '../../core/input/input.dart';
import '../../core/responsive/responsive.dart';
import '../../l10n/app_localizations.dart';
import '../../models/game_item.dart';
import '../../models/system_model.dart';
import '../../providers/app_providers.dart';
import '../../providers/game_providers.dart';
import '../../providers/library_providers.dart';
import '../../providers/ra_providers.dart';
import '../../services/config_bootstrap.dart';
import '../../services/library_sync_service.dart';
import '../../services/input_debouncer.dart';
import '../../services/thumbnail_service.dart';
import '../game_detail/game_detail_screen.dart';
import 'logic/game_list_controller.dart';
import '../../widgets/console_hud.dart';
import '../../widgets/download_overlay.dart';
import '../../widgets/quick_menu.dart';
import '../../providers/download_providers.dart';
import '../../providers/installed_files_provider.dart';
import '../../providers/shelf_providers.dart';
import '../library/widgets/shelf_picker_dialog.dart';
import 'widgets/game_grid.dart';
import 'widgets/game_list_header.dart';
import 'widgets/filter_overlay.dart';

class GameListScreen extends ConsumerStatefulWidget {
  final SystemModel system;
  final String targetFolder;

  const GameListScreen({
    super.key,
    required this.system,
    required this.targetFolder,
  });

  @override
  ConsumerState<GameListScreen> createState() => _GameListScreenState();
}

class _GameListScreenState extends ConsumerState<GameListScreen>
    with ConsoleScreenMixin, SearchableScreenMixin {
  late final GameListController _controller;
  late final FocusSyncManager _focusManager;
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<int> _selectedIndexNotifier = ValueNotifier(0);
  final ValueNotifier<bool> _scrollSuppression = ValueNotifier(false);
  final Map<int, GlobalKey> _itemKeys = {};

  bool _isFiltering = false;
  bool _showStartHint = false;
  ProviderSubscription? _installedFilesSubscription;
  ProviderSubscription? _syncSub;

  late int _columns;
  double _lastPinchScale = 1.0;
  late InputDebouncer _debouncer;
  SystemConfig? _systemConfig;

  @override
  String get routeId => 'game_list_${widget.system.name}';

  @override
  Color get searchAccentColor => widget.system.accentColor;

  @override
  String get searchHintText => 'Search ${widget.system.name}...';

  @override
  void onSearchQueryChanged(String query) {
    if (!mounted) return;
    final prevCount = _controller.state.filteredGroups.length;
    _controller.filterGames(query);
    final newCount = _controller.state.filteredGroups.length;

    if (newCount == 0) {
      _focusManager.reset(0);
    } else if (_focusManager.selectedIndex >= newCount) {
      _focusManager.reset(newCount - 1);
    }

    if (newCount != prevCount) {
      _updateItemKeys();
    }

    _selectedIndexNotifier.value = _focusManager.selectedIndex;
    setState(() {});
  }

  @override
  void onSearchReset() {
    _controller.resetFilter();
    _focusManager.reset(0);
    _selectedIndexNotifier.value = 0;
    _updateItemKeys();
  }

  @override
  void onSearchSelectionReset() {
    _focusManager.reset(0);
    _selectedIndexNotifier.value = 0;
  }

  @override
  void onBeforeSearchOpen() {
    if (_isFiltering) setState(() => _isFiltering = false);
  }

  @override
  Map<Type, Action<Intent>> get screenActions {
    return {
        NavigateIntent: OverlayGuardedAction<NavigateIntent>(ref,
          onInvoke: (intent) { _navigateGrid(intent.direction); return null; },
          isEnabledOverride: searchOrNone,
        ),
        AdjustColumnsIntent: OverlayGuardedAction<AdjustColumnsIntent>(ref,
          onInvoke: (intent) { _adjustColumns(intent.increase); return null; },
          isEnabledOverride: searchOrNone,
        ),
        ConfirmIntent: CallbackAction<ConfirmIntent>(
          onInvoke: (_) {
            _openSelectedGame();
            return null;
          },
        ),
        BackIntent: OverlayGuardedAction<BackIntent>(ref,
          onInvoke: (_) { _handleBack(); return null; },
          isEnabledOverride: searchOrNone,
        ),
        SearchIntent: CallbackAction<SearchIntent>(
          onInvoke: (_) {
            if (!_isFiltering) toggleSearch();
            return null;
          },
        ),
        FavoriteIntent: OverlayGuardedAction<FavoriteIntent>(ref,
          onInvoke: (_) { _handleFavorite(); return null; },
        ),
        ToggleOverlayIntent: ToggleOverlayAction(ref, onToggle: () {
          _dismissStartHint();
          toggleQuickMenu();
        }),
      };
  }

  @override
  void initState() {
    super.initState();
    _columns = ref.read(gridColumnsProvider(widget.system.name));
    _debouncer = ref.read(inputDebouncerProvider);

    final appConfig =
        ref.read(bootstrappedConfigProvider).value ?? AppConfig.empty;
    final systemConfig =
        ConfigBootstrap.configForSystem(appConfig, widget.system);
    _systemConfig = systemConfig;

    final installedData = ref.read(installedFilesProvider).value;

    _controller = GameListController(
      system: widget.system,
      targetFolder: widget.targetFolder,
      systemConfig: systemConfig ?? SystemConfig(id: widget.system.id, name: widget.system.name, targetFolder: widget.targetFolder, providers: []),
      installedFilenames: installedData?.bySystem[widget.system.id],
      storage: ref.read(storageServiceProvider),
    )..addListener(_onControllerChanged);

    _controller.onGamesSaved = () {
      ref.read(gameDbChangedProvider.notifier).state++;
    };

    _focusManager = FocusSyncManager(
      scrollController: _scrollController,
      getCrossAxisCount: () => _columns,
      getItemCount: () => _controller.state.filteredGroups.length,
      getGridRatio: () => 1.0,
      onSelectionChanged: (index) => _selectedIndexNotifier.value = index,
      scrollSuppression: _scrollSuppression,
    );

    initSearch();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreSavedIndex();
      _installedFilesSubscription = ref.listenManual(installedFilesProvider, (prev, next) {
        if (!mounted) return;
        final data = next.value;
        if (data != null) {
          _controller.applyInstalledFilenames(
            data.bySystem[widget.system.id] ?? {},
          );
        }
      });

      // Auto-retry when sync finishes and we're showing an error or have no games
      _syncSub = ref.listenManual(
        librarySyncServiceProvider.select((s) => s.isSyncing),
        (prev, isSyncing) {
          if (prev == true && !isSyncing) {
            if (_controller.state.error != null || _controller.state.allGames.isEmpty) {
              _controller.loadGames();
            }
          }
        },
      );

      final storage = ref.read(storageServiceProvider);
      if (!storage.getStartHintShown()) {
        storage.setStartHintShown();
        setState(() => _showStartHint = true);
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) setState(() => _showStartHint = false);
        });
      }
    });
  }

  void _dismissStartHint() {
    if (_showStartHint) setState(() => _showStartHint = false);
  }

  void _restoreSavedIndex() {
    final saved = getSavedFocusState();
    if (saved?.selectedIndex != null && saved!.selectedIndex! > 0) {
      final maxIndex = _controller.state.filteredGroups.length - 1;
      if (maxIndex < 0) return;
      final clampedIndex = saved.selectedIndex!.clamp(0, maxIndex);
      _focusManager.setSelectedIndex(clampedIndex);
      _selectedIndexNotifier.value = clampedIndex;
    }
  }

  @override
  void dispose() {
    // Capture before dispose, defer save to avoid provider modification during finalization
    final selectedIndex = _focusManager.selectedIndex;
    Future.microtask(() {
      focusStateManager.saveFocusState(routeId, selectedIndex: selectedIndex);
    });

    _installedFilesSubscription?.close();
    _syncSub?.close();
    _debouncer.stopHold();
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _focusManager.dispose();
    _scrollController.dispose();
    _selectedIndexNotifier.dispose();
    _scrollSuppression.dispose();
    disposeSearch();
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    // Trigger deferred migration (idempotent, no-op if already migrated)
    if (_controller.state.allGames.isNotEmpty) {
      ref.read(favoriteGamesProvider.notifier).migrateIfNeeded(_controller.state.allGames);
    }
    _focusManager.validateState(_columns);
    setState(() {});
    _updateItemKeys();
  }

  void _updateItemKeys() {
    final count = _controller.state.filteredGroups.length;
    if (_itemKeys.length == count) return;
    _itemKeys.clear();
    for (int i = 0; i < count; i++) {
      _itemKeys[i] = GlobalKey();
    }
    _focusManager.ensureFocusNodes(count);
  }

  void _toggleFilter() {
    ref.read(feedbackServiceProvider).tick();
    if (_isFiltering) {
      _closeFilter();
    } else {
      if (isSearchActive) closeSearch();
      _openFilter();
    }
  }

  void _openFilter() {
    setState(() => _isFiltering = true);
  }

  void _closeFilter() {
    setState(() => _isFiltering = false);
    _resetFocusAfterFilterChange();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) requestScreenFocus();
    });
  }

  void _resetFocusAfterFilterChange() {
    final count = _controller.state.filteredGroups.length;
    if (count == 0) {
      _focusManager.reset(0);
    } else if (_focusManager.selectedIndex >= count) {
      _focusManager.reset(count - 1);
    }
    _selectedIndexNotifier.value = _focusManager.selectedIndex;
    _updateItemKeys();
  }

  void _adjustColumns(bool increase) {
    final next = adjustColumnCount(
      current: _columns,
      increase: increase,
      providerKey: widget.system.name,
      ref: ref,
    );
    if (next == _columns) return;
    setState(() => _columns = next);
    _scrollToSelectedAfterColumnChange();
  }

  void _scrollToSelectedAfterColumnChange() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollToSelected();
    });
  }

  void _scrollToSelected({bool instant = false}) {
    _focusManager.scrollToSelectedWithFallback(
      itemKey: _itemKeys[_focusManager.selectedIndex],
      crossAxisCount: _columns,
      instant: instant,
      isMounted: () => mounted,
      retryCallback: () => _scrollToSelected(instant: true),
    );
  }

  void _navigateGrid(GridDirection direction) {
    if (_debouncer.startHold(() {
      if (_focusManager.moveFocus(direction)) {
        // moveFocus updates _selectedIndexNotifier via onSelectionChanged.
        // No setState needed — only 2 affected Cards rebuild.
        _focusManager.scrollToSelected(
          _itemKeys[_focusManager.selectedIndex],
          instant: _debouncer.isHolding,
        );
      }
    })) {
      ref.read(feedbackServiceProvider).tick();
    }
  }

  void _handleBack() {
    ref.read(feedbackServiceProvider).cancel();
    if (_isFiltering) {
      _closeFilter();
    } else if (isSearchActive) {
      handleSearchBack();
    } else {
      Navigator.pop(context);
    }
  }

  void _handleFavorite() {
    final state = _controller.state;
    final selectedIndex = _focusManager.selectedIndex;
    if (selectedIndex < 0 || selectedIndex >= state.filteredGroups.length) return;

    final displayName = state.filteredGroups[selectedIndex];
    final variants = state.filteredGroupedGames[displayName];
    if (variants == null || variants.length != 1) return;

    ref.read(feedbackServiceProvider).tick();
    ref.read(favoriteGamesProvider.notifier).toggleFavorite(variants.first.filename);
  }

  void _handleAddToShelf() {
    final state = _controller.state;
    final selectedIndex = _focusManager.selectedIndex;
    if (selectedIndex < 0 || selectedIndex >= state.filteredGroups.length) return;

    final displayName = state.filteredGroups[selectedIndex];
    final variants = state.filteredGroupedGames[displayName];
    if (variants == null || variants.length != 1) return;

    final game = variants.first;
    final shelves = ref.read(customShelvesProvider);
    final availableShelves = shelves
        .where((s) => !s.containsGame(game.filename, game.displayName, widget.system.id))
        .toList();
    if (availableShelves.isEmpty) return;

    showShelfPickerDialog(
      context: context,
      ref: ref,
      shelves: availableShelves,
      onSelect: (shelfId) {
        ref.read(customShelvesProvider.notifier).addGameToShelf(shelfId, game.filename);
      },
    );
  }

  bool _selectedIsSingleVariant() {
    final state = _controller.state;
    final idx = _focusManager.selectedIndex;
    if (idx < 0 || idx >= state.filteredGroups.length) return false;
    final variants = state.filteredGroupedGames[state.filteredGroups[idx]];
    return variants != null && variants.length == 1;
  }

  bool _selectedIsFavorite() {
    final state = _controller.state;
    final idx = _focusManager.selectedIndex;
    if (idx < 0 || idx >= state.filteredGroups.length) return false;
    final variants = state.filteredGroupedGames[state.filteredGroups[idx]];
    if (variants == null || variants.length != 1) return false;
    return ref.read(favoriteGamesProvider).contains(variants.first.filename);
  }

  bool _canAddToShelf() {
    if (!_selectedIsSingleVariant()) return false;
    final shelves = ref.read(customShelvesProvider);
    if (shelves.isEmpty) return false;
    final state = _controller.state;
    final idx = _focusManager.selectedIndex;
    final variants = state.filteredGroupedGames[state.filteredGroups[idx]];
    if (variants == null || variants.isEmpty) return false;
    final game = variants.first;
    return shelves.any((s) => !s.containsGame(game.filename, game.displayName, widget.system.id));
  }

  List<QuickMenuItem?> _buildQuickMenuItems() {
    final l = L.of(context);
    final state = _controller.state;
    final hasDownloads = ref.read(hasQueueItemsProvider);
    return [
      QuickMenuItem(
        label: l.gameList_zoomIn,
        icon: Icons.zoom_in_rounded,
        shortcutHint: 'L',
        onSelect: () => _adjustColumns(true),
      ),
      QuickMenuItem(
        label: l.gameList_zoomOut,
        icon: Icons.zoom_out_rounded,
        shortcutHint: 'R',
        onSelect: () => _adjustColumns(false),
      ),
      QuickMenuItem(
        label: l.common_search,
        icon: Icons.search_rounded,
        shortcutHint: 'Y',
        onSelect: openSearch,
      ),
      if (_selectedIsSingleVariant()) ...[
        QuickMenuItem(
          label: _selectedIsFavorite() ? l.common_unfavorite : l.common_favorite,
          icon: _selectedIsFavorite()
              ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          shortcutHint: '−',
          onSelect: _handleFavorite,
        ),
      ],
      if (_canAddToShelf())
        QuickMenuItem(
          label: l.gameDetail_addToShelf,
          icon: Icons.shelves,
          onSelect: _handleAddToShelf,
        ),
      QuickMenuItem(
        label: state.activeFilters.isNotEmpty ? l.gameList_filterActive : l.gameList_filter,
        icon: Icons.filter_list_rounded,
        onSelect: _toggleFilter,
      ),
      if (hasDownloads) ...[
        null,
        QuickMenuItem(
          label: l.common_downloads,
          icon: Icons.download_rounded,
          onSelect: () => toggleDownloadOverlay(ref),
          highlight: true,
        ),
      ],
    ];
  }

  void _openSelectedGame() {
    final state = _controller.state;
    final selectedIndex = _focusManager.selectedIndex;
    if (selectedIndex >= 0 && selectedIndex < state.filteredGroups.length) {
      final displayName = state.filteredGroups[selectedIndex];
      final variants = state.filteredGroupedGames[displayName];
      if (variants == null || variants.isEmpty) return;
      _openGameDetail(displayName, variants);
    }
  }

  Future<void> _openGameDetail(
      String displayName, List<GameItem> variants) async {
    searchFieldNode.unfocus();
    suspendSearchOverlay();
    ref.read(feedbackServiceProvider).confirm();
    final isLocalOnly = _controller.state.isLocalOnly;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GameDetailScreen(
          game: variants.first,
          variants: variants,
          system: widget.system,
          targetFolder: widget.targetFolder,
          isLocalOnly: isLocalOnly,
          autoExtract: _systemConfig?.autoExtract ?? false,
        ),
      ),
    );
    if (mounted) resumeSearchOverlay();
    if (isLocalOnly) {
      await _controller.loadGames(silent: true);
    } else {
      await _controller.updateInstalledStatus(displayName);
    }
    if (isSearchActive && mounted) {
      requestScreenFocus();
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    final searchResult = handleSearchKeyEvent(event);
    if (searchResult != null) return searchResult;

    if (event is KeyUpEvent) {
      _debouncer.stopHold();
      return KeyEventResult.ignored;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final state = _controller.state;
    final baseTopPadding = rs.safeAreaTop + (rs.isSmall ? 60 : 80);
    final folderExtraPadding = widget.targetFolder.isNotEmpty ? (rs.isSmall ? 14.0 : 16.0) : 0.0;
    final localOnlyExtraPadding = state.isLocalOnly ? (rs.isSmall ? 24.0 : 28.0) : 0.0;
    final searchExtraPadding = rs.isSmall ? 16.0 : 20.0;
    final topPadding =
        baseTopPadding + folderExtraPadding + localOnlyExtraPadding + (isSearchActive ? searchExtraPadding : 0.0);

    return buildWithActions(
      PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            _handleBack();
          }
        },
        child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onScaleStart: (details) {
            _lastPinchScale = 1.0;
          },
          onScaleEnd: (details) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _focusManager
                  .scrollToSelected(_itemKeys[_focusManager.selectedIndex]);
            });
          },
          onScaleUpdate: (details) {
            if (details.scale != 1.0) {
              final pinchDelta = details.scale - _lastPinchScale;
              if (pinchDelta.abs() > 0.15) {
                _lastPinchScale = details.scale;
                if (pinchDelta > 0) {
                  _adjustColumns(false);
                } else {
                  _adjustColumns(true);
                }
              }
            }
          },
          child: Stack(
            children: [
              _buildNormalContent(state, topPadding),
              if (isSearchActive) _buildSearchContent(state),
              if (_isFiltering) _buildFilterContent(state),
              if (_isFiltering)
                ConsoleHud(
                  a: null,
                  b: HudAction(L.of(context).common_close, onTap: _closeFilter),
                  x: HudAction(L.of(context).common_clear, onTap: () {
                    _controller.clearFilters();
                    _resetFocusAfterFilterChange();
                    setState(() {});
                  }),
                )
              else if (isSearchActive)
                buildSearchHud(
                  aAction: HudAction(L.of(context).common_select, onTap: _openSelectedGame),
                )
              else if (!showQuickMenu)
                ConsoleHud(
                  a: HudAction(L.of(context).common_select, onTap: _openSelectedGame),
                  b: HudAction(L.of(context).common_back, onTap: () => Navigator.pop(context)),
                  start: HudAction(L.of(context).common_menu, onTap: () {
                    _dismissStartHint();
                    toggleQuickMenu();
                  }),
                ),
              if (showQuickMenu)
                QuickMenuOverlay(
                  items: _buildQuickMenuItems(),
                  onClose: closeQuickMenu,
                ),
              if (_showStartHint) _buildStartHint(context),
            ],
          ),
        ),
      ),
      ),
      onKeyEvent: _handleKeyEvent,
    );
  }

  Widget _buildNormalContent(GameListState state, double topPadding) {
    final syncState = ref.watch(librarySyncServiceProvider);
    final syncActive = syncState.isSyncing && (
      LibrarySyncService.isSyncingSystem(widget.system.id) ||
      !syncState.gamesPerSystem.containsKey(widget.system.id)
    );

    return Stack(
      children: [
        Padding(
          padding: EdgeInsets.only(top: topPadding),
          child: _buildGridOrStatus(state, syncActive),
        ),
        GameListHeader(
          system: widget.system,
          gameCount: state.filteredGroups.length,
          hasActiveFilters: state.activeFilters.isNotEmpty,
          isLocalOnly: state.isLocalOnly,
          isOffline: state.isOffline,
          targetFolder: widget.targetFolder,
        ),
      ],
    );
  }

  Widget _buildGridOrStatus(GameListState state, bool syncActive) {
    if (state.isLoading) {
      if (syncActive) {
        return GameGridSyncing(accentColor: widget.system.accentColor);
      }
      return GameGridLoading(
        accentColor: widget.system.accentColor,
        crossAxisCount: _columns,
      );
    }
    if (state.error != null) {
      // Sync is active — show syncing state instead of confusing error
      if (syncActive) {
        return GameGridSyncing(accentColor: widget.system.accentColor);
      }
      return GameGridError(
        error: state.error!,
        accentColor: widget.system.accentColor,
        onRetry: _controller.loadGames,
      );
    }
    // Empty game list while sync hasn't reached this system yet
    if (state.filteredGroups.isEmpty && syncActive &&
        state.searchQuery.isEmpty && state.activeFilters.isEmpty) {
      return GameGridSyncing(accentColor: widget.system.accentColor);
    }
    // Only rebuild when favorites relevant to THIS system's games change
    final systemFilenames = state.filteredGroupedGames.values
        .expand((v) => v.map((g) => g.filename))
        .toSet();
    final favoriteFilenames = ref.watch(favoriteGamesProvider.select(
      (all) => all.where(systemFilenames.contains).toSet(),
    ));
    final favorites = <String>{};
    for (final entry in state.filteredGroupedGames.entries) {
      if (entry.value.any((v) => favoriteFilenames.contains(v.filename))) {
        favorites.add(entry.key);
      }
    }
    final raMatches =
        ref.watch(raMatchesForSystemProvider(widget.system.id)).value ?? {};
    final deviceMemory = ref.read(deviceMemoryProvider);
    return GameGrid(
      key: const ValueKey('game_grid'),
      system: widget.system,
      filteredGroups: state.filteredGroups,
      groupedGames: state.filteredGroupedGames,
      installedCache: state.installedCache,
      favorites: favorites,
      itemKeys: _itemKeys,
      focusNodes: _focusManager.focusNodes,
      selectedIndexNotifier: _selectedIndexNotifier,
      crossAxisCount: _columns,
      scrollController: _scrollController,
      onScrollNotification: (n) {
        _focusManager.updateScrollVelocity(n);
        return _focusManager.handleScrollNotification(n, context);
      },
      scrollSuppression: _scrollSuppression,
      onOpenGame: _openGameDetail,
      onSelectionChanged: (index) {
        _focusManager.setSelectedIndex(index);
        _selectedIndexNotifier.value = index;
      },
      onCoverFound: (url, variants) async {
        await _controller.updateCoverUrls(variants, url);
      },
      onThumbnailNeeded: (url, variants) async {
        if (variants.first.hasThumbnail) return;
        final result = await ThumbnailService.generateThumbnail(url);
        if (result.success) {
          await _controller.updateThumbnailData(variants);
        }
      },
      searchQuery: state.searchQuery,
      hasActiveFilters: state.activeFilters.isNotEmpty,
      isLocalOnly: state.isLocalOnly,
      targetFolder: widget.targetFolder,
      raMatches: raMatches,
      memCacheWidthMax: deviceMemory.memCacheWidthMax,
      gridCacheExtent: deviceMemory.gridCacheExtent,
    );
  }

  Widget _buildSearchContent(GameListState state) {
    return buildSearchWidget(searchQuery: state.searchQuery);
  }

  Widget _buildFilterContent(GameListState state) {
    return DialogFocusScope(
      isVisible: _isFiltering,
      onClose: _closeFilter,
      child: FilterOverlay(
        accentColor: widget.system.textAccentColor,
        availableRegions: state.availableRegions,
        availableLanguages: state.availableLanguages,
        selectedRegions: state.activeFilters.selectedRegions,
        selectedLanguages: state.activeFilters.selectedLanguages,
        favoritesOnly: state.activeFilters.favoritesOnly,
        localOnly: state.activeFilters.localOnly,
        isLocalSystem: state.isLocalOnly,
        onToggleRegion: (r) {
          _controller.toggleRegionFilter(r);
          _resetFocusAfterFilterChange();
          setState(() {});
        },
        onToggleLanguage: (l) {
          _controller.toggleLanguageFilter(l);
          _resetFocusAfterFilterChange();
          setState(() {});
        },
        onToggleFavorites: () {
          _controller.toggleFavoritesFilter();
          _resetFocusAfterFilterChange();
          setState(() {});
        },
        onToggleLocal: () {
          _controller.toggleLocalFilter();
          _resetFocusAfterFilterChange();
          setState(() {});
        },
        onClearAll: () {
          _controller.clearFilters();
          _resetFocusAfterFilterChange();
          setState(() {});
        },
        onClose: _closeFilter,
      ),
    );
  }

  Widget _buildStartHint(BuildContext context) {
    final rs = context.rs;
    return Positioned(
      bottom: rs.isPortrait ? 56 : 48,
      left: 0,
      right: 0,
      child: Center(
        child: AnimatedOpacity(
          opacity: _showStartHint ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: rs.spacing.md,
              vertical: rs.spacing.sm,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(rs.radius.md),
              border: Border.all(
                color: widget.system.accentColor.withValues(alpha: 0.4),
              ),
            ),
            child: Text(
              L.of(context).gameList_pressMenuHint,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: rs.isSmall ? 11 : 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

