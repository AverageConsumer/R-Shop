import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/widgets/console_focusable.dart';
import '../../../providers/app_providers.dart';
import '../models/settings_entry.dart';
import 'device_info_card.dart';
import 'settings_list_view.dart';

class SettingsAboutTab extends ConsumerStatefulWidget {
  final String appVersion;
  final FocusNode firstAboutTabNode;
  final ConfettiController confettiController;

  const SettingsAboutTab({
    super.key,
    required this.appVersion,
    required this.firstAboutTabNode,
    required this.confettiController,
  });

  @override
  ConsumerState<SettingsAboutTab> createState() => _SettingsAboutTabState();
}

class _SettingsAboutTabState extends ConsumerState<SettingsAboutTab> {
  int _taglineTapCount = 0;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return SettingsListView(
      firstFocusNode: widget.firstAboutTabNode,
      sections: [
        SettingsSection(l.settings_sectionInfo, [
          SettingsEntry.custom(
            child: DeviceInfoCard(
              appVersion: widget.appVersion,
              focusNode: widget.firstAboutTabNode,
            ),
          ),
        ]),
        SettingsSection(l.settings_sectionLinks, [
          SettingsEntry.nav(
            icon: Icons.open_in_new_rounded,
            title: l.settings_github,
            subtitle: l.settings_githubSubtitle,
            onSelect: () => launchUrl(
                Uri.parse('https://github.com/AverageConsumer/R-Shop')),
          ),
          SettingsEntry.nav(
            icon: Icons.bug_report_outlined,
            title: l.settings_issues,
            subtitle: l.settings_issuesSubtitle,
            onSelect: () => launchUrl(Uri.parse(
                'https://github.com/AverageConsumer/R-Shop/issues')),
          ),
          SettingsEntry.custom(
            child: ConsoleFocusableListItem(
              onSelect: () {
                _taglineTapCount++;
                if (_taglineTapCount >= 5) {
                  widget.confettiController.play();
                  _taglineTapCount = 0;
                  ref.read(feedbackServiceProvider).confirm();
                } else {
                  ref.read(feedbackServiceProvider).tick();
                }
              },
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Center(
                  child: Text(
                    l.settings_tagline,
                    style: AppTheme.titleMedium.copyWith(
                      color: Colors.white54,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ],
    );
  }
}
