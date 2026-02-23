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
import '../../models/game_item.dart';
import '../../models/system_model.dart';
import '../../providers/app_providers.dart';
import '../../providers/download_providers.dart';
import '../../providers/installed_files_provider.dart';
import '../../providers/game_providers.dart';
import '../../services/config_bootstrap.dart';
import '../../services/database_service.dart';
import '../../services/input_debouncer.dart';
import '../../utils/game_metadata.dart';
import '../../utils/image_helper.dart';
import '../game_detail/game_detail_screen.dart';
import '../../widgets/base_game_card.dart';
import '../../widgets/console_hud.dart';
import '../../widgets/download_overlay.dart';
import '../../widgets/quick_menu.dart';
import '../../widgets/selection_aware_item.dart';
import 'widgets/library_tabs.dart';

enum LibrarySortMode { alphabetical, bySystem }

class LibraryScreen extends ConsumerStatefulWidget {
  final bool openSearch;
  const LibraryScreen({super.key, this.openSearch = false});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with ConsoleScreenMixin, SearchableScreenMixin {
  int _selectedTab = 0; // 0=All, 1=Installed, 2=Favorites
  LibrarySortMode _sortMode = LibrarySortMode.alphabetical;
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
  List<_LibraryEntry> _allGames = [];
  Set<String> _installedFiles = {};
  Set<String> _favoriteIds = {};
  // Filtered/sorted view
  List<_LibraryEntry> _filteredGames = [];

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
        ToggleOverlayIntent: ToggleOverlayAction(ref, onToggle: toggleQuickMenu),
      };
  }

  @override
  void initState() {
    super.initState();
    _columns = ref.read(gridColumnsProvider('library'));
    _debouncer = ref.read(inputDebouncerProvider);

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
    final favorites = ref.read(favoriteGamesProvider).toSet();

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

    final entries = <_LibraryEntry>[];
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

      entries.add(_LibraryEntry(
        filename: row['filename'] as String,
        displayName: GameMetadata.cleanTitle(row['filename'] as String),
        url: row['url'] as String,
        coverUrl: row['cover_url'] as String?,
        systemSlug: systemSlug,
        providerConfig: providerConfig,
        hasThumbnail: (row['has_thumbnail'] as int?) == 1,
      ));
    }

    if (!mounted) return;

    setState(() {
      _allGames = entries;
      _favoriteIds = favorites;
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
    var games = List<_LibraryEntry>.from(_allGames);

    // Tab filter
    switch (_selectedTab) {
      case 1: // Installed
        games = games
            .where((g) => _isGameInstalled(g))
            .toList();
      case 2: // Favorites
        games =
            games.where((g) => _favoriteIds.contains(g.displayName)).toList();
    }

    // Search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      games = games
          .where((g) => g.displayName.toLowerCase().contains(query))
          .toList();
    }

    // Sort
    switch (_sortMode) {
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

    setState(() {
      _filteredGames = games;
      _updateItemKeys();
      if (_currentIndex >= _filteredGames.length) {
        _currentIndex =
            _filteredGames.isEmpty ? 0 : _filteredGames.length - 1;
      }
    });
  }

  void _updateItemKeys() {
    _itemKeys.clear();
    for (int i = 0; i < _filteredGames.length; i++) {
      _itemKeys[i] = GlobalKey();
    }
  }

  // --- Tab Navigation ---

  void _nextTab() {
    ref.read(feedbackServiceProvider).tick();
    setState(() {
      _selectedTab = (_selectedTab + 1) % 3;
      _currentIndex = 0;
    });
    _applyFilters();
    _scrollToTop();
  }

  void _prevTab() {
    ref.read(feedbackServiceProvider).tick();
    setState(() {
      _selectedTab = (_selectedTab - 1 + 3) % 3;
      _currentIndex = 0;
    });
    _applyFilters();
    _scrollToTop();
  }

  void _selectTab(int index) {
    if (index == _selectedTab) return;
    ref.read(feedbackServiceProvider).tick();
    setState(() {
      _selectedTab = index;
      _currentIndex = 0;
    });
    _applyFilters();
    _scrollToTop();
  }

  void _cycleSortMode() {
    ref.read(feedbackServiceProvider).tick();
    setState(() {
      _sortMode = _sortMode == LibrarySortMode.alphabetical
          ? LibrarySortMode.bySystem
          : LibrarySortMode.alphabetical;
      _currentIndex = 0;
    });
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

  Future<void> _openGameDetail(_LibraryEntry entry) async {
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
      // Reload to pick up install/favorite changes
      _favoriteIds = ref.read(favoriteGamesProvider).toSet();
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

  void _handleBack() {
    ref.read(feedbackServiceProvider).cancel();
    if (isSearchActive) {
      handleSearchBack();
    } else {
      Navigator.pop(context);
    }
  }

  List<QuickMenuItem> _buildQuickMenuItems() {
    final sortLabel =
        _sortMode == LibrarySortMode.alphabetical ? 'Sort by System' : 'Sort A-Z';
    final hasDownloads = ref.read(hasQueueItemsProvider);
    return [
      QuickMenuItem(
        label: 'Search',
        icon: Icons.search_rounded,
        shortcutHint: 'Y',
        onSelect: openSearch,
      ),
      QuickMenuItem(
        label: sortLabel,
        icon: Icons.sort_rounded,
        shortcutHint: 'X',
        onSelect: _cycleSortMode,
      ),
      QuickMenuItem(
        label: 'Prev Tab',
        icon: Icons.chevron_left_rounded,
        shortcutHint: 'ZL',
        onSelect: _prevTab,
      ),
      QuickMenuItem(
        label: 'Next Tab',
        icon: Icons.chevron_right_rounded,
        shortcutHint: 'ZR',
        onSelect: _nextTab,
      ),
      QuickMenuItem(
        label: 'Zoom In',
        icon: Icons.zoom_in_rounded,
        shortcutHint: 'R',
        onSelect: () => _adjustColumns(false),
      ),
      QuickMenuItem(
        label: 'Zoom Out',
        icon: Icons.zoom_out_rounded,
        shortcutHint: 'L',
        onSelect: () => _adjustColumns(true),
      ),
      if (hasDownloads)
        QuickMenuItem(
          label: 'Downloads',
          icon: Icons.download_rounded,
          onSelect: () => toggleDownloadOverlay(ref),
          highlight: true,
        ),
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

  bool _isGameInstalled(_LibraryEntry entry) {
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

  int get _allCount => _allGames.length;

  int get _installedCount =>
      _allGames.where((g) => _isGameInstalled(g)).length;

  int get _favoritesCount =>
      _allGames.where((g) => _favoriteIds.contains(g.displayName)).length;

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
    final tabLabels = ['All', 'Installed', 'Favorites'];
    final tabCounts = [_allCount, _installedCount, _favoritesCount];

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
                        _sortMode == LibrarySortMode.alphabetical
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
                  tabs: List.generate(
                    3,
                    (i) => LibraryTab(
                      label: tabLabels[i],
                      count: tabCounts[i],
                    ),
                  ),
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

    final gridPadding = rs.spacing.lg * 2;
    final spacing = rs.isSmall ? 10.0 : 16.0;
    final gridWidth = MediaQuery.of(context).size.width - gridPadding;
    final itemWidth = (gridWidth - (_columns - 1) * spacing) / _columns;
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final optimalCacheWidth = (itemWidth * dpr).round().clamp(150, 500);

    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: RepaintBoundary(
        child: GridView.builder(
        cacheExtent: 600,
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
        final isFavorite = _favoriteIds.contains(entry.displayName);

        final systemModel = SystemModel.supportedSystems
            .where((s) => s.id == entry.systemSlug)
            .firstOrNull;

        final coverUrls = systemModel != null
            ? ImageHelper.getCoverUrlsForSingle(systemModel, entry.filename)
            : <String>[];

        // Short system label for badge
        final systemLabel = _systemShortLabel(entry.systemSlug);
        final systemColor =
            systemModel?.accentColor ?? Colors.grey;

        return RepaintBoundary(
          key: _itemKeys[index],
          child: SelectionAwareItem(
            selectedIndexNotifier: _selectedIndexNotifier,
            index: index,
            builder: (isSelected) => BaseGameCard(
              displayName: entry.displayName,
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
              onTap: () {
                if (_currentIndex == index) {
                  _openGameDetail(entry);
                } else {
                  _currentIndex = index;
                  ref.read(feedbackServiceProvider).tick();
                }
              },
              onTapSelect: () {
                if (_currentIndex != index) {
                  _currentIndex = index;
                  ref.read(feedbackServiceProvider).tick();
                }
              },
            ),
          ),
        );
      },
      ),
      ),
    );
  }

  Widget _buildHud() {
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
      'ps4': 'PS4',
      'psp': 'PSP',
      'psvita': 'Vita',
      'mastersystem': 'SMS',
      'megadrive': 'MD',
      'gamegear': 'GG',
      'dreamcast': 'DC',
      'saturn': 'Saturn',
      'ngpc': 'NGPC',
      'arcade': 'Arcade',
      'xbox': 'Xbox',
      'xbox360': 'X360',
    };
    return labels[slug] ?? slug.toUpperCase();
  }
}

class _LibraryEntry {
  final String filename;
  final String displayName;
  final String url;
  final String? coverUrl;
  final String systemSlug;
  final ProviderConfig? providerConfig;
  final bool hasThumbnail;

  const _LibraryEntry({
    required this.filename,
    required this.displayName,
    required this.url,
    this.coverUrl,
    required this.systemSlug,
    this.providerConfig,
    this.hasThumbnail = false,
  });
}

