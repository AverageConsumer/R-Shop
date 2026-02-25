import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/responsive/responsive.dart';
import '../../../core/widgets/console_focusable.dart';
import '../../../models/system_model.dart';
import '../onboarding_controller.dart';
import 'chat_bubble.dart';
import 'romm_action_button.dart';

class RommFolderView extends ConsumerWidget {
  final VoidCallback onComplete;
  const RommFolderView({super.key, required this.onComplete});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingControllerProvider);
    final rs = context.rs;
    final rommSetup = state.rommSetupState;
    if (rommSetup == null) return const SizedBox.shrink();

    final scanned = rommSetup.scannedFolders;

    // Phase 1: No scan yet — show choice buttons
    if (scanned == null && !rommSetup.isScanning) {
      return FolderChoiceView(onComplete: onComplete);
    }

    // Scanning in progress
    if (rommSetup.isScanning) {
      return FocusScope(
        child: Column(
          key: const ValueKey('rommFolderScanning'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ChatBubble(
              message: "Scanning your ROM folder...",
              onComplete: onComplete,
            ),
            SizedBox(height: rs.spacing.lg),
            Padding(
              padding: EdgeInsets.only(left: rs.isSmall ? 40 : 60),
              child: const CircularProgressIndicator(
                color: Colors.redAccent,
                strokeWidth: 2,
              ),
            ),
          ],
        ),
      );
    }

    // Phase 2: Show scan results
    return FolderResultsView(
      rommSetup: rommSetup,
      onComplete: onComplete,
    );
  }
}

class FolderChoiceView extends ConsumerWidget {
  final VoidCallback onComplete;
  const FolderChoiceView({super.key, required this.onComplete});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(onboardingControllerProvider.notifier);
    final rs = context.rs;
    final hintFontSize = rs.isSmall ? 10.0 : 12.0;

