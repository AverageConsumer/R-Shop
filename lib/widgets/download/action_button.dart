import 'package:flutter/material.dart';
import '../../core/responsive/responsive.dart';
import '../../models/download_item.dart';

/// Action button (cancel / retry / dismiss)
class DownloadActionButton extends StatelessWidget {
  final DownloadItem item;
  final bool isHighlighted;
  final VoidCallback onTap;

  const DownloadActionButton({
    super.key,
    required this.item,
    required this.isHighlighted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final (color, icon, tooltip) = _getConfig();
    final buttonSize = rs.isSmall ? 34.0 : 40.0;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: buttonSize,
        height: buttonSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isHighlighted
              ? color.withValues(alpha: 0.25)
              : color.withValues(alpha: 0.1),
          border: Border.all(
            color: isHighlighted
                ? color.withValues(alpha: 0.6)
                : color.withValues(alpha: 0.2),
          ),
        ),
        child: Icon(
          icon,
          color: isHighlighted
              ? color
              : color.withValues(alpha: 0.6),
          size: rs.isSmall ? 16 : 20,
        ),
      ),
    );
  }

  (Color, IconData, String) _getConfig() {
    if (item.isComplete) {
      return (Colors.green, Icons.check_rounded, 'Dismiss');
    } else if (item.isCancelled) {
      return (Colors.grey, Icons.close_rounded, 'Dismiss');
    } else if (item.isFailed) {
      return (Colors.red, Icons.refresh_rounded, 'Retry');
    } else if (item.isActive) {
      return (Colors.red.shade300, Icons.stop_rounded, 'Cancel');
    } else {
      return (Colors.white38, Icons.close_rounded, 'Remove');
    }
  }
}
