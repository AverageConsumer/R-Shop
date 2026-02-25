import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/responsive/responsive.dart';
import '../onboarding_controller.dart';
import 'chat_bubble.dart';
import 'romm_action_button.dart';
import 'romm_connect_view.dart';
import 'romm_folder_view.dart';
import 'romm_select_view.dart';

class RommSetupStep extends ConsumerWidget {
  final VoidCallback onComplete;

  const RommSetupStep({super.key, required this.onComplete});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingControllerProvider);
    final rs = state.rommSetupState;
    if (rs == null) return const SizedBox.shrink();

    switch (rs.subStep) {
      case RommSetupSubStep.ask:
        return _RommAskView(onComplete: onComplete);
      case RommSetupSubStep.connect:
        return RommConnectView(onComplete: onComplete);
      case RommSetupSubStep.select:
        return RommSelectView(onComplete: onComplete);
      case RommSetupSubStep.folder:
        return RommFolderView(onComplete: onComplete);
    }
  }
}

// --- Ask View ---

class _RommAskView extends ConsumerWidget {
  final VoidCallback onComplete;
  const _RommAskView({required this.onComplete});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(onboardingControllerProvider.notifier);
    final rs = context.rs;
    final buttonFontSize = rs.isSmall ? 12.0 : 14.0;
    final labelFontSize = rs.isSmall ? 10.0 : 12.0;
    final iconSize = rs.isSmall ? 14.0 : 18.0;

    return FocusScope(
      child: Column(
        key: const ValueKey('rommAsk'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ChatBubble(
            message:
                "Do you use a RomM server for your game collection? I can connect to it and auto-discover your consoles!",
            onComplete: onComplete,
          ),
          SizedBox(height: rs.spacing.lg),
          Padding(
            padding: EdgeInsets.only(left: rs.isSmall ? 40 : 60),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(bottom: rs.spacing.sm),
                  child: Row(
                    children: [
                      Icon(Icons.dns_rounded,
                          color: Colors.blue.shade300, size: iconSize),
                      SizedBox(width: rs.spacing.sm),
                      Text(
                        'ROMM SERVER',
                        style: TextStyle(
                          color: Colors.blue.shade300,
                          fontSize: labelFontSize,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
                FocusTraversalGroup(
                  child: Row(
                    children: [
                      Expanded(
                        child: RommActionButton(
                          label: 'Yes, connect my server',
                          icon: Icons.cloud_done_rounded,
                          color: Colors.green,
                          autofocus: true,
                          onTap: () => controller.rommSetupAnswer(true),
                        ),
                      ),
                      SizedBox(width: rs.spacing.md),
                      Expanded(
                        child: RommActionButton(
                          label: 'No, skip',
                          icon: Icons.skip_next_rounded,
                          color: Colors.grey,
                          onTap: () => controller.rommSetupAnswer(false),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: rs.spacing.md),
                Text(
                  'You can always add RomM sources per-console later.',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: buttonFontSize - 2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
