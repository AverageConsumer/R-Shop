import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/console_focusable.dart';
import '../../../providers/app_providers.dart';
import '../../../services/device_info_service.dart';

class DeviceInfoCard extends ConsumerWidget {
  final String appVersion;
  final FocusNode? focusNode;

  const DeviceInfoCard({
    super.key,
    required this.appVersion,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memoryInfo = ref.watch(deviceMemoryProvider);

    final (tierLabel, tierColor) = switch (memoryInfo.tier) {
      MemoryTier.low => ('LOW', Colors.amber),
      MemoryTier.standard => ('STANDARD', Colors.cyanAccent),
      MemoryTier.high => ('HIGH', Colors.greenAccent),
    };

    final ramText = '${memoryInfo.totalGB.toStringAsFixed(0)} GB RAM';
    final versionText = appVersion.isNotEmpty ? 'v$appVersion' : '';

    return ConsoleFocusableListItem(
      focusNode: focusNode,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: tierColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: tierColor.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                tierLabel,
                style: TextStyle(
                  color: tierColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ramText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (versionText.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      versionText,
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.memory_rounded,
              color: Colors.grey[600],
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}
