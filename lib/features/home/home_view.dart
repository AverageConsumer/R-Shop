import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/input/input.dart';
import '../../core/responsive/responsive.dart';
import '../../core/widgets/screen_layout.dart';
import '../../models/system_model.dart';
import '../../providers/app_providers.dart';
import '../../providers/download_providers.dart';
import '../../services/input_debouncer.dart';
import '../../widgets/exit_confirmation_overlay.dart';
import '../../widgets/console_hud.dart';
import '../../widgets/download_overlay.dart';
import '../onboarding/onboarding_screen.dart';
import '../settings/settings_screen.dart';
import '../game_list/game_list_screen.dart';
import 'widgets/hero_carousel_item.dart';

class HomeView extends ConsumerStatefulWidget {
  const HomeView({super.key});
  @override
  ConsumerState<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends ConsumerState<HomeView> {
  late PageController _pageController;
  final FocusNode _focusNode = FocusNode();
  static const int _initialPage = 5000;
  int _currentIndex = 0;
  bool _isUserScrolling = false;
  int _lastStablePage = _initialPage;
  bool _showExitDialog = false;

  late InputDebouncer _debouncer;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _debouncer = ref.read(inputDebouncerProvider);
    _pageController = PageController(
      viewportFraction: 0.5,
      initialPage: _initialPage,
    );
    _currentIndex = _initialPage % SystemModel.supportedSystems.length;
    _lastStablePage = _initialPage;
    _pageController.addListener(_onPageScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(mainFocusRequestProvider.notifier).state = _focusNode;
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _focusNode.requestFocus();
          ref.read(audioManagerProvider).startBgm();
        }
      });
    });
  }

  @override
  void dispose() {
    _debouncer.stopHold();
    _pageController.removeListener(_onPageScroll);
    _pageController.dispose();
    _focusNode.dispose();
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
    final newIndex = pageIndex % _systemCount;
    if (newIndex != _currentIndex) {
      setState(() {
        _currentIndex = newIndex;
      });
    }
  }

  int get _systemCount => SystemModel.supportedSystems.length;
  SystemModel _getSystem(int index) {
    return SystemModel.supportedSystems[index % _systemCount];
  }

  void _navigateToCurrentSystem() {
    final romPath = ref.read(romPathProvider) ??
        ref.read(storageServiceProvider).getRomPath();
    final system = _getSystem(_currentIndex);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GameListScreen(
          system: system,
          romPath: romPath ?? '',
        ),
      ),
    );
  }

  void _navigateLeft() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  void _navigateRight() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  void _openSettings() async {
    // Stop holding inputs before navigating
    _debouncer.stopHold();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsScreen(
          onResetOnboarding: () {
            Navigator.of(context).popUntil((route) => route.isFirst);
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const OnboardingScreen(),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showExitDialogOverlay() {
    setState(() {
      _showExitDialog = true;
      _showExitDialog = true;
    });
  }

  void _hideExitDialog() {
    setState(() => _showExitDialog = false);
  }

  void _exitApp() {
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final currentSystem = _getSystem(_currentIndex);
    final accentColor = currentSystem.accentColor;

    return Shortcuts(
      shortcuts: AppShortcuts.defaultShortcuts,
      child: Actions(
        actions: _showExitDialog ? _getDialogActions() : _getNormalActions(),
        child: Focus(
          focusNode: _focusNode,
          autofocus: true,
          child: PopScope(
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
                if (rs.isPortrait)
                  _buildPortraitLayout(rs, currentSystem)
                else
                  _buildLandscapeLayout(rs, currentSystem),
                if (_showExitDialog)
                  ExitConfirmationOverlay(
                    onConfirm: _exitApp,
                    onCancel: _hideExitDialog,
                  ),
              ],
            ),
          ),
          ),
        ),
      ),
    );
  }

  Map<Type, Action<Intent>> _getNormalActions() {
    return {
      NavigateIntent: NavigateAction(ref, onNavigate: (intent) {
        if (intent.direction == GridDirection.left) {
          _navigateLeft();
          return true;
        } else if (intent.direction == GridDirection.right) {
          _navigateRight();
          return true;
        }
        return false;
      }),
      ConfirmIntent: ConfirmAction(ref, onConfirm: () {
        if (_debouncer.canPerformAction()) {
          _navigateToCurrentSystem();
        }
      }),
      InfoIntent: InfoAction(ref, onInfo: () {
        if (_debouncer.canPerformAction()) {
          _openSettings();
        }
      }),
      BackIntent: CallbackAction<BackIntent>(onInvoke: (_) {
         if (_debouncer.canPerformAction()) {
           _showExitDialogOverlay();
         }
         return null;
      }),
      ToggleOverlayIntent: ToggleOverlayAction(ref),
    };
  }

  Map<Type, Action<Intent>> _getDialogActions() {
    return {
       // Dialog handles its own shortcuts via CallbackShortcuts in ExitConfirmationOverlay
    };
  }

  Widget _buildLandscapeLayout(Responsive rs, SystemModel currentSystem) {
    return Stack(
      children: [
        _buildCarousel(rs),
        _buildSystemName(rs, currentSystem),
        _buildControls(rs),
      ],
    );
  }

  Widget _buildPortraitLayout(Responsive rs, SystemModel currentSystem) {
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
              child: _buildSystemNameColumn(rs, currentSystem),
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

  Widget _buildCarousel(Responsive rs) {
    double getCurrentPage() {
      try {
        if (_pageController.hasClients) {
          final position = _pageController.position;
          if (position.hasContentDimensions && position.haveDimensions) {
            return _pageController.page ?? _initialPage.toDouble();
          }
        }
      } catch (_) {}
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
              _currentIndex = index % _systemCount;
            });
          },
          itemCount: 10000,
          itemBuilder: (context, index) {
            final system = _getSystem(index);
            final value = (currentPage - index).abs();
            final scale = (1 - (value * 0.25)).clamp(0.75, 1.0);
            final opacity = (1 - (value * 0.6)).clamp(0.2, 1.0);
            final isSelected = value < 0.3;
            return HeroCarouselItem(
              system: system,
              scale: scale,
              opacity: opacity,
              isSelected: isSelected,
              rs: rs,
              onTap: () {
                _pageController.animateToPage(
                  index,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                );
                Future.delayed(const Duration(milliseconds: 250), () {
                  _navigateToCurrentSystem();
                });
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSystemName(Responsive rs, SystemModel system) {
    return Positioned(
      bottom: rs.isPortrait ? 0 : (rs.isSmall ? 50 : 70),
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
    final hasActiveDownloads = ref.watch(downloadCountProvider) > 0;
    final isOverlayExpanded = ref.watch(downloadOverlayExpandedProvider);

    // Only hide controls if the overlay is expanded AND there is content to show.
    // If the queue is empty, DownloadOverlay returns SizedBox.shrink(), so we should keep showing controls.
    if (isOverlayExpanded && hasAnyDownloads) return const SizedBox.shrink();

    final buttons = <Widget>[
      ControlButton(
          label: 'A', action: 'Select', onTap: _navigateToCurrentSystem),
      ControlButton(label: 'X', action: 'Settings', onTap: _openSettings),
      ControlButton(
          label: 'B', action: 'Exit', onTap: _showExitDialogOverlay),
      if (hasActiveDownloads)
        ControlButton(
          label: '',
          action: 'Downloads',
          icon: Icons.play_arrow_rounded,
          highlight: true,
          onTap: () => toggleDownloadOverlay(ref),
        ),
    ];

    return ConsoleHud(buttons: buttons);
  }
}
