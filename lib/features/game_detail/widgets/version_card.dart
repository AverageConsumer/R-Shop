import 'package:flutter/material.dart';

import '../../../core/responsive/responsive.dart';
import '../../../models/game_item.dart';
import '../../../models/system_model.dart';
import '../../../utils/game_metadata.dart';
import '../../../widgets/installed_indicator.dart';
import 'metadata_badges.dart' hide InstalledBadge;

class VersionCard extends StatelessWidget {
  final GameItem variant;
  final SystemModel system;
  final bool isSelected;
  final bool isInstalled;
  final bool isFocused;
  final FocusNode? focusNode;
  final VoidCallback onTap;
  final VoidCallback? onInfoTap;

  const VersionCard({
    super.key,
    required this.variant,
    required this.system,
    required this.isSelected,
    required this.isInstalled,
    this.isFocused = false,
    this.focusNode,
    required this.onTap,
    this.onInfoTap,
  });

  @override
  Widget build(BuildContext context) {
    final metadata = GameMetadata.parse(variant.filename);
    final rs = context.rs;
    final cardPadding = rs.isSmall ? 6.0 : 10.0;
    final cardWidth = rs.isSmall ? 130.0 : 150.0;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: isFocused ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: cardWidth,
          padding: EdgeInsets.all(cardPadding),
          decoration: BoxDecoration(
            color: isFocused
                ? Colors.white.withValues(alpha: 0.12)
                : isInstalled
                    ? Colors.green.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isFocused
                  ? Colors.white.withValues(alpha: 0.9)
                  : isInstalled
                      ? Colors.greenAccent.withValues(alpha: 0.4)
                      : isSelected
                          ? system.accentColor.withValues(alpha: 0.6)
                          : Colors.white.withValues(alpha: 0.1),
              width: isFocused ? 2 : 1,
            ),
            boxShadow: isFocused
                ? [
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
                  ]
                : isInstalled
                    ? [
                        BoxShadow(
                          color: Colors.greenAccent.withValues(alpha: 0.2),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(metadata, rs),
                  SizedBox(height: rs.isSmall ? 1.0 : 2.0),
                  _buildLanguages(metadata, rs),
                  SizedBox(height: rs.isSmall ? 1.0 : 2.0),
                  _buildTags(metadata, rs),
                ],
              ),
              if (isInstalled)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: InstalledLedStrip(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(9),
                      bottomRight: Radius.circular(9),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(GameMetadataFull metadata, Responsive rs) {
    final fontSize = rs.isSmall ? 14.0 : 18.0;
    final textFontSize = rs.isSmall ? 10.0 : 12.0;
    return Row(
      children: [
        Text(
          metadata.region.flag,
          style: TextStyle(fontSize: fontSize),
        ),
        SizedBox(width: rs.isSmall ? 4 : 6),
        Expanded(
          child: Text(
            metadata.region.name,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.95),
              fontSize: textFontSize,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildLanguages(GameMetadataFull metadata, Responsive rs) {
    final fontSize = rs.isSmall ? 11.0 : 13.0;
    if (metadata.languages.isEmpty) {
      return Text(
        'Unknown',
        style: TextStyle(
          color: Colors.grey.shade500,
          fontSize: rs.isSmall ? 9.0 : 11.0,
        ),
      );
    }

    return Row(
      children: [
        ...metadata.languages.take(4).map((lang) => Padding(
              padding: EdgeInsets.only(right: rs.isSmall ? 2 : 3),
              child: Tooltip(
                message: lang.name,
                child: Text(lang.flag, style: TextStyle(fontSize: fontSize)),
              ),
            )),
      ],
    );
  }

  Widget _buildTags(GameMetadataFull metadata, Responsive rs) {
    if (metadata.primaryTags.isEmpty && !metadata.hasInfoDetails) {
      return Text(
        'Standard',
        style: TextStyle(
          color: Colors.grey.shade500,
          fontSize: rs.isSmall ? 8.0 : 10.0,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: _CompactTagBadges(
            tags: metadata.primaryTags,
            maxVisible: 2,
          ),
        ),
        if (metadata.hasInfoDetails && onInfoTap != null)
          GestureDetector(
            onTap: onInfoTap,
            child: Container(
              padding: EdgeInsets.all(rs.isSmall ? 2 : 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.info_outline,
                size: rs.isSmall ? 10 : 12,
                color: Colors.grey.shade400,
              ),
            ),
          ),
      ],
    );
  }
}

class _CompactTagBadges extends StatelessWidget {
  final List<TagInfo> tags;
  final int maxVisible;

  const _CompactTagBadges({
    required this.tags,
    required this.maxVisible,
  });

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();

    final rs = context.rs;
    final visible = tags.take(maxVisible).toList();
    final remaining = tags.length - maxVisible;
    final fontSize = rs.isSmall ? 6.0 : 8.0;
    final padding = rs.isSmall ? 3.0 : 4.0;

    return Wrap(
      spacing: rs.isSmall ? 2 : 3,
      runSpacing: rs.isSmall ? 1 : 2,
      children: [
        ...visible.map((tag) {
          final color = tag.getColor();
          return Container(
            padding: EdgeInsets.symmetric(
                horizontal: padding, vertical: rs.isSmall ? 1 : 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(rs.isSmall ? 2 : 3),
              border: Border.all(
                color: color.withValues(alpha: 0.5),
                width: 0.5,
              ),
            ),
            child: Text(
              tag.raw.replaceAll('(', '').replaceAll(')', ''),
              style: TextStyle(
                color: color.withValues(alpha: 0.95),
                fontSize: fontSize,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        }),
        if (remaining > 0)
          Container(
            padding: EdgeInsets.symmetric(
                horizontal: padding, vertical: rs.isSmall ? 1 : 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(rs.isSmall ? 2 : 3),
            ),
            child: Text(
              '+$remaining',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }
}

class SingleVersionDisplay extends StatelessWidget {
  final GameItem variant;
  final SystemModel system;
  final bool isInstalled;
  final bool isFocused;
  final FocusNode? focusNode;
  final VoidCallback? onInfoTap;

  const SingleVersionDisplay({
    super.key,
    required this.variant,
    required this.system,
    required this.isInstalled,
    this.isFocused = false,
    this.focusNode,
    this.onInfoTap,
  });

  @override
  Widget build(BuildContext context) {
    final metadata = GameMetadata.parse(variant.filename);

    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isInstalled
                ? Colors.green.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isInstalled
                  ? Colors.greenAccent.withValues(alpha: 0.4)
                  : Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
            boxShadow: isInstalled
                ? [
                    BoxShadow(
                      color: Colors.greenAccent.withValues(alpha: 0.15),
                      blurRadius: 10,
                    ),
                  ]
                : null,
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
                  if (isInstalled) const InstalledBadge(compact: false),
                ],
              ),
              if (metadata.primaryTags.isNotEmpty) ...[
                const SizedBox(height: 12),
                TagBadges(tags: metadata.primaryTags, maxVisible: 5),
              ],
              if (metadata.hasInfoDetails && onInfoTap != null) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: onInfoTap,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 14,
                        color: system.accentColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'View all tags',
                        style: TextStyle(
                          color: system.accentColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        if (isInstalled)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: InstalledLedStrip(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(11),
                bottomRight: Radius.circular(11),
              ),
            ),
          ),
      ],
    );
  }
}
