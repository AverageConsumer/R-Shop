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
    return ConsoleHud(
      b: HudAction('Cancel', onTap: controller.cancelProviderForm),
      y: HudAction(
        'Test',
        onTap: state.isTestingConnection || !state.canTest
            ? null
            : controller.testProviderConnection,
      ),
      showDownloads: false,
    );
  }

  if (state.hasConsoleSelected) {
    return ConsoleHud(
      b: HudAction('Close', onTap: controller.deselectConsole),
      y: HudAction('Add Source', onTap: controller.startAddProvider),
      showDownloads: false,
    );
  }

  return null;
}
