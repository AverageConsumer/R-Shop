import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/app_providers.dart';
import '../models/settings_entry.dart';
import 'settings_list_view.dart';

class SettingsAudioTab extends ConsumerWidget {
  final FocusNode firstFocusNode;

  const SettingsAudioTab({super.key, required this.firstFocusNode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final sound = ref.watch(soundSettingsProvider);
    final hapticEnabled = ref.watch(hapticEnabledProvider);

    return SettingsListView(
      firstFocusNode: firstFocusNode,
      sections: [
        SettingsSection(l.settings_sectionFeedback, [
          SettingsEntry.toggle(
            title: l.settings_vibration,
            subtitle: l.settings_vibrationSubtitle,
            value: hapticEnabled,
            onChanged: () => ref.read(hapticEnabledProvider.notifier).toggle(),
          ),
          SettingsEntry.toggle(
            title: l.settings_soundEffects,
            subtitle: l.settings_soundEffectsSubtitle,
            value: sound.enabled,
            onChanged: () async {
              final value = !sound.enabled;
              await ref.read(soundSettingsProvider.notifier).setEnabled(value);
              if (value) ref.read(audioManagerProvider).playConfirm();
            },
          ),
        ]),
        SettingsSection(l.settings_sectionVolume, [
          SettingsEntry.slider(
            title: l.settings_music,
            subtitle: l.settings_musicSubtitle,
            value: sound.bgmVolume,
            onChanged: (v) => ref
                .read(soundSettingsProvider.notifier)
                .setBgmVolume(v.clamp(0.0, 1.0)),
          ),
          SettingsEntry.slider(
            title: l.settings_effects,
            subtitle: l.settings_effectsSubtitle,
            value: sound.sfxVolume,
            onChanged: (v) => ref
                .read(soundSettingsProvider.notifier)
                .setSfxVolume(v.clamp(0.0, 1.0)),
          ),
        ]),
      ],
    );
  }
}
