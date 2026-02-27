import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

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

    if (ls.isAutoDetecting || ls.isScanningPhase) {
      return _LocalScanningView(
        message: ls.isAutoDetecting
            ? "Checking for ROM folders..."
            : "Scanning your ROM folder...",
        onComplete: onComplete,
      );
    }
    if (ls.isResultsPhase) {
      return _LocalResultsView(localSetup: ls, onComplete: onComplete);
    }
    if (ls.isCreatePhase) {
      return _LocalCreateView(localSetup: ls, onComplete: onComplete);
    }
    return _LocalChoiceView(localSetup: ls, onComplete: onComplete);
  }
}

// --- Choice View ---

class _LocalChoiceView extends ConsumerWidget {
  final LocalSetupState localSetup;
  final VoidCallback onComplete;
  const _LocalChoiceView({required this.localSetup, required this.onComplete});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(onboardingControllerProvider.notifier);
    final rs = context.rs;
    final labelFontSize = rs.isSmall ? 10.0 : 12.0;
    final iconSize = rs.isSmall ? 14.0 : 18.0;
    final hintFontSize = rs.isSmall ? 10.0 : 12.0;
    final detected = localSetup.detectedPath;

    final String chatMessage;
    final String primaryLabel;
    final IconData primaryIcon;
    final Color primaryColor;
    final VoidCallback primaryAction;
    final String secondaryLabel;
    final IconData secondaryIcon;
    final Color secondaryColor;
    final VoidCallback secondaryAction;

    if (detected != null) {
      chatMessage =
          "I found a ROM folder at $detected! Scan it, or set up fresh?";
      primaryLabel = 'Scan found folder';
      primaryIcon = Icons.search_rounded;
      primaryColor = Colors.blue;
      primaryAction =
          () => controller.localSetupChoice(LocalSetupAction.scanDetected);
      secondaryLabel = 'Pick different folder';
      secondaryIcon = Icons.folder_open_rounded;
      secondaryColor = Colors.grey;
      secondaryAction =
          () => controller.localSetupChoice(LocalSetupAction.pickFolder);
    } else {
      chatMessage =
          "No ROM folder found. Want me to create one, or do you have ROMs somewhere else?";
      primaryLabel = 'Create standard folders';
      primaryIcon = Icons.create_new_folder_rounded;
      primaryColor = Colors.green;
      primaryAction =
          () => controller.localSetupChoice(LocalSetupAction.createFolders);
      secondaryLabel = 'Pick existing folder';
      secondaryIcon = Icons.folder_open_rounded;
      secondaryColor = Colors.blue;
      secondaryAction =
          () => controller.localSetupChoice(LocalSetupAction.pickFolder);
    }

