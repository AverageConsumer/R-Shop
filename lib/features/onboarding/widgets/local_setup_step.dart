import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/responsive/responsive.dart';
import '../../../core/widgets/console_focusable.dart';
import '../../../models/system_model.dart';
import '../onboarding_controller.dart';
import 'chat_bubble.dart';

class LocalSetupStep extends ConsumerWidget {
  final VoidCallback onComplete;

  const LocalSetupStep({super.key, required this.onComplete});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingControllerProvider);
    final ls = state.localSetupState;
    if (ls == null) return const SizedBox.shrink();

    if (ls.isScanningPhase) {
      return _LocalScanningView(onComplete: onComplete);
    }
    if (ls.isResultsPhase) {
      return _LocalResultsView(localSetup: ls, onComplete: onComplete);
    }
    return _LocalChoiceView(onComplete: onComplete);
  }
}

// --- Choice View ---

class _LocalChoiceView extends ConsumerWidget {
  final VoidCallback onComplete;
  const _LocalChoiceView({required this.onComplete});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(onboardingControllerProvider.notifier);
    final rs = context.rs;
    final labelFontSize = rs.isSmall ? 10.0 : 12.0;
    final iconSize = rs.isSmall ? 14.0 : 18.0;
    final hintFontSize = rs.isSmall ? 10.0 : 12.0;

