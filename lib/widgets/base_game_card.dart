import 'package:flutter/material.dart';
import '../core/responsive/responsive.dart';
import 'installed_indicator.dart';
import 'smart_cover_image.dart';

class BaseGameCard extends StatelessWidget {
  // Core
  final String displayName;
  final List<String> coverUrls;
  final String? cachedUrl;
  final bool isInstalled;
  final bool isSelected;
  final Color accentColor;
  final VoidCallback onTap;

  // Optional badges
  final bool isFavorite;
  final String? systemLabel;
  final int variantCount;
  final String? providerLabel;

  // Optional behavior
  final FocusNode? focusNode;
  final VoidCallback? onTapSelect;
  final void Function(String)? onCoverFound;

  const BaseGameCard({
    super.key,
    required this.displayName,
    required this.coverUrls,
    required this.cachedUrl,
    required this.isInstalled,
    required this.isSelected,
    this.isFavorite = false,
    required this.accentColor,
    required this.onTap,
    this.systemLabel,
    this.variantCount = 0,
    this.providerLabel,
    this.focusNode,
    this.onTapSelect,
    this.onCoverFound,
  });

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final selectedScale = rs.isSmall ? 1.08 : 1.1;
    final borderSelected = rs.isSmall ? 2.0 : 3.0;
    final titleFontSize =
        isSelected ? (rs.isSmall ? 9.0 : 11.0) : (rs.isSmall ? 7.0 : 9.0);
    final variantFontSize = rs.isSmall ? 6.0 : 8.0;
    final padding = rs.isSmall ? 4.0 : 6.0;
    final borderRadius = rs.isSmall ? 8.0 : 10.0;
    final innerBorderRadius = rs.isSmall ? 6.0 : 8.0;

    Widget card = GestureDetector(
      onTapDown: (_) => onTapSelect?.call(),
      onTap: onTap,
      child: AnimatedScale(
        scale: isSelected ? selectedScale : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            border: isSelected
                ? Border.all(color: Colors.white, width: borderSelected)
                : Border.all(
                    color: Colors.white.withValues(alpha: 0.08), width: 1),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.4),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.3),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.7),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(innerBorderRadius),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  color: const Color(0xFF151515),
                  child: SmartCoverImage(
                    urls: coverUrls,
                    cachedUrl: cachedUrl,
                    fit: BoxFit.contain,
                    onUrlFound: onCoverFound,
                  ),
                ),
                // Top-left badges (system + installed)
                if (systemLabel != null || isInstalled)
                  Positioned(
                    top: padding,
                    left: padding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (systemLabel != null)
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: rs.isSmall ? 4.0 : 5.0,
                              vertical: rs.isSmall ? 1.5 : 2.0,
                            ),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: Text(
                              systemLabel!.toUpperCase(),
                              style: TextStyle(
                                fontSize: rs.isSmall ? 5.0 : 6.0,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        if (isInstalled) ...[
                          if (systemLabel != null)
                            SizedBox(height: rs.isSmall ? 2.0 : 3.0),
                          Container(
                            padding: EdgeInsets.all(rs.isSmall ? 3.0 : 4.0),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      Colors.greenAccent.withValues(alpha: 0.5),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.check_circle,
                              size: rs.isSmall ? 10.0 : 14.0,
                              color: Colors.greenAccent,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                // Favorite heart — top right
                if (isFavorite)
                  Positioned(
                    top: padding,
                    right: padding,
                    child: Container(
                      padding: EdgeInsets.all(rs.isSmall ? 3.0 : 4.0),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.redAccent.withValues(alpha: 0.5),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.favorite,
                        size: rs.isSmall ? 10.0 : 14.0,
                        color: Colors.redAccent,
                      ),
                    ),
                  ),
                // Title gradient overlay
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.fromLTRB(
                      padding,
                      rs.isSmall ? 16 : 24,
                      padding,
                      padding,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.95),
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          displayName,
                          style: TextStyle(
                            fontSize: titleFontSize,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            height: 1.2,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.9),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (variantCount > 1 || providerLabel != null)
                          Row(
                            children: [
                              if (variantCount > 1)
                                Text(
                                  '$variantCount variants',
                                  style: TextStyle(
                                    fontSize: variantFontSize,
                                    color: Colors.grey[400],
                                  ),
                                ),
                              if (providerLabel != null) ...[
                                if (variantCount > 1)
                                  Text(
                                    ' · ',
                                    style: TextStyle(
                                      fontSize: variantFontSize,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                Text(
                                  providerLabel!,
                                  style: TextStyle(
                                    fontSize: rs.isSmall ? 6.0 : 7.0,
                                    color: Colors.grey[500],
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                // Installed LED strip (above gradient so it's visible)
                if (isInstalled)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: InstalledLedStrip(
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(innerBorderRadius),
                        bottomRight: Radius.circular(innerBorderRadius),
                      ),
                    ),
                  ),
                // Selection line
                if (isSelected)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: rs.isSmall ? 2 : 3,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.white,
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    if (focusNode != null) {
      card = Focus(
        focusNode: focusNode,
        canRequestFocus: false,
        descendantsAreFocusable: false,
        child: card,
      );
    }

    return card;
  }
}
