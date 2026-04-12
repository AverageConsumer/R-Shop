import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../core/input/input.dart';
import '../../l10n/app_localizations.dart';
import '../../core/responsive/responsive.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/screen_layout.dart';
import '../../providers/app_providers.dart';
import '../../utils/friendly_error.dart';
import '../../providers/download_providers.dart';
import '../../providers/game_providers.dart';
import '../../widgets/download_overlay.dart';
import '../../services/database_service.dart';
import '../../services/image_cache_service.dart';
import '../../services/thumbnail_service.dart';
import '../../widgets/console_hud.dart';
import '../../widgets/console_notification.dart';
import '../../widgets/exit_confirmation_overlay.dart';
import '../../widgets/quick_menu.dart';
import '../onboarding/onboarding_controller.dart';
import 'widgets/about_tab.dart';
import 'widgets/advanced_tab.dart';
import 'widgets/audio_feedback_tab.dart';
import 'widgets/general_tab.dart';
import 'widgets/settings_tabs.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  final VoidCallback? onResetOnboarding;
  const SettingsScreen({super.key, this.onResetOnboarding});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with ConsoleScreenMixin {
  static const _tabCount = 4;
  bool _showResetConfirm = false;
  late final ConfettiController _confettiController;
  String _appVersion = '';
  int _selectedTab = 0;

  final FocusNode _firstGeneralNode = FocusNode();
  final FocusNode _firstAudioNode = FocusNode();
  final FocusNode _firstAdvancedNode = FocusNode();
  final FocusNode _firstAboutNode = FocusNode();

  @override
  String get routeId => 'settings';

  @override
  Map<ShortcutActivator, Intent>? get additionalShortcuts => {
        const SingleActivator(LogicalKeyboardKey.gameButtonLeft2,
                includeRepeats: false):
            const TabLeftIntent(),
        const SingleActivator(LogicalKeyboardKey.gameButtonRight2,
                includeRepeats: false):
            const TabRightIntent(),
      };

  @override
  Map<Type, Action<Intent>> get screenActions => {
        BackIntent: CallbackAction<BackIntent>(onInvoke: (_) {
          _exitSettings();
          return null;
        }),
        ToggleOverlayIntent:
            ToggleOverlayAction(ref, onToggle: toggleQuickMenu),
        TabLeftIntent: TabLeftAction(ref, onTabLeft: _prevTab),
        TabRightIntent: TabRightAction(ref, onTabRight: _nextTab),
      };

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 2));
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _appVersion = info.version);
    }).catchError((e) {
      debugPrint('Failed to get package info: $e');
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _firstGeneralNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _firstGeneralNode.dispose();
    _firstAudioNode.dispose();
    _firstAdvancedNode.dispose();
    _firstAboutNode.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Tab navigation
  // ---------------------------------------------------------------------------

  void _nextTab() {
    final next = (_selectedTab + 1) % _tabCount;
    ref.read(feedbackServiceProvider).tick();
    setState(() => _selectedTab = next);
    _focusFirstItemInTab(next);
  }

  void _prevTab() {
    final next = (_selectedTab - 1 + _tabCount) % _tabCount;
    ref.read(feedbackServiceProvider).tick();
    setState(() => _selectedTab = next);
    _focusFirstItemInTab(next);
  }

  void _selectTab(int index) {
    if (index == _selectedTab) return;
    ref.read(feedbackServiceProvider).tick();
    setState(() => _selectedTab = index);
    _focusFirstItemInTab(index);
  }

  void _focusFirstItemInTab(int tab) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      switch (tab) {
        case 0:
          _firstGeneralNode.requestFocus();
        case 1:
          _firstAudioNode.requestFocus();
        case 2:
          _firstAdvancedNode.requestFocus();
        case 3:
          _firstAboutNode.requestFocus();
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Reset
  // ---------------------------------------------------------------------------

  void _showResetDialog() {
    ref.read(feedbackServiceProvider).tick();
    setState(() => _showResetConfirm = true);
  }

  void _hideResetDialog() {
    setState(() => _showResetConfirm = false);
  }

  Future<void> _performReset() async {
    try {
      final storage = ref.read(storageServiceProvider);
      await storage.resetAll();
      await ref.read(configStorageServiceProvider).deleteConfig();
      final db = DatabaseService();
      await db.clearThumbnailData();
      await db.clearCache();
      await ThumbnailService.clearAll();
      await GameCoverCacheManager.instance.emptyCache();
      FailedUrlsCache.instance.clear();
      ref.invalidate(onboardingControllerProvider);
      ref.invalidate(bootstrappedConfigProvider);
      ref.invalidate(hideEmptyConsolesProvider);
      ref.invalidate(favoriteGamesProvider);
      _hideResetDialog();
      widget.onResetOnboarding?.call();
    } catch (e) {
      _hideResetDialog();
      if (mounted) {
        showErrorNotification(context, ref,
            message: 'Reset error: ${getUserFriendlyError(e)}');
      }
    }
  }

  void _exitSettings() {
    Navigator.pop(context);
  }

  // ---------------------------------------------------------------------------
  // Quick menu
  // ---------------------------------------------------------------------------

  List<QuickMenuItem?> _buildQuickMenuItems(L l) {
    final hasDownloads = ref.read(hasQueueItemsProvider);
    return [
      QuickMenuItem(
        label: l.settings_previousTab,
        icon: Icons.arrow_back_rounded,
        shortcutHint: 'L',
        onSelect: _prevTab,
      ),
      QuickMenuItem(
        label: l.settings_nextTab,
        icon: Icons.arrow_forward_rounded,
        shortcutHint: 'R',
        onSelect: _nextTab,
      ),
      null,
      QuickMenuItem(
        label: l.settings_resetApp,
        icon: Icons.restart_alt_rounded,
        onSelect: _showResetDialog,
      ),
      if (hasDownloads)
        QuickMenuItem(
          label: l.common_downloads,
          icon: Icons.download_rounded,
          onSelect: () => toggleDownloadOverlay(ref),
          highlight: true,
        ),
    ];
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final rs = context.rs;
    final topPadding = rs.safeAreaTop + (rs.isSmall ? 72 : 96);

    return buildWithActions(
      PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _exitSettings();
        },
        child: ScreenLayout(
          backgroundColor: Colors.black,
          accentColor: AppTheme.primaryColor,
          body: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF1A1A1A), Colors.black],
                    ),
                  ),
                ),
              ),
              Column(
                children: [
                  SizedBox(height: topPadding),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 150),
                      child: switch (_selectedTab) {
                        0 => SettingsGeneralTab(
                            key: const ValueKey('general'),
                            firstFocusNode: _firstGeneralNode),
                        1 => SettingsAudioTab(
                            key: const ValueKey('audio'),
                            firstFocusNode: _firstAudioNode),
                        2 => SettingsAdvancedTab(
                            key: const ValueKey('advanced'),
                            firstFocusNode: _firstAdvancedNode),
                        _ => SettingsAboutTab(
                            key: const ValueKey('about'),
                            appVersion: _appVersion,
                            firstAboutTabNode: _firstAboutNode,
                            confettiController: _confettiController),
                      },
                    ),
                  ),
                  if (!showQuickMenu)
                    ConsoleHud(
                      b: HudAction(l.common_back, onTap: _exitSettings),
                      start: HudAction(l.common_menu, onTap: toggleQuickMenu),
                      embedded: true,
                    ),
                ],
              ),
              _buildHeader(rs, l),
              Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirectionality: BlastDirectionality.explosive,
                  colors: const [
                    Colors.blue,
                    Colors.lightBlue,
                    Colors.white,
                    Color(0xFF1565C0),
                  ],
                  numberOfParticles: 30,
                  gravity: 0.2,
                ),
              ),
              if (showQuickMenu)
                QuickMenuOverlay(
                  items: _buildQuickMenuItems(l),
                  onClose: closeQuickMenu,
                ),
              if (_showResetConfirm)
                ExitConfirmationOverlay(
                  title: l.settings_resetDialogTitle,
                  message: l.settings_resetDialogMessage,
                  icon: Icons.restart_alt_rounded,
                  confirmLabel: l.settings_resetDialogConfirm,
                  cancelLabel: l.settings_resetDialogCancel,
                  onConfirm: _performReset,
                  onCancel: _hideResetDialog,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Responsive rs, L l) {
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
                Text(
                  l.settings_title,
                  style: TextStyle(
                    fontSize: rs.isSmall ? 18 : 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 4,
                  ),
                ),
                SizedBox(height: rs.isSmall ? 6 : 10),
                SettingsTabs(
                  selectedTab: _selectedTab,
                  tabs: [l.settings_tabGeneral, l.settings_tabAudio, l.settings_tabAdvanced, l.settings_tabAbout],
                  accentColor: AppTheme.primaryColor,
                  onTap: _selectTab,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
