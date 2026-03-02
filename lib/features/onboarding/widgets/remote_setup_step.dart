import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/responsive/responsive.dart';
import '../onboarding_controller.dart';
import 'chat_bubble.dart';
import 'configured_servers_summary.dart';
import 'remote_connect_view.dart';
import 'remote_folder_results_view.dart';
import 'romm_action_button.dart';

class RemoteSetupStep extends ConsumerWidget {
  final VoidCallback onComplete;

  const RemoteSetupStep({super.key, required this.onComplete});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingControllerProvider);
    final rs = state.remoteSetupState;
    if (rs == null) return const SizedBox.shrink();

    switch (rs.subStep) {
      case RemoteSetupSubStep.ask:
        return _RemoteAskView(onComplete: onComplete);
      case RemoteSetupSubStep.connect:
        return RemoteConnectView(onComplete: onComplete);
      case RemoteSetupSubStep.scanning:
        return _RemoteScanningView(onComplete: onComplete);
      case RemoteSetupSubStep.results:
        return RemoteFolderResultsView(onComplete: onComplete);
    }
  }
}

class _RemoteAskView extends ConsumerWidget {
  final VoidCallback onComplete;
  const _RemoteAskView({required this.onComplete});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);
    final rs = context.rs;
    final labelFontSize = rs.isSmall ? 10.0 : 12.0;
    final iconSize = rs.isSmall ? 14.0 : 18.0;
    final hintFontSize = rs.isSmall ? 10.0 : 12.0;
    final previousServers = state.configuredRemoteServers;
    final hasPreviousServers = previousServers.isNotEmpty;

    final chatMessage = hasPreviousServers
        ? "You've set up ${previousServers.length} "
            "${previousServers.length == 1 ? 'server' : 'servers'}. "
            "Want to add another, or continue to the next step?"
        : "Got a file server with your ROMs? If your server has an ES-DE "
            "style folder structure (like roms/snes/, roms/gba/, roms/psx/), "
            "I can auto-detect your consoles! Just point me to the ROM root folder.";

    return FocusScope(
      child: Column(
        key: const ValueKey('remoteAsk'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ChatBubble(
            key: ValueKey('bubble_remoteAsk_$hasPreviousServers'),
            message: chatMessage,
            onComplete: onComplete,
          ),
          SizedBox(height: rs.spacing.lg),
          Padding(
            padding: EdgeInsets.only(left: rs.isSmall ? 40 : 60),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasPreviousServers) ...[
                  ConfiguredServersSummary(servers: previousServers),
                ],
                Padding(
                  padding: EdgeInsets.only(bottom: rs.spacing.sm),
                  child: Row(
                    children: [
                      Icon(Icons.dns_rounded,
                          color: Colors.teal.shade300, size: iconSize),
                      SizedBox(width: rs.spacing.sm),
                      Text(
                        'FILE SERVER',
                        style: TextStyle(
                          color: Colors.teal.shade300,
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
                          label: hasPreviousServers
                              ? 'Add another server'
                              : 'Set up file server',
                          icon: hasPreviousServers
                              ? Icons.add_rounded
                              : Icons.cloud_done_rounded,
                          color: Colors.green,
                          autofocus: true,
                          onTap: () => controller.remoteSetupAnswer(true),
                        ),
                      ),
                      SizedBox(width: rs.spacing.md),
                      Expanded(
                        child: RommActionButton(
                          label: hasPreviousServers ? 'Continue' : 'Skip',
                          icon: hasPreviousServers
                              ? Icons.arrow_forward_rounded
                              : Icons.skip_next_rounded,
                          color: Colors.grey,
                          onTap: () => controller.remoteSetupAnswer(false),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: rs.spacing.md),
                Text(
                  'Supports SMB, FTP, and Web (HTTP) servers.',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: hintFontSize,
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

class _RemoteScanningView extends ConsumerWidget {
  final VoidCallback onComplete;
  const _RemoteScanningView({required this.onComplete});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rs = context.rs;

    return FocusScope(
      child: Column(
        key: const ValueKey('remoteScanning'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ChatBubble(
            message: "Scanning your server for console folders...",
            onComplete: onComplete,
          ),
          SizedBox(height: rs.spacing.lg),
          Padding(
            padding: EdgeInsets.only(left: rs.isSmall ? 40 : 60),
            child: const CircularProgressIndicator(
              color: Colors.teal,
              strokeWidth: 2,
            ),
          ),
        ],
      ),
    );
  }
}
