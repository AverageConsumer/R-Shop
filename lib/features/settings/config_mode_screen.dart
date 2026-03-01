import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/responsive/responsive.dart';
import '../../models/system_model.dart';
import '../../providers/app_providers.dart';
import '../../providers/ra_providers.dart';
import '../../services/audio_manager.dart';
import '../../providers/game_providers.dart';
import '../../widgets/console_hud.dart';
import '../../widgets/console_notification.dart';
import '../onboarding/onboarding_controller.dart';
import '../onboarding/widgets/console_setup_hud.dart';
import '../onboarding/widgets/console_setup_step.dart';
import '../onboarding/widgets/pixel_mascot.dart';

class ConfigModeScreen extends ConsumerStatefulWidget {
  const ConfigModeScreen({super.key});
  @override
  ConsumerState<ConfigModeScreen> createState() => _ConfigModeScreenState();
}

class _ConfigModeScreenState extends ConsumerState<ConfigModeScreen> {
  final FocusNode _focusNode = FocusNode();
  bool _initialized = false;
  late final AudioManager _audioManager;

  @override
  void initState() {
    super.initState();
    _audioManager = ref.read(audioManagerProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    try {
      _audioManager.stopTyping();
    } catch (e) { debugPrint('ConfigModeScreen: stopTyping failed: $e'); }
    _focusNode.dispose();
    super.dispose();
  }

  void _initFromConfig() {
    if (_initialized) return;
    _initialized = true;
    final configAsync = ref.read(bootstrappedConfigProvider);
    if (configAsync case AsyncData(value: final config)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(onboardingControllerProvider.notifier).loadFromConfig(config);
        }
      });
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (!ref.read(inputDebouncerProvider).canPerformAction()) {
      return KeyEventResult.handled;
    }

    final state = ref.read(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);

    // Provider form is open
    if (state.hasProviderForm) {
      if (event.logicalKey == LogicalKeyboardKey.gameButtonB ||
          event.logicalKey == LogicalKeyboardKey.escape) {
        controller.cancelProviderForm();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.gameButtonY) {
        if (state.canTest && !state.isTestingConnection) {
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

    // Grid level: B = save and go back
    if (event.logicalKey == LogicalKeyboardKey.gameButtonB ||
        event.logicalKey == LogicalKeyboardKey.escape) {
      _saveAndGoBack();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.gameButtonStart) {
      _exportConfig();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.gameButtonSelect) {
      _importConfig();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  Future<void> _saveAndGoBack() async {
    final audioManager = ref.read(audioManagerProvider);
    audioManager.stopTyping();
    final controller = ref.read(onboardingControllerProvider.notifier);
    final config = controller.buildFinalConfig();
    final jsonString =
        const JsonEncoder.withIndent('  ').convert(config.toJson());
    await ref.read(configStorageServiceProvider).saveConfig(jsonString);
    ref.invalidate(bootstrappedConfigProvider);
    _triggerRaSync();
    if (!mounted) return;
    Navigator.pop(context);
  }

  /// Trigger RA sync for newly added systems after config change.
  void _triggerRaSync() {
    final storage = ref.read(storageServiceProvider);
    if (!storage.isRaConfigured) return;
    final raSystems = SystemModel.supportedSystems
        .where((s) => s.raConsoleId != null)
        .toList();
    if (raSystems.isNotEmpty) {
      ref.read(raSyncServiceProvider.notifier).syncAll(raSystems, force: true);
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
      // Reload controller from freshly imported config
      ref.read(onboardingControllerProvider.notifier).loadFromConfig(result.config!);
      showConsoleNotification(context, message: 'Config imported!', isError: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingControllerProvider);
    final rs = context.rs;

    // Initialize on first build once config is available
    if (ref.watch(bootstrappedConfigProvider) case AsyncData()) {
      _initFromConfig();
    }

    // Re-request focus only after structural changes (console select/deselect,
    // form open/close). Skip minor changes (folder path, toggles, merge mode)
    // to avoid fighting with child focus restoration (e.g. after folder picker).
    ref.listen(onboardingControllerProvider, (prev, next) {
      if (next.hasProviderForm) return;
      if (prev != null &&
          prev.hasConsoleSelected == next.hasConsoleSelected &&
          prev.hasProviderForm == next.hasProviderForm) {
        return; // Minor change — don't steal focus
      }
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
          if (!didPop) _saveAndGoBack();
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              const _ConfigModeBackground(),
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
          Expanded(child: _buildContent(state)),
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
      child: ConsoleSetupStep(
        onComplete: () {}, // No message animation needed in config mode
      ),
    );
  }

  Widget _buildControls(OnboardingState state, Responsive rs) {
    final shared = buildConsoleSetupHud(state: state, ref: ref);
    if (shared != null) return shared;

    // Grid level
    return ConsoleHud(
      b: HudAction('Save & Back', onTap: _saveAndGoBack),
      start: HudAction('Export', onTap: _exportConfig),
      select: HudAction('Import', onTap: _importConfig),
    );
  }
}

class _ConfigModeBackground extends StatelessWidget {
  const _ConfigModeBackground();
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
