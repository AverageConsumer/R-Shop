import 'package:flutter/material.dart';
import '../../core/responsive/responsive.dart';
import '../../l10n/app_localizations.dart';
import '../../models/download_item.dart';

/// Status label (Downloading, Queued, etc.)
class StatusLabel extends StatelessWidget {
  final DownloadItem item;
  const StatusLabel({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final (label, color, icon) = _getInfo(L.of(context));

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: rs.isSmall ? 12 : 14),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: rs.isSmall ? 10 : 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        if (item.isActive && item.speedText != null) ...[
          const SizedBox(width: 6),
          Container(
            width: 1,
            height: 10,
            color: Colors.white.withValues(alpha: 0.15),
          ),
          const SizedBox(width: 6),
          Text(
            item.speedText!,
            style: TextStyle(
              color: Colors.white70,
              fontSize: rs.isSmall ? 10 : 12,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ],
    );
  }

  (String, Color, IconData) _getInfo(L l) {
    switch (item.status) {
      case DownloadStatus.downloading:
        return (l.downloadStatus_downloading, Colors.green, Icons.arrow_downward_rounded);
      case DownloadStatus.extracting:
        return (l.downloadStatus_extracting, Colors.amber, Icons.unarchive_rounded);
      case DownloadStatus.moving:
        return (l.downloadStatus_installing, Colors.amber, Icons.drive_file_move_rounded);
      case DownloadStatus.queued:
        return (l.downloadStatus_waiting, Colors.white38, Icons.schedule_rounded);
      case DownloadStatus.completed:
        return (l.downloadStatus_complete, Colors.green, Icons.check_circle_rounded);
      case DownloadStatus.cancelled:
        return (l.downloadStatus_cancelled, Colors.grey, Icons.cancel_rounded);
      case DownloadStatus.error:
        return (l.downloadStatus_failed, Colors.red, Icons.error_rounded);
    }
  }
}
