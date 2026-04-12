import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/responsive/responsive.dart';
import '../../../core/widgets/console_focusable.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/system_model.dart';
import '../onboarding_controller.dart';
import 'provider_form.dart';

class ConsoleConfigPanel extends ConsumerStatefulWidget {
  const ConsoleConfigPanel({super.key});

  @override
  ConsumerState<ConsoleConfigPanel> createState() =>
      _ConsoleConfigPanelState();
}

class _ConsoleConfigPanelState extends ConsumerState<ConsoleConfigPanel> {
  final _folderFocusNode = FocusNode();

  @override
  void dispose() {
    _folderFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);
    final system = state.selectedSystem;
    final sub = state.consoleSubState;
    if (system == null || sub == null) return const SizedBox.shrink();

    final rs = context.rs;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(rs.radius.lg),
        border: Border.all(
          color: system.accentColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: system.accentColor.withValues(alpha: 0.1),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(rs, system, controller),
          Flexible(
            child: SingleChildScrollView(
              key: ValueKey(state.hasProviderForm),
              padding: EdgeInsets.symmetric(
                horizontal: rs.spacing.md,
                vertical: rs.spacing.sm,
              ),
              child: FocusTraversalGroup(
                child: state.hasProviderForm
                    ? const ProviderForm()
                    : _buildConfigBody(rs, system, sub, state, controller),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    Responsive rs,
    SystemModel system,
    OnboardingController controller,
  ) {
    final titleFontSize = rs.isSmall ? 14.0 : 18.0;
    final iconSize = rs.isSmall ? 28.0 : 36.0;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: rs.spacing.md,
        vertical: rs.spacing.sm,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(rs.radius.sm),
            child: SvgPicture.asset(
              system.iconAssetPath,
              width: iconSize,
              height: iconSize,
              colorFilter: ColorFilter.mode(system.iconColor, BlendMode.srcIn),
              placeholderBuilder: (_) => Icon(
                Icons.videogame_asset,
                color: system.accentColor,
                size: iconSize,
              ),
            ),
          ),
          SizedBox(width: rs.spacing.sm),
          Expanded(
            child: Text(
              system.name,
              style: TextStyle(
                color: Colors.white,
                fontSize: titleFontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ConsoleFocusable(
            onSelect: controller.deselectConsole,
            borderRadius: rs.radius.sm,
            focusScale: 1.1,
            child: GestureDetector(
              onTap: controller.deselectConsole,
              child: SizedBox(
                width: 48,
                height: 48,
                child: Center(
                  child: Container(
                    padding: EdgeInsets.all(rs.spacing.xs),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(rs.radius.sm),
                    ),
                    child: Icon(
                      Icons.close,
                      color: Colors.white54,
                      size: rs.isSmall ? 18.0 : 22.0,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigBody(
    Responsive rs,
    SystemModel system,
    ConsoleSetupState sub,
    OnboardingState state,
    OnboardingController controller,
  ) {
    final fontSize = rs.isSmall ? 12.0 : 14.0;
    final labelFontSize = rs.isSmall ? 10.0 : 12.0;

    final l = L.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ROM Folder
        _buildSectionLabel(l.onboarding_romFolder, labelFontSize),
        SizedBox(height: rs.spacing.sm),
        _buildFolderRow(rs, sub, controller, fontSize),
        SizedBox(height: rs.spacing.lg),

        // Auto-Extract toggle
        _buildSectionLabel(l.onboarding_options, labelFontSize),
        SizedBox(height: rs.spacing.sm),
        _buildToggleRow(
          rs: rs,
          label: l.onboarding_autoExtractZips,
          value: sub.autoExtract,
          onChanged: controller.setAutoExtract,
          fontSize: fontSize,
        ),
        SizedBox(height: rs.spacing.md),

        // Auto-sync toggle
        _buildToggleRow(
          rs: rs,
          label: l.onboarding_autoSyncLabel,
          value: sub.autoSync,
          onChanged: controller.setAutoSync,
          fontSize: fontSize,
          subtitle: sub.autoSync
              ? l.onboarding_autoSyncEnabled
              : l.onboarding_autoSyncDisabled,
        ),
        SizedBox(height: rs.spacing.lg),

        // Read-only summary of which sources currently contribute to
        // this system. Adding/removing/reordering sources moved to
        // Settings → Sources after the source-centric refactor; this
        // panel only handles system-level config now (folder, toggles).
        _buildSectionLabel(
          'SOURCES (${sub.providers.length})',
          labelFontSize,
        ),
        SizedBox(height: rs.spacing.sm),
        if (sub.providers.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: rs.spacing.sm),
            child: Text(
              'No sources mapped — manage in Settings → Sources.',
              style: TextStyle(
                color: Colors.white54,
                fontSize: fontSize,
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else ...[
          ...sub.providers.map((p) => Padding(
                padding: EdgeInsets.only(bottom: rs.spacing.xs),
                child: Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: rs.spacing.md, vertical: rs.spacing.sm),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(rs.radius.sm),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.cloud_outlined,
                          size: rs.isSmall ? 14 : 16,
                          color: Colors.white54),
                      SizedBox(width: rs.spacing.sm),
                      Expanded(
                        child: Text(
                          p.detailLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: fontSize,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )),
          SizedBox(height: rs.spacing.xs),
          Text(
            'Add or remove sources in Settings → Sources.',
            style: TextStyle(
              color: Colors.white38,
              fontSize: labelFontSize,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        SizedBox(height: rs.spacing.lg),

        // Done button
        ConsoleFocusable(
          onSelect: sub.isComplete ? controller.saveConsoleConfig : null,
          borderRadius: rs.radius.sm,
          child: GestureDetector(
            onTap: sub.isComplete ? controller.saveConsoleConfig : null,
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 48),
              padding: EdgeInsets.symmetric(vertical: rs.spacing.md),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: sub.isComplete
                      ? [
                          Colors.green.withValues(alpha: 0.3),
                          Colors.green.withValues(alpha: 0.15),
                        ]
                      : [
                          Colors.grey.withValues(alpha: 0.1),
                          Colors.grey.withValues(alpha: 0.05),
                        ],
                ),
                borderRadius: BorderRadius.circular(rs.radius.sm),
                border: Border.all(
                  color: sub.isComplete
                      ? Colors.green.withValues(alpha: 0.5)
                      : Colors.grey.withValues(alpha: 0.2),
                ),
              ),
              child: Center(
                child: Text(
                  l.common_done,
                  style: TextStyle(
                    color: sub.isComplete ? Colors.white : Colors.white38,
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: rs.spacing.sm),
      ],
    );
  }

  Widget _buildSectionLabel(String text, double fontSize) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.grey.shade500,
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildFolderRow(
    Responsive rs,
    ConsoleSetupState sub,
    OnboardingController controller,
    double fontSize,
  ) {
    Future<void> pickFolder() async {
      final path = await FilePicker.platform.getDirectoryPath();
      if (path != null) {
        controller.setTargetFolder(path);
      }
      // Delay focus restoration so it runs after the platform has fully
      // restored window focus AND after ref.listen's postFrameCallback
      // (which grabs screen-level focus) has already completed.
      Future<void>.delayed(const Duration(milliseconds: 150), () {
        if (_folderFocusNode.canRequestFocus) {
          _folderFocusNode.requestFocus();
        }
      });
    }

    return ConsoleFocusable(
      autofocus: true,
      focusNode: _folderFocusNode,
      onSelect: pickFolder,
      borderRadius: rs.radius.sm,
      child: GestureDetector(
        onTap: pickFolder,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: EdgeInsets.symmetric(
            horizontal: rs.spacing.md,
            vertical: rs.spacing.md,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(rs.radius.sm),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.folder_open,
                color: sub.targetFolder != null ? Colors.redAccent : Colors.white38,
                size: rs.isSmall ? 18.0 : 22.0,
              ),
              SizedBox(width: rs.spacing.sm),
              Expanded(
                child: Text(
                  sub.targetFolder ?? L.of(context).onboarding_selectFolder,
                  style: TextStyle(
                    color: sub.targetFolder != null ? Colors.white : Colors.white38,
                    fontSize: fontSize,
                    fontFamily: sub.targetFolder != null ? 'monospace' : null,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.white24,
                size: rs.isSmall ? 18.0 : 22.0,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleRow({
    required Responsive rs,
    required String label,
    required bool value,
    required void Function(bool) onChanged,
    required double fontSize,
    String? subtitle,
  }) {
    return ConsoleFocusable(
      onSelect: () => onChanged(!value),
      borderRadius: rs.radius.sm,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: EdgeInsets.symmetric(
            horizontal: rs.spacing.md,
            vertical: rs.spacing.md,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(rs.radius.sm),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(color: Colors.white, fontSize: fontSize),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: fontSize - 2,
                        ),
                      ),
                  ],
                ),
              ),
              _buildMiniSwitch(value),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniSwitch(bool value) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 40,
      height: 22,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: value ? Colors.redAccent : Colors.grey.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Align(
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 18,
          height: 18,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
