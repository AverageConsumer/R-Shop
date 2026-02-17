import 'package:flutter/material.dart';
import '../../../core/responsive/responsive.dart';
import '../../../widgets/installed_indicator.dart';
import '../../../widgets/smart_cover_image.dart';

class GameCard extends StatelessWidget {
  final String displayName;
  final List<String> coverUrls;
  final String? cachedUrl;
  final int variantCount;
  final bool isInstalled;
  final bool isSelected;
  final Color accentColor;
  final FocusNode? focusNode;
  final VoidCallback onTap;
  final VoidCallback? onTapSelect;
  final void Function(String)? onCoverFound;

  const GameCard({
    super.key,
    required this.displayName,
    required this.coverUrls,
    required this.cachedUrl,
    required this.variantCount,
    required this.isInstalled,
    required this.isSelected,
    required this.accentColor,
    this.focusNode,
    required this.onTap,
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

    return Focus(
      focusNode: focusNode,
      canRequestFocus: false,
      descendantsAreFocusable: false,
      child: GestureDetector(
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
                  if (isInstalled) ...[
                    Positioned(
                      top: padding,
                      right: padding,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const InstalledBadge(compact: true),
                      ),
                    ),
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
                  ],
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
                          if (variantCount > 1)
                            Text(
                              '$variantCount variants',
                              style: TextStyle(
                                fontSize: variantFontSize,
                                color: Colors.grey[400],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (isSelected)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: rs.isSmall ? 2 : 3,
                        decoration: BoxDecoration(
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
      ),
    );
  }
}
