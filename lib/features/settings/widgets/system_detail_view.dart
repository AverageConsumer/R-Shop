import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/app_providers.dart';
import '../../onboarding/onboarding_controller.dart';
import '../models/settings_entry.dart';
import 'settings_list_view.dart';

/// Per-system settings view using the declarative SettingsListView.
/// Reads/writes state through [OnboardingController] so save/load
/// in [ConfigModeScreen] keeps working unchanged.
class SystemDetailView extends ConsumerWidget {
  final FocusNode firstFocusNode;

  const SystemDetailView({super.key, required this.firstFocusNode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final state = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);
    final sub = state.consoleSubState;
    if (sub == null) return const SizedBox.shrink();

    final system = state.selectedSystem;
    final sourceCount = sub.providers.length;

    return SettingsListView(
      firstFocusNode: firstFocusNode,
      sections: [
        SettingsSection(l.systemDetail_sectionStorage, [
          SettingsEntry.nav(
            focusNode: firstFocusNode,
            icon: Icons.folder_outlined,
            title: sub.targetFolder ?? l.systemDetail_selectRomFolder,
            subtitle: sub.targetFolder != null
                ? l.systemDetail_tapToChangeFolder
                : 'Where ROMs for ${system?.name ?? 'this system'} are stored',
            onSelect: () async {
              try {
                final path = await FilePicker.platform.getDirectoryPath(
                  dialogTitle: 'ROM folder for ${system?.name ?? 'system'}',
                );
                if (path != null) {
                  controller.setTargetFolder(path);
                  ref.read(feedbackServiceProvider).confirm();
                }
              } catch (e) {
                debugPrint('SystemDetailView: folder picker failed: $e');
              }
            },
          ),
        ]),
        SettingsSection(l.systemDetail_sectionBehavior, [
          SettingsEntry.toggle(
            title: l.systemDetail_autoExtractZips,
            subtitle: sub.autoExtract
                ? l.systemDetail_autoExtractEnabled
                : l.systemDetail_autoExtractDisabled,
            value: sub.autoExtract,
            onChanged: () =>
                controller.setAutoExtract(!sub.autoExtract),
          ),
          SettingsEntry.toggle(
            title: l.systemDetail_autoSyncOnLaunch,
            subtitle: sub.autoSync
                ? l.systemDetail_autoSyncEnabled
                : l.systemDetail_autoSyncDisabled,
            value: sub.autoSync,
            onChanged: () => controller.setAutoSync(!sub.autoSync),
          ),
        ]),
        SettingsSection(l.systemDetail_sectionSources, [
          SettingsEntry.custom(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Text(
                sourceCount == 0
                    ? 'No sources mapped — manage in Settings → My Sources'
                    : '$sourceCount source${sourceCount == 1 ? '' : 's'} mapped '
                        '— manage in Settings → My Sources',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ]),
      ],
    );
  }
}
