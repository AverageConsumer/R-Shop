import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/input/input.dart';
import '../../core/responsive/responsive.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/screen_layout.dart';
import '../../providers/app_providers.dart';
import '../../providers/download_providers.dart';
import '../../widgets/download_overlay.dart';
import '../../services/cover_preload_service.dart';
import '../../services/database_service.dart';
import '../../services/image_cache_service.dart';
import '../../services/thumbnail_service.dart';
import '../../widgets/console_hud.dart';
import '../../widgets/console_notification.dart';
import '../../widgets/exit_confirmation_overlay.dart';
import '../../widgets/quick_menu.dart';
import '../onboarding/onboarding_controller.dart';
import 'config_mode_screen.dart';
import 'library_scan_screen.dart';
import 'romm_config_screen.dart';
import 'widgets/about_tab.dart';
import 'widgets/preferences_tab.dart';
import 'widgets/settings_tabs.dart';
import 'widgets/system_tab.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  final VoidCallback? onResetOnboarding;
  const SettingsScreen({super.key, this.onResetOnboarding});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with ConsoleScreenMixin {
  late bool _hapticEnabled;
  late bool _soundEnabled;
  late double _bgmVolume;
  late double _sfxVolume;
  late int _maxDownloads;
  late bool _allowNonLanHttp;
  bool _showResetConfirm = false;
  ProviderSubscription<CoverPreloadState>? _coverPreloadSub;
  ThumbnailDiskUsage? _thumbnailUsage;
  int? _gamesNeedingCovers;
  final FocusNode _hapticFocusNode = FocusNode();
  final FocusNode _layoutFocusNode = FocusNode();
  final FocusNode _homeLayoutFocusNode = FocusNode();
  final FocusNode _firstSystemTabNode = FocusNode();
  final FocusNode _firstAboutTabNode = FocusNode();
  late final ConfettiController _confettiController;
  String _appVersion = '';
  int _selectedTab = 0;

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
        InfoIntent: InfoAction(ref, onInfo: _showResetDialog),
        ToggleOverlayIntent:
            ToggleOverlayAction(ref, onToggle: toggleQuickMenu),
        TabLeftIntent: TabLeftAction(ref, onTabLeft: _prevTab),
        TabRightIntent: TabRightAction(ref, onTabRight: _nextTab),
      };

  @override
  void initState() {
    super.initState();
    final storage = ref.read(storageServiceProvider);
    _hapticEnabled = storage.getHapticEnabled();
    _maxDownloads = storage.getMaxConcurrentDownloads();
    _allowNonLanHttp = storage.getAllowNonLanHttp();
    final soundSettings = ref.read(soundSettingsProvider);
    _soundEnabled = soundSettings.enabled;
    _bgmVolume = soundSettings.bgmVolume;
    _sfxVolume = soundSettings.sfxVolume;

    _confettiController =
        ConfettiController(duration: const Duration(seconds: 2));
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _appVersion = info.version);
    }).catchError((e) {
      debugPrint('Failed to get package info: $e');
    });
    _loadCoverStats();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _homeLayoutFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _coverPreloadSub?.close();
    _confettiController.dispose();
    _hapticFocusNode.dispose();
    _layoutFocusNode.dispose();
    _homeLayoutFocusNode.dispose();
    _firstSystemTabNode.dispose();
    _firstAboutTabNode.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Tab navigation
  // ---------------------------------------------------------------------------

  void _nextTab() {
    final next = (_selectedTab + 1) % 3;
    ref.read(feedbackServiceProvider).tick();
    setState(() => _selectedTab = next);
    _focusFirstItemInTab(next);
  }

  void _prevTab() {
    final next = (_selectedTab - 1 + 3) % 3;
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
          _homeLayoutFocusNode.requestFocus();
        case 1:
          _firstSystemTabNode.requestFocus();
        case 2:
          _firstAboutTabNode.requestFocus();
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Settings actions
  // ---------------------------------------------------------------------------

  Future<void> _toggleHaptic() async {
    final value = !_hapticEnabled;
    final storage = ref.read(storageServiceProvider);
    final haptic = ref.read(hapticServiceProvider);
    await storage.setHapticEnabled(value);
    haptic.setEnabled(value);
    setState(() => _hapticEnabled = value);
    if (value) haptic.tick();
  }

  Future<void> _toggleSound() async {
    final value = !_soundEnabled;
    setState(() => _soundEnabled = value);
    await ref.read(soundSettingsProvider.notifier).setEnabled(value);
    if (value) {
      ref.read(audioManagerProvider).playConfirm();
    }
  }

  Future<void> _adjustBgmVolume(double delta) async {
    final newVolume = (_bgmVolume + delta).clamp(0.0, 1.0);
    setState(() => _bgmVolume = newVolume);
    await ref.read(soundSettingsProvider.notifier).setBgmVolume(newVolume);
  }

  Future<void> _adjustSfxVolume(double delta) async {
    final newVolume = (_sfxVolume + delta).clamp(0.0, 1.0);
    setState(() => _sfxVolume = newVolume);
    await ref.read(soundSettingsProvider.notifier).setSfxVolume(newVolume);
  }

  Future<void> _setBgmVolume(double volume) async {
    final clamped = volume.clamp(0.0, 1.0);
    setState(() => _bgmVolume = clamped);
    await ref.read(soundSettingsProvider.notifier).setBgmVolume(clamped);
  }

  Future<void> _setSfxVolume(double volume) async {
    final clamped = volume.clamp(0.0, 1.0);
    setState(() => _sfxVolume = clamped);
    await ref.read(soundSettingsProvider.notifier).setSfxVolume(clamped);
  }

  void _adjustMaxDownloads(int delta) {
    final newValue = (_maxDownloads + delta).clamp(1, 3);
    if (newValue == _maxDownloads) return;
    setState(() => _maxDownloads = newValue);
    ref.read(downloadQueueManagerProvider).setMaxConcurrent(newValue);
  }

  Future<void> _toggleAllowNonLanHttp() async {
    final value = !_allowNonLanHttp;
    await ref.read(storageServiceProvider).setAllowNonLanHttp(value);
    setState(() => _allowNonLanHttp = value);
    ref.read(feedbackServiceProvider).tick();
  }

  void _openRommConfig() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RommConfigScreen()),
    );
  }

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
      _hideResetDialog();
      widget.onResetOnboarding?.call();
    } catch (e) {
      _hideResetDialog();
      if (mounted) {
        showConsoleNotification(context, message: 'Reset error: $e');
      }
    }
  }

  void _exitSettings() {
    Navigator.pop(context);
  }

  void _openConfigMode() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ConfigModeScreen()),
    );
  }

  void _openLibraryScan() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LibraryScanScreen()),
    );
  }

  Future<void> _loadCoverStats() async {
    final usage = await ThumbnailService.getDiskUsage();
    final pending = await DatabaseService().getGamesNeedingCovers();
    if (mounted) {
      setState(() {
        _thumbnailUsage = usage;
        _gamesNeedingCovers = pending.length;
      });
    }
  }

  String _buildCoverSubtitle() {
    final parts = <String>[];
    if (_thumbnailUsage != null && _thumbnailUsage!.fileCount > 0) {
      parts.add(
          '${_thumbnailUsage!.formattedSize} (${_thumbnailUsage!.fileCount} cached)');
    }
    if (_gamesNeedingCovers != null && _gamesNeedingCovers! > 0) {
      final estBytes = _gamesNeedingCovers! * 30 * 1024;
      final estMb = (estBytes / (1024 * 1024)).toStringAsFixed(1);
      parts.add('$_gamesNeedingCovers remaining (~$estMb MB)');
    }
    if (parts.isEmpty) {
      return _thumbnailUsage != null
          ? 'All covers cached'
          : 'Download cover art for all games';
    }
    return parts.join(' · ');
  }

  void _startCoverPreload() {
    final preloadState = ref.read(coverPreloadServiceProvider);
    if (preloadState.isRunning) {
      ref.read(coverPreloadServiceProvider.notifier).cancel();
      return;
    }

    showConsoleNotification(context,
        message: 'Fetching covers...', isError: false);

    _coverPreloadSub?.close();
    _coverPreloadSub =
        ref.listenManual(coverPreloadServiceProvider, (prev, next) {
      if (prev != null && prev.isRunning && !next.isRunning) {
        _coverPreloadSub?.close();
        _coverPreloadSub = null;
        if (!mounted) return;
        _loadCoverStats();
        if (next.failed > 0) {
          showConsoleNotification(
            context,
            message: 'Covers: ${next.succeeded} ok, ${next.failed} failed',
            isError: true,
          );
        } else {
          showConsoleNotification(
            context,
            message: '${next.succeeded} covers loaded!',
            isError: false,
          );
        }
      }
    });

    final deviceMemory = ref.read(deviceMemoryProvider);
    ref
        .read(coverPreloadServiceProvider.notifier)
        .preloadAll(
          DatabaseService(),
          phase1Pool: deviceMemory.preloadPhase1Pool,
          phase2Pool: deviceMemory.preloadPhase2Pool,
        );
  }

  void _cycleLayout() {
    ref.read(feedbackServiceProvider).tick();
    ref.read(controllerLayoutProvider.notifier).cycle();
  }

  void _toggleHomeLayout() {
    ref.read(feedbackServiceProvider).tick();
    ref.read(homeLayoutProvider.notifier).toggle();
  }

  Future<void> _exportErrorLog() async {
    final logFile = ref.read(crashLogServiceProvider).getLogFile();
    if (logFile == null) {
      if (mounted) {
        showConsoleNotification(context, message: 'No error log available');
      }
      return;
    }
    try {
      await Share.shareXFiles([XFile(logFile.path)]);
    } catch (e) {
      if (mounted) {
        showConsoleNotification(context,
            message: 'Share failed: $e', isError: true);
      }
    }
  }

  List<QuickMenuItem?> _buildQuickMenuItems() {
    final hasDownloads = ref.read(hasQueueItemsProvider);
    return [
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
      null,
      QuickMenuItem(
        label: 'Reset App',
        icon: Icons.restart_alt_rounded,
        shortcutHint: 'X',
        onSelect: _showResetDialog,
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

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final controllerLayout = ref.watch(controllerLayoutProvider);
    final isHomeGrid = ref.watch(homeLayoutProvider);
    final topPadding = rs.safeAreaTop + (rs.isSmall ? 72 : 96);

    return buildWithActions(
      PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            _exitSettings();
          }
        },
        child: ScreenLayout(
          backgroundColor: Colors.black,
          accentColor: AppTheme.primaryColor,
          body: Stack(
            children: [
              // Background decoration
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF1A1A1A),
                        Colors.black,
                      ],
                    ),
                  ),
                ),
              ),

              // Tab content (behind header)
              Column(
                children: [
                  SizedBox(height: topPadding),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 150),
                      child: switch (_selectedTab) {
                        0 => SettingsPreferencesTab(
                            controllerLayout: controllerLayout,
                            isHomeGrid: isHomeGrid,
                            hapticEnabled: _hapticEnabled,
                            soundEnabled: _soundEnabled,
                            bgmVolume: _bgmVolume,
                            sfxVolume: _sfxVolume,
                            homeLayoutFocusNode: _homeLayoutFocusNode,
                            layoutFocusNode: _layoutFocusNode,
                            hapticFocusNode: _hapticFocusNode,
                            onToggleHomeLayout: _toggleHomeLayout,
                            onCycleLayout: _cycleLayout,
                            onToggleHaptic: _toggleHaptic,
                            onToggleSound: _toggleSound,
                            onAdjustBgmVolume: _adjustBgmVolume,
                            onAdjustSfxVolume: _adjustSfxVolume,
                            onSetBgmVolume: _setBgmVolume,
                            onSetSfxVolume: _setSfxVolume,
                          ),
                        1 => SettingsSystemTab(
                            firstSystemTabNode: _firstSystemTabNode,
                            maxDownloads: _maxDownloads,
                            allowNonLanHttp: _allowNonLanHttp,
                            coverSubtitle: _buildCoverSubtitle(),
                            onOpenRommConfig: _openRommConfig,
                            onOpenConfigMode: _openConfigMode,
                            onOpenLibraryScan: _openLibraryScan,
                            onStartCoverPreload: _startCoverPreload,
                            onExportErrorLog: _exportErrorLog,
                            onAdjustMaxDownloads: _adjustMaxDownloads,
                            onToggleAllowNonLanHttp: _toggleAllowNonLanHttp,
                          ),
                        _ => SettingsAboutTab(
                            appVersion: _appVersion,
                            firstAboutTabNode: _firstAboutTabNode,
                            confettiController: _confettiController,
                          ),
                      },
                    ),
                  ),
                  if (!showQuickMenu)
                    ConsoleHud(
                      b: HudAction('Back', onTap: _exitSettings),
                      start: HudAction('Menu', onTap: toggleQuickMenu),
                      embedded: true,
                    ),
                ],
              ),

              // Header (over content, with gradient fade)
              _buildHeader(rs),

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
                  items: _buildQuickMenuItems(),
                  onClose: closeQuickMenu,
                ),

              if (_showResetConfirm)
                ExitConfirmationOverlay(
                  title: 'RESET APPLICATION',
                  message:
                      'This will delete all settings and restart the setup.',
                  icon: Icons.restart_alt_rounded,
                  confirmLabel: 'RESET',
                  cancelLabel: 'CANCEL',
                  onConfirm: _performReset,
                  onCancel: _hideResetDialog,
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------

  Widget _buildHeader(Responsive rs) {
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
                  'SETTINGS',
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
                  tabs: const ['Preferences', 'System', 'About'],
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

  // ---------------------------------------------------------------------------
  // Cover subtitle (used by system tab)
  // ---------------------------------------------------------------------------
}
