import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/input/input.dart';
import '../../core/responsive/responsive.dart';
import '../../core/widgets/screen_layout.dart';
import '../../models/system_model.dart';
import '../../providers/app_providers.dart';
import '../../providers/download_providers.dart';
import '../../providers/game_providers.dart';
import '../../widgets/quick_menu.dart';
import '../../providers/library_providers.dart';
import '../../services/config_bootstrap.dart';
import '../../services/library_sync_service.dart';
import '../../services/input_debouncer.dart';
import '../../widgets/exit_confirmation_overlay.dart';
import '../../widgets/console_hud.dart';
import '../../widgets/download_overlay.dart';
import '../../widgets/sync_badge.dart';
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

  final ScrollController _gridScrollController = ScrollController();
  final Map<int, GlobalKey> _gridItemKeys = {};
  late int _columns;

  late InputDebouncer _debouncer;

  /// Filtered list of systems that have a config entry.
  List<SystemModel> _configuredSystems = [];

  @override
  String get routeId => 'home';

  @override
  Map<ShortcutActivator, Intent>? get additionalShortcuts {
    if (!ref.read(homeLayoutProvider)) return null;
    // LB = Zoom Out (more columns), RB = Zoom In (fewer columns)
    return {
      const SingleActivator(LogicalKeyboardKey.gameButtonLeft1,
              includeRepeats: false):
          const AdjustColumnsIntent(increase: true),
      const SingleActivator(LogicalKeyboardKey.gameButtonRight1,
              includeRepeats: false):
          const AdjustColumnsIntent(increase: false),
      const SingleActivator(LogicalKeyboardKey.pageUp,
              includeRepeats: false):
          const AdjustColumnsIntent(increase: true),
      const SingleActivator(LogicalKeyboardKey.pageDown,
              includeRepeats: false):
          const AdjustColumnsIntent(increase: false),
    };
  }

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
        InfoIntent: InfoAction(ref, onInfo: _openSettings),
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
          screenFocusNode.requestFocus();
          ref.read(audioManagerProvider).startBgm();
        }
      });
      // Trigger background library sync
      _triggerLibrarySync();
    });
  }

  Future<void> _triggerLibrarySync() async {
    final config = await ref.read(bootstrappedConfigProvider.future);
    if (!mounted) return;
    if (config.systems.isNotEmpty) {
      ref.read(librarySyncServiceProvider.notifier).syncAll(config);
    }
  }

  @override
  void dispose() {
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
    // Config may have changed — reload and re-sync
    ref.invalidate(bootstrappedConfigProvider);
    LibrarySyncService.clearFreshness();
    final config = await ref.read(bootstrappedConfigProvider.future);
    if (!mounted) return;
    if (config.systems.isNotEmpty) {
      ref.read(librarySyncServiceProvider.notifier).syncAll(config);
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

  List<QuickMenuItem> _buildQuickMenuItems() {
    final isGrid = ref.read(homeLayoutProvider);
    final hasDownloads = ref.read(hasQueueItemsProvider);
    return [
      QuickMenuItem(
        label: 'Search',
        icon: Icons.search_rounded,
        shortcutHint: 'Y',
        onSelect: _openLibrarySearch,
      ),
      QuickMenuItem(
        label: 'Settings',
        icon: Icons.settings_rounded,
        shortcutHint: 'X',
        onSelect: _openSettings,
      ),
      if (isGrid) ...[
        QuickMenuItem(
          label: 'Zoom In',
          icon: Icons.zoom_in_rounded,
          shortcutHint: 'R',
          onSelect: _zoomIn,
        ),
        QuickMenuItem(
          label: 'Zoom Out',
          icon: Icons.zoom_out_rounded,
          shortcutHint: 'L',
          onSelect: _zoomOut,
        ),
      ],
      if (hasDownloads)
        QuickMenuItem(
          label: 'Downloads',
          icon: Icons.download_rounded,
          shortcutHint: null,
          onSelect: () => toggleDownloadOverlay(ref),
          highlight: true,
        ),
    ];
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

    // Filter systems: hides local-only consoles with no content
    final visibleAsync = ref.watch(visibleSystemsProvider);
    visibleAsync.whenData((filtered) {
      final oldIds = _configuredSystems.map((s) => s.id).toList();
      final newIds = filtered.map((s) => s.id).toList();
      final changed = oldIds.length != newIds.length ||
          !oldIds.every((id) => newIds.contains(id));
      if (!changed) return;
      if (filtered.isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() => _configuredSystems = []);
            _gridItemKeys.clear();
          }
        });
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
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
      });
    });

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
                        'No consoles configured',
                        style: TextStyle(color: Colors.grey[500], fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Press + for Menu',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
              ConsoleHud(
                embedded: true,
                b: HudAction('Exit', onTap: _showExitDialogOverlay),
                start: HudAction('Menu', onTap: toggleQuickMenu),
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
              const SyncBadge(),
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
        Text(
          system.name.toUpperCase(),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: rs.isSmall ? 28 : (rs.isMedium ? 36 : 42),
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: rs.isSmall ? 4 : 8,
            shadows: [
              Shadow(
                color: system.accentColor.withValues(alpha: 0.8),
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
          '${system.manufacturer} · ${system.releaseYear}',
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

  Widget _buildLibraryNameColumn(Responsive rs) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
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
    double getCurrentPage() {
      try {
        if (_pageController.hasClients) {
          final position = _pageController.position;
          if (position.hasContentDimensions && position.haveDimensions) {
            return _pageController.page ?? _initialPage.toDouble();
          }
        }
      } catch (e) {
        debugPrint('HomeView: pageController access failed: $e');
      }
      return _initialPage.toDouble();
    }

    return AnimatedBuilder(
      animation: _pageController,
      builder: (context, child) {
        final currentPage = getCurrentPage();
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
                _navigateToCurrentSystem();
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
            Text(
              system.name.toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: rs.isSmall ? 28 : (rs.isMedium ? 36 : 42),
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: rs.isSmall ? 4 : 8,
                shadows: [
                  Shadow(
                    color: system.accentColor.withValues(alpha: 0.8),
                    blurRadius: rs.isSmall ? 20 : 40,
                  ),
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.9),
                    blurRadius: rs.isSmall ? 10 : 20,
                    offset: const Offset(0, 4),
                  ),
                  Shadow(
                    color: system.accentColor.withValues(alpha: 0.5),
                    blurRadius: rs.isSmall ? 40 : 80,
                  ),
                ],
              ),
            ),
            SizedBox(height: rs.spacing.sm),
            Text(
              '${system.manufacturer} · ${system.releaseYear}',
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

  Widget _buildControls(Responsive rs) {
    // Check full queue (including history) to see if overlay has content
    final hasAnyDownloads = ref.watch(downloadQueueProvider).isNotEmpty;
    final isOverlayExpanded = ref.watch(downloadOverlayExpandedProvider);

    // Only hide controls if the overlay is expanded AND there is content to show.
    if (isOverlayExpanded && hasAnyDownloads) return const SizedBox.shrink();
    if (_showExitDialog || showQuickMenu) {
      return const SizedBox.shrink();
    }

    return ConsoleHud(
      a: HudAction('Select', onTap: _navigateToCurrentSystem),
      b: HudAction('Exit', onTap: _showExitDialogOverlay),
      start: HudAction('Menu', onTap: toggleQuickMenu),
    );
  }
}

