import 'package:flutter/material.dart';
import '../../models/download_item.dart';

/// Sleek progress bar with glow
class DownloadProgressBar extends StatelessWidget {
  final DownloadItem item;
  const DownloadProgressBar({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final accentColor = item.system.accentColor;
    final isQueued = item.status == DownloadItemStatus.queued;
    final isIndeterminate = item.status == DownloadItemStatus.extracting ||
        item.status == DownloadItemStatus.moving;

    if (isQueued) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: LinearProgressIndicator(
          value: 0,
          backgroundColor: Colors.white.withValues(alpha: 0.06),
          valueColor: AlwaysStoppedAnimation(Colors.white.withValues(alpha: 0.15)),
          minHeight: 3,
        ),
      );
    }

    if (isIndeterminate) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: LinearProgressIndicator(
          backgroundColor: Colors.white.withValues(alpha: 0.06),
          valueColor: AlwaysStoppedAnimation(Colors.amber.withValues(alpha: 0.7)),
          minHeight: 3,
        ),
      );
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: item.progress),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      builder: (context, value, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Percentage text
            if (item.progress > 0.01)
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    '${(value * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: accentColor.withValues(alpha: 0.8),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            // Track + filled bar
            Stack(
              children: [
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: value.clamp(0.0, 1.0),
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      gradient: LinearGradient(
                        colors: [
                          accentColor.withValues(alpha: 0.7),
                          accentColor,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withValues(alpha: 0.5),
                          blurRadius: 6,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
