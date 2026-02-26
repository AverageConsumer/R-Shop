import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/responsive/responsive.dart';
import '../../models/system_model.dart';
import '../../providers/app_providers.dart';
import '../../providers/game_providers.dart';
import '../../widgets/console_hud.dart';
import '../../widgets/console_notification.dart';
import '../../widgets/download_overlay.dart';
import 'onboarding_controller.dart';
import 'widgets/console_setup_hud.dart';
import 'widgets/chat_bubble.dart';
import 'widgets/console_setup_step.dart';
import 'widgets/pixel_mascot.dart';
import 'widgets/local_setup_step.dart';
import 'widgets/romm_setup_step.dart';

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
    final controller = ref.read(onboardingControllerProvider.notifier);

    // RomM setup step — delegate based on sub-step
    if (state.currentStep == OnboardingStep.rommSetup) {
      final rs = state.rommSetupState;
      if (rs != null) {
        switch (rs.subStep) {
          case RommSetupSubStep.ask:
            // ConsoleFocusable buttons handle A/Enter; only handle B here
            if (event.logicalKey == LogicalKeyboardKey.gameButtonB ||
                event.logicalKey == LogicalKeyboardKey.escape) {
              _handleBack();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          case RommSetupSubStep.connect:
            if (event.logicalKey == LogicalKeyboardKey.gameButtonB ||
                event.logicalKey == LogicalKeyboardKey.escape) {
              controller.rommSetupBack();
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.gameButtonY) {
              if (rs.hasConnection && !state.isTestingConnection) {
                controller.testRommSetupConnection();
              }
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          case RommSetupSubStep.select:
            if (event.logicalKey == LogicalKeyboardKey.gameButtonB ||
                event.logicalKey == LogicalKeyboardKey.escape) {
              controller.rommSetupBack();
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.gameButtonStart) {
              _handleContinue();
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.gameButtonY) {
              final allSelected =
                  rs.selectedCount == rs.matchedCount;
              controller.toggleAllRommSystems(!allSelected);
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          case RommSetupSubStep.folder:
            if (event.logicalKey == LogicalKeyboardKey.gameButtonB ||
                event.logicalKey == LogicalKeyboardKey.escape) {
              controller.rommSetupBack();
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.gameButtonStart) {
              _handleContinue();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
        }
      }
    }

    // Local setup step — delegate based on phase
    if (state.currentStep == OnboardingStep.localSetup) {
      final ls = state.localSetupState;
      if (ls != null) {
        if (ls.isAutoDetecting || ls.isScanningPhase) {
          return KeyEventResult.handled;
        }
        if (ls.isResultsPhase) {
          if (event.logicalKey == LogicalKeyboardKey.gameButtonB ||
              event.logicalKey == LogicalKeyboardKey.escape) {
            controller.localSetupBack();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.gameButtonStart) {
            _handleContinue();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        }
        if (ls.isCreatePhase) {
          if (event.logicalKey == LogicalKeyboardKey.gameButtonB ||
              event.logicalKey == LogicalKeyboardKey.escape) {
            controller.localSetupBack();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.gameButtonStart) {
            _handleContinue();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.gameButtonY) {
            final allSelected = ls.createSystemIds!.length ==
                SystemModel.supportedSystems.length;
            controller.toggleAllCreateSystems(!allSelected);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        }
        // Choice phase
        if (event.logicalKey == LogicalKeyboardKey.gameButtonB ||
            event.logicalKey == LogicalKeyboardKey.escape) {
          _handleBack();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      }
    }

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
          if (state.canTest &&
              !state.isTestingConnection &&
              !isNonLanHttpBlocked(state, ref)) {
            controller.testAndSaveProvider();
          }
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
        return KeyEventResult.ignored;
      }

      // Grid level: Start = continue, Select = import
      if (event.logicalKey == LogicalKeyboardKey.gameButtonStart) {
        _handleContinue();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.gameButtonSelect) {
        _importConfig();
        return KeyEventResult.handled;
      }
    }

    // Complete step: Select = export
    if (state.isLastStep &&
        event.logicalKey == LogicalKeyboardKey.gameButtonSelect) {
      _exportConfig();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.gameButtonA ||
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.space ||
        event.logicalKey == LogicalKeyboardKey.gameButtonSelect) {
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
    } else if (state.currentStep == OnboardingStep.rommSetup) {
      final rommState = state.rommSetupState;
      if (rommState != null) {
        if (rommState.subStep == RommSetupSubStep.select) {
          _persistRommCredentials(rommState);
          feedback.tick();
          controller.nextStep();
        } else if (rommState.subStep == RommSetupSubStep.folder) {
          feedback.tick();
          controller.rommFolderConfirm();
        }
      }
      return;
    } else if (state.currentStep == OnboardingStep.localSetup) {
      final ls = state.localSetupState;
      if (ls != null && ls.isResultsPhase) {
        feedback.tick();
        controller.localSetupConfirm();
      } else if (ls != null && ls.isCreatePhase && ls.createSystemIds!.isNotEmpty) {
        feedback.tick();
        controller.confirmCreateFolders().then((error) {
          if (error != null && mounted) {
            showConsoleNotification(context, message: error);
          }
        });
      }
      return;
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

    if (state.currentStep == OnboardingStep.rommSetup) {
      audioManager.stopTyping();
      feedback.cancel();
      controller.rommSetupBack();
      return;
    }

    if (state.currentStep == OnboardingStep.localSetup) {
      audioManager.stopTyping();
      feedback.cancel();
      controller.localSetupBack();
      return;
    }

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
      showConsoleNotification(context, message: 'Export failed: $e');
    }
  }

  Future<void> _importConfig() async {
    final result = await importConfigFile(ref);
    if (!mounted) return;
    if (result.cancelled) return;
    if (result.error != null) {
      showConsoleNotification(context, message: 'Invalid config: ${result.error}');
    } else {
      ref.read(onboardingControllerProvider.notifier).loadFromConfig(result.config!);
      showConsoleNotification(context, message: 'Config imported!', isError: false);
    }
  }

  void _persistRommCredentials(RommSetupState rommState) {
    final storage = ref.read(storageServiceProvider);
    if (rommState.hasConnection) {
      storage.setRommUrl(rommState.url.trim());
      final auth = rommState.authConfig;
      if (auth != null) {
        storage.setRommAuth(const JsonEncoder().convert(auth.toJson()));
      } else {
        storage.setRommAuth(null);
      }
    }
  }

  Future<void> _finishOnboarding() async {
    final controller = ref.read(onboardingControllerProvider.notifier);
    final audioManager = ref.read(audioManagerProvider);
    audioManager.stopTyping();
    final storage = ref.read(storageServiceProvider);

    try {
      final config = controller.buildFinalConfig();
      final jsonString = const JsonEncoder.withIndent('  ').convert(config.toJson());
      await ref.read(configStorageServiceProvider).saveConfig(jsonString);
      await storage.setOnboardingCompleted(true);
      if (!mounted) return;
      ref.invalidate(bootstrappedConfigProvider);
    } catch (e) {
      if (!mounted) return;
      showConsoleNotification(context, message: 'Failed to save: $e');
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/home');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingControllerProvider);
    final rs = context.rs;
    ref.listen(onboardingControllerProvider.select((s) => s.currentStep), (prev, next) {
      if (next == OnboardingStep.consoleSetup) return;
      if (next == OnboardingStep.rommSetup) return;
      if (next == OnboardingStep.localSetup) return;
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
      case OnboardingStep.rommSetup:
        return RommSetupStep(onComplete: controller.onMessageComplete);
      case OnboardingStep.localSetup:
        return LocalSetupStep(onComplete: controller.onMessageComplete);
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
    if (state.currentStep == OnboardingStep.rommSetup) {
      final rommState = state.rommSetupState;
      if (rommState != null) {
        switch (rommState.subStep) {
          case RommSetupSubStep.ask:
            return ConsoleHud(
              b: HudAction('Back', onTap: _handleBack),
            );
          case RommSetupSubStep.connect:
            final controller =
                ref.read(onboardingControllerProvider.notifier);
            return ConsoleHud(
              b: HudAction('Back', onTap: () => controller.rommSetupBack()),
              y: HudAction(
                'Test & Discover',
                onTap: rommState.hasConnection && !state.isTestingConnection
                    ? controller.testRommSetupConnection
                    : null,
              ),
            );
          case RommSetupSubStep.select:
            final controller =
                ref.read(onboardingControllerProvider.notifier);
            final allSelected =
                rommState.selectedCount == rommState.matchedCount;
            return ConsoleHud(
              start: HudAction('Continue', onTap: _handleContinue,
                  highlight: true),
              b: HudAction('Back', onTap: () => controller.rommSetupBack()),
              y: HudAction(
                allSelected ? 'Deselect All' : 'Select All',
                onTap: () =>
                    controller.toggleAllRommSystems(!allSelected),
              ),
            );
          case RommSetupSubStep.folder:
            final controller =
                ref.read(onboardingControllerProvider.notifier);
            return ConsoleHud(
              start: HudAction('Continue', onTap: _handleContinue,
                  highlight: true),
              b: HudAction('Back', onTap: () => controller.rommSetupBack()),
            );
        }
      }
    }

    if (state.currentStep == OnboardingStep.localSetup) {
      final ls = state.localSetupState;
      if (ls != null && ls.isResultsPhase) {
        return ConsoleHud(
          start: HudAction('Continue', onTap: _handleContinue, highlight: true),
          b: HudAction('Back', onTap: _handleBack),
        );
      }
      if (ls != null && ls.isCreatePhase) {
        final controller = ref.read(onboardingControllerProvider.notifier);
        final allSelected = ls.createSystemIds!.length ==
            SystemModel.supportedSystems.length;
        return ConsoleHud(
          start: ls.createSystemIds!.isNotEmpty
              ? HudAction('Create', onTap: _handleContinue, highlight: true)
              : null,
          b: HudAction('Back', onTap: _handleBack),
          y: HudAction(
            allSelected ? 'Deselect All' : 'Select All',
            onTap: () => controller.toggleAllCreateSystems(!allSelected),
          ),
        );
      }
      // Hide Back during auto-detect to prevent race condition
      if (ls != null && ls.isAutoDetecting) {
        return const ConsoleHud();
      }
      return ConsoleHud(
        b: HudAction('Back', onTap: _handleBack),
      );
    }

    if (state.currentStep == OnboardingStep.consoleSetup) {
      final shared = buildConsoleSetupHud(state: state, ref: ref);
      if (shared != null) return shared;

      // Grid level
      return ConsoleHud(
        start: state.configuredCount > 0
            ? HudAction('Continue', onTap: _handleContinue, highlight: true)
            : null,
        b: !state.isFirstStep ? HudAction('Back', onTap: _handleBack) : null,
        select: HudAction('Import', onTap: _importConfig),
      );
    }

    // Standard steps
    return ConsoleHud(
      a: HudAction(
        state.isLastStep ? 'Start!' : 'Continue',
        onTap: state.canProceed ? _handleContinue : null,
        highlight: state.canProceed,
      ),
      b: !state.isFirstStep ? HudAction('Back', onTap: _handleBack) : null,
      select: state.isLastStep ? HudAction('Export', onTap: _exportConfig) : null,
    );
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
