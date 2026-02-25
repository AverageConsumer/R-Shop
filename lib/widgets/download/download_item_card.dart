import 'package:flutter/material.dart';
import '../../core/responsive/responsive.dart';
import '../../models/download_item.dart';
import '../../utils/image_helper.dart';
import 'action_button.dart';
import 'cover_thumbnail.dart';
import 'progress_bar.dart';
import 'status_label.dart';

// ──────────────────────────────────────────────────────────────────────────────
//  DOWNLOAD ITEM CARD – horizontal card with cover art
// ──────────────────────────────────────────────────────────────────────────────

class DownloadItemCard extends StatelessWidget {
  final DownloadItem item;
  final int index;
  final VoidCallback onTap;
  final ValueChanged<bool> onHover;
  final bool isFocused;
  final bool isHovered;

  const DownloadItemCard({
    super.key,
    required this.item,
    required this.index,
    required this.onTap,
    required this.onHover,
    this.isFocused = false,
    this.isHovered = false,
  });

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final accentColor = item.system.accentColor;
    final isHighlighted = isFocused || isHovered;

    final coverUrls =
        ImageHelper.getCoverUrlsForSingle(item.system, item.game.filename);
    final coverSize = rs.isSmall ? 56.0 : 72.0;

    return MouseRegion(
      onEnter: (_) => onHover(true),
      onExit: (_) => onHover(false),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          margin: EdgeInsets.only(bottom: rs.spacing.sm),
          padding: EdgeInsets.all(rs.isSmall ? 10 : 14),
          transform: isHighlighted
              ? Matrix4.diagonal3Values(1.015, 1.015, 1.0)
              : Matrix4.identity(),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            color: _getBackgroundColor(isHighlighted),
            borderRadius: BorderRadius.circular(rs.isSmall ? 14 : 18),
            border: Border.all(
              color: _getBorderColor(isHighlighted),
              width: isHighlighted ? 1.5 : 1,
            ),
            boxShadow: isHighlighted
                ? [
                    BoxShadow(
                      color: _getGlowColor().withValues(alpha: 0.2),
                      blurRadius: 20,
                      spreadRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  // Cover art thumbnail
                  CoverThumbnail(
                    coverUrls: coverUrls,
                    cachedUrl: item.game.cachedCoverUrl,
                    accentColor: accentColor,
                    size: coverSize,
                    isComplete: item.isComplete,
                    isFailed: item.isFailed,
                    isCancelled: item.isCancelled,
                  ),
                  SizedBox(width: rs.isSmall ? 10 : 14),
                  // Info section
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Game title
                        Text(
                          item.game.displayName,
                          style: TextStyle(
                            color: item.isCancelled
                                ? Colors.white38
                                : Colors.white,
                            fontSize: rs.isSmall ? 14 : 16,
                            fontWeight: FontWeight.w700,
                            decoration: item.isCancelled
                                ? TextDecoration.lineThrough
                                : null,
                            decorationColor: Colors.white38,
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        // System + status row
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                item.system.name,
                                style: TextStyle(
                                  color: accentColor.withValues(alpha: 0.9),
                                  fontSize: rs.isSmall ? 9 : 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            StatusLabel(item: item),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: rs.spacing.sm),
                  // Action button
                  DownloadActionButton(
                    item: item,
                    isHighlighted: isHighlighted,
                    onTap: onTap,
                  ),
                ],
              ),
              // Progress bar under everything
              if (item.isActive || item.status == DownloadItemStatus.queued)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: DownloadProgressBar(item: item),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getGlowColor() {
    if (item.isComplete) return Colors.green;
    if (item.isCancelled) return Colors.grey;
    if (item.isFailed) return Colors.red;
    return Colors.white;
  }

  Color _getBackgroundColor(bool isHighlighted) {
    if (item.isComplete) {
      return Colors.green.withValues(alpha: isHighlighted ? 0.12 : 0.06);
    } else if (item.isCancelled) {
      return Colors.grey.withValues(alpha: isHighlighted ? 0.12 : 0.05);
    } else if (item.isFailed) {
      return Colors.red.withValues(alpha: isHighlighted ? 0.12 : 0.06);
    } else if (isHighlighted) {
      return Colors.white.withValues(alpha: 0.08);
    }
    return Colors.white.withValues(alpha: 0.03);
  }

  Color _getBorderColor(bool isHighlighted) {
    if (item.isComplete) {
      return Colors.green.withValues(alpha: isHighlighted ? 0.5 : 0.15);
    } else if (item.isCancelled) {
      return Colors.grey.withValues(alpha: isHighlighted ? 0.4 : 0.1);
    } else if (item.isFailed) {
      return Colors.red.withValues(alpha: isHighlighted ? 0.5 : 0.15);
    } else if (isHighlighted) {
      return Colors.white.withValues(alpha: 0.25);
    }
    return Colors.white.withValues(alpha: 0.06);
  }
}
