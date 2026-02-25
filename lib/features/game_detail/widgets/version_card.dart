import 'package:flutter/material.dart';

import '../../../models/game_item.dart';
import '../../../models/system_model.dart';
import '../../../utils/game_metadata.dart';
import '../../../widgets/installed_indicator.dart';
import 'metadata_badges.dart' hide InstalledBadge;

class SingleVersionDisplay extends StatelessWidget {
  final GameItem variant;
  final SystemModel system;
  final bool isInstalled;
  final bool isSelected;
  final bool isFocused;
  final bool isFavorite;
  final FocusNode? focusNode;
  final VoidCallback? onTap;

  const SingleVersionDisplay({
    super.key,
    required this.variant,
    required this.system,
    required this.isInstalled,
    this.isSelected = false,
    this.isFocused = false,
    this.isFavorite = false,
    this.focusNode,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final metadata = GameMetadata.parse(variant.filename);

    // Priority: focused > installed > selected > default
    final Color bgColor;
    final Color borderColor;
    final double borderWidth;
    final List<BoxShadow>? shadows;

    if (isFocused) {
      bgColor = Colors.white.withValues(alpha: 0.12);
      borderColor = Colors.white.withValues(alpha: 0.9);
      borderWidth = 2;
      shadows = [
        BoxShadow(
          color: isInstalled
              ? Colors.greenAccent.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.35),
          blurRadius: 16,
          spreadRadius: 1,
        ),
        BoxShadow(
          color: isInstalled
              ? Colors.greenAccent.withValues(alpha: 0.3)
              : system.accentColor.withValues(alpha: 0.25),
          blurRadius: 24,
          spreadRadius: 3,
        ),
      ];
    } else if (isInstalled) {
      bgColor = Colors.green.withValues(alpha: 0.08);
      borderColor = Colors.greenAccent.withValues(alpha: 0.4);
      borderWidth = 1;
      shadows = [
        BoxShadow(
          color: Colors.greenAccent.withValues(alpha: 0.15),
          blurRadius: 10,
        ),
      ];
    } else if (isSelected) {
      bgColor = system.accentColor.withValues(alpha: 0.08);
      borderColor = system.accentColor.withValues(alpha: 0.6);
      borderWidth = 1.5;
      shadows = [
        BoxShadow(
          color: system.accentColor.withValues(alpha: 0.15),
          blurRadius: 10,
        ),
      ];
    } else {
      bgColor = Colors.white.withValues(alpha: 0.05);
      borderColor = Colors.white.withValues(alpha: 0.1);
      borderWidth = 1;
      shadows = null;
    }

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: borderWidth),
              boxShadow: shadows,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    RegionBadge(region: metadata.region),
                    const SizedBox(width: 12),
                    LanguageBadges(languages: metadata.languages),
                    const Spacer(),
                    if (variant.providerConfig != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Text(
                          variant.providerConfig!.detailLabel,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (isFavorite) ...[
                      Icon(
                        Icons.favorite_rounded,
                        size: 14,
                        color: Colors.redAccent.withValues(alpha: 0.8),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (isInstalled) const InstalledBadge(compact: false),
                  ],
                ),
                if (metadata.primaryTags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  TagBadges(tags: metadata.primaryTags, maxVisible: 5),
                ],
              ],
            ),
          ),
          if (isInstalled)
            const Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: InstalledLedStrip(
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(11),
                  bottomRight: Radius.circular(11),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
