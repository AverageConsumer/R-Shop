import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/responsive/responsive.dart';
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

    if (state.hasConsoleSelected) {
      final system = state.selectedSystem;
      final sub = state.consoleSubState;

      String message;
      Color? accentColor;
      if (state.hasProviderForm) {
        final isRomm = state.providerForm?.type == ProviderType.romm;
        if (state.isTestingConnection) {
          message = "Hang on, testing the connection...";
        } else if (isRomm && state.rommPlatforms != null && state.rommMatchedPlatform != null) {
          message = "I found this console on your RomM server! Confirm or pick a different one.";
          accentColor = Colors.green;
        } else if (isRomm && state.rommPlatforms != null && state.rommMatchedPlatform == null) {
          message = "Pick the matching platform from your RomM server.";
        } else if (isRomm && state.rommFetchError != null) {
          message = "Couldn't reach your RomM server. Check the URL and try again.";
        } else if (!isRomm && state.connectionTestSuccess) {
          message = "Connection looks good! You're all set to save this source.";
          accentColor = Colors.green;
        } else if (!isRomm && state.connectionTestError != null) {
          message = "Hmm, couldn't connect. Double-check the address and credentials.";
        } else {
          message = "What kind of source is this? Pick the connection type.";
        }
      } else if (sub != null && sub.providers.isNotEmpty && sub.targetFolder != null) {
        message = "Looking good! Add more sources or tap Done when you're ready.";
      } else if (sub != null && sub.targetFolder != null) {
        message = "Now add at least one source so I know where to find the ROMs.";
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
      message = "Let's set up your consoles! Tap any system to get started.";
    } else {
      message =
          "Nice! $configuredCount ${configuredCount == 1 ? 'console' : 'consoles'} configured. Tap another to add more, or press A to continue.";
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
