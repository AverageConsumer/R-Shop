import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/responsive/responsive.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/console_focusable.dart';
import '../../providers/app_providers.dart';
import '../../utils/friendly_error.dart';
import '../../providers/game_providers.dart';
import '../../providers/ra_providers.dart';
import '../../widgets/console_hud.dart';
import '../../widgets/console_notification.dart';
import '../../widgets/download_overlay.dart';
import '../settings/ra_config_screen.dart';
import 'onboarding_controller.dart';
import 'widgets/welcome_chooser_step.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (!mounted) return KeyEventResult.ignored;
    final isOverlayExpanded = ref.read(downloadOverlayExpandedProvider);
    if (isOverlayExpanded) return KeyEventResult.handled;
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (!ref.read(inputDebouncerProvider).canPerformAction()) {
      return KeyEventResult.handled;
    }

    final state = ref.read(onboardingControllerProvider);

    // Welcome chooser and complete step are fully self-contained —
    // their ConsoleFocusable buttons handle all input.
    if (state.currentStep == OnboardingStep.welcome ||
        state.currentStep == OnboardingStep.complete) {
      return KeyEventResult.ignored;
    }

    return KeyEventResult.ignored;
  }

  Future<void> _exportConfig() async {
    try {
      final controller = ref.read(onboardingControllerProvider.notifier);
      await controller.exportConfig();
    } catch (e) {
      if (!mounted) return;
      showErrorNotification(context, ref, message: 'Export failed: ${getUserFriendlyError(e)}');
    }
  }

  Future<void> _importConfig() async {
    final result = await importConfigFile(ref);
    if (!mounted) return;
    if (result.cancelled) return;
    if (result.error != null) {
      showErrorNotification(context, ref, message: 'Invalid config: ${result.error}');
    } else {
      ref.read(onboardingControllerProvider.notifier).loadFromConfig(result.config!);
      // Refresh sources so the notifier picks up any imported sources.
      ref.read(sourcesProvider.notifier).replaceAll(result.config!.sources);
      showSuccessNotification(context, ref, message: 'Config imported!');
    }
  }

  Future<void> _finishOnboarding() async {
    final controller = ref.read(onboardingControllerProvider.notifier);
    final audioManager = ref.read(audioManagerProvider);
    audioManager.stopTyping();
    final storage = ref.read(storageServiceProvider);

    try {
      final config = await controller.buildFinalConfig();
      final jsonString = const JsonEncoder.withIndent('  ').convert(config.toJson());
      await ref.read(configStorageServiceProvider).saveConfig(jsonString);
      await storage.setOnboardingCompleted(true);
      // Re-run the SourcesNotifier rebuild so the resolver injects
      // managed providers into the systems we just wrote. Without this
      // the systems land on disk with `providers: []` and sync skips
      // every system because there's nothing to fetch from.
      final sourcesNotifier = ref.read(sourcesProvider.notifier);
      await sourcesNotifier
          .replaceAll(ref.read(sourcesProvider).sources.toList());
      if (!mounted) return;
      ref.invalidate(bootstrappedConfigProvider);
    } catch (e) {
      if (!mounted) return;
      showErrorNotification(context, ref, message: 'Failed to save: ${getUserFriendlyError(e)}');
      return;
    }
    if (!mounted) return;

    // Capture provider references before navigation disposes this widget
    final syncNotifier = ref.read(raSyncServiceProvider.notifier);

    Navigator.of(context).pushReplacementNamed('/home');

    // Trigger RA sync after onboarding if RA was configured.
    // Deferred to let HomeView settle and avoid contention with config bootstrap.
    Future.delayed(const Duration(seconds: 3), () {
      triggerRaSync(syncNotifier, storage);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingControllerProvider);
    final rs = context.rs;

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      autofocus: true,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {},
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              const _AnimatedBackground(),
              const _RadialGlow(),
              SafeArea(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: rs.isSmall ? rs.spacing.md : rs.spacing.lg,
                    vertical: rs.isSmall ? rs.spacing.md : rs.spacing.xxl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildContent(state)),
                    ],
                  ),
                ),
              ),
              _buildControls(state),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(OnboardingState state) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: _buildStepContent(state),
    );
  }

  Widget _buildStepContent(OnboardingState state) {
    final controller = ref.read(onboardingControllerProvider.notifier);
    switch (state.currentStep) {
      case OnboardingStep.welcome:
        return const WelcomeChooserStep();
      case OnboardingStep.consoleSetup:
        // consoleSetup is only reachable via config_mode_screen's
        // loadFromConfig(), not from the onboarding flow itself.
        return const SizedBox.shrink();
      case OnboardingStep.complete:
        return _CompleteStep(
          configuredCount: state.configuredCount,
          onComplete: controller.onMessageComplete,
          onExport: () => _exportConfig(),
          onJumpIn: _finishOnboarding,
        );
    }
  }

  Widget _buildControls(OnboardingState state) {
    // Welcome chooser has an Import shortcut so power users can still
    // drop in a JSON config without going through any setup wizard.
    if (state.currentStep == OnboardingStep.welcome) {
      return ConsoleHud(
        select: HudAction('Import config', onTap: _importConfig),
      );
    }

    // Complete step has its own ConsoleFocusable tiles for Jump In / Export.
    return const SizedBox.shrink();
  }
}