    return FocusScope(
      child: Column(
        key: const ValueKey('localChoice'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ChatBubble(
            key: ValueKey('bubble_localChoice_${detected != null}'),
            message: chatMessage,
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _ActionButton(
                              label: primaryLabel,
                              icon: primaryIcon,
                              color: primaryColor,
                              autofocus: true,
                              onTap: primaryAction,
                            ),
                          ),
                          SizedBox(width: rs.spacing.md),
                          Expanded(
                            child: _ActionButton(
                              label: secondaryLabel,
                              icon: secondaryIcon,
                              color: secondaryColor,
                              onTap: secondaryAction,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: rs.spacing.md),
                      _TextLink(
                        label: 'Skip \u2014 set up manually',
                        onTap: () => controller
                            .localSetupChoice(LocalSetupAction.skip),
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

// --- Create View ---

class _LocalCreateView extends ConsumerWidget {
  final LocalSetupState localSetup;
  final VoidCallback onComplete;

  const _LocalCreateView({
    required this.localSetup,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(onboardingControllerProvider.notifier);
    final rs = context.rs;
    final selectedIds = localSetup.createSystemIds ?? const {};
    final basePath = localSetup.createBasePath ?? '/storage/emulated/0/ROMs';
    const allSystems = SystemModel.supportedSystems;
    final total = allSystems.length;
    final labelFontSize = rs.isSmall ? 10.0 : 12.0;
    final hintFontSize = rs.isSmall ? 10.0 : 12.0;

    return FocusScope(
      child: Column(
        key: const ValueKey('localCreate'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ChatBubble(
            message:
                "Pick the consoles you want! I'll create a folder for each one.",
            onComplete: onComplete,
          ),
          SizedBox(height: rs.spacing.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                left: rs.isSmall ? 40 : 60,
                bottom: 64,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row
                  Padding(
                    padding: EdgeInsets.only(bottom: rs.spacing.sm),
                    child: Row(
                      children: [
                        Text(
                          '${selectedIds.length} / $total selected',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: labelFontSize,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        _TextLink(
                          label: selectedIds.length == total
                              ? 'Deselect All'
                              : 'Select All',
                          onTap: () => controller.toggleAllCreateSystems(
                            selectedIds.length != total,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // System list
                  Expanded(
                    child: FocusTraversalGroup(
                      child: ListView.builder(
                        itemCount: allSystems.length,
                        itemBuilder: (context, index) {
                          final system = allSystems[index];
                          final isSelected = selectedIds.contains(system.id);
                          return _CreateSystemRow(
                            system: system,
                            isSelected: isSelected,
                            autofocus: index == 0,
                            onToggle: () =>
                                controller.toggleCreateSystem(system.id),
                          );
                        },
                      ),
                    ),
                  ),
                  // Base path display
                  SizedBox(height: rs.spacing.sm),
                  FocusTraversalGroup(
                    child: Row(
                      children: [
                        Icon(Icons.folder_rounded,
                            color: Colors.grey.shade500, size: 14),
                        SizedBox(width: rs.spacing.xs),
                        Expanded(
                          child: Text(
                            '$basePath/',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: hintFontSize,
                              fontFamily: 'monospace',
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: rs.spacing.sm),
                        _TextLink(
                          label: 'Change',
                          onTap: controller.pickCreateBasePath,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Create System Row ---

class _CreateSystemRow extends StatelessWidget {
  final SystemModel system;
  final bool isSelected;
  final bool autofocus;
  final VoidCallback onToggle;

  const _CreateSystemRow({
    required this.system,
    required this.isSelected,
    required this.onToggle,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final nameFontSize = rs.isSmall ? 11.0 : 13.0;
    final checkSize = rs.isSmall ? 18.0 : 22.0;

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
            SvgPicture.asset(
              system.iconAssetPath,
              width: 20,
              height: 20,
              colorFilter: ColorFilter.mode(system.iconColor, BlendMode.srcIn),
              placeholderBuilder: (_) => Icon(
                Icons.videogame_asset_rounded,
                color: system.accentColor,
                size: 20,
              ),
            ),
            SizedBox(width: rs.spacing.sm),
            Expanded(
              child: Text(
                system.name,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey.shade500,
                  fontSize: nameFontSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              width: checkSize,
              height: checkSize,
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.green.withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isSelected
                      ? Colors.green.withValues(alpha: 0.7)
                      : Colors.white.withValues(alpha: 0.2),
                ),
              ),
              child: isSelected
                  ? Icon(Icons.check, color: Colors.green, size: checkSize - 6)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// --- Scanning View ---

class _LocalScanningView extends StatelessWidget {
  final String message;
  final VoidCallback onComplete;
  const _LocalScanningView({
    required this.message,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;

    return FocusScope(
      child: Column(
        key: const ValueKey('localScanning'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ChatBubble(
            message: message,
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
      } else if (folder.autoMatchedSystemId != null) {
        matched.add(folder);
        assignedSystems.add(folder.autoMatchedSystemId!);
      } else if (folder.fileCount > 0) {
        unmatched.add(folder);
      } else {
        ignored.add(folder);
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
                    // Scan error warning
                    if (localSetup.scanError != null)
                      Padding(
                        padding: EdgeInsets.only(bottom: rs.spacing.md),
                        child: Container(
                          padding: EdgeInsets.all(rs.spacing.md),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius:
                                BorderRadius.circular(rs.radius.sm),
                            border: Border.all(
                              color: Colors.orange.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.warning_amber_rounded,
                                  color: Colors.orange.shade300, size: 18),
                              SizedBox(width: rs.spacing.sm),
                              Expanded(
                                child: Text(
                                  localSetup.scanError!,
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
                    // Permission warning when all folders appear empty
                    if (scanned.isNotEmpty &&
                        scanned.every((f) => f.fileCount == 0))
                      Padding(
                        padding: EdgeInsets.only(bottom: rs.spacing.md),
                        child: Container(
                          padding: EdgeInsets.all(rs.spacing.md),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius:
                                BorderRadius.circular(rs.radius.sm),
                            border: Border.all(
                              color: Colors.orange.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.warning_amber_rounded,
                                  color: Colors.orange.shade300, size: 18),
                              SizedBox(width: rs.spacing.sm),
                              Expanded(
                                child: Text(
                                  'All folders appear empty. R-Shop may need '
                                  'storage permission \u2014 check Android '
                                  'Settings \u203A Apps \u203A R-Shop \u203A Permissions.',
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
                  Row(
                    children: [
                      Text(
                        '${folder.name}/ \u2022 ${folder.fileCount} files',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: detailFontSize,
                        ),
                      ),
                      if (folder.fileCount == 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'empty',
                            style: TextStyle(
                              color: Colors.orange.shade300,
                              fontSize: detailFontSize,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
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
        onSelect: availableSystemIds.isNotEmpty
            ? () => onAssign(availableSystemIds.first)
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

// --- Shared widgets ---

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

class _TextLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _TextLink({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final fontSize = rs.isSmall ? 10.0 : 12.0;

    return ConsoleFocusable(
      onSelect: onTap,
      borderRadius: rs.radius.sm,
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: rs.spacing.xs,
            horizontal: rs.spacing.sm,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: fontSize,
              decoration: TextDecoration.underline,
              decorationColor: Colors.grey.shade600,
            ),
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
