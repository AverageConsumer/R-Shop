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
import 'widgets/library_tabs.dart';

enum LibrarySortMode { alphabetical, bySystem }

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with ConsoleScreenMixin {
  int _selectedTab = 0; // 0=All, 1=Installed, 2=Favorites
  LibrarySortMode _sortMode = LibrarySortMode.alphabetical;
  int _currentIndex = 0;
  late int _columns;
  String _searchQuery = '';
  bool _isSearching = false;
  bool _isSearchFocused = false;
  bool _isClosingSearch = false;
  bool _isLoading = true;
  bool _showQuickMenu = false;

  final ScrollController _scrollController = ScrollController();
  final FocusNode _searchFocusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();
  final Map<int, GlobalKey> _itemKeys = {};

  late InputDebouncer _debouncer;

  bool _isProgrammaticScroll = false;
  bool _isHardwareInput = false;
  Timer? _hardwareInputTimer;

  // Raw data from DB
  List<_LibraryEntry> _allGames = [];
  Set<String> _installedFiles = {};
  Set<String> _favoriteIds = {};
  // Filtered/sorted view
  List<_LibraryEntry> _filteredGames = [];

  @override
  String get routeId => 'library';

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
  Map<Type, Action<Intent>> get screenActions => {
        NavigateIntent: _LibraryNavigateAction(this),
        AdjustColumnsIntent: _LibraryAdjustColumnsAction(this),
        ConfirmIntent: CallbackAction<ConfirmIntent>(
          onInvoke: (_) {
            _openSelectedGame();
            return null;
          },
        ),
        BackIntent: _LibraryBackAction(this),
        SearchIntent: CallbackAction<SearchIntent>(
          onInvoke: (_) {
            _toggleSearch();
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
        ToggleOverlayIntent: ToggleOverlayAction(ref, onToggle: _toggleQuickMenu),
      };

  @override
  void initState() {
    super.initState();
    _columns = ref.read(gridColumnsProvider('library'));
    _debouncer = ref.read(inputDebouncerProvider);
    _searchFocusNode.addListener(_onSearchFocusChange);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(mainFocusRequestProvider.notifier).state = screenFocusNode;
      _loadData();
    });
  }

  @override
  void dispose() {
    final selectedIndex = _currentIndex;
    Future.delayed(Duration.zero, () {
      focusStateManager.saveFocusState(routeId, selectedIndex: selectedIndex);
    });
    _hardwareInputTimer?.cancel();
    _debouncer.stopHold();
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final db = DatabaseService();
    final appConfig =
        ref.read(bootstrappedConfigProvider).value ?? AppConfig.empty;

    // Load all games from DB
    final rawGames = await db.getAllGames();
    final favorites = ref.read(favoriteGamesProvider).toSet();

    // Scan installed files for all configured systems
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
        } catch (_) {}
      }
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
        } catch (_) {}
      }

      entries.add(_LibraryEntry(
        filename: row['filename'] as String,
        displayName: GameMetadata.cleanTitle(row['filename'] as String),
        url: row['url'] as String,
        coverUrl: row['cover_url'] as String?,
        systemSlug: systemSlug,
        providerConfig: providerConfig,
      ));
    }

    if (!mounted) return;

    setState(() {
      _allGames = entries;
      _installedFiles = installed;
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
  }

  void _applyFilters() {
    var games = List<_LibraryEntry>.from(_allGames);

    // Tab filter
    switch (_selectedTab) {
      case 1: // Installed
        games = games
            .where((g) => _isGameInstalled(g.filename))
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

  // --- Search ---

  void _toggleSearch() {
    ref.read(feedbackServiceProvider).tick();
    if (_isSearching) {
      _closeSearch();
    } else {
      _openSearch();
    }
  }

  void _openSearch() {
    _searchController.clear();
    _searchQuery = '';
    _isClosingSearch = false;
    setState(() => _isSearching = true);
    _applyFilters();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isSearching) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  void _closeSearch() {
    _isClosingSearch = true;
    FocusManager.instance.primaryFocus?.unfocus();
    FocusScope.of(context).unfocus();

    _searchController.clear();
    _searchQuery = '';
    _applyFilters();

    setState(() {
      _isSearching = false;
      _isSearchFocused = false;
      _currentIndex = 0;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) requestScreenFocus();
      _isClosingSearch = false;
    });
  }

  void _onSearchChanged(String query) {
    _searchQuery = query;
    _currentIndex = 0;
    _applyFilters();
  }

  void _unfocusSearch() {
    _searchFocusNode.unfocus();
    setState(() => _isSearchFocused = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) requestScreenFocus();
    });
  }

  void _onSearchSubmitted() {
    _unfocusSearch();
  }

  void _onSearchFocusChange() {
    if (!mounted) return;
    final hasFocus = _searchFocusNode.hasFocus;
    setState(() => _isSearchFocused = hasFocus);

    if (!hasFocus && _isSearching && !_isClosingSearch) {
      if (!screenFocusNode.hasFocus) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _isSearching && !_isClosingSearch &&
              !_searchFocusNode.hasFocus) {
            requestScreenFocus();
          }
        });
      }
    }
  }

  // --- Grid Navigation ---

  void _setHardwareInputActive() {
    _isHardwareInput = true;
    _hardwareInputTimer?.cancel();
    _hardwareInputTimer = Timer(const Duration(milliseconds: 500), () {
      _isHardwareInput = false;
    });
  }

  void _navigateGrid(GridDirection direction) {
    if (_filteredGames.isEmpty) return;

    if (_debouncer.startHold(() {
      _setHardwareInputActive();
      int newIndex = _currentIndex;
      switch (direction) {
        case GridDirection.left:
          if (_currentIndex % _columns > 0) newIndex--;
        case GridDirection.right:
          if ((_currentIndex + 1) % _columns > 0 &&
              _currentIndex + 1 < _filteredGames.length) {
            newIndex++;
          }
        case GridDirection.up:
          if (_currentIndex - _columns >= 0) {
            newIndex -= _columns;
          } else if (_isSearching) {
            _searchFocusNode.requestFocus();
            return;
          }
        case GridDirection.down:
          if (_currentIndex + _columns < _filteredGames.length) {
            newIndex += _columns;
          }
      }
      if (newIndex != _currentIndex) {
        setState(() => _currentIndex = newIndex);
        _scrollToSelected(instant: _debouncer.isHolding);
      }
    })) {
      ref.read(feedbackServiceProvider).tick();
    }
  }

  void _scrollToSelected({bool instant = false}) {
    final key = _itemKeys[_currentIndex];
    if (key?.currentContext != null) {
      _isProgrammaticScroll = true;
      Scrollable.ensureVisible(
        key!.currentContext!,
        alignment: 0.5,
        duration: instant ? Duration.zero : const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      ).then((_) {
        Future.delayed(const Duration(milliseconds: 100), () {
          _isProgrammaticScroll = false;
        });
      });
      return;
    }

    if (!_scrollController.hasClients) return;
    final row = _currentIndex ~/ _columns;
    final totalRows =
        (_filteredGames.length + _columns - 1) ~/ _columns;
    if (totalRows <= 1) return;
    final maxExtent = _scrollController.position.maxScrollExtent;
    final estimatedOffset =
        (maxExtent * row / (totalRows - 1)).clamp(0.0, maxExtent);
    _isProgrammaticScroll = true;
    _scrollController.jumpTo(estimatedOffset);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollToSelected(instant: true);
    });
  }

  // --- Scroll Sync ---

  bool _handleScrollNotification(ScrollNotification notification) {
    if (_isProgrammaticScroll) return false;
    if (notification is ScrollEndNotification && !_isHardwareInput) {
      _syncFocusToVisibleArea();
    }
    return false;
  }

  void _syncFocusToVisibleArea() {
    if (!_scrollController.hasClients ||
        _isHardwareInput ||
        _filteredGames.isEmpty) {
      return;
    }

    final screenHeight = MediaQuery.of(context).size.height;
    final gridWidth = MediaQuery.of(context).size.width -
        (context.rs.isSmall ? 32.0 : 48.0);
    final spacing = context.rs.isSmall ? 12.0 : 16.0;
    final itemWidth = (gridWidth - (_columns - 1) * spacing) / _columns;
    final itemHeight = itemWidth / 0.75;
    final rowHeight = itemHeight + spacing;

    final viewportCenter = _scrollController.offset + (screenHeight / 2);
    final targetRow = (viewportCenter / rowHeight).floor();
    final targetIndex =
        (targetRow * _columns).clamp(0, _filteredGames.length - 1);

    if (targetIndex != _currentIndex) {
      setState(() => _currentIndex = targetIndex);
    }
  }

  // --- Columns ---

  void _adjustColumns(bool increase) {
    if (increase) {
      _moreColumns();
    } else {
      _lessColumns();
    }
  }

  void _lessColumns() {
    if (_columns <= 3) return;
    setState(() {
      _columns--;
      ref.read(gridColumnsProvider('library').notifier).setColumns(_columns);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelected();
    });
  }

  void _moreColumns() {
    if (_columns >= 8) return;
    setState(() {
      _columns++;
      ref.read(gridColumnsProvider('library').notifier).setColumns(_columns);
    });
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
    _searchFocusNode.unfocus();
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
      // Reload to pick up install/favorite changes
      _favoriteIds = ref.read(favoriteGamesProvider).toSet();
      _applyFilters();
      if (_isSearching) {
        requestScreenFocus();
      }
    }
  }

  void _handleBack() {
    ref.read(feedbackServiceProvider).cancel();
    if (_isSearching) {
      if (_searchFocusNode.hasFocus) {
        _unfocusSearch();
      } else {
        _closeSearch();
      }
    } else {
      Navigator.pop(context);
    }
  }

  // --- Quick Menu ---

  void _toggleQuickMenu() {
    if (_showQuickMenu) return;
    if (ref.read(overlayPriorityProvider) != OverlayPriority.none) return;
    ref.read(feedbackServiceProvider).tick();
    setState(() => _showQuickMenu = true);
  }

  void _closeQuickMenu() {
    setState(() => _showQuickMenu = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) requestScreenFocus();
    });
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
        onSelect: _openSearch,
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
    if (_isSearching && _searchFocusNode.hasFocus) {
      return KeyEventResult.skipRemainingHandlers;
    }
    if (event is KeyUpEvent) {
      _debouncer.stopHold();
      return KeyEventResult.ignored;
    }
    return KeyEventResult.ignored;
  }

  // --- Count helpers ---

  bool _isGameInstalled(String filename) {
    if (_installedFiles.contains(filename)) return true;
    // Strip archive extension for multi-file folder match
    const archiveExts = ['.zip', '.7z', '.rar'];
    for (final ext in archiveExts) {
      if (filename.toLowerCase().endsWith(ext)) {
        final stripped = filename.substring(0, filename.length - ext.length);
        return _installedFiles.contains(stripped);
      }
    }
    return false;
  }

  int get _allCount => _allGames.length;

  int get _installedCount =>
      _allGames.where((g) => _isGameInstalled(g.filename)).length;

  int get _favoritesCount =>
      _allGames.where((g) => _favoriteIds.contains(g.displayName)).length;

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final baseTopPadding = rs.safeAreaTop + (rs.isSmall ? 72 : 96);
    final searchExtraPadding = _isSearching ? (rs.isSmall ? 50.0 : 56.0) : 0.0;
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
              if (_isSearching) _buildSearchBar(rs),
              // HUD
              if (!_showQuickMenu) _buildHud(),
              // Quick Menu
              if (_showQuickMenu)
                QuickMenuOverlay(
                  items: _buildQuickMenuItems(),
                  onClose: _closeQuickMenu,
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

  Widget _buildSearchBar(Responsive rs) {
    final topOffset = rs.safeAreaTop + (rs.isSmall ? 52 : 68);
    final textFieldFontSize = rs.isSmall ? 15.0 : 18.0;
    final borderRadius = rs.isSmall ? 22.0 : 30.0;
    final contentPadding = rs.isSmall ? 12.0 : 16.0;

    return Positioned(
      top: topOffset,
      left: rs.isSmall ? 16.0 : 24.0,
      right: rs.isSmall ? 16.0 : 24.0,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape, includeRepeats: false): () {
            if (_searchFocusNode.hasFocus) {
              _unfocusSearch();
            } else {
              _closeSearch();
            }
          },
          const SingleActivator(LogicalKeyboardKey.gameButtonB, includeRepeats: false): () {
            if (_searchFocusNode.hasFocus) {
              _unfocusSearch();
            } else {
              _closeSearch();
            }
          },
          const SingleActivator(LogicalKeyboardKey.goBack, includeRepeats: false): () {
            if (_searchFocusNode.hasFocus) {
              _unfocusSearch();
            } else {
              _closeSearch();
            }
          },
          const SingleActivator(LogicalKeyboardKey.arrowDown, includeRepeats: false): () {
            if (_searchFocusNode.hasFocus) {
              _unfocusSearch();
            }
          },
          const SingleActivator(LogicalKeyboardKey.arrowLeft): () {},
          const SingleActivator(LogicalKeyboardKey.arrowRight): () {},
        },
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF252525),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: _isSearchFocused
                  ? Colors.cyanAccent
                  : Colors.cyanAccent.withValues(alpha: 0.4),
              width: 2,
            ),
            boxShadow: _isSearchFocused
                ? [
                    BoxShadow(
                      color: Colors.cyanAccent.withValues(alpha: 0.4),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            autocorrect: false,
            textInputAction: TextInputAction.search,
            onTapOutside: (_) {},
            onChanged: _onSearchChanged,
            onSubmitted: (_) => _onSearchSubmitted(),
            style: TextStyle(
              color: Colors.white,
              fontSize: textFieldFontSize,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: 'Search library...',
              hintStyle: TextStyle(
                color: Colors.grey[500],
                fontSize: textFieldFontSize,
              ),
              prefixIcon: Icon(
                Icons.search,
                color: Colors.cyanAccent,
                size: rs.isSmall ? 20 : 24,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: contentPadding,
                vertical: contentPadding,
              ),
            ),
          ),
        ),
      ),
    );
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

    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: RepaintBoundary(
        child: GridView.builder(
        cacheExtent: 500,
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
        final isSelected = index == _currentIndex;
        final isInstalled = _isGameInstalled(entry.filename);
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
          child: BaseGameCard(
            displayName: entry.displayName,
            systemLabel: systemLabel,
            accentColor: systemColor,
            coverUrls: coverUrls,
            cachedUrl: entry.coverUrl,
            isInstalled: isInstalled,
            isSelected: isSelected,
            isFavorite: isFavorite,
            onTap: () {
              if (isSelected) {
                _openGameDetail(entry);
              } else {
                setState(() => _currentIndex = index);
                ref.read(feedbackServiceProvider).tick();
              }
            },
            onTapSelect: () {
              if (!isSelected) {
                setState(() => _currentIndex = index);
                ref.read(feedbackServiceProvider).tick();
              }
            },
          ),
        );
      },
      ),
      ),
    );
  }

  Widget _buildHud() {
    if (_isSearching) {
      return ConsoleHud(
        dpad: !_isSearchFocused
            ? (label: '\u2191', action: 'Search')
            : null,
        lt: HudAction('Prev Tab', onTap: _prevTab),
        rt: HudAction('Next Tab', onTap: _nextTab),
        a: HudAction('Select', onTap: _openSelectedGame),
        b: HudAction(
          _isSearchFocused ? 'Keyboard' : 'Close',
          highlight: _isSearchFocused,
          onTap: () => _handleBack(),
        ),
      );
    }

    return ConsoleHud(
      lt: HudAction('Prev Tab', onTap: _prevTab),
      rt: HudAction('Next Tab', onTap: _nextTab),
      a: HudAction('Select', onTap: _openSelectedGame),
      b: HudAction('Back', onTap: () => Navigator.pop(context)),
      start: HudAction('Menu', onTap: _toggleQuickMenu),
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

  const _LibraryEntry({
    required this.filename,
    required this.displayName,
    required this.url,
    this.coverUrl,
    required this.systemSlug,
    this.providerConfig,
  });
}

class _LibraryNavigateAction extends Action<NavigateIntent> {
  final _LibraryScreenState screen;

  _LibraryNavigateAction(this.screen);

  @override
  Object? invoke(NavigateIntent intent) {
    screen._navigateGrid(intent.direction);
    return null;
  }
}

class _LibraryAdjustColumnsAction extends Action<AdjustColumnsIntent> {
  final _LibraryScreenState screen;

  _LibraryAdjustColumnsAction(this.screen);

  @override
  Object? invoke(AdjustColumnsIntent intent) {
    screen._adjustColumns(intent.increase);
    return null;
  }
}

class _LibraryBackAction extends Action<BackIntent> {
  final _LibraryScreenState screen;

  _LibraryBackAction(this.screen);

  @override
  Object? invoke(BackIntent intent) {
    screen._handleBack();
    return null;
  }
}
