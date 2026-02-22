import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/input/input.dart';
import '../../core/widgets/console_focusable.dart';
import '../../core/responsive/responsive.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/screen_layout.dart';
import '../../providers/app_providers.dart';
import '../../providers/download_providers.dart';
import '../../widgets/download_overlay.dart';
import '../../services/config_storage_service.dart';
import '../../services/cover_preload_service.dart';
import '../../services/database_service.dart';
import '../../services/image_cache_service.dart';
import '../../services/thumbnail_service.dart';
import '../../widgets/console_hud.dart';
import '../../widgets/console_notification.dart';
import '../../widgets/exit_confirmation_overlay.dart';
import '../../widgets/quick_menu.dart';
import 'config_mode_screen.dart';
import 'library_scan_screen.dart';
import 'romm_config_screen.dart';
import 'widgets/settings_item.dart';
import 'widgets/volume_slider.dart';

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
  bool _showResetConfirm = false;
  final FocusNode _hapticFocusNode = FocusNode();
  final FocusNode _layoutFocusNode = FocusNode();
  final FocusNode _homeLayoutFocusNode = FocusNode();
  late final ConfettiController _confettiController;
  int _taglineTapCount = 0;
  String _appVersion = '';

  @override
  String get routeId => 'settings';

  @override
  Map<Type, Action<Intent>> get screenActions => {
        BackIntent: CallbackAction<BackIntent>(onInvoke: (_) {
          _exitSettings();
          return null;
        }),
        InfoIntent: InfoAction(ref, onInfo: _showResetDialog),
        ToggleOverlayIntent: ToggleOverlayAction(ref, onToggle: toggleQuickMenu),
      };

  @override
  void initState() {
    super.initState();
    final storage = ref.read(storageServiceProvider);
    _hapticEnabled = storage.getHapticEnabled();
    _maxDownloads = storage.getMaxConcurrentDownloads();
    final soundSettings = ref.read(soundSettingsProvider);
    _soundEnabled = soundSettings.enabled;
    _bgmVolume = soundSettings.bgmVolume;
    _sfxVolume = soundSettings.sfxVolume;

    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _appVersion = info.version);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _homeLayoutFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _hapticFocusNode.dispose();
    _layoutFocusNode.dispose();
    _homeLayoutFocusNode.dispose();
    super.dispose();
  }

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
      await ConfigStorageService().deleteConfig();
      final db = DatabaseService();
      await db.clearThumbnailData();
      await db.clearCache();
      await ThumbnailService.clearAll();
      await GameCoverCacheManager.instance.emptyCache();
      FailedUrlsCache.instance.clear();
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

  List<QuickMenuItem> _buildQuickMenuItems() {
    final hasDownloads = ref.read(hasQueueItemsProvider);
    return [
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

  void _startCoverPreload() {
    final preloadState = ref.read(coverPreloadServiceProvider);
    if (preloadState.isRunning) {
      ref.read(coverPreloadServiceProvider.notifier).cancel();
      return;
    }

    showConsoleNotification(context, message: 'Fetching covers...', isError: false);

    // One-shot listener for completion
    ProviderSubscription<CoverPreloadState>? sub;
    sub = ref.listenManual(coverPreloadServiceProvider, (prev, next) {
      if (prev != null && prev.isRunning && !next.isRunning) {
        sub?.close();
        if (!mounted) return;
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

    ref
        .read(coverPreloadServiceProvider.notifier)
        .preloadAll(DatabaseService());
  }

  void _cycleLayout() {
    ref.read(feedbackServiceProvider).tick();
    ref.read(controllerLayoutProvider.notifier).cycle();
  }

  void _toggleHomeLayout() {
    ref.read(feedbackServiceProvider).tick();
    ref.read(homeLayoutProvider.notifier).toggle();
  }

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final controllerLayout = ref.watch(controllerLayoutProvider);
    final isHomeGrid = ref.watch(homeLayoutProvider);

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

          Column(
            children: [
              SizedBox(height: rs.safeAreaTop + rs.spacing.lg),
              _buildTitle(rs),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: FocusTraversalGroup(
                      child: ListView(
                        padding: EdgeInsets.symmetric(
                          horizontal: rs.spacing.lg,
                          vertical: rs.spacing.md,
                        ),
                        children: [
                          _buildSectionHeader('Preferences', rs),
                          _buildSettingsItemWrapper(
                            onNavigate: (dir) {
                              if (dir == GridDirection.left || dir == GridDirection.right) {
                                _toggleHomeLayout();
                                return true;
                              }
                              return false;
                            },
                            child: SettingsItem(
                              focusNode: _homeLayoutFocusNode,
                              title: 'Home Screen Layout',
                              subtitle: isHomeGrid ? 'Grid View' : 'Horizontal Carousel',
                              trailing: _buildSwitch(isHomeGrid),
                              onTap: _toggleHomeLayout,
                            ),
                          ),
                          SizedBox(height: rs.spacing.md),
                          _buildSettingsItemWrapper(
                            onNavigate: (dir) {
                              if (dir == GridDirection.left || dir == GridDirection.right) {
                                _cycleLayout();
                                return true;
                              }
                              return false;
                            },
                            child: SettingsItem(
                              focusNode: _layoutFocusNode,
                              title: 'Controller Layout',
                              subtitle: switch (controllerLayout) {
                                ControllerLayout.nintendo => 'Nintendo (default)',
                                ControllerLayout.xbox => 'Xbox (A/B & X/Y swapped)',
                                ControllerLayout.playstation => 'PlayStation (✕ ○ □ △)',
                              },
                              trailing: _buildLayoutLabel(controllerLayout),
                              onTap: _cycleLayout,
                            ),
                          ),
                          SizedBox(height: rs.spacing.md),
                          _buildSettingsItemWrapper(
                            onNavigate: (dir) {
                              if (dir == GridDirection.left || dir == GridDirection.right) {
                                _toggleHaptic();
                                return true;
                              }
                              return false;
                            },
                            child: SettingsItem(
                              focusNode: _hapticFocusNode,
                              title: 'Haptic Feedback',
                              subtitle: 'Vibration on button presses',
                              trailing: _buildSwitch(_hapticEnabled),
                              onTap: _toggleHaptic,
                            ),
                          ),
                          SizedBox(height: rs.spacing.md),
                          _buildSettingsItemWrapper(
                            onNavigate: (dir) {
                               if (dir == GridDirection.left || dir == GridDirection.right) {
                                _toggleSound();
                                return true;
                              }
                              return false;
                            },
                            child: SettingsItem(
                              title: 'Sound Effects',
                              subtitle: 'Audio feedback for actions',
                              trailing: _buildSwitch(_soundEnabled),
                              onTap: _toggleSound,
                            ),
                          ),

                          SizedBox(height: rs.spacing.xl),
                          _buildSectionHeader('Audio', rs),

                          _buildSettingsItemWrapper(
                            onNavigate: (dir) {
                              if (dir == GridDirection.left) {
                                _adjustBgmVolume(-0.05);
                                ref.read(feedbackServiceProvider).tick();
                                return true;
                              } else if (dir == GridDirection.right) {
                                _adjustBgmVolume(0.05);
                                ref.read(feedbackServiceProvider).tick();
                                return true;
                              }
                              return false;
                            },
                            child: SettingsItem(
                              title: 'Background Music',
                              subtitle: 'Ambient background music volume',
                              trailingBuilder: (isFocused) => VolumeSlider(
                                volume: _bgmVolume,
                                isSelected: isFocused,
                                onChanged: _setBgmVolume,
                              ),
                            ),
                          ),
                          SizedBox(height: rs.spacing.md),
                          _buildSettingsItemWrapper(
                             onNavigate: (dir) {
                              if (dir == GridDirection.left) {
                                _adjustSfxVolume(-0.05);
                                ref.read(feedbackServiceProvider).tick();
                                return true;
                              } else if (dir == GridDirection.right) {
                                _adjustSfxVolume(0.05);
                                ref.read(feedbackServiceProvider).tick();
                                return true;
                              }
                              return false;
                            },
                            child: SettingsItem(
                              title: 'SFX Volume',
                              subtitle: 'Interface sound effects volume',
                              trailingBuilder: (isFocused) => VolumeSlider(
                                volume: _sfxVolume,
                                isSelected: isFocused,
                                onChanged: _setSfxVolume,
                              ),
                            ),
                          ),

                          SizedBox(height: rs.spacing.xl),
                          _buildSectionHeader('Downloads', rs),

                          _buildSettingsItemWrapper(
                            onNavigate: (dir) {
                              if (dir == GridDirection.left) {
                                _adjustMaxDownloads(-1);
                                ref.read(feedbackServiceProvider).tick();
                                return true;
                              } else if (dir == GridDirection.right) {
                                _adjustMaxDownloads(1);
                                ref.read(feedbackServiceProvider).tick();
                                return true;
                              }
                              return false;
                            },
                            child: SettingsItem(
                              title: 'Max Concurrent Downloads',
                              subtitle: 'Number of simultaneous downloads',
                              trailingBuilder: (isFocused) => Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      _adjustMaxDownloads(-1);
                                      ref.read(feedbackServiceProvider).tick();
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: Icon(
                                        Icons.chevron_left,
                                        color: _maxDownloads > 1
                                            ? (isFocused ? Colors.white : Colors.white70)
                                            : Colors.white24,
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 24,
                                    child: Text(
                                      '$_maxDownloads',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: isFocused ? Colors.white : Colors.white70,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      _adjustMaxDownloads(1);
                                      ref.read(feedbackServiceProvider).tick();
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: Icon(
                                        Icons.chevron_right,
                                        color: _maxDownloads < 3
                                            ? (isFocused ? Colors.white : Colors.white70)
                                            : Colors.white24,
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          SizedBox(height: rs.spacing.xl),
                          _buildSectionHeader('Connections', rs),

                          SettingsItem(
                            title: 'RomM Server',
                            subtitle: 'Global RomM connection settings',
                            trailing: const Icon(Icons.dns_outlined, color: Colors.white70),
                            onTap: _openRommConfig,
                          ),

                          SizedBox(height: rs.spacing.xl),
                          _buildSectionHeader('System', rs),

                          SettingsItem(
                            title: 'Edit Consoles',
                            subtitle: 'Add, remove or reconfigure consoles',
                            trailing: const Icon(Icons.tune, color: Colors.white70),
                            onTap: _openConfigMode,
                          ),
                          SizedBox(height: rs.spacing.md),
                          SettingsItem(
                            title: 'Scan Library',
                            subtitle: 'Discover all games across all consoles',
                            trailing: const Icon(Icons.radar_rounded, color: Colors.white70),
                            onTap: _openLibraryScan,
                          ),
                          SizedBox(height: rs.spacing.md),
                          _buildCoverPreloadTile(),

                          SizedBox(height: rs.spacing.xl),
                          _buildSectionHeader('About', rs),
                          _buildAboutSection(rs),
                          SizedBox(height: rs.spacing.md),
                          SettingsItem(
                            title: 'GitHub',
                            subtitle: 'View source code on GitHub',
                            trailing: const Icon(Icons.open_in_new_rounded, color: Colors.white70),
                            onTap: () => launchUrl(Uri.parse('https://github.com/AverageConsumer/R-Shop')),
                          ),
                          SizedBox(height: rs.spacing.md),
                          SettingsItem(
                            title: 'Issues',
                            subtitle: 'Report bugs or request features',
                            trailing: const Icon(Icons.bug_report_outlined, color: Colors.white70),
                            onTap: () => launchUrl(Uri.parse('https://github.com/AverageConsumer/R-Shop/issues')),
                          ),
                          SizedBox(height: rs.spacing.xl),
                        ],
                      ),
                    ),
                  ),
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

          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              colors: const [Colors.blue, Colors.lightBlue, Colors.white, Color(0xFF1565C0)],
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
               message: 'This will delete all settings and restart the setup.',
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

  Widget _buildCoverPreloadTile() {
    final preload = ref.watch(coverPreloadServiceProvider);
    if (preload.isRunning) {
      final pct = (preload.progress * 100).round();
      return SettingsItem(
        title: 'Fetching Covers...',
        subtitle: '${preload.completed} / ${preload.total} games',
        trailingBuilder: (isFocused) => SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: preload.progress,
                strokeWidth: 3,
                color: AppTheme.primaryColor,
                backgroundColor: Colors.white12,
              ),
              Text(
                '$pct%',
                style: TextStyle(
                  color: isFocused ? Colors.white : Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        onTap: _startCoverPreload,
      );
    }
    return SettingsItem(
      title: 'Fetch All Covers',
      subtitle: 'Download cover art for all games',
      trailing: const Icon(Icons.image_outlined, color: Colors.white70),
      onTap: _startCoverPreload,
    );
  }

  Widget _buildSwitch(bool value) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 50,
      height: 28,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: value ? AppTheme.primaryColor : Colors.grey.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Align(
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLayoutLabel(ControllerLayout layout) {
    final label = switch (layout) {
      ControllerLayout.nintendo => 'NIN',
      ControllerLayout.xbox => 'XBOX',
      ControllerLayout.playstation => 'PS',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.4),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.primaryColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Responsive rs) {
    return Padding(
      padding: EdgeInsets.only(bottom: rs.spacing.sm, left: rs.spacing.xs),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppTheme.primaryColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildTitle(Responsive rs) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: rs.spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
           const Icon(Icons.settings, size: 48, color: Colors.white24),
           SizedBox(height: rs.spacing.sm),
           Text(
            'SETTINGS',
            style: AppTheme.headlineLarge.copyWith(
              fontSize: 42,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection(Responsive rs) {
    return Column(
      children: [
        SizedBox(height: rs.spacing.md),
        const Icon(Icons.sports_esports_rounded, size: 32, color: Colors.white24),
        SizedBox(height: rs.spacing.sm),
        Text(
          'R-SHOP',
          style: AppTheme.headlineLarge.copyWith(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
          ),
        ),
        SizedBox(height: rs.spacing.xs),
        Text(
          _appVersion.isNotEmpty ? 'v$_appVersion' : '',
          style: AppTheme.bodySmall.copyWith(color: Colors.white38),
        ),
        SizedBox(height: rs.spacing.md),
        ConsoleFocusableListItem(
          onSelect: () {
            _taglineTapCount++;
            if (_taglineTapCount >= 5) {
              _confettiController.play();
              _taglineTapCount = 0;
              ref.read(feedbackServiceProvider).confirm();
            } else {
              ref.read(feedbackServiceProvider).tick();
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Center(
              child: Text(
                'INTENSIV, AGGRESSIV, MUTIG',
                style: AppTheme.titleMedium.copyWith(
                  color: Colors.white54,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: rs.spacing.md),
      ],
    );
  }

  Widget _buildSettingsItemWrapper({
    required Widget child,
    required bool Function(GridDirection) onNavigate,
  }) {
    return Actions(
      actions: {
        NavigateIntent: NavigateAction(ref, onNavigate: (intent) {
          return onNavigate(intent.direction);
        }),
      },
      child: child,
    );
  }
}
