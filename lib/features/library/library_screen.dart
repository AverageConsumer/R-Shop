import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/input/input.dart';
import '../../core/responsive/responsive.dart';
import '../../models/config/app_config.dart';
import '../../models/config/provider_config.dart';
import '../../models/custom_shelf.dart';
import '../../models/game_item.dart';
import '../../models/system_model.dart';
import '../../providers/app_providers.dart';
import '../../providers/download_providers.dart';
import '../../providers/installed_files_provider.dart';
import '../../providers/game_providers.dart';
import '../../providers/shelf_providers.dart';
import '../../services/config_bootstrap.dart';
import '../../services/database_service.dart';
import '../../services/input_debouncer.dart';
import '../../services/thumbnail_service.dart';
import '../../utils/game_metadata.dart';
import '../../utils/image_helper.dart';
import '../game_detail/game_detail_screen.dart';
import '../../widgets/base_game_card.dart';
import '../../widgets/console_hud.dart';
import '../../widgets/download_overlay.dart';
import '../../widgets/quick_menu.dart';
import '../../widgets/selection_aware_item.dart';
import 'shelf_edit_screen.dart';
import 'widgets/library_entry.dart';
import 'widgets/library_tabs.dart';
import 'widgets/reorderable_card_wrapper.dart';
import 'widgets/shelf_picker_dialog.dart';

enum LibrarySortMode { alphabetical, bySystem }

enum ReorderState { none, selecting, grabbed }

