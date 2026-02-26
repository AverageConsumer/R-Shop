import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/console_hud.dart';
import '../onboarding_controller.dart';
import 'provider_form.dart';

/// Returns true when the provider form's URL is a non-LAN HTTP address
/// and the user hasn't opted in via the setting.
bool isNonLanHttpBlocked(OnboardingState state, WidgetRef ref) {
  final url = state.providerForm?.fields['url']?.toString() ?? '';
  if (!url.startsWith('http://')) return false;
  if (isPrivateNetworkUrl(url)) return false;
  return !ref.read(storageServiceProvider).getAllowNonLanHttp();
}

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
    final canAct = state.canTest &&
        !state.isTestingConnection &&
        !isNonLanHttpBlocked(state, ref);
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
