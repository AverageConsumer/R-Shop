import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/responsive/responsive.dart';
import '../../providers/app_providers.dart';
import '../../providers/download_providers.dart';
import '../../providers/game_providers.dart';
import '../../services/config_storage_service.dart';
import '../../widgets/console_hud.dart';
import '../../widgets/download_overlay.dart';
import 'onboarding_controller.dart';
import 'widgets/chat_bubble.dart';
import 'widgets/console_setup_step.dart';
import 'widgets/pixel_mascot.dart';

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
    final isOverlayExpanded = ref.read(downloadOverlayExpandedProvider);
    if (isOverlayExpanded) return KeyEventResult.handled;
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (!ref.read(inputDebouncerProvider).canPerformAction()) {
      return KeyEventResult.handled;
    }

    final state = ref.read(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);

    // Console setup step — delegate based on sub-state
    if (state.currentStep == OnboardingStep.consoleSetup) {
      // Provider form is open
      if (state.hasProviderForm) {
        if (event.logicalKey == LogicalKeyboardKey.gameButtonB ||
            event.logicalKey == LogicalKeyboardKey.escape) {
          controller.cancelProviderForm();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.gameButtonY) {
          controller.testProviderConnection();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.gameButtonA ||
            event.logicalKey == LogicalKeyboardKey.enter) {
          controller.saveProvider();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      }

      // Console panel is open
      if (state.hasConsoleSelected) {
        if (event.logicalKey == LogicalKeyboardKey.gameButtonB ||
            event.logicalKey == LogicalKeyboardKey.escape) {
          controller.deselectConsole();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.gameButtonY) {
          controller.startAddProvider();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.gameButtonA ||
            event.logicalKey == LogicalKeyboardKey.enter) {
          controller.saveConsoleConfig();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      }

      // Grid level: Start = export, Select = import
      if (event.logicalKey == LogicalKeyboardKey.gameButtonStart) {
        _exportConfig();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.select) {
        _importConfig();
        return KeyEventResult.handled;
      }
    }

    if (event.logicalKey == LogicalKeyboardKey.gameButtonA ||
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.space ||
        event.logicalKey == LogicalKeyboardKey.select) {
      _handleContinue();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.gameButtonB ||
        event.logicalKey == LogicalKeyboardKey.backspace ||
        event.logicalKey == LogicalKeyboardKey.escape) {
      _handleBack();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _handleContinue() {
    final state = ref.read(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);
    final feedback = ref.read(feedbackServiceProvider);
    final audioManager = ref.read(audioManagerProvider);

    if (!state.canProceed) return;

    audioManager.stopTyping();

    if (state.isLastStep) {
      feedback.success();
      _finishOnboarding();
    } else if (state.currentStep == OnboardingStep.consoleSetup) {
      // Need at least one console configured to proceed
      if (state.configuredCount == 0) return;
      feedback.tick();
      controller.nextStep();
    } else {
      feedback.tick();
      controller.nextStep();
    }
  }

  void _handleBack() {
    final state = ref.read(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);
    final feedback = ref.read(feedbackServiceProvider);
    final audioManager = ref.read(audioManagerProvider);
    if (!state.isFirstStep) {
      audioManager.stopTyping();
      feedback.cancel();
      controller.previousStep();
    }
  }

  Future<void> _exportConfig() async {
    try {
      final controller = ref.read(onboardingControllerProvider.notifier);
      await controller.exportConfig();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red.shade800),
      );
    }
  }

  Future<void> _importConfig() async {
    final result = await importConfigFile(ref);
    if (!mounted) return;
    if (result.cancelled) return;
    if (result.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid config: ${result.error}'), backgroundColor: Colors.red.shade800),
      );
    } else {
      ref.read(onboardingControllerProvider.notifier).loadFromConfig(result.config!);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Config imported successfully!'), backgroundColor: Color(0xFF2E7D32)),
      );
    }
  }

  void _finishOnboarding() async {
    final controller = ref.read(onboardingControllerProvider.notifier);
    final audioManager = ref.read(audioManagerProvider);
    audioManager.stopTyping();
    final storage = ref.read(storageServiceProvider);

    // Build and persist config
    final config = controller.buildFinalConfig();
    final jsonString = const JsonEncoder.withIndent('  ').convert(config.toJson());
    await ConfigStorageService().saveConfig(jsonString);

    await storage.setOnboardingCompleted(true);
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/home');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingControllerProvider);
    final rs = context.rs;
    ref.listen(onboardingControllerProvider.select((s) => s.currentStep), (prev, next) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_focusNode.hasFocus) {
          _focusNode.requestFocus();
        }
      });
    });
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      autofocus: true,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            _handleBack();
          }
        },
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
                    rs.isPortrait
                        ? _buildPortraitContent(state, rs)
                        : _buildLandscapeContent(state, rs),
                  ],
                ),
              ),
            ),
            _buildControls(state, rs),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildLandscapeContent(OnboardingState state, Responsive rs) {
    return Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PixelMascot(size: rs.isSmall ? 36 : 48),
          Expanded(
            child: _buildContent(state),
          ),
        ],
      ),
    );
  }

  Widget _buildPortraitContent(OnboardingState state, Responsive rs) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PixelMascot(size: rs.isSmall ? 28 : 40),
          SizedBox(height: rs.spacing.sm),
          Expanded(child: _buildContent(state)),
        ],
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
        return _WelcomeStep(onComplete: controller.onMessageComplete);
      case OnboardingStep.legalNotice:
        return _LegalNoticeStep(onComplete: controller.onMessageComplete);
      case OnboardingStep.consoleSetup:
        return ConsoleSetupStep(onComplete: controller.onMessageComplete);
      case OnboardingStep.complete:
        return _CompleteStep(
          configuredCount: state.configuredCount,
          onComplete: controller.onMessageComplete,
          onExport: controller.exportConfig,
        );
    }
  }

  Widget _buildControls(OnboardingState state, Responsive rs) {
    // Dynamic HUD buttons based on sub-state
    final List<Widget> buttons = [];

    if (state.currentStep == OnboardingStep.consoleSetup) {
      if (state.hasProviderForm) {
        // Form level
        buttons.addAll([
          ControlButton(
            label: 'A',
            action: 'Save',
            onTap: () => ref.read(onboardingControllerProvider.notifier).saveProvider(),
          ),
          ControlButton(
            label: 'B',
            action: 'Cancel',
            onTap: () => ref.read(onboardingControllerProvider.notifier).cancelProviderForm(),
          ),
          ControlButton(
            label: 'Y',
            action: 'Test',
            onTap: state.isTestingConnection
                ? null
                : () => ref.read(onboardingControllerProvider.notifier).testProviderConnection(),
          ),
        ]);
      } else if (state.hasConsoleSelected) {
        // Panel level
        final sub = state.consoleSubState;
        buttons.addAll([
          ControlButton(
            label: 'A',
            action: 'Done',
            onTap: sub?.isComplete == true
                ? () => ref.read(onboardingControllerProvider.notifier).saveConsoleConfig()
                : null,
            highlight: sub?.isComplete == true,
          ),
          ControlButton(
            label: 'B',
            action: 'Close',
            onTap: () => ref.read(onboardingControllerProvider.notifier).deselectConsole(),
          ),
          ControlButton(
            label: 'Y',
            action: 'Add Source',
            onTap: () => ref.read(onboardingControllerProvider.notifier).startAddProvider(),
          ),
        ]);
      } else {
        // Grid level
        buttons.addAll([
          ControlButton(
            label: 'A',
            action: 'Continue',
            onTap: state.configuredCount > 0 ? _handleContinue : null,
            highlight: state.configuredCount > 0,
          ),
          if (!state.isFirstStep)
            ControlButton(
              label: 'B',
              action: 'Back',
              onTap: _handleBack,
            ),
          if (state.configuredCount > 0)
            ControlButton(label: '+', action: 'Export', onTap: _exportConfig),
          ControlButton(label: '\u2212', action: 'Import', onTap: _importConfig),
        ]);
      }
    } else {
      // Standard step buttons
      buttons.add(
        ControlButton(
          label: 'A',
          action: state.isLastStep ? 'Start!' : 'Continue',
          onTap: state.canProceed ? _handleContinue : null,
          highlight: state.canProceed,
        ),
      );
      if (!state.isFirstStep) {
        buttons.add(
          ControlButton(
            label: 'B',
            action: 'Back',
            onTap: _handleBack,
          ),
        );
      }
    }

    if (ref.watch(downloadCountProvider) > 0) {
      buttons.add(
        ControlButton(
          label: '',
          action: 'Downloads',
          icon: Icons.play_arrow_rounded,
          highlight: true,
          onTap: () => toggleDownloadOverlay(ref),
        ),
      );
    }

    return ConsoleHud(buttons: buttons);
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

class _WelcomeStep extends StatelessWidget {
  final VoidCallback onComplete;
  const _WelcomeStep({required this.onComplete});
  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final labelFontSize = rs.isSmall ? 10.0 : 12.0;
    return Column(
      key: const ValueKey('welcome'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ChatBubble(
          message:
              "Hey there! I'm Pixel, your R-Shop guide! Ready to explore your retro game collection?",
          onComplete: onComplete,
        ),
        SizedBox(height: rs.spacing.md),
        Padding(
          padding: EdgeInsets.only(left: rs.isSmall ? 40 : 60),
          child: Text(
            'Welcome to R-Shop',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: labelFontSize,
              letterSpacing: 2,
            ),
          ),
        ),
      ],
    );
  }
}

