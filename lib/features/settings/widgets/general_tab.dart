import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/app_providers.dart';
import '../../onboarding/widgets/ra_onboarding_screen.dart';
import '../config_mode_screen.dart';
import '../models/settings_entry.dart';
import '../sources_screen.dart';
import 'settings_list_view.dart';

/// Native language names for supported locales (always displayed in their own language).
const _localeNames = <String, String>{
  'en': 'English',
  'de': 'Deutsch',
  'es': 'Español',
  'fr': 'Français',
  'pt': 'Português',
  'ja': '日本語',
  'zh': '中文 (简体)',
  'zh-TW': '繁體中文 (台灣)',
};

class SettingsGeneralTab extends ConsumerWidget {
  final FocusNode firstFocusNode;

  const SettingsGeneralTab({super.key, required this.firstFocusNode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final isHomeGrid = ref.watch(homeLayoutProvider);
    final hideEmpty = ref.watch(hideEmptyConsolesProvider);
    final layout = ref.watch(controllerLayoutProvider);
    final localeOverride = ref.watch(localeProvider);
    final localeName = localeOverride == null
        ? l.settings_languageSystem
        : _localeNames[localeOverride.toLanguageTag()] ??
            _localeNames[localeOverride.languageCode] ??
            localeOverride.languageCode;
    final localeShort = localeOverride == null
        ? 'AUTO'
        : localeOverride.languageCode.toUpperCase();

    return SettingsListView(
      firstFocusNode: firstFocusNode,
      sections: [
        SettingsSection(l.settings_sectionLibrary, [
          SettingsEntry.nav(
            icon: Icons.cloud_outlined,
            title: l.settings_mySources,
            subtitle: l.settings_mySourcesSubtitle,
            onSelect: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SourcesScreen())),
          ),
          SettingsEntry.nav(
            icon: Icons.tune,
            title: l.settings_consoleSettings,
            subtitle: l.settings_consoleSettingsSubtitle,
            onSelect: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ConfigModeScreen())),
          ),
          SettingsEntry.nav(
            icon: Icons.emoji_events_outlined,
            title: l.settings_retroAchievements,
            subtitle: l.settings_retroAchievementsSubtitle,
            onSelect: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        const RaOnboardingScreen(popOnSuccess: false))),
          ),
        ]),
        SettingsSection(l.settings_sectionDisplay, [
          SettingsEntry.toggle(
            title: l.settings_homeLayout,
            subtitle: isHomeGrid ? l.settings_homeLayoutGrid : l.settings_homeLayoutCarousel,
            value: isHomeGrid,
            onChanged: () {
              ref.read(feedbackServiceProvider).tick();
              ref.read(homeLayoutProvider.notifier).toggle();
            },
          ),
          SettingsEntry.toggle(
            title: l.settings_hideEmptyConsoles,
            subtitle: l.settings_hideEmptyConsolesSubtitle,
            value: hideEmpty,
            onChanged: () {
              ref.read(hideEmptyConsolesProvider.notifier).toggle();
              ref.read(feedbackServiceProvider).tick();
            },
          ),
          SettingsEntry.cycle(
            title: l.settings_controllerButtons,
            subtitle: switch (layout) {
              ControllerLayout.nintendo => l.settings_controllerNintendo,
              ControllerLayout.xbox => 'Xbox (A/B & X/Y swapped)',
              ControllerLayout.playstation =>
                'PlayStation (\u2715 \u25CB \u25A1 \u25B3)',
            },
            displayValue: switch (layout) {
              ControllerLayout.nintendo => l.settings_controllerNin,
              ControllerLayout.xbox => l.settings_controllerXbox,
              ControllerLayout.playstation => l.settings_controllerPs,
            },
            onCycle: () {
              ref.read(feedbackServiceProvider).tick();
              ref.read(controllerLayoutProvider.notifier).cycle();
            },
          ),
          SettingsEntry.cycle(
            title: l.settings_language,
            subtitle: localeName,
            displayValue: localeShort,
            onCycle: () {
              ref.read(feedbackServiceProvider).tick();
              ref.read(localeProvider.notifier).cycle(L.supportedLocales);
            },
          ),
        ]),
      ],
    );
  }
}
