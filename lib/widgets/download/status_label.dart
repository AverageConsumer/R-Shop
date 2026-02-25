import 'package:flutter/material.dart';
import '../../core/responsive/responsive.dart';
import '../../models/download_item.dart';

/// Status label (Downloading, Queued, etc.)
class StatusLabel extends StatelessWidget {
  final DownloadItem item;
  const StatusLabel({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final (label, color, icon) = _getInfo();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: rs.isSmall ? 12 : 14),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: rs.isSmall ? 10 : 12,
            fontWeight: FontWeight.w500,
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

  (String, Color, IconData) _getInfo() {
    switch (item.status) {
      case DownloadItemStatus.downloading:
        return ('Downloading...', Colors.green, Icons.arrow_downward_rounded);
      case DownloadItemStatus.extracting:
        return ('Extracting...', Colors.amber, Icons.unarchive_rounded);
      case DownloadItemStatus.moving:
        return ('Installing...', Colors.amber, Icons.drive_file_move_rounded);
      case DownloadItemStatus.queued:
        return ('Waiting...', Colors.white38, Icons.schedule_rounded);
      case DownloadItemStatus.completed:
        return ('Complete', Colors.green, Icons.check_circle_rounded);
      case DownloadItemStatus.cancelled:
        return ('Cancelled', Colors.grey, Icons.cancel_rounded);
      case DownloadItemStatus.error:
        return ('Failed', Colors.red, Icons.error_rounded);
    }
  }
}
