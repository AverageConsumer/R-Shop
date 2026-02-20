import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/responsive/responsive.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/console_focusable.dart';
import '../../../models/system_model.dart';
import '../../../providers/app_providers.dart';
import '../../../services/romm_api_service.dart';
import '../onboarding_controller.dart';
import 'chat_bubble.dart';
import 'connection_test_indicator.dart';

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
        return _RommConnectView(onComplete: onComplete);
      case RommSetupSubStep.select:
        return _RommSelectView(onComplete: onComplete);
      case RommSetupSubStep.folder:
        return _RommFolderView(onComplete: onComplete);
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
                        child: _ActionButton(
                          label: 'Yes, connect my server',
                          icon: Icons.cloud_done_rounded,
                          color: Colors.green,
                          autofocus: true,
                          onTap: () => controller.rommSetupAnswer(true),
                        ),
                      ),
                      SizedBox(width: rs.spacing.md),
                      Expanded(
                        child: _ActionButton(
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

// --- Connect View ---

class _RommConnectView extends ConsumerStatefulWidget {
  final VoidCallback onComplete;
  const _RommConnectView({required this.onComplete});

  @override
  ConsumerState<_RommConnectView> createState() => _RommConnectViewState();
}

class _RommConnectViewState extends ConsumerState<_RommConnectView> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};
  final Map<String, FocusNode> _consoleFocusNodes = {};
  bool _didAutoFill = false;

  TextEditingController _getController(String key, String initialValue) {
    if (!_controllers.containsKey(key)) {
      _controllers[key] = TextEditingController(text: initialValue);
    }
    return _controllers[key]!;
  }

  FocusNode _getFocusNode(String key) {
    if (!_focusNodes.containsKey(key)) {
      _focusNodes[key] = FocusNode(skipTraversal: true);
    }
    return _focusNodes[key]!;
  }

  FocusNode _getConsoleFocusNode(String key) {
    if (!_consoleFocusNodes.containsKey(key)) {
      _consoleFocusNodes[key] = FocusNode(debugLabel: 'romm_console_$key');
    }
    return _consoleFocusNodes[key]!;
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final f in _focusNodes.values) {
      f.dispose();
    }
    for (final f in _consoleFocusNodes.values) {
      f.dispose();
    }
    super.dispose();
  }

  void _autoFillFromStorage() {
    if (_didAutoFill) return;
    _didAutoFill = true;

    final storage = ref.read(storageServiceProvider);
    final globalUrl = storage.getRommUrl();
    if (globalUrl != null && globalUrl.isNotEmpty) {
      _getController('url', '').text = globalUrl;
      ref
          .read(onboardingControllerProvider.notifier)
          .updateRommSetupField('url', globalUrl);
    }

    final authJson = storage.getRommAuth();
    if (authJson != null) {
      try {
        final map = jsonDecode(authJson) as Map<String, dynamic>;
        if (map['api_key'] != null) {
          final v = map['api_key'] as String;
          _getController('apiKey', '').text = v;
          ref
              .read(onboardingControllerProvider.notifier)
              .updateRommSetupField('apiKey', v);
        }
        if (map['user'] != null) {
          final v = map['user'] as String;
          _getController('user', '').text = v;
          ref
              .read(onboardingControllerProvider.notifier)
              .updateRommSetupField('user', v);
        }
        if (map['pass'] != null) {
          final v = map['pass'] as String;
          _getController('pass', '').text = v;
          ref
              .read(onboardingControllerProvider.notifier)
              .updateRommSetupField('pass', v);
        }
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingControllerProvider);
    final rs = context.rs;
    final controller = ref.read(onboardingControllerProvider.notifier);
    final rommSetup = state.rommSetupState;
    if (rommSetup == null) return const SizedBox.shrink();

    // Auto-fill from global storage on first build if fields are empty
    if (!_didAutoFill && rommSetup.url.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _autoFillFromStorage();
      });
    }

    return FocusScope(
      child: Column(
        key: const ValueKey('rommConnect'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ChatBubble(
            key: ValueKey('bubble_rommConnect_${state.isTestingConnection}'
                '_${state.connectionTestSuccess}'
                '_${state.connectionTestError ?? ''}'),
            message: state.isTestingConnection
                ? "Hang on, connecting to your RomM server..."
                : state.connectionTestError != null
                    ? "Couldn't reach your server. Check the URL and credentials."
                    : "Enter your RomM server details and I'll discover your consoles.",
            accentColor: state.connectionTestError != null
                ? Colors.redAccent
                : null,
            onComplete: widget.onComplete,
          ),
          SizedBox(height: rs.spacing.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                left: rs.isSmall ? 40 : 60,
                bottom: 64,
              ),
              child: FocusTraversalGroup(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTextField(rs, 'url', 'URL',
                          'https://romm.example.com', rommSetup.url, controller),
                      SizedBox(height: rs.spacing.sm),
                      _buildTextField(rs, 'apiKey', 'API Key', '(optional)',
                          rommSetup.apiKey, controller),
                      SizedBox(height: rs.spacing.sm),
                      _buildTextField(rs, 'user', 'Username', '(optional)',
                          rommSetup.user, controller),
                      SizedBox(height: rs.spacing.sm),
                      _buildTextField(rs, 'pass', 'Password', '(optional)',
                          rommSetup.pass, controller,
                          obscure: true),
                      SizedBox(height: rs.spacing.md),
                      ConnectionTestIndicator(
                        isTesting: state.isTestingConnection,
                        isSuccess: state.connectionTestSuccess,
                        error: state.connectionTestError,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    Responsive rs,
    String key,
    String label,
    String hint,
    String currentValue,
    OnboardingController controller, {
    bool obscure = false,
  }) {
    final fontSize = rs.isSmall ? 12.0 : 14.0;
    final labelFontSize = rs.isSmall ? 10.0 : 12.0;
    final fieldController = _getController(key, currentValue);
    final textFocusNode = _getFocusNode(key);
    final consoleFocusNode = _getConsoleFocusNode(key);

    return ConsoleFocusable(
      key: ValueKey('romm_field_$key'),
      focusNode: consoleFocusNode,
      autofocus: key == 'url',
      focusScale: 1.0,
      borderRadius: rs.radius.sm,
      onSelect: () => textFocusNode.requestFocus(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: labelFontSize,
              letterSpacing: 1,
            ),
          ),
          SizedBox(height: rs.spacing.xs),
          ListenableBuilder(
            listenable: textFocusNode,
            builder: (context, child) {
              final hasFocus = textFocusNode.hasFocus;
              return Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF252525),
                  borderRadius: BorderRadius.circular(rs.radius.sm),
                  border: Border.all(
                    color: hasFocus
                        ? AppTheme.primaryColor
                        : AppTheme.primaryColor.withValues(alpha: 0.4),
                    width: 2,
                  ),
                  boxShadow: hasFocus
                      ? [
                          BoxShadow(
                            color: AppTheme.primaryColor.withValues(alpha: 0.3),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: child,
              );
            },
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.escape, includeRepeats: false): () =>
                    consoleFocusNode.requestFocus(),
                const SingleActivator(LogicalKeyboardKey.gameButtonB, includeRepeats: false): () =>
                    consoleFocusNode.requestFocus(),
                const SingleActivator(LogicalKeyboardKey.goBack, includeRepeats: false): () =>
                    consoleFocusNode.requestFocus(),
              },
              child: TextField(
                controller: fieldController,
                focusNode: textFocusNode,
                obscureText: obscure,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: fontSize,
                  fontFamily: 'monospace',
                ),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: fontSize,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: rs.spacing.md,
                    vertical: rs.spacing.md,
                  ),
                ),
                onChanged: (value) =>
                    controller.updateRommSetupField(key, value),
                onSubmitted: (_) => consoleFocusNode.requestFocus(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Select View ---

class _RommSelectView extends ConsumerWidget {
  final VoidCallback onComplete;
  const _RommSelectView({required this.onComplete});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);
    final rs = context.rs;
    final rommSetup = state.rommSetupState;
    if (rommSetup == null) return const SizedBox.shrink();

    final matchedCount = rommSetup.matchedCount;
    final selectedCount = rommSetup.selectedCount;
    final allSelected = selectedCount == matchedCount;

    // Build sorted list of matched systems
    final matchedEntries = rommSetup.systemMatches.entries.toList()
      ..sort((a, b) {
        final sysA = SystemModel.supportedSystems
            .firstWhere((s) => s.id == a.key);
        final sysB = SystemModel.supportedSystems
            .firstWhere((s) => s.id == b.key);
        return sysA.name.compareTo(sysB.name);
      });

    return FocusScope(
      child: Column(
        key: const ValueKey('rommSelect'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ChatBubble(
            key: ValueKey('bubble_rommSelect_$matchedCount'),
            message: matchedCount == 0
                ? "Hmm, I couldn't match any consoles from your RomM server. You can still set them up manually."
                : "I found $matchedCount ${matchedCount == 1 ? 'console' : 'consoles'} on your RomM server! Uncheck any you don't want.",
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
              child: matchedCount == 0
                  ? const SizedBox.shrink()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(rs, selectedCount, matchedCount,
                            allSelected, controller),
                        SizedBox(height: rs.spacing.sm),
                        Expanded(
                          child: FocusTraversalGroup(
                            child: ListView.builder(
                              itemCount: matchedEntries.length,
                              itemBuilder: (context, index) {
                                final entry = matchedEntries[index];
                                final systemId = entry.key;
                                final platform = entry.value;
                                final system =
                                    SystemModel.supportedSystems.firstWhere(
                                  (s) => s.id == systemId,
                                );
                                final isSelected = rommSetup.selectedSystemIds
                                    .contains(systemId);

                                return _SystemRow(
                                  system: system,
                                  platform: platform,
                                  isSelected: isSelected,
                                  autofocus: index == 0,
                                  onToggle: () =>
                                      controller.toggleRommSystem(systemId),
                                );
                              },
                            ),
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

  Widget _buildHeader(Responsive rs, int selectedCount, int matchedCount,
      bool allSelected, OnboardingController controller) {
    final fontSize = rs.isSmall ? 11.0 : 13.0;

    return Row(
      children: [
        Text(
          '$selectedCount / $matchedCount selected',
          style: TextStyle(
            color: Colors.grey.shade400,
            fontSize: fontSize,
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () => controller.toggleAllRommSystems(!allSelected),
          child: Text(
            allSelected ? 'Deselect All' : 'Select All',
            style: TextStyle(
              color: Colors.blue.shade300,
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _SystemRow extends StatelessWidget {
  final SystemModel system;
  final RommPlatform platform;
  final bool isSelected;
  final bool autofocus;
  final VoidCallback onToggle;

  const _SystemRow({
    required this.system,
    required this.platform,
    required this.isSelected,
    required this.onToggle,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final nameFontSize = rs.isSmall ? 12.0 : 14.0;
    final detailFontSize = rs.isSmall ? 10.0 : 12.0;
    final iconSize = rs.isSmall ? 24.0 : 30.0;
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
            // System icon
            ClipRRect(
              borderRadius: BorderRadius.circular(rs.radius.sm),
              child: Image.asset(
                system.iconAssetPath,
                width: iconSize,
                height: iconSize,
                cacheWidth: 128,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.videogame_asset,
                  color: system.accentColor,
                  size: iconSize,
                ),
              ),
            ),
            SizedBox(width: rs.spacing.md),
            // System + platform info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    system.name,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: nameFontSize,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${platform.name} \u2022 ${platform.romCount} ROMs',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: detailFontSize,
                    ),
                  ),
                ],
              ),
            ),
            // Checkbox
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

// --- Folder View ---

class _RommFolderView extends ConsumerWidget {
  final VoidCallback onComplete;
  const _RommFolderView({required this.onComplete});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingControllerProvider);
    final rs = context.rs;
    final rommSetup = state.rommSetupState;
    if (rommSetup == null) return const SizedBox.shrink();

    final scanned = rommSetup.scannedFolders;

    // Phase 1: No scan yet — show choice buttons
    if (scanned == null && !rommSetup.isScanning) {
      return _FolderChoiceView(onComplete: onComplete);
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
    return _FolderResultsView(
      rommSetup: rommSetup,
      onComplete: onComplete,
    );
  }
}

class _FolderChoiceView extends ConsumerWidget {
  final VoidCallback onComplete;
  const _FolderChoiceView({required this.onComplete});

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
                        child: _ActionButton(
                          label: 'Yes, pick folder',
                          icon: Icons.folder_open_rounded,
                          color: Colors.blue,
                          autofocus: true,
                          onTap: () => controller.rommFolderChoice(true),
                        ),
                      ),
                      SizedBox(width: rs.spacing.md),
                      Expanded(
                        child: _ActionButton(
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

class _FolderResultsView extends ConsumerWidget {
  final RommSetupState rommSetup;
  final VoidCallback onComplete;

  const _FolderResultsView({
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
                      _FolderRow(
                        folder: folder,
                        status: _FolderStatus.matched,
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
                        _LocalFoundFolderRow(
                          folder: folder,
                          isEnabled: localOnlyIds.contains(folder.autoMatchedSystemId),
                          onToggle: () => controller.toggleLocalSystem(folder.autoMatchedSystemId!),
                        ),
                    ],
                    // Unmatched folders (with dropdown)
                    for (final folder in unmatched)
                      _UnmatchedFolderRow(
                        folder: folder,
                        availableSystemIds: availableForDropdown,
                        onAssign: (systemId) =>
                            controller.assignFolderToSystem(folder.name, systemId),
                      ),
                    // Ignored folders
                    for (final folder in ignored)
                      _FolderRow(
                        folder: folder,
                        status: folder.fileCount == 0
                            ? _FolderStatus.ignoredNoFiles
                            : _FolderStatus.ignoredNotSelected,
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
                      child: _ActionButton(
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

enum _FolderStatus { matched, ignoredNoFiles, ignoredNotSelected }

class _FolderRow extends StatelessWidget {
  final ScannedFolder folder;
  final _FolderStatus status;
  final String? assignedSystemId;
  final bool autofocus;

  const _FolderRow({
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
      case _FolderStatus.matched:
        icon = Icons.check_circle_rounded;
        iconColor = Colors.green;
        final system = assignedSystemId != null
            ? SystemModel.supportedSystems
                .where((s) => s.id == assignedSystemId)
                .firstOrNull
            : null;
        statusText = system?.name ?? assignedSystemId ?? '';
        statusColor = Colors.green.shade300;
      case _FolderStatus.ignoredNoFiles:
        icon = Icons.cancel_rounded;
        iconColor = Colors.grey.shade700;
        statusText = 'ignored';
        statusColor = Colors.grey.shade700;
      case _FolderStatus.ignoredNotSelected:
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
                  color: status == _FolderStatus.matched
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

class _LocalFoundFolderRow extends StatelessWidget {
  final ScannedFolder folder;
  final bool isEnabled;
  final VoidCallback onToggle;

  const _LocalFoundFolderRow({
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
            // Dropdown for assignment
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