    return FocusScope(
      child: Column(
        key: const ValueKey('localChoice'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ChatBubble(
            message:
                "Do you have a ROM folder on your device? I can scan it and auto-detect your consoles!",
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
                      Icon(Icons.folder_open_rounded,
                          color: Colors.blue.shade300, size: iconSize),
                      SizedBox(width: rs.spacing.sm),
                      Text(
                        'ROM FOLDER',
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
                        child: _ActionButton(
                          label: 'Yes, pick folder',
                          icon: Icons.folder_open_rounded,
                          color: Colors.blue,
                          autofocus: true,
                          onTap: () => controller.localSetupChoice(true),
                        ),
                      ),
                      SizedBox(width: rs.spacing.md),
                      Expanded(
                        child: _ActionButton(
                          label: 'No, skip',
                          icon: Icons.skip_next_rounded,
                          color: Colors.grey,
                          onTap: () => controller.localSetupChoice(false),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: rs.spacing.md),
                Text(
                  'You can always set up folders per-console later.',
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

// --- Scanning View ---

class _LocalScanningView extends StatelessWidget {
  final VoidCallback onComplete;
  const _LocalScanningView({required this.onComplete});

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;

    return FocusScope(
      child: Column(
        key: const ValueKey('localScanning'),
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
}

// --- Results View ---

class _LocalResultsView extends ConsumerWidget {
  final LocalSetupState localSetup;
  final VoidCallback onComplete;

  const _LocalResultsView({
    required this.localSetup,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(onboardingControllerProvider.notifier);
    final rs = context.rs;
    final scanned = localSetup.scannedFolders ?? [];
    final enabledIds = localSetup.enabledSystemIds;
    final labelFontSize = rs.isSmall ? 10.0 : 12.0;

    // Categorize folders
    final matched = <ScannedFolder>[];
    final unmatched = <ScannedFolder>[];
    final ignored = <ScannedFolder>[];

    final assignedSystems = <String>{};
    final manualAssignments = localSetup.folderAssignments;

    for (final folder in scanned) {
      final manualSystemId = manualAssignments.entries
          .where((e) => e.value == folder.name)
          .map((e) => e.key)
          .firstOrNull;

      if (manualSystemId != null) {
        matched.add(folder);
        assignedSystems.add(manualSystemId);
      } else if (folder.autoMatchedSystemId != null && folder.fileCount > 0) {
        matched.add(folder);
        assignedSystems.add(folder.autoMatchedSystemId!);
      } else if (folder.fileCount == 0) {
        ignored.add(folder);
      } else {
        unmatched.add(folder);
      }
    }

    // Available systems for dropdowns
    final allSystemIds = SystemModel.supportedSystems.map((s) => s.id).toSet();
    final availableForDropdown = allSystemIds
        .where((id) => !assignedSystems.contains(id))
        .toList()
      ..sort();

    final matchedCount = matched.where((f) {
      final sysId = manualAssignments.entries
              .where((e) => e.value == f.name)
              .map((e) => e.key)
              .firstOrNull ??
          f.autoMatchedSystemId;
      return sysId != null && enabledIds.contains(sysId);
    }).length;

    final totalFolders = matched.length + unmatched.length + ignored.length;

    // Build chat message
    String chatMessage;
    Color accentColor;
    if (totalFolders == 0) {
      chatMessage =
          "I didn't find any subfolders. You can set up consoles manually.";
      accentColor = Colors.orange;
    } else if (matched.isNotEmpty) {
      chatMessage =
          "I found $totalFolders ${totalFolders == 1 ? 'folder' : 'folders'} and matched ${matched.length} to consoles! Uncheck any you don't want.";
      accentColor = Colors.green;
    } else {
      chatMessage =
          "I found $totalFolders ${totalFolders == 1 ? 'folder' : 'folders'} but couldn't auto-match any. Use the dropdowns to assign them.";
      accentColor = Colors.orange;
    }

    return FocusScope(
      child: Column(
        key: const ValueKey('localResults'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ChatBubble(
            key: ValueKey(
                'bubble_localResults_${totalFolders}_$matchedCount'),
            message: chatMessage,
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
              child: FocusTraversalGroup(
                child: ListView(
                  children: [
                    // Matched folders
                    for (final (i, folder) in matched.indexed)
                      _MatchedFolderRow(
                        folder: folder,
                        assignedSystemId: manualAssignments.entries
                                .where((e) => e.value == folder.name)
                                .map((e) => e.key)
                                .firstOrNull ??
                            folder.autoMatchedSystemId,
                        isEnabled: () {
                          final sysId = manualAssignments.entries
                                  .where((e) => e.value == folder.name)
                                  .map((e) => e.key)
                                  .firstOrNull ??
                              folder.autoMatchedSystemId;
                          return sysId != null && enabledIds.contains(sysId);
                        }(),
                        autofocus: i == 0,
                        onToggle: () {
                          final sysId = manualAssignments.entries
                                  .where((e) => e.value == folder.name)
                                  .map((e) => e.key)
                                  .firstOrNull ??
                              folder.autoMatchedSystemId;
                          if (sysId != null) {
                            controller.toggleLocalSetupSystem(sysId);
                          }
                        },
                      ),
                    // Unmatched folders
                    if (unmatched.isNotEmpty) ...[
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: rs.spacing.md),
                        child: Row(
                          children: [
                            Icon(Icons.help_outline_rounded,
                                color: Colors.orange.shade400, size: 14),
                            SizedBox(width: rs.spacing.xs),
                            Text(
                              'UNMATCHED',
                              style: TextStyle(
                                color: Colors.orange.shade400,
                                fontSize: labelFontSize,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      for (final folder in unmatched)
                        _UnmatchedFolderRow(
                          folder: folder,
                          availableSystemIds: availableForDropdown,
                          onAssign: (systemId) =>
                              controller.assignLocalFolder(folder.name, systemId),
                        ),
                    ],
                    // Ignored folders
                    for (final folder in ignored)
                      _IgnoredFolderRow(folder: folder),
                    // Re-pick folder button
                    Padding(
                      padding: EdgeInsets.only(top: rs.spacing.lg),
                      child: _ActionButton(
                        label: 'Pick different folder',
                        icon: Icons.folder_open_rounded,
                        color: Colors.grey,
                        onTap: () => controller.pickLocalFolder(),
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

// --- Row widgets ---

class _MatchedFolderRow extends StatelessWidget {
  final ScannedFolder folder;
  final String? assignedSystemId;
  final bool isEnabled;
  final bool autofocus;
  final VoidCallback onToggle;

  const _MatchedFolderRow({
    required this.folder,
    required this.assignedSystemId,
    required this.isEnabled,
    required this.onToggle,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final nameFontSize = rs.isSmall ? 11.0 : 13.0;
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
        autofocus: autofocus,
        onSelect: onToggle,
        borderRadius: rs.radius.sm,
        padding: EdgeInsets.symmetric(
          horizontal: rs.spacing.md,
          vertical: rs.spacing.sm,
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_rounded,
                color: isEnabled ? Colors.green : Colors.grey.shade600,
                size: 16),
            SizedBox(width: rs.spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    system?.name ?? assignedSystemId ?? folder.name,
                    style: TextStyle(
                      color: isEnabled ? Colors.white : Colors.grey.shade500,
                      fontSize: nameFontSize,
                      fontWeight: FontWeight.w600,
                    ),
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
                  ? Icon(Icons.check, color: Colors.green, size: checkSize - 6)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _UnmatchedFolderRow extends StatelessWidget {
  final ScannedFolder folder;
  final List<String> availableSystemIds;
  final void Function(String?) onAssign;

  const _UnmatchedFolderRow({
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
            _SystemDropdown(
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

class _IgnoredFolderRow extends StatelessWidget {
  final ScannedFolder folder;
  const _IgnoredFolderRow({required this.folder});

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
            Icon(Icons.cancel_rounded, color: Colors.grey.shade700, size: 16),
            SizedBox(width: rs.spacing.sm),
            Expanded(
              child: Text(
                '${folder.name}/',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: fontSize,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            Text(
              'ignored',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: detailFontSize,
              ),
            ),
            SizedBox(width: rs.spacing.md),
            Text(
              '0 files',
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

// --- Shared widgets (duplicated from romm_setup_step.dart since private) ---

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool autofocus;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final fontSize = rs.isSmall ? 11.0 : 13.0;

    return ConsoleFocusable(
      autofocus: autofocus,
      onSelect: onTap,
      borderRadius: rs.radius.md,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: EdgeInsets.symmetric(
            horizontal: rs.spacing.md,
            vertical: rs.spacing.md,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(rs.radius.md),
            border: Border.all(
              color: color.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color.withValues(alpha: 0.8), size: 18),
              SizedBox(width: rs.spacing.sm),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: fontSize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SystemDropdown extends StatelessWidget {
  final List<String> availableSystemIds;
  final void Function(String?) onChanged;

  const _SystemDropdown({
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