class _AnimatedBackground extends StatelessWidget {
  const _AnimatedBackground();
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.redAccent.withValues(alpha: 0.25),
            Colors.redAccent.withValues(alpha: 0.12),
            const Color(0xFF080808),
            const Color(0xFF030303),
            Colors.black,
          ],
          stops: const [0.0, 0.15, 0.35, 0.6, 1.0],
        ),
      ),
    );
  }
}

class _RadialGlow extends StatelessWidget {
  const _RadialGlow();
  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-0.3, -0.3),
              radius: 1.2,
              colors: [
                Colors.redAccent.withValues(alpha: 0.35),
                Colors.redAccent.withValues(alpha: 0.15),
                Colors.redAccent.withValues(alpha: 0.05),
                Colors.transparent,
              ],
              stops: const [0.0, 0.3, 0.6, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompleteStep extends StatefulWidget {
  final int configuredCount;
  final VoidCallback onComplete;
  final VoidCallback onExport;
  final VoidCallback onJumpIn;

  const _CompleteStep({
    required this.configuredCount,
    required this.onComplete,
    required this.onExport,
    required this.onJumpIn,
  });

  @override
  State<_CompleteStep> createState() => _CompleteStepState();
}

class _CompleteStepState extends State<_CompleteStep> {
  final FocusNode _jumpFocus = FocusNode(debugLabel: 'complete_jump');
  final FocusNode _raFocus = FocusNode(debugLabel: 'complete_ra');
  final FocusNode _exportFocus = FocusNode(debugLabel: 'complete_export');
  final FocusNode _screenFocus = FocusNode(debugLabel: 'complete_screen');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onComplete();
      if (mounted) _jumpFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _jumpFocus.dispose();
    _raFocus.dispose();
    _exportFocus.dispose();
    _screenFocus.dispose();
    super.dispose();
  }

  void _move(int delta) {
    final order = [_jumpFocus, _raFocus, _exportFocus];
    final cur = order.indexWhere((n) => n.hasFocus);
    final next = (cur < 0 ? 0 : cur + delta).clamp(0, order.length - 1);
    order[next].requestFocus();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      _move(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _move(-1);
      return KeyEventResult.handled;
    }
    // Swallow B so the user can't navigate back from the complete screen.
    if (key == LogicalKeyboardKey.gameButtonB ||
        key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.backspace) {
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.configuredCount;
    final label = count == 1 ? 'system' : 'systems';

    return Focus(
      focusNode: _screenFocus,
      onKeyEvent: _onKey,
      child: SingleChildScrollView(
        child: Column(
          key: const ValueKey('complete'),
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "You're all set",
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              count == 0
                  ? 'No systems configured yet — you can add sources later from Settings.'
                  : '$count $label ready to browse.',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            ),
            const SizedBox(height: 24),
            _CompleteTile(
              focusNode: _jumpFocus,
              icon: Icons.play_arrow_rounded,
              title: 'Jump in',
              subtitle: 'Open the home screen and start syncing',
              onSelect: widget.onJumpIn,
            ),
            const SizedBox(height: 12),
            _CompleteTile(
              focusNode: _raFocus,
              icon: Icons.emoji_events,
              title: 'RetroAchievements',
              subtitle: 'Track your retro gaming achievements',
              onSelect: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RaConfigScreen()),
                );
              },
            ),
            const SizedBox(height: 12),
            _CompleteTile(
              focusNode: _exportFocus,
              icon: Icons.share,
              title: 'Export config',
              subtitle: 'Re-use this setup on another device',
              onSelect: widget.onExport,
            ),
          ],
        ),
      ),
    );
  }
}

class _CompleteTile extends StatelessWidget {
  const _CompleteTile({
    required this.focusNode,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onSelect,
  });

  final FocusNode focusNode;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return ConsoleFocusable(
      focusNode: focusNode,
      onSelect: onSelect,
      borderRadius: 12,
      focusScale: 1.0,
      focusBorderColor: AppTheme.primaryColor,
      child: GestureDetector(
        onTap: onSelect,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1C),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: AppTheme.primaryColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white30),
            ],
          ),
        ),
      ),
    );
  }
}
