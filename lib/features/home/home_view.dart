import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/input/input.dart';
import '../../core/responsive/responsive.dart';
import '../../core/widgets/screen_layout.dart';
import '../../l10n/app_localizations.dart';
import '../../models/system_model.dart';
import '../../providers/app_providers.dart';
import '../../providers/download_providers.dart';
import '../../providers/game_providers.dart';
import '../../widgets/quick_menu.dart';
import '../../providers/library_providers.dart';
import '../../providers/ra_providers.dart';
import '../../services/config_bootstrap.dart';
import '../../services/input_debouncer.dart';
import '../../widgets/exit_confirmation_overlay.dart';
import '../../core/util/color_contrast.dart';
import '../../widgets/console_hud.dart';
import '../../widgets/download_overlay.dart';
import '../library/library_screen.dart';
import '../onboarding/onboarding_screen.dart';
import '../settings/settings_screen.dart';
import '../game_list/game_list_screen.dart';
import 'widgets/hero_carousel_item.dart';
import 'widgets/home_grid_view.dart';

class HomeView extends ConsumerStatefulWidget {
  const HomeView({super.key});
  @override
  ConsumerState<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends ConsumerState<HomeView>
    with ConsoleScreenMixin {
  late PageController _pageController;
  static const int _initialPage = 5000;
  int _currentIndex = 0;
  bool _isUserScrolling = false;
  int _lastStablePage = _initialPage;
  bool _showExitDialog = false;
  bool _wasGrid = false;
  bool _resumeAutoSyncAfterManual = false;
  ProviderSubscription? _visibleSystemsSub;
  ProviderSubscription? _syncStateSub;

  final ScrollController _gridScrollController = ScrollController();
  final Map<int, GlobalKey> _gridItemKeys = {};
  late int _columns;

  late InputDebouncer _debouncer;

  /// Filtered list of systems that have a config entry.
  List<SystemModel> _configuredSystems = [];

  @override
  String get routeId => 'home';

  // L1/R1 zoom shortcuts are handled by global shortcuts.

  @override
  Map<Type, Action<Intent>> get screenActions => {
        NavigateIntent: NavigateAction(ref, onNavigate: (intent) {
          final isGrid = ref.read(homeLayoutProvider);
          if (isGrid) {
            return _navigateGrid(intent.direction);
          } else {
            if (intent.direction == GridDirection.left) {
              if (_navigateLeft()) ref.read(feedbackServiceProvider).tick();
              return true;
            } else if (intent.direction == GridDirection.right) {
              if (_navigateRight()) ref.read(feedbackServiceProvider).tick();
              return true;
            }
          }
          return false;
        }),
        ConfirmIntent: ConfirmAction(ref, onConfirm: _navigateToCurrentSystem),
        SearchIntent: SearchAction(ref, onSearch: _openLibrarySearch),
        AdjustColumnsIntent: CallbackAction<AdjustColumnsIntent>(
          onInvoke: (intent) {
            if (intent.increase) { _zoomOut(); } else { _zoomIn(); }
            return null;
          },
        ),
        BackIntent: OverlayGuardedAction<BackIntent>(ref,
          onInvoke: (_) {
            if (!_debouncer.canPerformAction()) return null;
            _showExitDialogOverlay();
            return null;
          },
        ),
        ToggleOverlayIntent: ToggleOverlayAction(ref, onToggle: toggleQuickMenu),
      };

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _columns = ref.read(homeGridColumnsProvider);
    _debouncer = ref.read(inputDebouncerProvider);
    _pageController = PageController(
      viewportFraction: 0.5,
      initialPage: _initialPage,
    );
    _currentIndex = _configuredSystems.isEmpty ? 0 : _initialPage % _configuredSystems.length;
    _lastStablePage = _initialPage;
    _pageController.addListener(_onPageScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          ref.read(audioManagerProvider).startBgm();
        }
      });
      // Trigger background library sync
      _triggerLibrarySync();
    });
    _visibleSystemsSub = ref.listenManual(visibleSystemsProvider, (prev, next) {
      if (next case AsyncData<List<SystemModel>>(value: final filtered)) {
        final oldIds = _configuredSystems.map((s) => s.id).toList();
        final newIds = filtered.map((s) => s.id).toList();
        final changed = oldIds.length != newIds.length ||
            !oldIds.every(newIds.contains);
        if (!changed) return;
        if (filtered.isEmpty) {
          setState(() => _configuredSystems = []);
          _gridItemKeys.clear();
          return;
        }
        setState(() {
          _configuredSystems = filtered;
          _currentIndex = _lastStablePage % (filtered.length + 1);
        });
        _updateGridItemKeys();
        if (ref.read(homeLayoutProvider)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _scrollToSelected();
          });
        }
      }
    }, fireImmediately: true);

    // Resume auto-sync after a manual single-system sync completes
    _syncStateSub = ref.listenManual(
      librarySyncServiceProvider.select((s) => s.isSyncing),
      (prev, isSyncing) {
        if (prev == true && !isSyncing && _resumeAutoSyncAfterManual) {
          _resumeAutoSyncAfterManual = false;
          _triggerLibrarySync();
        }
      },
    );
  }

  Future<void> _triggerLibrarySync({Set<String> forceSystemIds = const {}}) async {
    final config = await ref.read(bootstrappedConfigProvider.future);
    if (!mounted) return;
    if (config.systems.isNotEmpty) {
      final timeout = Duration(seconds: ref.read(syncTimeoutProvider));
      final cooldownMinutes = ref.read(syncCooldownProvider);
      final storage = ref.read(storageServiceProvider);
      ref.read(librarySyncServiceProvider.notifier).syncSmart(
          config,
          syncTimeout: timeout,
          cooldown: Duration(minutes: cooldownMinutes),
          forceSystemIds: forceSystemIds,
          storageService: storage);
    }
  }

  @override
  void dispose() {
    _visibleSystemsSub?.close();
    _syncStateSub?.close();
    _debouncer.stopHold();
    _gridScrollController.dispose();
    _pageController.removeListener(_onPageScroll);
    _pageController.dispose();
    super.dispose();
  }

  void _onPageScroll() {
    if (!_pageController.hasClients ||
        !_pageController.position.hasContentDimensions) {
      return;
    }
    final page = _pageController.page;
    if (page == null) return;
    final isScrolling = _pageController.position.isScrollingNotifier.value;
    if (isScrolling && !_isUserScrolling) {
      _isUserScrolling = true;
    }
    if (!isScrolling && _isUserScrolling) {
      _isUserScrolling = false;
      final roundedPage = page.round();
      if (roundedPage != _lastStablePage) {
        _lastStablePage = roundedPage;
        _syncFocusToPage(roundedPage);
      }
    }
  }

  void _syncFocusToPage(int pageIndex) {
    final newIndex = pageIndex % _totalItemCount;
    if (newIndex != _currentIndex) {
      setState(() {
        _currentIndex = newIndex;
      });
    }
  }

  int get _systemCount => _configuredSystems.length;
  /// Total items in grid/carousel: systems + library entry
  int get _totalItemCount => _configuredSystems.length + 1;
  bool get _isLibraryIndex => _currentIndex == _configuredSystems.length;

  SystemModel _getSystem(int index) {
    return _configuredSystems[index % _systemCount];
  }

  void _navigateToCurrentSystem() {
    if (_configuredSystems.isEmpty) return;
    ref.read(feedbackServiceProvider).confirm();
    if (_isLibraryIndex) {
      _openLibrary();
      return;
    }
    final system = _getSystem(_currentIndex);
    final appConfig =
        ref.read(bootstrappedConfigProvider).value;
    final systemConfig = appConfig != null
        ? ConfigBootstrap.configForSystem(appConfig, system)
        : null;
    final targetFolder = systemConfig?.targetFolder ?? '';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GameListScreen(
          system: system,
          targetFolder: targetFolder,
        ),
      ),
    );
  }

  void _openLibrary() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LibraryScreen(),
      ),
    );
  }

  bool _navigateLeft() {
    final page = _pageController.page;
    if (page != null && page != page.roundToDouble()) return false;
    _pageController.previousPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
    return true;
  }

  bool _navigateRight() {
    final page = _pageController.page;
    if (page != null && page != page.roundToDouble()) return false;
    _pageController.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
    return true;
  }

  bool _navigateGrid(GridDirection direction) {
    if (_configuredSystems.isEmpty) return false;

    if (_debouncer.startHold(() {
      int newIndex = _currentIndex;
      final total = _totalItemCount;
      switch (direction) {
        case GridDirection.left:
          if (_currentIndex % _columns > 0) newIndex--;
        case GridDirection.right:
          if ((_currentIndex + 1) % _columns > 0 &&
              _currentIndex + 1 < total) {
            newIndex++;
          }
        case GridDirection.up:
          if (_currentIndex - _columns >= 0) newIndex -= _columns;
        case GridDirection.down:
          if (_currentIndex + _columns < total) newIndex += _columns;
      }
      if (newIndex != _currentIndex) {
        setState(() => _currentIndex = newIndex);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _scrollToSelected(instant: _debouncer.isHolding);
        });
      }
    })) {
      ref.read(feedbackServiceProvider).tick();
      return true;
    }
    return false;
  }

  void _updateGridItemKeys() {
    if (_gridItemKeys.length == _totalItemCount) return;
    _gridItemKeys.clear();
    for (int i = 0; i < _totalItemCount; i++) {
      _gridItemKeys[i] = GlobalKey();
    }
  }

  void _scrollToSelected({bool instant = false}) {
    final key = _gridItemKeys[_currentIndex];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        alignment: 0.5,
        duration: instant ? Duration.zero : const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
      return;
    }

    // Item not visible (e.g. after zoom). Jump to estimated position
    // so the item gets built, then retry in the next frame.
    if (!_gridScrollController.hasClients) return;
    final row = _currentIndex ~/ _columns;
    final totalRows = (_totalItemCount + _columns - 1) ~/ _columns;
    if (totalRows <= 1) return;
    final maxExtent = _gridScrollController.position.maxScrollExtent;
    final estimatedOffset =
        (maxExtent * row / (totalRows - 1)).clamp(0.0, maxExtent);
    _gridScrollController.jumpTo(estimatedOffset);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollToSelected(instant: true);
    });
  }

  void _zoomIn() {
    if (_columns <= 2) return;
    setState(() {
      _columns--;
      ref.read(homeGridColumnsProvider.notifier).setColumns(_columns);
    });
    ref.read(feedbackServiceProvider).tick();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollToSelected();
    });
  }

  void _zoomOut() {
    if (_columns >= 6) return;
    setState(() {
      _columns++;
      ref.read(homeGridColumnsProvider.notifier).setColumns(_columns);
    });
    ref.read(feedbackServiceProvider).tick();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollToSelected();
    });
  }

  void _openSettings() async {
    ref.read(feedbackServiceProvider).tick();
    // Stop holding inputs before navigating
    _debouncer.stopHold();
    // Snapshot current system IDs before entering settings
    final preSettingsIds = ref.read(bootstrappedConfigProvider).valueOrNull
        ?.systems.map((s) => s.id).toSet() ?? <String>{};
    final homeContext = context;
    await Navigator.push(
      homeContext,
      MaterialPageRoute(
        builder: (context) => SettingsScreen(
          onResetOnboarding: () {
            Navigator.of(homeContext).popUntil((route) => route.isFirst);
            Navigator.of(homeContext).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const OnboardingScreen(),
              ),
            );
          },
        ),
      ),
    );
    if (!mounted) return;
    // Config may have changed — reload and smart-sync
    ref.invalidate(bootstrappedConfigProvider);
    final config = await ref.read(bootstrappedConfigProvider.future);
    if (!mounted) return;
    // Only force-sync newly added consoles
    final newIds = config.systems.map((s) => s.id).toSet()
        .difference(preSettingsIds);
    if (config.systems.isNotEmpty) {
      _triggerLibrarySync(forceSystemIds: newIds);
    }
  }

  void _openLibrarySearch() {
    ref.read(feedbackServiceProvider).tick();
    _debouncer.stopHold();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LibraryScreen(openSearch: true),
      ),
    );
  }

  void _showExitDialogOverlay() {
    setState(() {
      _showExitDialog = true;
    });
  }

  void _hideExitDialog() {
    setState(() => _showExitDialog = false);
  }

  List<QuickMenuItem?> _buildQuickMenuItems() {
    final l = L.of(context);
    final hasDownloads = ref.read(hasQueueItemsProvider);
    return [
      QuickMenuItem(
        label: l.common_search,
        icon: Icons.search_rounded,
        shortcutHint: 'Y',
        onSelect: _openLibrarySearch,
      ),
      if (!_isLibraryIndex && _configuredSystems.isNotEmpty)
        QuickMenuItem(
          label: l.home_syncSystem(_getSystem(_currentIndex).name),
          subtitle: _lastSyncLabel(_getSystem(_currentIndex).id),
          icon: Icons.sync_rounded,
          onSelect: _syncCurrentSystem,
        ),
      if (_configuredSystems.length > 1)
        QuickMenuItem(
          label: l.home_syncAll,
          icon: Icons.sync_rounded,
          onSelect: _syncAll,
        ),
      QuickMenuItem(
        label: l.home_settings,
        icon: Icons.settings_rounded,
        onSelect: _openSettings,
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

  void _syncCurrentSystem() async {
    if (_isLibraryIndex || _configuredSystems.isEmpty) return;
    final system = _getSystem(_currentIndex);
    final config = ref.read(bootstrappedConfigProvider).valueOrNull;
    if (config == null) return;
    final syncService = ref.read(librarySyncServiceProvider.notifier);
    final syncState = ref.read(librarySyncServiceProvider);
    // If a bulk sync (syncAll/syncSmart) is running, cancel it first
    if (syncState.isSyncing && !syncService.isQueueSync) {
      syncService.cancel();
      await syncService.waitForCompletion();
      if (!mounted) return;
    }
    // If a queue sync is running, syncSystem will enqueue; if idle, it starts
    final timeout = Duration(seconds: ref.read(syncTimeoutProvider));
    _resumeAutoSyncAfterManual = true;
    syncService.syncSystem(
      system.id,
      config,
      syncTimeout: timeout,
      storageService: ref.read(storageServiceProvider),
    );
  }

  void _syncAll() async {
    final config = await ref.read(bootstrappedConfigProvider.future);
    if (config.systems.isEmpty) return;
    final syncService = ref.read(librarySyncServiceProvider.notifier);
    if (ref.read(librarySyncServiceProvider).isSyncing) {
      syncService.cancel();
      await syncService.waitForCompletion();
      if (!mounted) return;
    }
    final timeout = Duration(seconds: ref.read(syncTimeoutProvider));
    syncService.syncAll(
      config,
      syncTimeout: timeout,
      storageService: ref.read(storageServiceProvider),
    );
    triggerRaSync(
      ref.read(raSyncServiceProvider.notifier),
      ref.read(storageServiceProvider),
      force: true,
    );
  }

  String _lastSyncLabel(String systemId) {
    final l = L.of(context);
    final lastSync = ref.read(storageServiceProvider).getLastSyncTime(systemId);
    if (lastSync == null) return l.home_lastSyncNever;
    final diff = DateTime.now().difference(lastSync);
    if (diff.inMinutes < 1) return l.home_lastSyncJustNow;
    if (diff.inMinutes < 60) return l.home_lastSyncMinutes(diff.inMinutes);
    if (diff.inHours < 24) return l.home_lastSyncHours(diff.inHours);
    return l.home_lastSyncDays(diff.inDays);
  }

  void _exitApp() {
    SystemNavigator.pop();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) {
      _debouncer.stopHold();
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;

    // Filter systems: kept in sync via _visibleSystemsSub listener
    final visibleAsync = ref.watch(visibleSystemsProvider);

    // Still loading → black screen, don't flash "No consoles" prematurely
    if (_configuredSystems.isEmpty && visibleAsync.isLoading) {
      return buildWithActions(
        const Scaffold(backgroundColor: Colors.black),
      );
    }

    if (_configuredSystems.isEmpty) {
      return buildWithActions(
        Scaffold(
          backgroundColor: Colors.black,
          body: Column(
            children: [
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.videogame_asset_off, size: 64, color: Colors.white24),
                      const SizedBox(height: 16),
                      Text(
                        L.of(context).home_noConsoles,
                        style: TextStyle(color: Colors.grey[500], fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        L.of(context).home_pressStartForMenu,
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
              ConsoleHud(
                embedded: true,
                b: HudAction(L.of(context).common_exit, onTap: _showExitDialogOverlay),
                start: HudAction(L.of(context).common_menu, onTap: toggleQuickMenu),
              ),
            ],
          ),
        ),
      );
    }

    final isLibrary = _isLibraryIndex;
    final currentSystem = isLibrary ? null : _getSystem(_currentIndex);
    final accentColor = isLibrary ? Colors.cyanAccent : currentSystem!.accentColor;
    final isGrid = ref.watch(homeLayoutProvider);

    if (isGrid && !_wasGrid) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToSelected();
      });
    } else if (!isGrid && _wasGrid) {
      // Grid→Carousel: jump PageController to match _currentIndex
      final targetPage =
          _initialPage - (_initialPage % _totalItemCount) + _currentIndex;
      _lastStablePage = targetPage;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pageController.hasClients) {
          _pageController.jumpToPage(targetPage);
        }
      });
    }
    _wasGrid = isGrid;

    return buildWithActions(
      PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            if (_showExitDialog) {
              _hideExitDialog();
            } else if (_debouncer.canPerformAction()) {
              _showExitDialogOverlay();
            }
          }
        },
        child: ScreenLayout(
          backgroundColor: Colors.black,
          accentColor: accentColor,
          glowIntensity: isGrid ? 1.7 : 1.0,
          secondaryGlow: isGrid,
          useSafeArea: false,
          padding: EdgeInsets.zero,
          body: Stack(
            children: [
              if (isGrid)
                HomeGridView(
                  systems: _configuredSystems,
                  selectedIndex: _currentIndex,
                  columns: _columns,
                  scrollController: _gridScrollController,
                  itemKeys: _gridItemKeys,
                  onSelect: (idx) {
                    setState(() => _currentIndex = idx);
                    ref.read(feedbackServiceProvider).tick();
                  },
                  onConfirm: _navigateToCurrentSystem,
                  rs: rs,
                )
              else if (rs.isPortrait)
                _buildPortraitLayout(rs, currentSystem, isLibrary)
              else
                _buildLandscapeLayout(rs, currentSystem, isLibrary),
              if (isGrid) _buildControls(rs),
              if (showQuickMenu)
                QuickMenuOverlay(
                  items: _buildQuickMenuItems(),
                  onClose: closeQuickMenu,
                ),
              if (_showExitDialog)
                ExitConfirmationOverlay(
                  onConfirm: _exitApp,
                  onCancel: _hideExitDialog,
                ),
            ],
          ),
        ),
      ),
      onKeyEvent: _handleKeyEvent,
    );
  }

  Widget _buildLandscapeLayout(Responsive rs, SystemModel? currentSystem, bool isLibrary) {
    return Stack(
      children: [
        _buildCarousel(rs),
        if (isLibrary)
          _buildLibraryName(rs)
        else
          _buildSystemName(rs, currentSystem!),
        _buildControls(rs),
      ],
    );
  }

  Widget _buildPortraitLayout(Responsive rs, SystemModel? currentSystem, bool isLibrary) {
    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              flex: 55,
              child: _buildCarousel(rs),
            ),
            Expanded(
              flex: 45,
              child: isLibrary
                  ? _buildLibraryNameColumn(rs)
                  : _buildSystemNameColumn(rs, currentSystem!),
            ),
          ],
        ),
        _buildControls(rs),
      ],
    );
  }

  Widget _buildSystemNameColumn(Responsive rs, SystemModel system) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildGameCountBadges(system),
        Text(
          '${system.manufacturer} · ${system.releaseYear}',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: rs.isSmall ? 13 : 16,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.6),
            letterSpacing: 3,
          ),
        ),
      ],
    );
  }

  Widget _buildGameCountBadges(SystemModel system) {
    final countsAsync = ref.watch(systemSourceCountsProvider);
    return countsAsync.when(
      data: (counts) {
        final c = counts[system.id];
        if (c == null || (c.remote == 0 && c.local == 0)) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (c.remote > 0) _GameCountPill(
                icon: Icons.cloud_outlined,
                count: c.remote,
                color: system.accentColor.forText,
              ),
              if (c.remote > 0 && c.local > 0) const SizedBox(width: 6),
              if (c.local > 0) _GameCountPill(
                icon: Icons.folder_outlined,
                count: c.local,
                color: system.accentColor.forText,
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildLibraryCountBadges() {
    final countsAsync = ref.watch(systemSourceCountsProvider);
    return countsAsync.when(
      data: (counts) {
        int totalRemote = 0;
        int totalLocal = 0;
        for (final c in counts.values) {
          totalRemote += c.remote;
          totalLocal += c.local;
        }
        if (totalRemote == 0 && totalLocal == 0) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (totalRemote > 0) _GameCountPill(
                icon: Icons.cloud_outlined,
                count: totalRemote,
                color: Colors.cyanAccent,
              ),
              if (totalRemote > 0 && totalLocal > 0) const SizedBox(width: 6),
              if (totalLocal > 0) _GameCountPill(
                icon: Icons.folder_outlined,
                count: totalLocal,
                color: Colors.cyanAccent,
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildLibraryNameColumn(Responsive rs) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLibraryCountBadges(),
        Text(
          L.of(context).home_allGames,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: rs.isSmall ? 28 : (rs.isMedium ? 36 : 42),
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: rs.isSmall ? 4 : 8,
            shadows: [
              Shadow(
                color: Colors.cyanAccent.withValues(alpha: 0.8),
                blurRadius: rs.isSmall ? 20 : 40,
              ),
              Shadow(
                color: Colors.black.withValues(alpha: 0.9),
                blurRadius: rs.isSmall ? 10 : 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
        ),
        SizedBox(height: rs.spacing.sm),
        Text(
          L.of(context).home_library,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: rs.isSmall ? 11 : 14,
            fontWeight: FontWeight.w400,
            color: Colors.grey[500],
            letterSpacing: 3,
          ),
        ),
      ],
    );
  }

  Widget _buildLibraryName(Responsive rs) {
    final bottomOffset = rs.spacing.lg + 44 + rs.spacing.md;
    return Positioned(
      bottom: rs.isPortrait ? 0 : bottomOffset,
      left: 0,
      right: 0,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: Column(
          key: ValueKey(_currentIndex),
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLibraryCountBadges(),
            Text(
              'ALL GAMES',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: rs.isSmall ? 28 : (rs.isMedium ? 36 : 42),
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: rs.isSmall ? 4 : 8,
                shadows: [
                  Shadow(
                    color: Colors.cyanAccent.withValues(alpha: 0.8),
                    blurRadius: rs.isSmall ? 20 : 40,
                  ),
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.9),
                    blurRadius: rs.isSmall ? 10 : 20,
                    offset: const Offset(0, 4),
                  ),
                  Shadow(
                    color: Colors.cyanAccent.withValues(alpha: 0.5),
                    blurRadius: rs.isSmall ? 40 : 80,
                  ),
                ],
              ),
            ),
            SizedBox(height: rs.spacing.sm),
            Text(
              'Library',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: rs.isSmall ? 11 : 14,
                fontWeight: FontWeight.w400,
                color: Colors.grey[500],
                letterSpacing: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCarousel(Responsive rs) {
    return PageView.builder(
      key: ValueKey('carousel_${rs.isPortrait}'),
      controller: _pageController,
      onPageChanged: (index) {
        _lastStablePage = index;
        setState(() {
          _currentIndex = index % _totalItemCount;
        });
      },
      itemCount: 10000,
      itemBuilder: (context, index) {
        // AnimatedBuilder per item — only rebuilds the 2-3 visible items,
        // not the entire PageView.
        return AnimatedBuilder(
          animation: _pageController,
          builder: (context, child) {
            double currentPage = _initialPage.toDouble();
            try {
              if (_pageController.hasClients) {
                final position = _pageController.position;
                if (position.hasContentDimensions && position.haveDimensions) {
                  currentPage =
                      _pageController.page ?? _initialPage.toDouble();
                }
              }
            } catch (e) {
              debugPrint('HomeView: pageController access failed: $e');
            }
            final value = (currentPage - index).abs();
            final scale = (1 - (value * 0.25)).clamp(0.75, 1.0);
            final opacity = (1 - (value * 0.6)).clamp(0.2, 1.0);
            final isSelected = value < 0.3;
            final itemIndex = index % _totalItemCount;

            void onTap() {
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
              );
              Future.delayed(const Duration(milliseconds: 250), () {
                if (mounted) _navigateToCurrentSystem();
              });
            }

            if (itemIndex == _systemCount) {
              return HeroLibraryCarouselItem(
                scale: scale,
                opacity: opacity,
                isSelected: isSelected,
                rs: rs,
                onTap: onTap,
              );
            }
            final system = _configuredSystems[itemIndex];
            return HeroCarouselItem(
              system: system,
              scale: scale,
              opacity: opacity,
              isSelected: isSelected,
              rs: rs,
              onTap: onTap,
            );
          },
        );
      },
    );
  }

  Widget _buildSystemName(Responsive rs, SystemModel system) {
    // Clear the HUD bar: lg (HUD bottom margin) + ~44px (HUD height) + md (gap)
    final bottomOffset = rs.spacing.lg + 44 + rs.spacing.md;
    return Positioned(
      bottom: rs.isPortrait ? 0 : bottomOffset,
      left: 0,
      right: 0,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: Column(
          key: ValueKey(_currentIndex),
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildGameCountBadges(system),
            Text(
              '${system.manufacturer} · ${system.releaseYear}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: rs.isSmall ? 13 : 16,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.6),
                letterSpacing: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls(Responsive rs) {
    // Check full queue (including history) to see if overlay has content
    final hasAnyDownloads = ref.watch(
      downloadQueueProvider.select((q) => q.isNotEmpty),
    );
    final isOverlayExpanded = ref.watch(downloadOverlayExpandedProvider);

    // Only hide controls if the overlay is expanded AND there is content to show.
    if (isOverlayExpanded && hasAnyDownloads) return const SizedBox.shrink();
    if (_showExitDialog || showQuickMenu) {
      return const SizedBox.shrink();
    }

    final l = L.of(context);
    return ConsoleHud(
      a: HudAction(l.common_select, onTap: _navigateToCurrentSystem),
      b: HudAction(l.common_exit, onTap: _showExitDialogOverlay),
      start: HudAction(l.common_menu, onTap: toggleQuickMenu),
    );
  }
}

class _GameCountPill extends StatelessWidget {
  final IconData icon;
  final int count;
  final Color color;

  const _GameCountPill({
    required this.icon,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Color.lerp(Colors.black, color, 0.25)!.withValues(alpha: 0.80),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.60), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

