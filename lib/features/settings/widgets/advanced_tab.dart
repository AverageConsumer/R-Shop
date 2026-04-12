import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/widgets/console_focusable.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/download_providers.dart';
import '../../../services/cover_preload_service.dart';
import '../../../services/database_service.dart';
import '../../../services/thumbnail_service.dart';
import '../../../utils/friendly_error.dart';
import '../../../widgets/console_notification.dart';
import '../models/settings_entry.dart';
import 'settings_list_view.dart';

class SettingsAdvancedTab extends ConsumerStatefulWidget {
  final FocusNode firstFocusNode;

  const SettingsAdvancedTab({super.key, required this.firstFocusNode});

  @override
  ConsumerState<SettingsAdvancedTab> createState() =>
      _SettingsAdvancedTabState();
}

class _SettingsAdvancedTabState extends ConsumerState<SettingsAdvancedTab> {
  ProviderSubscription<CoverPreloadState>? _coverPreloadSub;
  ThumbnailDiskUsage? _thumbnailUsage;
  int? _gamesNeedingCovers;

  @override
  void initState() {
    super.initState();
    _loadCoverStats();
  }

  @override
  void dispose() {
    _coverPreloadSub?.close();
    super.dispose();
  }

  Future<void> _loadCoverStats() async {
    final usage = await ThumbnailService.getDiskUsage();
    final pending = await DatabaseService().getGamesNeedingCovers();
    if (mounted) {
      setState(() {
        _thumbnailUsage = usage;
        _gamesNeedingCovers = pending.length;
      });
    }
  }

  String _coverSubtitle() {
    final parts = <String>[];
    if (_thumbnailUsage != null && _thumbnailUsage!.fileCount > 0) {
      parts.add(
          '${_thumbnailUsage!.formattedSize} (${_thumbnailUsage!.fileCount} cached)');
    }
    if (_gamesNeedingCovers != null && _gamesNeedingCovers! > 0) {
      final estBytes = _gamesNeedingCovers! * 30 * 1024;
      final estMb = (estBytes / (1024 * 1024)).toStringAsFixed(1);
      parts.add('$_gamesNeedingCovers remaining (~$estMb MB)');
    }
    if (parts.isEmpty) {
      return _thumbnailUsage != null
          ? 'All covers cached'
          : 'Download cover art for all games';
    }
    return parts.join(' · ');
  }

  void _startCoverPreload() {
    final preloadState = ref.read(coverPreloadServiceProvider);
    if (preloadState.isRunning) {
      ref.read(coverPreloadServiceProvider.notifier).cancel();
      return;
    }
    showConsoleNotification(context,
        message: L.of(context).settings_fetchingCovers, isError: false);
    _coverPreloadSub?.close();
    _coverPreloadSub =
        ref.listenManual(coverPreloadServiceProvider, (prev, next) {
      if (prev != null && prev.isRunning && !next.isRunning) {
        _coverPreloadSub?.close();
        _coverPreloadSub = null;
        if (!mounted) return;
        _loadCoverStats();
        final l = L.of(context);
        if (next.failed > 0) {
          showErrorNotification(context, ref,
              message: l.settings_coversResult(next.succeeded, next.failed));
        } else {
          showSuccessNotification(context, ref,
              message: l.settings_coversLoaded(next.succeeded));
        }
      }
    });
    final deviceMemory = ref.read(deviceMemoryProvider);
    ref.read(coverPreloadServiceProvider.notifier).preloadAll(
          DatabaseService(),
          phase1Pool: deviceMemory.preloadPhase1Pool,
          phase2Pool: deviceMemory.preloadPhase2Pool,
        );
  }

