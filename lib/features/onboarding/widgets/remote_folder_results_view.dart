import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/responsive/responsive.dart';
import '../../../core/widgets/console_focusable.dart';
import '../../../models/system_model.dart';
import '../onboarding_controller.dart';
import 'chat_bubble.dart';
import 'configured_servers_summary.dart';
import 'romm_action_button.dart';
import 'system_picker_dialog.dart';

class RemoteFolderResultsView extends ConsumerWidget {
  final VoidCallback onComplete;

  const RemoteFolderResultsView({super.key, required this.onComplete});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);
    final rs = context.rs;
    final remoteState = state.remoteSetupState;
    if (remoteState == null) return const SizedBox.shrink();

    final scanned = remoteState.scannedFolders ?? [];
    final labelFontSize = rs.isSmall ? 10.0 : 12.0;

    // Categorize folders
    final matched = <ScannedFolder>[];
    final unmatched = <ScannedFolder>[];
    final manualAssignments = remoteState.folderAssignments;

    final assignedSystems = <String>{};

    for (final folder in scanned) {
      final manualSystemId = manualAssignments.entries
          .where((e) => e.value == folder.name)
          .map((e) => e.key)
          .firstOrNull;

      if (manualSystemId != null) {
        matched.add(folder);
        assignedSystems.add(manualSystemId);
      } else if (folder.autoMatchedSystemId != null &&
          remoteState.enabledSystemIds.contains(folder.autoMatchedSystemId)) {
        matched.add(folder);
        assignedSystems.add(folder.autoMatchedSystemId!);
      } else if (folder.autoMatchedSystemId == null) {
        unmatched.add(folder);
      } else {
        // Auto-matched but not enabled — treat as matched but toggled off
        matched.add(folder);
      }
    }

    // Available systems for dropdowns
    final allSystemIds = SystemModel.supportedSystems.map((s) => s.id).toSet();
    final availableForDropdown = allSystemIds
        .where((id) => !assignedSystems.contains(id))
        .toList()
      ..sort();

    // Build chat message
    final matchedCount = scanned.where((f) =>
        f.autoMatchedSystemId != null || manualAssignments.values.contains(f.name)).length;
    String chatMessage;
    if (scanned.isEmpty) {
      chatMessage = "I didn't find any folders at that path. "
          "Check the path and try again, or skip this step.";
    } else if (matchedCount == 0) {
      chatMessage = "I found ${scanned.length} "
          "${scanned.length == 1 ? 'folder' : 'folders'} but couldn't auto-match "
          "any to consoles. Use the dropdowns to assign them manually!";
    } else {
      chatMessage = "I found ${scanned.length} "
          "${scanned.length == 1 ? 'folder' : 'folders'} and auto-matched "
          "$matchedCount to consoles!";
    }

    return FocusScope(
      child: Column(
        key: const ValueKey('remoteFolderResults'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ChatBubble(
            key: ValueKey('bubble_remoteResults_${scanned.length}_$matchedCount'),
            message: chatMessage,
            accentColor: matchedCount > 0 ? Colors.green : Colors.orange,
            onComplete: onComplete,
          ),
          SizedBox(height: rs.spacing.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                left: rs.isSmall ? 40 : 60,
                bottom: 64,
              ),
              child: FocusTraversalGroup(
                child: ListView(
                  children: [
                    if (state.configuredRemoteServers.isNotEmpty)
                      ConfiguredServersSummary(
                          servers: state.configuredRemoteServers),
                    if (remoteState.scanError != null)
                      Padding(
                        padding: EdgeInsets.only(bottom: rs.spacing.md),
                        child: Container(
                          padding: EdgeInsets.all(rs.spacing.md),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(rs.radius.sm),
                            border: Border.all(
                              color: Colors.orange.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.warning_amber_rounded,
                                  color: Colors.orange.shade300, size: 18),
                              SizedBox(width: rs.spacing.sm),
                              Expanded(
                                child: Text(
                                  remoteState.scanError!,
                                  style: TextStyle(
                                    color: Colors.orange.shade300,
                                    fontSize: rs.isSmall ? 10.0 : 12.0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    // Provider badge
                    Padding(
                      padding: EdgeInsets.only(bottom: rs.spacing.md),
                      child: Row(
                        children: [
                          Icon(Icons.dns_rounded,
                              color: Colors.teal.shade400, size: 14),
                          SizedBox(width: rs.spacing.xs),
                          Text(
                            '${remoteState.providerType.name.toUpperCase()} SERVER',
                            style: TextStyle(
                              color: Colors.teal.shade400,
                              fontSize: labelFontSize,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Matched folders
                    for (final (i, folder) in matched.indexed) ...[
                      () {
                        final sysId = manualAssignments.entries
                                .where((e) => e.value == folder.name)
                                .map((e) => e.key)
                                .firstOrNull ??
                            folder.autoMatchedSystemId;
                        return _RemoteMatchedRow(
                          folder: folder,
                          autofocus: i == 0,
                          isEnabled: sysId != null &&
                              remoteState.enabledSystemIds.contains(sysId),
                          assignedSystemId: sysId,
                          onToggle: () {
                            if (sysId != null) {
                              controller.toggleRemoteSystem(sysId);
                            }
                          },
                        );
                      }(),
                    ],
                    // Unmatched folders
                    for (final (i, folder) in unmatched.indexed)
                      _RemoteUnmatchedRow(
                        folder: folder,
                        autofocus: matched.isEmpty && i == 0,
                        availableSystemIds: availableForDropdown,
                        onAssign: (systemId) =>
                            controller.assignRemoteFolder(folder.name, systemId),
                      ),
                    // Add another provider button
                    Padding(
                      padding: EdgeInsets.only(top: rs.spacing.lg),
                      child: RommActionButton(
                        label: 'Add another server',
                        icon: Icons.add_rounded,
                        color: Colors.teal,
                        onTap: () => controller.addAnotherRemoteProvider(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RemoteMatchedRow extends StatelessWidget {
  final ScannedFolder folder;
  final bool autofocus;
  final bool isEnabled;
  final String? assignedSystemId;
  final VoidCallback onToggle;

  const _RemoteMatchedRow({
    required this.folder,
    this.autofocus = false,
    required this.isEnabled,
    this.assignedSystemId,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final fontSize = rs.isSmall ? 11.0 : 13.0;
    final detailFontSize = rs.isSmall ? 9.0 : 11.0;
    final checkSize = rs.isSmall ? 18.0 : 22.0;

    final system = assignedSystemId != null
        ? SystemModel.supportedSystems
            .where((s) => s.id == assignedSystemId)
            .firstOrNull
        : null;

    return Padding(
      padding: EdgeInsets.only(bottom: rs.spacing.xs),
      child: ConsoleFocusableListItem(
        onSelect: onToggle,
        autofocus: autofocus,
        borderRadius: rs.radius.sm,
        padding: EdgeInsets.symmetric(
          horizontal: rs.spacing.md,
          vertical: rs.spacing.sm,
        ),
        child: Row(
          children: [
            Icon(
              isEnabled ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: isEnabled ? Colors.green : Colors.grey.shade700,
              size: 16,
            ),
            SizedBox(width: rs.spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    system?.name ?? assignedSystemId ?? folder.name,
                    style: TextStyle(
                      color: isEnabled ? Colors.white : Colors.grey.shade500,
                      fontSize: fontSize,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${folder.name}/',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: detailFontSize,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            Container(
                width: checkSize,
                height: checkSize,
                decoration: BoxDecoration(
                  color: isEnabled
                      ? Colors.green.withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isEnabled
                        ? Colors.green.withValues(alpha: 0.7)
                        : Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                child: isEnabled
                    ? Icon(Icons.check,
                        color: Colors.green, size: checkSize - 6)
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}

class _RemoteUnmatchedRow extends ConsumerWidget {
  final ScannedFolder folder;
  final bool autofocus;
  final List<String> availableSystemIds;
  final void Function(String?) onAssign;

  const _RemoteUnmatchedRow({
    required this.folder,
    this.autofocus = false,
    required this.availableSystemIds,
    required this.onAssign,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rs = context.rs;
    final fontSize = rs.isSmall ? 11.0 : 13.0;

    return Padding(
      padding: EdgeInsets.only(bottom: rs.spacing.xs),
      child: ConsoleFocusableListItem(
        autofocus: autofocus,
        onSelect: availableSystemIds.isNotEmpty
            ? () => showSystemPickerDialog(
                  context: context,
                  ref: ref,
                  availableSystemIds: availableSystemIds,
                  onSelect: (systemId) => onAssign(systemId),
                )
            : null,
        borderRadius: rs.radius.sm,
        padding: EdgeInsets.symmetric(
          horizontal: rs.spacing.md,
          vertical: rs.spacing.sm,
        ),
        child: Row(
          children: [
            Icon(Icons.help_outline_rounded,
                color: Colors.orange.shade400, size: 16),
            SizedBox(width: rs.spacing.sm),
            Expanded(
              child: Text(
                '${folder.name}/',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: fontSize,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: Colors.grey.shade600, size: 18),
          ],
        ),
      ),
    );
  }
}
