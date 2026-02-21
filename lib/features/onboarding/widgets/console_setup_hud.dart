import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../widgets/console_hud.dart';
import '../onboarding_controller.dart';

/// Shared HUD builder for provider-form and console-panel sub-states.
///
/// Used by both OnboardingScreen and ConfigModeScreen. Returns null at
/// grid level so the caller can provide its own screen-specific HUD.
ConsoleHud? buildConsoleSetupHud({
  required OnboardingState state,
  required WidgetRef ref,
}) {
  final controller = ref.read(onboardingControllerProvider.notifier);

  if (state.hasProviderForm) {
    final canAct = state.canTest && !state.isTestingConnection;
    return ConsoleHud(
      b: HudAction('Cancel', onTap: controller.cancelProviderForm),
      y: HudAction(
        'Test & Save',
        onTap: canAct ? controller.testAndSaveProvider : null,
      ),
    );
  }

  if (state.hasConsoleSelected) {
    final hasSources = state.consoleSubState?.providers.isNotEmpty ?? false;
    return ConsoleHud(
      b: HudAction('Close', onTap: controller.deselectConsole),
      y: HudAction('Add Source', onTap: controller.startAddProvider),
      dpad: hasSources ? (label: '◄►', action: 'Reorder') : null,
      x: hasSources ? const HudAction('Delete') : null,
    );
  }

  return null;
}
