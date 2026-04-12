import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/responsive/responsive.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/config/provider_config.dart';
import '../onboarding_controller.dart';
import 'chat_bubble.dart';
import 'console_config_panel.dart';
import 'console_grid.dart';

class ConsoleSetupStep extends ConsumerWidget {
  final VoidCallback onComplete;

  const ConsoleSetupStep({super.key, required this.onComplete});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingControllerProvider);
    final rs = context.rs;
    final l = L.of(context);

    if (state.hasConsoleSelected) {
      final system = state.selectedSystem;
      final sub = state.consoleSubState;

      String message;
      Color? accentColor;
      if (state.hasProviderForm) {
        final isRomm = state.providerForm?.type == ProviderType.romm;
        if (state.isTestingConnection) {
          message = l.onboarding_hangOn;
        } else if (isRomm && state.rommPlatforms != null && state.rommMatchedPlatform != null) {
          message = l.onboarding_foundConsole;
          accentColor = Colors.green;
        } else if (isRomm && state.rommPlatforms != null && state.rommMatchedPlatform == null) {
          message = l.onboarding_pickPlatform;
        } else if (isRomm && state.rommFetchError != null) {
          message = l.onboarding_couldNotReach;
        } else if (!isRomm && state.connectionTestSuccess) {
          message = l.onboarding_connectionGood;
          accentColor = Colors.green;
        } else if (!isRomm && state.connectionTestError != null) {
          message = l.onboarding_couldNotConnect;
        } else {
          message = l.onboarding_whatKindOfSource;
        }
      } else if (sub != null && sub.providers.isNotEmpty && sub.targetFolder != null) {
        message = l.onboarding_lookingGood;
      } else if (sub != null && sub.targetFolder != null && sub.providers.isEmpty) {
        message = l.onboarding_localCollection;
        accentColor = Colors.cyanAccent;
      } else if (sub != null && sub.targetFolder != null) {
        message = l.onboarding_addMoreSources;
      } else {
        message = "Cool, ${system?.name ?? 'this one'}! First, pick a folder for your ROMs.";
      }

      return FocusScope(
        child: Column(
          key: const ValueKey('consoleConfig'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ChatBubble(
              key: ValueKey('bubble_config_${state.selectedConsoleId}'
                  '_${state.hasProviderForm}'
                  '_${state.isTestingConnection}'
                  '_${state.connectionTestSuccess}'
                  '_${state.connectionTestError ?? ''}'
                  '_${state.rommMatchedPlatform?.id ?? ''}'),
              message: message,
              accentColor: accentColor,
              onComplete: onComplete,
            ),
            SizedBox(height: rs.spacing.md),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  left: rs.isSmall ? 40 : 60,
                  bottom: 64,
                ),
                child: const ConsoleConfigPanel(),
              ),
            ),
          ],
        ),
      );
    }

    // Grid view
    final configuredCount = state.configuredCount;
    String message;
    if (configuredCount == 0) {
      message = l.onboarding_letsSetUp;
    } else {
      message =
          "Nice! $configuredCount ${configuredCount == 1 ? 'console' : 'consoles'} configured. Select another to add more, or press B to go back.";
    }

    return FocusScope(
      child: Column(
        key: const ValueKey('consoleGrid'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ChatBubble(
            key: ValueKey('bubble_grid_$configuredCount'),
            message: message,
            onComplete: onComplete,
          ),
          SizedBox(height: rs.spacing.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                left: rs.isSmall ? 40 : 60,
                bottom: 64,
              ),
              child: const ConsoleGrid(),
            ),
          ),
        ],
      ),
    );
  }
}