  Future<void> _exportErrorLog() async {
    final logFile = ref.read(crashLogServiceProvider).getLogFile();
    if (logFile == null) {
      if (mounted) {
        showConsoleNotification(context, message: L.of(context).settings_noErrorLog);
      }
      return;
    }
    try {
      await Share.shareXFiles([XFile(logFile.path)]);
    } catch (e) {
      if (mounted) {
        showErrorNotification(context, ref,
            message: 'Share failed: ${getUserFriendlyError(e)}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final syncTimeout = ref.watch(syncTimeoutProvider);
    final syncCooldown = ref.watch(syncCooldownProvider);
    final allowHttp = ref.watch(allowNonLanHttpProvider);
    final maxDownloads =
        ref.watch(downloadQueueManagerProvider).state.maxConcurrent;
    final preload = ref.watch(coverPreloadServiceProvider);
    final hasLogFile = ref.read(crashLogServiceProvider).getLogFile() != null;

    return SettingsListView(
      firstFocusNode: widget.firstFocusNode,
      sections: [
        SettingsSection(l.settings_sectionDownloads, [
          SettingsEntry.spinner(
            title: l.settings_simultaneousDownloads,
            subtitle: l.settings_simultaneousDownloadsSubtitle,
            value: maxDownloads,
            min: 1,
            max: 3,
            onChanged: (delta) {
              final newValue = (maxDownloads + delta).clamp(1, 3);
              if (newValue != maxDownloads) {
                ref
                    .read(downloadQueueManagerProvider)
                    .setMaxConcurrent(newValue);
                ref.read(feedbackServiceProvider).tick();
              }
            },
          ),
          SettingsEntry.custom(
            child: _CoverPreloadTile(
              preload: preload,
              subtitle: _coverSubtitle(),
              onTap: _startCoverPreload,
            ),
          ),
        ]),
        SettingsSection(l.settings_sectionSync, [
          SettingsEntry.cycle(
            title: l.settings_syncTimeout,
            subtitle: l.settings_syncTimeoutSubtitle,
            displayValue: formatSyncTimeout(syncTimeout),
            onCycle: () {
              ref.read(syncTimeoutProvider.notifier).cycle();
              ref.read(feedbackServiceProvider).tick();
            },
          ),
          SettingsEntry.cycle(
            title: l.settings_autoSyncInterval,
            subtitle: l.settings_autoSyncIntervalSubtitle,
            displayValue: formatSyncCooldown(syncCooldown),
            onCycle: () {
              ref.read(syncCooldownProvider.notifier).cycle();
              ref.read(feedbackServiceProvider).tick();
            },
          ),
        ]),
        SettingsSection(l.settings_sectionDebug, [
          SettingsEntry.toggle(
            title: l.settings_allowInsecure,
            subtitle: l.settings_allowInsecureSubtitle,
            value: allowHttp,
            onChanged: () {
              ref.read(allowNonLanHttpProvider.notifier).toggle();
              ref.read(feedbackServiceProvider).tick();
            },
          ),
          if (hasLogFile)
            SettingsEntry.nav(
              icon: Icons.upload_file_rounded,
              title: l.settings_exportErrorLog,
              subtitle: l.settings_exportErrorLogSubtitle,
              onSelect: _exportErrorLog,
            ),
        ]),
      ],
    );
  }
}

/// Custom tile for the cover preload item that shows progress when running.
class _CoverPreloadTile extends StatefulWidget {
  final CoverPreloadState preload;
  final String subtitle;
  final VoidCallback onTap;

  const _CoverPreloadTile({
    required this.preload,
    required this.subtitle,
    required this.onTap,
  });

  @override
  State<_CoverPreloadTile> createState() => _CoverPreloadTileState();
}

class _CoverPreloadTileState extends State<_CoverPreloadTile> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final preload = widget.preload;
    final trailing = preload.isRunning
        ? SizedBox(
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
                  '${(preload.progress * 100).round()}%',
                  style: TextStyle(
                    color: _isFocused ? Colors.white : Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          )
        : const Icon(Icons.image_outlined, color: Colors.white70);

    return ConsoleFocusableListItem(
      onSelect: widget.onTap,
      child: Builder(builder: (context) {
        // Listen for focus changes via the FocusNode that
        // ConsoleFocusableListItem creates internally.
        final focusNode = Focus.of(context);
        if (focusNode.hasFocus != _isFocused) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _isFocused = focusNode.hasFocus);
          });
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      preload.isRunning
                          ? L.of(context).settings_downloadingCovers
                          : L.of(context).settings_downloadAllCovers,
                      style: AppTheme.titleMedium.copyWith(
                        color: _isFocused ? Colors.white : Colors.white70,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      preload.isRunning
                          ? '${preload.completed} / ${preload.total} games'
                          : widget.subtitle,
                      style: AppTheme.bodySmall.copyWith(
                        color: _isFocused ? Colors.white70 : Colors.white38,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              trailing,
            ],
          ),
        );
      }),
    );
  }
}
