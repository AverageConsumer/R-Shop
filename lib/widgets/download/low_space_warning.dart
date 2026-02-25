import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/responsive/responsive.dart';
import '../../models/download_item.dart';
import '../../providers/app_providers.dart';

/// Low storage warning banner shown in the download modal.
class LowSpaceWarning extends ConsumerWidget {
  final List<DownloadItem> items;
  const LowSpaceWarning({super.key, required this.items});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Find the target folder from the first active or queued download
    final activeOrQueued = items
        .where((i) => i.isActive || i.status == DownloadItemStatus.queued)
        .toList();
    if (activeOrQueued.isEmpty) return const SizedBox.shrink();

    final targetFolder = activeOrQueued.first.targetFolder;
    final storageAsync = ref.watch(storageInfoProvider(targetFolder));

    return storageAsync.when(
      data: (info) {
        if (info == null || info.isHealthy) return const SizedBox.shrink();

        final rs = context.rs;
        final Color color;
        final String message;
        if (info.isLow) {
          color = Colors.red;
          message = 'Very low storage: ${info.freeSpaceText}';
        } else {
          color = Colors.amber;
          message = 'Storage getting low: ${info.freeSpaceText}';
        }

        return Container(
          width: double.infinity,
          margin: EdgeInsets.symmetric(
            horizontal: rs.spacing.lg,
            vertical: rs.spacing.sm,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: rs.isSmall ? 10 : 14,
            vertical: rs.isSmall ? 6 : 8,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(rs.isSmall ? 6 : 8),
            border: Border.all(
              color: color.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.warning_rounded,
                size: rs.isSmall ? 14 : 16,
                color: color,
              ),
              SizedBox(width: rs.spacing.sm),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: rs.isSmall ? 11.0 : 13.0,
                    color: info.isLow ? Colors.red.shade200 : Colors.amber.shade200,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