class _LegalNoticeStep extends StatelessWidget {
  final VoidCallback onComplete;
  const _LegalNoticeStep({required this.onComplete});
  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final labelFontSize = rs.isSmall ? 10.0 : 12.0;
    final iconSize = rs.isSmall ? 12.0 : 16.0;
    return Column(
      key: const ValueKey('legalNotice'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ChatBubble(
          message:
              "Heads up! R-Shop connects to file servers YOU configure to browse and download ROMs. Make sure you have the legal right to download any content \u2013 respect copyright laws in your region.",
          onComplete: onComplete,
        ),
        SizedBox(height: rs.spacing.md),
        Padding(
          padding: EdgeInsets.only(left: rs.isSmall ? 40 : 60),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: Colors.orange.shade400, size: iconSize),
              SizedBox(width: rs.spacing.sm),
              Text(
                'LEGAL NOTICE',
                style: TextStyle(
                  color: Colors.orange.shade400,
                  fontSize: labelFontSize,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CompleteStep extends StatelessWidget {
  final int configuredCount;
  final VoidCallback onComplete;
  final Future<void> Function() onExport;

  const _CompleteStep({
    required this.configuredCount,
    required this.onComplete,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final labelFontSize = rs.isSmall ? 11.0 : 14.0;
    final iconSize = rs.isSmall ? 16.0 : 20.0;
    final buttonFontSize = rs.isSmall ? 12.0 : 14.0;

    return Column(
      key: const ValueKey('complete'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ChatBubble(
          message:
              "Perfect! $configuredCount ${configuredCount == 1 ? 'console' : 'consoles'} set up. Export your config to use it on other devices. Press A to jump in!",
          onComplete: onComplete,
        ),
        SizedBox(height: rs.isSmall ? rs.spacing.lg : rs.spacing.xl),
        Padding(
          padding: EdgeInsets.only(left: rs.isSmall ? 40 : 60),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary badge
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: rs.isSmall ? rs.spacing.md : rs.spacing.lg,
                  vertical: rs.isSmall ? rs.spacing.sm : rs.spacing.md,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(rs.radius.md),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: iconSize),
                    SizedBox(width: rs.spacing.sm),
                    Text(
                      'Setup Complete',
                      style: TextStyle(
                        color: Colors.green.shade300,
                        fontSize: labelFontSize,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: rs.spacing.md),
              // Export button
              GestureDetector(
                onTap: onExport,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: rs.spacing.lg,
                    vertical: rs.spacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(rs.radius.md),
                    border: Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.share, color: Colors.redAccent, size: iconSize),
                      SizedBox(width: rs.spacing.sm),
                      Text(
                        'Export Config',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: buttonFontSize,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
