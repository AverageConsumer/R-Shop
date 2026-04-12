import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
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
  required BuildContext context,
}) {
  final l = L.of(context);
  final controller = ref.read(onboardingControllerProvider.notifier);

  if (state.hasProviderForm) {
    final isBlocked = state.isTestingConnection || isNonLanHttpBlocked(state, ref);
    return ConsoleHud(
      b: HudAction(l.common_cancel, onTap: controller.cancelProviderForm),
      y: HudAction(
        l.providerForm_testAndSave,
        onTap: isBlocked ? null : controller.testAndSaveProvider,
      ),
    );
  }

  if (state.hasConsoleSelected) {
    // Source add/remove/reorder lives in Settings → Sources now;
    // this panel only handles system-level options.
    return ConsoleHud(
      b: HudAction(l.common_close, onTap: controller.deselectConsole),
    );
  }

  return null;
}