class LibraryScreen extends ConsumerStatefulWidget {
  final bool openSearch;
  const LibraryScreen({super.key, this.openSearch = false});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with ConsoleScreenMixin, SearchableScreenMixin {
  static const _fixedTabCount = 3;
  int _selectedTab = 0; // 0=All, 1=Installed, 2=Favorites, 3+=Shelves
  LibrarySortMode _sortMode = LibrarySortMode.alphabetical;
  List<CustomShelf> _shelves = [];

  // Reorder mode
  ReorderState _reorderState = ReorderState.none;
  int _grabbedIndex = -1;
  int? _reorderClaimToken;
  final ValueNotifier<int> _selectedIndexNotifier = ValueNotifier(0);
  int get _currentIndex => _selectedIndexNotifier.value;
  set _currentIndex(int v) {
    _selectedIndexNotifier.value = v;
    _focusManager.setSelectedIndex(v);
  }
  late int _columns;
  String _searchQuery = '';
  bool _isLoading = true;

  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<bool> _scrollSuppression = ValueNotifier(false);
  final Map<int, GlobalKey> _itemKeys = {};

  late InputDebouncer _debouncer;
  late final FocusSyncManager _focusManager;

  ProviderSubscription? _installedFilesSubscription;

  // Raw data from DB
  List<LibraryEntry> _allGames = [];
  Set<String> _installedFiles = {};
  Set<String> _favoriteIds = {};
  // Filtered/sorted view
  List<LibraryEntry> _filteredGames = [];
  // Pre-computed cover URLs per filtered index
  Map<int, List<String>> _coverUrlCache = {};

  int get _totalTabCount => _fixedTabCount + _shelves.length;

  bool get _isShelfTab => _selectedTab >= _fixedTabCount;

  CustomShelf? get _activeShelf {
    if (!_isShelfTab) return null;
    final idx = _selectedTab - _fixedTabCount;
    if (idx < 0 || idx >= _shelves.length) return null;
    return _shelves[idx];
  }

  @override
  String get routeId => 'library';

  @override
  Color get searchAccentColor => Colors.cyanAccent;

  @override
  String get searchHintText => 'Search library...';

  @override
  void onSearchQueryChanged(String query) {
    _searchQuery = query;
    _currentIndex = 0;
    _applyFilters();
  }

  @override
  void onSearchReset() {
    _searchQuery = '';
    _applyFilters();
  }

  @override
  void onSearchSelectionReset() => _currentIndex = 0;

  @override
  Map<ShortcutActivator, Intent>? get additionalShortcuts => {
        // L1/R1 = Zoom (overrides global tab mapping for this screen)
        const SingleActivator(LogicalKeyboardKey.gameButtonLeft1,
                includeRepeats: false):
            const AdjustColumnsIntent(increase: true), // L1 = more columns
        const SingleActivator(LogicalKeyboardKey.gameButtonRight1,
                includeRepeats: false):
            const AdjustColumnsIntent(increase: false), // R1 = fewer columns
        // L2/R2 = Tab switch
        const SingleActivator(LogicalKeyboardKey.gameButtonLeft2,
                includeRepeats: false):
            const TabLeftIntent(),
        const SingleActivator(LogicalKeyboardKey.gameButtonRight2,
                includeRepeats: false):
            const TabRightIntent(),
      };

  @override
  Map<Type, Action<Intent>> get screenActions {
    return {
        NavigateIntent: OverlayGuardedAction<NavigateIntent>(ref,
          onInvoke: (intent) { _navigateGrid(intent.direction); return null; },
          isEnabledOverride: _reorderOrSearchOrNone,
        ),
        AdjustColumnsIntent: OverlayGuardedAction<AdjustColumnsIntent>(ref,
          onInvoke: (intent) { _adjustColumns(intent.increase); return null; },
          isEnabledOverride: searchOrNone,
        ),
        ConfirmIntent: OverlayGuardedAction<ConfirmIntent>(ref,
          onInvoke: (_) { _handleConfirm(); return null; },
          isEnabledOverride: _reorderOrSearchOrNone,
        ),
        BackIntent: OverlayGuardedAction<BackIntent>(ref,
          onInvoke: (_) { _handleBack(); return null; },
          isEnabledOverride: _reorderOrSearchOrNone,
        ),
        SearchIntent: CallbackAction<SearchIntent>(
          onInvoke: (_) {
            toggleSearch();
            return null;
          },
        ),
        TabLeftIntent: TabLeftAction(ref, onTabLeft: _prevTab),
        TabRightIntent: TabRightAction(ref, onTabRight: _nextTab),
        InfoIntent: CallbackAction<InfoIntent>(
          onInvoke: (_) {
            _cycleSortMode();
            return null;
          },
        ),
        FavoriteIntent: OverlayGuardedAction<FavoriteIntent>(ref,
          onInvoke: (_) { _handleFavorite(); return null; },
        ),
        ToggleOverlayIntent: ToggleOverlayAction(ref, onToggle: toggleQuickMenu),
      };
  }

  bool _reorderOrSearchOrNone(dynamic priority) {
    if (_reorderState != ReorderState.none) return true;
    return searchOrNone(priority);
  }

  @override
  void initState() {
    super.initState();
    _columns = ref.read(gridColumnsProvider('library'));
    _debouncer = ref.read(inputDebouncerProvider);
    _shelves = ref.read(customShelvesProvider);

    _focusManager = FocusSyncManager(
      scrollController: _scrollController,
      getCrossAxisCount: () => _columns,
      getItemCount: () => _filteredGames.length,
      getGridRatio: () => 1.0,
      onSelectionChanged: (index) => _selectedIndexNotifier.value = index,
      scrollSuppression: _scrollSuppression,
    );

    initSearch();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
      _installedFilesSubscription = ref.listenManual(installedFilesProvider, (prev, next) {
        if (!mounted) return;
        final data = next.value;
        if (data != null) {
          setState(() => _installedFiles = data.all);
          _applyFilters();
        }
      });
    });
  }

  @override
  void dispose() {
    _exitReorderMode();
    final selectedIndex = _currentIndex;
    Future.microtask(() {
      focusStateManager.saveFocusState(routeId, selectedIndex: selectedIndex);
    });
    _installedFilesSubscription?.close();
    _debouncer.stopHold();
    _focusManager.dispose();
    _scrollController.dispose();
    disposeSearch();
    _scrollSuppression.dispose();
    _selectedIndexNotifier.dispose();
    super.dispose();
  }

  Future<void> _refreshInstalledFiles() async {
    final appConfig =
        ref.read(bootstrappedConfigProvider).value ?? AppConfig.empty;
    final installed = <String>{};
    for (final sysConfig in appConfig.systems) {
      if (sysConfig.targetFolder.isEmpty) continue;
      final dir = Directory(sysConfig.targetFolder);
      if (await dir.exists()) {
        try {
          await for (final entity in dir.list(followLinks: false)) {
            if (entity is File || entity is Directory) {
              installed.add(p.basename(entity.path));
            }
          }
        } catch (e) { debugPrint('LibraryScreen: dir list failed: $e'); }
      }
    }
    if (mounted) {
      setState(() => _installedFiles = installed);
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final db = DatabaseService();

    // Load all games from DB
    final rawGames = await db.getAllGames();

    // Use centralized installed-files index (provider-driven)
    final installedData = ref.read(installedFilesProvider).value;
    if (installedData != null) {
      _installedFiles = installedData.all;
    } else {
      // Provider not ready yet — fall back to direct scan
      await _refreshInstalledFiles();
    }

    final entries = <LibraryEntry>[];
    for (final row in rawGames) {
      final systemSlug = row['systemSlug'] as String;

      ProviderConfig? providerConfig;
      final pcJson = row['provider_config'] as String?;
      if (pcJson != null) {
        try {
          providerConfig = ProviderConfig.fromJson(
              jsonDecode(pcJson) as Map<String, dynamic>);
        } catch (e) { debugPrint('LibraryScreen: provider config parse failed: $e'); }
      }

      final fname = row['filename'] as String;
      entries.add(LibraryEntry(
        filename: fname,
        displayName: GameMetadata.cleanTitle(fname),
        cardTitle: GameMetadata.fileTitle(fname),
        url: row['url'] as String,
        coverUrl: row['cover_url'] as String?,
        systemSlug: systemSlug,
        providerConfig: providerConfig,
        hasThumbnail: (row['has_thumbnail'] as int?) == 1,
      ));
    }

    if (!mounted) return;

    // Trigger deferred migration from displayName → filename favorites
    final allGameItems = entries.map((e) => GameItem(
      filename: e.filename,
      displayName: e.displayName,
      url: e.url,
    )).toList();
    ref.read(favoriteGamesProvider.notifier).migrateIfNeeded(allGameItems);
    final migratedFavorites = ref.read(favoriteGamesProvider).toSet();

    setState(() {
      _allGames = entries;
      _favoriteIds = migratedFavorites;
      _isLoading = false;
    });

    _applyFilters();

    // Restore saved index
    final saved = getSavedFocusState();
    if (saved?.selectedIndex != null && saved!.selectedIndex! > 0) {
      _currentIndex =
          saved.selectedIndex!.clamp(0, _filteredGames.length - 1);
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSelected();
      });
    }

    if (widget.openSearch) {
      openSearch();
    }
  }

  void _applyFilters() {
    List<LibraryEntry> games;
    bool isManualSort = false;
    ShelfSortMode? shelfSortMode;

    if (_isShelfTab) {
      final resolved = _resolveShelfGames();
      games = resolved.games;
      isManualSort = resolved.isManualSort;
      shelfSortMode = resolved.shelfSortMode;
    } else {
      games = List<LibraryEntry>.from(_allGames);
      // Tab filter
      switch (_selectedTab) {
        case 1: // Installed
          games = _deduplicateInstalled(
            games.where((g) => _isGameInstalled(g)).toList(),
          );
        case 2: // Favorites
          games =
              games.where((g) => _favoriteIds.contains(g.filename)).toList();
      }
    }

    // Search filter
    if (_searchQuery.isNotEmpty) {
      final query = GameMetadata.normalizeForSearch(_searchQuery);
      games = games
          .where((g) => GameMetadata.normalizeForSearch(g.displayName).contains(query))
          .toList();
    }

    // Sort (skip for manual-sort shelves)
    if (!isManualSort) {
      final effectiveSort = shelfSortMode != null
          ? (shelfSortMode == ShelfSortMode.bySystem
              ? LibrarySortMode.bySystem
              : LibrarySortMode.alphabetical)
          : _sortMode;
      switch (effectiveSort) {
        case LibrarySortMode.alphabetical:
          games.sort(
              (a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
        case LibrarySortMode.bySystem:
          games.sort((a, b) {
            final cmp = a.systemSlug.compareTo(b.systemSlug);
            if (cmp != 0) return cmp;
            return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
          });
      }
    }

    setState(() {
      _filteredGames = games;
      _rebuildCoverUrlCache();
      _updateItemKeys();
      if (_currentIndex >= _filteredGames.length) {
        _currentIndex =
            _filteredGames.isEmpty ? 0 : _filteredGames.length - 1;
      }
    });
  }

  ({List<LibraryEntry> games, bool isManualSort, ShelfSortMode? shelfSortMode}) _resolveShelfGames() {
    final shelf = _activeShelf;
    if (shelf == null) return (games: <LibraryEntry>[], isManualSort: false, shelfSortMode: null);

    final allGameRecords = _allGames
        .map((g) => (
              filename: g.filename,
              displayName: g.displayName,
              systemSlug: g.systemSlug,
            ))
        .toList();

    final filenames = shelf.resolveFilenames(allGameRecords);
    final lookup = <String, LibraryEntry>{};
    for (final g in _allGames) {
      lookup[g.filename] = g;
    }

    final games = <LibraryEntry>[];
    for (final f in filenames) {
      final entry = lookup[f];
      if (entry != null) games.add(entry);
    }

    return (games: games, isManualSort: shelf.sortMode == ShelfSortMode.manual, shelfSortMode: shelf.sortMode);
  }

  void _updateItemKeys() {
    final count = _filteredGames.length;
    if (_itemKeys.length == count) return;
    _itemKeys.clear();
    for (int i = 0; i < count; i++) {
      _itemKeys[i] = GlobalKey();
    }
  }

  void _rebuildCoverUrlCache() {
    _coverUrlCache = {};
    for (int i = 0; i < _filteredGames.length; i++) {
      final entry = _filteredGames[i];
      final systemModel = SystemModel.supportedSystems
          .where((s) => s.id == entry.systemSlug)
          .firstOrNull;
      if (systemModel != null) {
        _coverUrlCache[i] =
            ImageHelper.getCoverUrlsForSingle(systemModel, entry.filename);
      }
    }
  }

  // --- Tab Navigation ---

  void _nextTab() {
    if (_reorderState != ReorderState.none) return;
    ref.read(feedbackServiceProvider).tick();
    _shelves = ref.read(customShelvesProvider);
    setState(() {
      _selectedTab = (_selectedTab + 1) % _totalTabCount;
      _currentIndex = 0;
    });
    _applyFilters();
    _scrollToTop();
  }

  void _prevTab() {
    if (_reorderState != ReorderState.none) return;
    ref.read(feedbackServiceProvider).tick();
    _shelves = ref.read(customShelvesProvider);
    setState(() {
      _selectedTab = (_selectedTab - 1 + _totalTabCount) % _totalTabCount;
      _currentIndex = 0;
    });
    _applyFilters();
    _scrollToTop();
  }

  void _selectTab(int index) {
    if (index == _selectedTab) return;
    if (_reorderState != ReorderState.none) return;
    ref.read(feedbackServiceProvider).tick();
    _shelves = ref.read(customShelvesProvider);
    setState(() {
      _selectedTab = index;
      _currentIndex = 0;
    });
    _applyFilters();
    _scrollToTop();
  }

  void _cycleSortMode() {
    ref.read(feedbackServiceProvider).tick();

    if (_isShelfTab) {
      final shelf = _activeShelf;
      if (shelf == null) return;
      final next = switch (shelf.sortMode) {
        ShelfSortMode.alphabetical => ShelfSortMode.bySystem,
        ShelfSortMode.bySystem => ShelfSortMode.manual,
        ShelfSortMode.manual => ShelfSortMode.alphabetical,
      };
      ref.read(customShelvesProvider.notifier).updateShelf(
        shelf.id,
        shelf.copyWith(sortMode: next),
      );
      _shelves = ref.read(customShelvesProvider);
    } else {
      _sortMode = _sortMode == LibrarySortMode.alphabetical
          ? LibrarySortMode.bySystem
          : LibrarySortMode.alphabetical;
    }

    setState(() => _currentIndex = 0);
    _applyFilters();
    _scrollToTop();
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  // --- Grid Navigation ---

  void _navigateGrid(GridDirection direction) {
    if (_filteredGames.isEmpty) return;

    if (_reorderState == ReorderState.grabbed) {
      _reorderMove(direction);
      return;
    }

    if (_debouncer.startHold(() {
      if (_focusManager.moveFocus(direction)) {
        _scrollToSelected(instant: _debouncer.isHolding);
      }
    })) {
      ref.read(feedbackServiceProvider).tick();
    }
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

  // --- Scroll Sync ---

  bool _handleScrollNotification(ScrollNotification notification) {
    _focusManager.updateScrollVelocity(notification);
    return _focusManager.handleScrollNotification(notification, context);
  }

  // --- Columns ---

  void _adjustColumns(bool increase) {
    final next = adjustColumnCount(
      current: _columns,
      increase: increase,
      providerKey: 'library',
      ref: ref,
    );
    if (next == _columns) return;
    setState(() => _columns = next);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelected();
    });
  }

  // --- Game Detail ---

  void _openSelectedGame() {
    if (_currentIndex < 0 || _currentIndex >= _filteredGames.length) return;
    final entry = _filteredGames[_currentIndex];
    _openGameDetail(entry);
  }

  Future<void> _openGameDetail(LibraryEntry entry) async {
    searchFieldNode.unfocus();
    suspendSearchOverlay();
    ref.read(feedbackServiceProvider).confirm();

    final appConfig =
        ref.read(bootstrappedConfigProvider).value ?? AppConfig.empty;
    final systemModel = SystemModel.supportedSystems
        .where((s) => s.id == entry.systemSlug)
        .firstOrNull;
    if (systemModel == null) return;

    final systemConfig =
        ConfigBootstrap.configForSystem(appConfig, systemModel);
    final targetFolder = systemConfig?.targetFolder ?? '';

    final game = GameItem(
      filename: entry.filename,
      displayName: entry.displayName,
      url: entry.url,
      cachedCoverUrl: entry.coverUrl,
      providerConfig: entry.providerConfig,
    );

    final isLocalOnly = systemConfig == null || systemConfig.providers.isEmpty;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GameDetailScreen(
          game: game,
          variants: [game],
          system: systemModel,
          targetFolder: targetFolder,
          isLocalOnly: isLocalOnly,
        ),
      ),
    );

    if (mounted) {
      resumeSearchOverlay();
      // Reload to pick up install/favorite/shelf changes
      _favoriteIds = ref.read(favoriteGamesProvider).toSet();
      _shelves = ref.read(customShelvesProvider);
      final data = ref.read(installedFilesProvider).value;
      if (data != null) {
        _installedFiles = data.all;
      }
      _applyFilters();
      if (isSearchActive) {
        requestScreenFocus();
      }
    }
  }

  void _handleConfirm() {
    if (_reorderState == ReorderState.selecting) {
      _grabItem();
      return;
    }
    if (_reorderState == ReorderState.grabbed) {
      _dropItem();
      return;
    }
    _openSelectedGame();
  }

  void _handleBack() {
    ref.read(feedbackServiceProvider).cancel();
    if (_reorderState == ReorderState.grabbed) {
      _dropItem();
      return;
    }
    if (_reorderState == ReorderState.selecting) {
      _exitReorderMode();
      return;
    }
    if (isSearchActive) {
      handleSearchBack();
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _onCoverFound(String url, LibraryEntry entry) async {
    await DatabaseService().updateGameCover(entry.filename, url);
    final idx = _allGames.indexWhere((g) => g.filename == entry.filename);
    if (idx >= 0) {
      _allGames[idx] = LibraryEntry(
        filename: entry.filename,
        displayName: entry.displayName,
        cardTitle: entry.cardTitle,
        url: entry.url,
        coverUrl: url,
        systemSlug: entry.systemSlug,
        providerConfig: entry.providerConfig,
        hasThumbnail: entry.hasThumbnail,
      );
    }
  }

  Future<void> _onThumbnailNeeded(String url, LibraryEntry entry) async {
    if (entry.hasThumbnail) return;
    final result = await ThumbnailService.generateThumbnail(url);
    if (result.success) {
      await DatabaseService().updateGameThumbnailData(
        entry.filename,
        hasThumbnail: true,
      );
      final idx = _allGames.indexWhere((g) => g.filename == entry.filename);
      if (idx >= 0) {
        _allGames[idx] = LibraryEntry(
          filename: entry.filename,
          displayName: entry.displayName,
          cardTitle: entry.cardTitle,
          url: entry.url,
          coverUrl: entry.coverUrl,
          systemSlug: entry.systemSlug,
          providerConfig: entry.providerConfig,
          hasThumbnail: true,
        );
      }
    }
  }

  // --- Reorder Mode ---

  void _enterReorderMode() {
    final shelf = _activeShelf;
    if (shelf == null || shelf.sortMode != ShelfSortMode.manual) return;
    _reorderClaimToken = ref.read(overlayPriorityProvider.notifier).claim(OverlayPriority.dialog);
    setState(() {
      _reorderState = ReorderState.selecting;
      _grabbedIndex = -1;
    });
  }

  void _exitReorderMode() {
    if (_reorderState == ReorderState.none) return;
    final token = _reorderClaimToken;
    if (token != null) {
      _reorderClaimToken = null;
      if (!ref.read(overlayPriorityProvider.notifier).release(token)) {
        ref.read(overlayPriorityProvider.notifier).releaseByPriority(OverlayPriority.dialog);
      }
    }
    setState(() {
      _reorderState = ReorderState.none;
      _grabbedIndex = -1;
    });
  }

  void _grabItem() {
    if (_filteredGames.isEmpty) return;
    ref.read(feedbackServiceProvider).confirm();
    setState(() {
      _reorderState = ReorderState.grabbed;
      _grabbedIndex = _currentIndex;
    });
  }

  void _dropItem() {
    ref.read(feedbackServiceProvider).tick();
    setState(() {
      _reorderState = ReorderState.selecting;
      _grabbedIndex = -1;
    });
  }

  void _reorderMove(GridDirection direction) {
    final shelf = _activeShelf;
    if (shelf == null || _grabbedIndex < 0) return;

    int targetIndex;
    switch (direction) {
      case GridDirection.left:
        targetIndex = _grabbedIndex - 1;
      case GridDirection.right:
        targetIndex = _grabbedIndex + 1;
      case GridDirection.up:
        targetIndex = _grabbedIndex - _columns;
      case GridDirection.down:
        targetIndex = _grabbedIndex + _columns;
    }

    if (targetIndex < 0 || targetIndex >= _filteredGames.length) return;

    ref.read(feedbackServiceProvider).tick();
    ref.read(customShelvesProvider.notifier).reorderGameInShelf(
      shelf.id,
      _grabbedIndex,
      targetIndex,
      resolvedOrder: _filteredGames.map((g) => g.filename).toList(),
    );
    _shelves = ref.read(customShelvesProvider);
    _applyFilters();
    setState(() {
      _grabbedIndex = targetIndex;
      _currentIndex = targetIndex;
    });
    _scrollToSelected();
  }

  // --- Shelf Management ---

  Future<void> _createShelf() async {
    final allGameRecords = _allGames.map((g) => (
      filename: g.filename,
      displayName: g.displayName,
      systemSlug: g.systemSlug,
    )).toList();
    final shelf = await Navigator.push<CustomShelf>(
      context,
      MaterialPageRoute(builder: (_) => ShelfEditScreen(allGameRecords: allGameRecords)),
    );
    if (shelf != null && mounted) {
      ref.read(customShelvesProvider.notifier).addShelf(shelf);
      _shelves = ref.read(customShelvesProvider);
      setState(() {
        _selectedTab = _fixedTabCount + _shelves.length - 1;
        _currentIndex = 0;
      });
      _applyFilters();
      _scrollToTop();
    }
  }

  Future<void> _editShelf() async {
    final shelf = _activeShelf;
    if (shelf == null) return;
    final allGameRecords = _allGames.map((g) => (
      filename: g.filename,
      displayName: g.displayName,
      systemSlug: g.systemSlug,
    )).toList();
    final updated = await Navigator.push<CustomShelf>(
      context,
      MaterialPageRoute(builder: (_) => ShelfEditScreen(shelf: shelf, allGameRecords: allGameRecords)),
    );
    if (!mounted) return;
    if (updated != null) {
      ref.read(customShelvesProvider.notifier).updateShelf(shelf.id, updated);
    }
    // Always refresh — shelf may have been deleted from edit screen
    _shelves = ref.read(customShelvesProvider);
    final stillExists = _shelves.any((s) => s.id == shelf.id);
    if (!stillExists) {
      setState(() {
        _selectedTab = (_selectedTab - 1).clamp(0, _totalTabCount - 1);
      });
    }
    _currentIndex = 0;
    _applyFilters();
    _scrollToTop();
  }

  void _addCurrentGameToShelf() {
    if (_currentIndex < 0 || _currentIndex >= _filteredGames.length) return;
    if (_shelves.isEmpty) return;
    final entry = _filteredGames[_currentIndex];
    final availableShelves = _shelves
        .where((s) => !s.containsGame(
            entry.filename, entry.displayName, entry.systemSlug))
        .toList();
    if (availableShelves.isEmpty) return;
    showShelfPickerDialog(
      context: context,
      ref: ref,
      shelves: availableShelves,
      onSelect: (shelfId) {
        ref.read(customShelvesProvider.notifier).addGameToShelf(shelfId, entry.filename);
        _shelves = ref.read(customShelvesProvider);
        _applyFilters();
      },
    );
  }

  void _removeCurrentGameFromShelf() {
    final shelf = _activeShelf;
    if (shelf == null) return;
    if (_currentIndex < 0 || _currentIndex >= _filteredGames.length) return;
    final entry = _filteredGames[_currentIndex];
    final matchesFilter = shelf.filterRules.any(
      (r) => r.matches(entry.displayName, entry.systemSlug),
    );
    if (matchesFilter) {
      // Filter-matched: must explicitly exclude so filter doesn't re-add it
      ref.read(customShelvesProvider.notifier).excludeGameFromShelf(shelf.id, entry.filename);
    } else {
      // Truly manual: just remove from manualGameIds, no exclusion needed
      ref.read(customShelvesProvider.notifier).removeGameFromShelf(shelf.id, entry.filename);
    }
    _shelves = ref.read(customShelvesProvider);
    _applyFilters();
  }

  void _handleFavorite() {
    if (_currentIndex < 0 || _currentIndex >= _filteredGames.length) return;
    final entry = _filteredGames[_currentIndex];
    ref.read(feedbackServiceProvider).tick();
    ref.read(favoriteGamesProvider.notifier).toggleFavorite(entry.filename);
    _favoriteIds = ref.read(favoriteGamesProvider).toSet();
    _applyFilters();
  }

  List<QuickMenuItem?> _buildQuickMenuItems() {
    final sortLabel = _isShelfTab
        ? switch (_activeShelf?.sortMode ?? ShelfSortMode.alphabetical) {
            ShelfSortMode.alphabetical => 'Sort by System',
            ShelfSortMode.bySystem => 'Sort Manual',
            ShelfSortMode.manual => 'Sort A-Z',
          }
        : _sortMode == LibrarySortMode.alphabetical
            ? 'Sort by System'
            : 'Sort A-Z';
    final hasDownloads = ref.read(hasQueueItemsProvider);
    final shelf = _activeShelf;
    return [
      QuickMenuItem(
        label: 'Search',
        icon: Icons.search_rounded,
        shortcutHint: 'Y',
        onSelect: openSearch,
      ),
      if (_filteredGames.isNotEmpty) ...[
        QuickMenuItem(
          label: _favoriteIds.contains(_filteredGames[_currentIndex].filename)
              ? 'Unfavorite' : 'Favorite',
          icon: _favoriteIds.contains(_filteredGames[_currentIndex].filename)
              ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          shortcutHint: '−',
          onSelect: _handleFavorite,
        ),
      ],
      QuickMenuItem(
        label: sortLabel,
        icon: Icons.sort_rounded,
        shortcutHint: 'X',
        onSelect: _cycleSortMode,
      ),
      // --- Shelf management ---
      null,
      QuickMenuItem(
        label: 'New Shelf',
        icon: Icons.create_new_folder_rounded,
        onSelect: _createShelf,
      ),
      if (shelf != null)
        QuickMenuItem(
          label: 'Edit Shelf',
          icon: Icons.edit_rounded,
          onSelect: _editShelf,
        ),
      if (_filteredGames.isNotEmpty && _shelves.any((s) => !s.containsGame(
          _filteredGames[_currentIndex].filename,
          _filteredGames[_currentIndex].displayName,
          _filteredGames[_currentIndex].systemSlug)))
        QuickMenuItem(
          label: 'Add to Shelf',
          icon: Icons.playlist_add_rounded,
          onSelect: _addCurrentGameToShelf,
        ),
      if (shelf != null && _filteredGames.isNotEmpty)
        QuickMenuItem(
          label: 'Remove from Shelf',
          icon: Icons.playlist_remove_rounded,
          onSelect: _removeCurrentGameFromShelf,
        ),
      if (shelf != null && shelf.sortMode == ShelfSortMode.manual && _filteredGames.length > 1)
        QuickMenuItem(
          label: 'Reorder Games',
          icon: Icons.swap_vert_rounded,
          onSelect: _enterReorderMode,
        ),
      // --- Downloads ---
      if (hasDownloads) ...[
        null,
        QuickMenuItem(
          label: 'Downloads',
          icon: Icons.download_rounded,
          onSelect: () => toggleDownloadOverlay(ref),
          highlight: true,
        ),
      ],
    ];
  }

  // --- Key Events ---

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    final searchResult = handleSearchKeyEvent(event);
    if (searchResult != null) return searchResult;
    if (event is KeyUpEvent) {
      _debouncer.stopHold();
      return KeyEventResult.ignored;
    }
    return KeyEventResult.ignored;
  }

  // --- Count helpers ---

  bool _isGameInstalled(LibraryEntry entry) {
    final filename = entry.filename;
    if (_installedFiles.contains(filename)) return true;
    // Strip archive extension for extracted ROM match
    for (final ext in SystemModel.archiveExtensions) {
      if (filename.toLowerCase().endsWith(ext)) {
        final stripped = filename.substring(0, filename.length - ext.length);
        // Folder match (multi-file games)
        if (_installedFiles.contains(stripped)) return true;
        // ROM extension replacement (like RomManager.getTargetFilename)
        final system = SystemModel.supportedSystems
            .where((s) => s.id == entry.systemSlug)
            .firstOrNull;
        if (system != null) {
          for (final romExt in system.romExtensions) {
            if (_installedFiles.contains('$stripped$romExt')) return true;
          }
        }
        return false;
      }
    }
    return false;
  }

  /// Deduplicates installed entries that share the same display name and system
  /// (e.g., Mario.iso and Mario.zip both matching after archive-fallback).
  /// Prefers the entry with an exact filesystem match.
  List<LibraryEntry> _deduplicateInstalled(List<LibraryEntry> games) {
    final seen = <String, LibraryEntry>{};
    for (final game in games) {
      final key = '${game.systemSlug}::${game.displayName.toLowerCase()}';
      final existing = seen[key];
      if (existing == null) {
        seen[key] = game;
      } else {
        final gameIsExact = _installedFiles.contains(game.filename);
        final existingIsExact = _installedFiles.contains(existing.filename);
        if (gameIsExact && !existingIsExact) {
          seen[key] = game;
        }
      }
    }
    return seen.values.toList();
  }

  int get _allCount => _allGames.length;

  int get _installedCount =>
      _deduplicateInstalled(
        _allGames.where((g) => _isGameInstalled(g)).toList(),
      ).length;

  int get _favoritesCount =>
      _allGames.where((g) => _favoriteIds.contains(g.filename)).length;

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final baseTopPadding = rs.safeAreaTop + (rs.isSmall ? 72 : 96);
    final searchExtraPadding = isSearchActive ? (rs.isSmall ? 16.0 : 20.0) : 0.0;
    final topPadding = baseTopPadding + searchExtraPadding;

    return buildWithActions(
      PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _handleBack();
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              // Grid content (behind header)
              Padding(
                padding: EdgeInsets.only(top: topPadding),
                child: _buildContent(rs),
              ),
              // Header (over grid, with gradient fade)
              _buildHeader(rs),
              // Search bar
              if (isSearchActive) _buildSearchBar(),
              // HUD
              if (!showQuickMenu) _buildHud(),
              // Quick Menu
              if (showQuickMenu)
                QuickMenuOverlay(
                  items: _buildQuickMenuItems(),
                  onClose: closeQuickMenu,
                ),
            ],
          ),
        ),
      ),
      onKeyEvent: _handleKeyEvent,
    );
  }

  Widget _buildHeader(Responsive rs) {
    final fixedLabels = ['All', 'Installed', 'Favorites'];
    final fixedCounts = [_allCount, _installedCount, _favoritesCount];

    final tabs = <LibraryTab>[
      for (int i = 0; i < _fixedTabCount; i++)
        LibraryTab(label: fixedLabels[i], count: fixedCounts[i]),
      for (final shelf in _shelves)
        LibraryTab(
          label: shelf.name,
          count: _shelfGameCount(shelf),
          isCustomShelf: true,
        ),
    ];

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black,
              Color.fromRGBO(0, 0, 0, 0.9),
              Color.fromRGBO(0, 0, 0, 0.6),
              Colors.transparent,
            ],
            stops: [0.0, 0.5, 0.8, 1.0],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: rs.isSmall ? 16.0 : 24.0,
              vertical: rs.isSmall ? 8.0 : 12.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'LIBRARY',
                      style: TextStyle(
                        fontSize: rs.isSmall ? 18 : 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 4,
                      ),
                    ),
                    const Spacer(),
                    // Sort indicator
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _isShelfTab
                            ? switch (_activeShelf?.sortMode ?? ShelfSortMode.alphabetical) {
                                ShelfSortMode.alphabetical => 'A-Z',
                                ShelfSortMode.bySystem => 'BY SYSTEM',
                                ShelfSortMode.manual => 'MANUAL',
                              }
                            : _sortMode == LibrarySortMode.alphabetical
                                ? 'A-Z'
                                : 'BY SYSTEM',
                        style: TextStyle(
                          fontSize: rs.isSmall ? 9 : 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[400],
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: rs.isSmall ? 6 : 10),
                LibraryTabs(
                  selectedTab: _selectedTab,
                  tabs: tabs,
                  accentColor: Colors.cyanAccent,
                  onTap: _selectTab,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int _shelfGameCount(CustomShelf shelf) {
    final allGameRecords = _allGames
        .map((g) => (
              filename: g.filename,
              displayName: g.displayName,
              systemSlug: g.systemSlug,
            ))
        .toList();
    return shelf.resolveFilenames(allGameRecords).length;
  }

  Widget _buildSearchBar() {
    return buildSearchWidget(searchQuery: _searchQuery);
  }

  Widget _buildContent(Responsive rs) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.cyanAccent),
      );
    }

    if (_filteredGames.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.library_books_outlined,
                size: 64, color: Colors.grey[700]),
            const SizedBox(height: 16),
            Text(
              _selectedTab == 1
                  ? 'No installed games'
                  : _selectedTab == 2
                      ? 'No favorites yet'
                      : _isShelfTab
                          ? (_searchQuery.isNotEmpty
                              ? 'No results for "$_searchQuery"'
                              : 'No games in this shelf')
                          : _searchQuery.isNotEmpty
                              ? 'No results for "$_searchQuery"'
                              : 'No games in library',
              style: TextStyle(color: Colors.grey[500], fontSize: 16),
            ),
            if (_allGames.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Games will appear after sync completes',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ],
        ),
      );
    }

    final deviceMemory = ref.read(deviceMemoryProvider);
    final gridPadding = rs.spacing.lg * 2;
    final spacing = rs.isSmall ? 10.0 : 16.0;
    final gridWidth = MediaQuery.of(context).size.width - gridPadding;
    final itemWidth = (gridWidth - (_columns - 1) * spacing) / _columns;
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final optimalCacheWidth =
        (itemWidth * dpr).round().clamp(150, deviceMemory.memCacheWidthMax);

    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: RepaintBoundary(
        child: GridView.builder(
        cacheExtent: deviceMemory.libraryCacheExtent,
        controller: _scrollController,
        padding: EdgeInsets.only(
          left: rs.spacing.lg,
          right: rs.spacing.lg,
          top: rs.spacing.md,
          bottom: rs.isPortrait ? 80 : 100,
        ),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _columns,
          mainAxisSpacing: rs.isSmall ? 10 : 16,
          crossAxisSpacing: rs.isSmall ? 10 : 16,
          childAspectRatio: 1.0,
        ),
        itemCount: _filteredGames.length,
        itemBuilder: (context, index) {
        final entry = _filteredGames[index];
        final isInstalled = _isGameInstalled(entry);
        final isFavorite = _favoriteIds.contains(entry.filename);

        final coverUrls = _coverUrlCache[index] ?? const [];

        final systemModel = SystemModel.supportedSystems
            .where((s) => s.id == entry.systemSlug)
            .firstOrNull;

        // Short system label for badge
        final systemLabel = _systemShortLabel(entry.systemSlug);
        final systemColor =
            systemModel?.accentColor ?? Colors.grey;

        final isGrabbed = _reorderState == ReorderState.grabbed && _grabbedIndex == index;
        final isReordering = _reorderState != ReorderState.none;

        Widget card = RepaintBoundary(
          key: _itemKeys[index],
          child: SelectionAwareItem(
            selectedIndexNotifier: _selectedIndexNotifier,
            index: index,
            builder: (isSelected) => BaseGameCard(
              displayName: entry.cardTitle,
              systemLabel: systemLabel,
              accentColor: systemColor,
              coverUrls: coverUrls,
              cachedUrl: entry.coverUrl,
              hasThumbnail: entry.hasThumbnail,
              memCacheWidth: optimalCacheWidth,
              scrollSuppression: _scrollSuppression,
              isInstalled: isInstalled,
              isSelected: isSelected,
              isFavorite: isFavorite,
              onCoverFound: (url) => _onCoverFound(url, entry),
              onThumbnailNeeded: (url) => _onThumbnailNeeded(url, entry),
              onTap: () {
                if (_reorderState == ReorderState.selecting) {
                  _currentIndex = index;
                  _grabItem();
                  return;
                }
                if (_reorderState == ReorderState.grabbed) return;
                if (_currentIndex == index) {
                  _openGameDetail(entry);
                } else {
                  _currentIndex = index;
                  ref.read(feedbackServiceProvider).tick();
                }
              },
              onTapSelect: () {
                if (_reorderState != ReorderState.none) return;
                if (_currentIndex != index) {
                  _currentIndex = index;
                  ref.read(feedbackServiceProvider).tick();
                }
              },
              onLongPress: isReordering ? null : () {
                if (_isShelfTab && _activeShelf?.sortMode == ShelfSortMode.manual) {
                  _currentIndex = index;
                  _enterReorderMode();
                  _grabItem();
                }
              },
            ),
          ),
        );

        if (isReordering) {
          card = ReorderableCardWrapper(
            isJiggling: _reorderState == ReorderState.selecting,
            isGrabbed: isGrabbed,
            child: card,
          );
        }

        return card;
      },
      ),
      ),
    );
  }

  Widget _buildHud() {
    if (_reorderState == ReorderState.grabbed) {
      return ConsoleHud(
        dpad: (label: '\u2190\u2191\u2193\u2192', action: 'Move'),
        a: HudAction('Drop', onTap: _dropItem),
        b: HudAction('Cancel', onTap: _dropItem),
      );
    }
    if (_reorderState == ReorderState.selecting) {
      return ConsoleHud(
        a: HudAction('Grab', onTap: _grabItem),
        b: HudAction('Done', onTap: _exitReorderMode),
      );
    }
    if (isSearchActive) {
      return buildSearchHud(
        aAction: HudAction('Select', onTap: _openSelectedGame),
      );
    }

    return ConsoleHud(
      a: HudAction('Select', onTap: _openSelectedGame),
      b: HudAction('Back', onTap: () => Navigator.pop(context)),
      start: HudAction('Menu', onTap: toggleQuickMenu),
    );
  }

  static String _systemShortLabel(String slug) {
    const labels = {
      'nes': 'NES',
      'snes': 'SNES',
      'n64': 'N64',
      'gc': 'GCN',
      'wii': 'Wii',
      'wiiu': 'Wii U',
      'switch': 'Switch',
      'gb': 'GB',
      'gbc': 'GBC',
      'gba': 'GBA',
      'nds': 'NDS',
      'n3ds': '3DS',
      'psx': 'PS1',
      'ps2': 'PS2',
      'ps3': 'PS3',
      'psp': 'PSP',
      'psvita': 'Vita',
      'mastersystem': 'SMS',
      'megadrive': 'MD',
      'gamegear': 'GG',
      'dreamcast': 'DC',
      'saturn': 'Saturn',
      'segacd': 'SCD',
      'sega32x': '32X',
      'atari2600': '2600',
      'atari5200': '5200',
      'atari7800': '7800',
      'lynx': 'Lynx',
      'pico8': 'P-8',
    };
    return labels[slug] ?? slug.toUpperCase();
  }
}

