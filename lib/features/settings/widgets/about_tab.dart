import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/responsive/responsive.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/console_focusable.dart';
import '../../../providers/app_providers.dart';
import 'device_info_card.dart';
import 'settings_item.dart';

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
    final rs = context.rs;

    return FocusTraversalGroup(
      key: const ValueKey(2),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: EdgeInsets.symmetric(
              horizontal: rs.spacing.lg,
              vertical: rs.spacing.md,
            ),
            children: [
              DeviceInfoCard(
                appVersion: widget.appVersion,
                focusNode: widget.firstAboutTabNode,
              ),
              SizedBox(height: rs.spacing.md),
              SettingsItem(
                title: 'GitHub',
                subtitle: 'View source code on GitHub',
                trailing: const Icon(Icons.open_in_new_rounded,
                    color: Colors.white70),
                onTap: () => launchUrl(
                    Uri.parse('https://github.com/AverageConsumer/R-Shop')),
              ),
              SizedBox(height: rs.spacing.md),
              SettingsItem(
                title: 'Issues',
                subtitle: 'Report bugs or request features',
                trailing: const Icon(Icons.bug_report_outlined,
                    color: Colors.white70),
                onTap: () => launchUrl(Uri.parse(
                    'https://github.com/AverageConsumer/R-Shop/issues')),
              ),
              SizedBox(height: rs.spacing.md),
              ConsoleFocusableListItem(
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  child: Center(
                    child: Text(
                      'INTENSIV, AGGRESSIV, MUTIG',
                      style: AppTheme.titleMedium.copyWith(
                        color: Colors.white54,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
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
