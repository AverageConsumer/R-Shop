import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/input/input.dart';
import '../../../core/responsive/responsive.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/app_providers.dart';
import '../../../services/cover_preload_service.dart';
import 'settings_item.dart';

class SettingsSystemTab extends ConsumerWidget {
  final FocusNode firstSystemTabNode;
  final int maxDownloads;
  final String coverSubtitle;
  final VoidCallback onOpenRommConfig;
  final VoidCallback onOpenConfigMode;
  final VoidCallback onOpenLibraryScan;
  final VoidCallback onStartCoverPreload;
  final VoidCallback onExportErrorLog;
  final ValueChanged<int> onAdjustMaxDownloads;

  const SettingsSystemTab({
    super.key,
    required this.firstSystemTabNode,
    required this.maxDownloads,
    required this.coverSubtitle,
    required this.onOpenRommConfig,
    required this.onOpenConfigMode,
    required this.onOpenLibraryScan,
    required this.onStartCoverPreload,
    required this.onExportErrorLog,
    required this.onAdjustMaxDownloads,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rs = context.rs;

    return FocusTraversalGroup(
      key: const ValueKey(1),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: EdgeInsets.symmetric(
              horizontal: rs.spacing.lg,
              vertical: rs.spacing.md,
            ),
            children: [
              SettingsItem(
                focusNode: firstSystemTabNode,
                title: 'RomM Server',
                subtitle: 'Global RomM connection settings',
                trailing:
                    const Icon(Icons.dns_outlined, color: Colors.white70),
                onTap: onOpenRommConfig,
              ),
              SizedBox(height: rs.spacing.md),
              _buildSettingsItemWrapper(
                ref: ref,
                onNavigate: (dir) {
                  if (dir == GridDirection.left) {
                    onAdjustMaxDownloads(-1);
                    ref.read(feedbackServiceProvider).tick();
                    return true;
                  } else if (dir == GridDirection.right) {
                    onAdjustMaxDownloads(1);
                    ref.read(feedbackServiceProvider).tick();
                    return true;
                  }
                  return false;
                },
                child: SettingsItem(
                  title: 'Max Concurrent Downloads',
                  subtitle: 'Number of simultaneous downloads',
                  trailingBuilder: (isFocused) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () {
                          onAdjustMaxDownloads(-1);
                          ref.read(feedbackServiceProvider).tick();
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            Icons.chevron_left,
                            color: maxDownloads > 1
                                ? (isFocused
                                    ? Colors.white
                                    : Colors.white70)
                                : Colors.white24,
                            size: 24,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 24,
                        child: Text(
                          '$maxDownloads',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color:
                                isFocused ? Colors.white : Colors.white70,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          onAdjustMaxDownloads(1);
                          ref.read(feedbackServiceProvider).tick();
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            Icons.chevron_right,
                            color: maxDownloads < 3
                                ? (isFocused
                                    ? Colors.white
                                    : Colors.white70)
                                : Colors.white24,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: rs.spacing.md),
              SettingsItem(
                title: 'Edit Consoles',
                subtitle: 'Add, remove or reconfigure consoles',
                trailing: const Icon(Icons.tune, color: Colors.white70),
                onTap: onOpenConfigMode,
              ),
              SizedBox(height: rs.spacing.md),
              SettingsItem(
                title: 'Scan Library',
                subtitle: 'Discover all games across all consoles',
                trailing:
                    const Icon(Icons.radar_rounded, color: Colors.white70),
                onTap: onOpenLibraryScan,
              ),
              SizedBox(height: rs.spacing.md),
              _buildCoverPreloadTile(ref),
              SizedBox(height: rs.spacing.md),
              _buildExportLogTile(ref),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoverPreloadTile(WidgetRef ref) {
    final preload = ref.watch(coverPreloadServiceProvider);
    if (preload.isRunning) {
      final pct = (preload.progress * 100).round();
      return SettingsItem(
        title: 'Fetching Covers...',
        subtitle: '${preload.completed} / ${preload.total} games',
        trailingBuilder: (isFocused) => SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: preload.progress,
                strokeWidth: 3,
                color: AppTheme.primaryColor,
                backgroundColor: Colors.white12,
              ),
              Text(
                '$pct%',
                style: TextStyle(
                  color: isFocused ? Colors.white : Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        onTap: onStartCoverPreload,
      );
    }
    return SettingsItem(
      title: 'Fetch All Covers',
      subtitle: coverSubtitle,
      trailing: const Icon(Icons.image_outlined, color: Colors.white70),
      onTap: onStartCoverPreload,
    );
  }

  Widget _buildExportLogTile(WidgetRef ref) {
    final logFile = ref.read(crashLogServiceProvider).getLogFile();
    if (logFile == null) {
      return const SizedBox.shrink();
    }
    return SettingsItem(
      title: 'Export Error Log',
      subtitle: 'Share crash log for debugging',
      trailing:
          const Icon(Icons.upload_file_rounded, color: Colors.white70),
      onTap: onExportErrorLog,
    );
  }

  Widget _buildSettingsItemWrapper({
    required WidgetRef ref,
    required Widget child,
    required bool Function(GridDirection) onNavigate,
  }) {
    return Actions(
      actions: {
        NavigateIntent: NavigateAction(ref, onNavigate: (intent) {
          return onNavigate(intent.direction);
        }),
      },
      child: child,
    );
  }
}