    return FocusScope(
      child: Column(
        key: const ValueKey('rommFolderChoice'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ChatBubble(
            message:
                "Do you have an existing ROM folder on your device? I can scan it and match subfolders to your consoles!",
            onComplete: onComplete,
          ),
          SizedBox(height: rs.spacing.lg),
          Padding(
            padding: EdgeInsets.only(left: rs.isSmall ? 40 : 60),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FocusTraversalGroup(
                  child: Row(
                    children: [
                      Expanded(
                        child: RommActionButton(
                          label: 'Yes, pick folder',
                          icon: Icons.folder_open_rounded,
                          color: Colors.blue,
                          autofocus: true,
                          onTap: () => controller.rommFolderChoice(true),
                        ),
                      ),
                      SizedBox(width: rs.spacing.md),
                      Expanded(
                        child: RommActionButton(
                          label: 'No, create new',
                          icon: Icons.create_new_folder_rounded,
                          color: Colors.green,
                          onTap: () => controller.rommFolderChoice(false),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: rs.spacing.md),
                Text(
                  'You can always change folders per-console later.',
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

class FolderResultsView extends ConsumerWidget {
  final RommSetupState rommSetup;
  final VoidCallback onComplete;

  const FolderResultsView({
    super.key,
    required this.rommSetup,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(onboardingControllerProvider.notifier);
    final rs = context.rs;
    final scanned = rommSetup.scannedFolders ?? [];
    final selectedIds = rommSetup.selectedSystemIds;
    final localOnlyIds = rommSetup.localOnlySystemIds;
    final fontSize = rs.isSmall ? 11.0 : 13.0;
    final labelFontSize = rs.isSmall ? 10.0 : 12.0;

    // Categorize folders
    final matched = <ScannedFolder>[];
    final localFound = <ScannedFolder>[];
    final unmatched = <ScannedFolder>[];
    final ignored = <ScannedFolder>[];

    // Build set of system IDs already assigned (auto or manual)
    final assignedSystems = <String>{};
    final manualAssignments = rommSetup.folderAssignments;

    for (final folder in scanned) {
      // Check manual assignment first
      final manualSystemId = manualAssignments.entries
          .where((e) => e.value == folder.name)
          .map((e) => e.key)
          .firstOrNull;

      if (manualSystemId != null) {
        matched.add(folder);
        assignedSystems.add(manualSystemId);
      } else if (folder.autoMatchedSystemId != null &&
          selectedIds.contains(folder.autoMatchedSystemId)) {
        matched.add(folder);
        assignedSystems.add(folder.autoMatchedSystemId!);
      } else if (folder.isLocalOnly && folder.fileCount > 0) {
        localFound.add(folder);
        if (localOnlyIds.contains(folder.autoMatchedSystemId)) {
          assignedSystems.add(folder.autoMatchedSystemId!);
        }
      } else if (folder.fileCount == 0) {
        ignored.add(folder);
      } else {
        unmatched.add(folder);
      }
    }

    // Missing systems: selected RomM systems OR enabled local-only with no folder assigned
    final allEnabledIds = {...selectedIds, ...localOnlyIds};
    final missingSystems = allEnabledIds
        .where((id) => !assignedSystems.contains(id))
        .toList()
      ..sort();

    // Available systems for dropdowns: ALL supported systems not yet assigned
    final allSystemIds = SystemModel.supportedSystems.map((s) => s.id).toSet();
    final availableForDropdown = allSystemIds
        .where((id) => !assignedSystems.contains(id))
        .toList()
      ..sort();

    final totalFolders = matched.length + localFound.length + unmatched.length + ignored.length;

    // Build chat message
    String chatMessage;
    if (totalFolders == 0) {
      chatMessage = "I didn't find any subfolders. Default paths will be used.";
    } else if (localFound.isNotEmpty) {
      final localNames = localFound
          .map((f) {
            final sys = SystemModel.supportedSystems
                .where((s) => s.id == f.autoMatchedSystemId)
                .firstOrNull;
            return sys?.name ?? f.name;
          })
          .take(3)
          .toList();
      final nameStr = localNames.length <= 2
          ? localNames.join(' and ')
          : '${localNames.take(2).join(', ')} and more';
      chatMessage =
          "I found $totalFolders ${totalFolders == 1 ? 'folder' : 'folders'}! I also spotted your local $nameStr ${localFound.length == 1 ? 'collection' : 'collections'}!";
    } else {
      chatMessage =
          "I found $totalFolders ${totalFolders == 1 ? 'folder' : 'folders'}! Here's what I matched:";
    }

    return FocusScope(
      child: Column(
        key: const ValueKey('rommFolderResults'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ChatBubble(
            key: ValueKey('bubble_folderResults_${totalFolders}_${localOnlyIds.length}'),
            message: chatMessage,
            accentColor: matched.isNotEmpty || localFound.isNotEmpty
                ? Colors.green
                : Colors.orange,
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
                    // Matched folders (RomM)
                    for (final (i, folder) in matched.indexed)
                      FolderRow(
                        folder: folder,
                        status: FolderStatus.matched,
                        autofocus: i == 0,
                        assignedSystemId: manualAssignments.entries
                                .where((e) => e.value == folder.name)
                                .map((e) => e.key)
                                .firstOrNull ??
                            folder.autoMatchedSystemId,
                      ),
                    // Local-only folders
                    if (localFound.isNotEmpty) ...[
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: rs.spacing.md),
                        child: Row(
                          children: [
                            Icon(Icons.folder_rounded,
                                color: Colors.cyanAccent.shade400, size: 14),
                            SizedBox(width: rs.spacing.xs),
                            Text(
                              'LOCAL COLLECTIONS',
                              style: TextStyle(
                                color: Colors.cyanAccent.shade400,
                                fontSize: labelFontSize,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      for (final folder in localFound)
                        LocalFoundFolderRow(
                          folder: folder,
                          isEnabled: localOnlyIds.contains(folder.autoMatchedSystemId),
                          onToggle: () => controller.toggleLocalSystem(folder.autoMatchedSystemId!),
                        ),
                    ],
                    // Unmatched folders (with dropdown)
                    for (final folder in unmatched)
                      UnmatchedFolderRow(
                        folder: folder,
                        availableSystemIds: availableForDropdown,
                        onAssign: (systemId) =>
                            controller.assignFolderToSystem(folder.name, systemId),
                      ),
                    // Ignored folders
                    for (final folder in ignored)
                      FolderRow(
                        folder: folder,
                        status: folder.fileCount == 0
                            ? FolderStatus.ignoredNoFiles
                            : FolderStatus.ignoredNotSelected,
                      ),
                    // Missing systems separator
                    if (missingSystems.isNotEmpty) ...[
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: rs.spacing.md),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 1,
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: rs.spacing.md),
                              child: Text(
                                'Default path on download',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: labelFontSize,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Container(
                                height: 1,
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Wrap(
                        spacing: rs.spacing.sm,
                        runSpacing: rs.spacing.sm,
                        children: [
                          for (final id in missingSystems)
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: rs.spacing.md,
                                vertical: rs.spacing.xs,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius:
                                    BorderRadius.circular(rs.radius.sm),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.1),
                                ),
                              ),
                              child: Text(
                                id,
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: fontSize,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                    // Re-pick folder button
                    Padding(
                      padding: EdgeInsets.only(top: rs.spacing.lg),
                      child: RommActionButton(
                        label: 'Pick different folder',
                        icon: Icons.folder_open_rounded,
                        color: Colors.grey,
                        onTap: () => controller.pickRomFolder(),
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

enum FolderStatus { matched, ignoredNoFiles, ignoredNotSelected }

class FolderRow extends StatelessWidget {
  final ScannedFolder folder;
  final FolderStatus status;
  final String? assignedSystemId;
  final bool autofocus;

  const FolderRow({
    super.key,
    required this.folder,
    required this.status,
    this.assignedSystemId,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final fontSize = rs.isSmall ? 11.0 : 13.0;
    final detailFontSize = rs.isSmall ? 9.0 : 11.0;

    final IconData icon;
    final Color iconColor;
    final String statusText;
    final Color statusColor;

    switch (status) {
      case FolderStatus.matched:
        icon = Icons.check_circle_rounded;
        iconColor = Colors.green;
        final system = assignedSystemId != null
            ? SystemModel.supportedSystems
                .where((s) => s.id == assignedSystemId)
                .firstOrNull
            : null;
        statusText = system?.name ?? assignedSystemId ?? '';
        statusColor = Colors.green.shade300;
      case FolderStatus.ignoredNoFiles:
        icon = Icons.cancel_rounded;
        iconColor = Colors.grey.shade700;
        statusText = 'ignored';
        statusColor = Colors.grey.shade700;
      case FolderStatus.ignoredNotSelected:
        icon = Icons.cancel_rounded;
        iconColor = Colors.grey.shade700;
        statusText = 'not selected';
        statusColor = Colors.grey.shade700;
    }

    return Padding(
      padding: EdgeInsets.only(bottom: rs.spacing.xs),
      child: ConsoleFocusableListItem(
        onSelect: () {},
        autofocus: autofocus,
        borderRadius: rs.radius.sm,
        padding: EdgeInsets.symmetric(
          horizontal: rs.spacing.md,
          vertical: rs.spacing.sm,
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 16),
            SizedBox(width: rs.spacing.sm),
            Expanded(
              child: Text(
                '${folder.name}/',
                style: TextStyle(
                  color: status == FolderStatus.matched
                      ? Colors.white
                      : Colors.grey.shade600,
                  fontSize: fontSize,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            Text(
              statusText,
              style: TextStyle(
                color: statusColor,
                fontSize: detailFontSize,
              ),
            ),
            SizedBox(width: rs.spacing.md),
            Text(
              '${folder.fileCount} files',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: detailFontSize,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LocalFoundFolderRow extends StatelessWidget {
  final ScannedFolder folder;
  final bool isEnabled;
  final VoidCallback onToggle;

  const LocalFoundFolderRow({
    super.key,
    required this.folder,
    required this.isEnabled,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final nameFontSize = rs.isSmall ? 11.0 : 13.0;
    final detailFontSize = rs.isSmall ? 9.0 : 11.0;
    final checkSize = rs.isSmall ? 18.0 : 22.0;

    final system = folder.autoMatchedSystemId != null
        ? SystemModel.supportedSystems
            .where((s) => s.id == folder.autoMatchedSystemId)
            .firstOrNull
        : null;

    return Padding(
      padding: EdgeInsets.only(bottom: rs.spacing.xs),
      child: ConsoleFocusableListItem(
        onSelect: onToggle,
        borderRadius: rs.radius.sm,
        padding: EdgeInsets.symmetric(
          horizontal: rs.spacing.md,
          vertical: rs.spacing.sm,
        ),
        child: Row(
          children: [
            Icon(Icons.folder_rounded,
                color: Colors.cyanAccent.shade400, size: 16),
            SizedBox(width: rs.spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          system?.name ?? folder.name,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: nameFontSize,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SizedBox(width: rs.spacing.sm),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: rs.spacing.xs,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.cyanAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: Colors.cyanAccent.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          'local',
                          style: TextStyle(
                            color: Colors.cyanAccent.shade400,
                            fontSize: detailFontSize - 1,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${folder.name}/ \u2022 ${folder.fileCount} files',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: detailFontSize,
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
                    ? Colors.cyanAccent.withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isEnabled
                      ? Colors.cyanAccent.withValues(alpha: 0.7)
                      : Colors.white.withValues(alpha: 0.2),
                ),
              ),
              child: isEnabled
                  ? Icon(Icons.check,
                      color: Colors.cyanAccent, size: checkSize - 6)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class UnmatchedFolderRow extends StatelessWidget {
  final ScannedFolder folder;
  final List<String> availableSystemIds;
  final void Function(String?) onAssign;

  const UnmatchedFolderRow({
    super.key,
    required this.folder,
    required this.availableSystemIds,
    required this.onAssign,
  });

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final fontSize = rs.isSmall ? 11.0 : 13.0;
    final detailFontSize = rs.isSmall ? 9.0 : 11.0;

    return Padding(
      padding: EdgeInsets.only(bottom: rs.spacing.xs),
      child: ConsoleFocusableListItem(
        onSelect: () {},
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
            // Dropdown for assignment
            SystemDropdown(
              availableSystemIds: availableSystemIds,
              onChanged: onAssign,
            ),
            SizedBox(width: rs.spacing.md),
            Text(
              '${folder.fileCount} files',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: detailFontSize,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SystemDropdown extends StatelessWidget {
  final List<String> availableSystemIds;
  final void Function(String?) onChanged;

  const SystemDropdown({
    super.key,
    required this.availableSystemIds,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final fontSize = rs.isSmall ? 10.0 : 12.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: rs.spacing.sm),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(rs.radius.sm),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: null,
          hint: Text(
            '-- Skip --',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: fontSize,
            ),
          ),
          dropdownColor: const Color(0xFF1A1A1A),
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
          ),
          iconEnabledColor: Colors.orange.shade400,
          iconSize: 16,
          isDense: true,
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text(
                '-- Skip --',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: fontSize,
                ),
              ),
            ),
            for (final id in availableSystemIds)
              DropdownMenuItem<String?>(
                value: id,
                child: Text(
                  _systemLabel(id),
                  style: TextStyle(fontSize: fontSize),
                ),
              ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  String _systemLabel(String id) {
    final system = SystemModel.supportedSystems
        .where((s) => s.id == id)
        .firstOrNull;
    return system?.name ?? id;
  }
}
