import 'package:flutter/material.dart';
import '../core/responsive/responsive.dart';
import '../l10n/app_localizations.dart';
import '../models/ra_models.dart';
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
  final int? raAchievementCount;
  final RaMatchType raMatchType;
  final bool isMastered;

  /// Optional color for the small "source dot" rendered in the bottom-
  /// right corner of the cover. When `null`, no dot is drawn — used for
  /// games that come from legacy/unmanaged providers or for cards
  /// outside the v3 source pipeline.
  /// Optional list of additional source dots beyond the primary one. Each
  /// entry renders as a small dot stacked to the left of the primary, in
  /// reverse order so the primary stays right-most. Empty list = single dot.
  final List<SourceDotData>? extraSourceDots;
  final Color? sourceDotColor;

  /// When `true`, the source dot is rendered with a hollow ring + share
  /// glyph instead of a solid circle, marking games that came from a
  /// borrowed (read-only / shared) source.
  final bool sourceDotBorrowed;

  // Thumbnail pipeline
  final bool hasThumbnail;
  final void Function(String url)? onThumbnailNeeded;

  // Performance
  final int memCacheWidth;
  final ValueNotifier<bool>? scrollSuppression;

  // Optional behavior
  final FocusNode? focusNode;
  final VoidCallback? onTapSelect;
  final VoidCallback? onLongPress;
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
    this.raAchievementCount,
    this.raMatchType = RaMatchType.none,
    this.isMastered = false,
    this.hasThumbnail = false,
    this.onThumbnailNeeded,
    this.memCacheWidth = 500,
    this.scrollSuppression,
    this.focusNode,
    this.onTapSelect,
    this.onLongPress,
    this.onCoverFound,
    this.sourceDotColor,
    this.sourceDotBorrowed = false,
    this.extraSourceDots,
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
      onLongPress: onLongPress,
      child: Transform.scale(
        scale: isSelected ? selectedScale : 1.0,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            border: isSelected
                ? Border.all(color: Colors.white, width: borderSelected)
                : Border.all(
                    color: Colors.white.withValues(alpha: 0.08), width: 1),
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
                    hasThumbnail: hasThumbnail,
                    onThumbnailNeeded: onThumbnailNeeded,
                    memCacheWidth: memCacheWidth,
                    scrollSuppression: scrollSuppression,
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
                          _InstalledBadge(isSmall: rs.isSmall),
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
                      ),
                      child: Icon(
                        Icons.favorite,
                        size: rs.isSmall ? 10.0 : 14.0,
                        color: Colors.redAccent,
                      ),
                    ),
                  ),
                // RA achievement badge — top right (below favorite)
                if (raAchievementCount != null &&
                    raAchievementCount! > 0 &&
                    raMatchType != RaMatchType.none)
                  Positioned(
                    top: isFavorite
                        ? padding + (rs.isSmall ? 22.0 : 28.0)
                        : padding,
                    right: padding,
                    child: _RaBadge(
                      count: raAchievementCount!,
                      matchType: raMatchType,
                      isMastered: isMastered,
                      isSmall: rs.isSmall,
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
                                  L.of(context).gameCard_variantCount(variantCount),
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
                // Source dot — bottom right, above the title gradient.
                // Solid circle = owned, hollow ring = borrowed.
                if (sourceDotColor != null)
                  Positioned(
                    right: padding,
                    bottom: padding,
                    child: _SourceDotRow(
                      primary: SourceDotData(
                        color: sourceDotColor!,
                        borrowed: sourceDotBorrowed,
                      ),
                      extras: extraSourceDots ?? const [],
                      isSmall: rs.isSmall,
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

class _InstalledBadge extends StatelessWidget {
  final bool isSmall;
  const _InstalledBadge({required this.isSmall});

  @override
  Widget build(BuildContext context) {
    final iconSize = isSmall ? 10.0 : 13.0;
    final fontSize = isSmall ? 6.0 : 7.5;
    final hPad = isSmall ? 4.0 : 5.0;
    final vPad = isSmall ? 2.0 : 3.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        color: const Color(0xCC0A3A0A),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: Colors.greenAccent.withValues(alpha: 0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.greenAccent.withValues(alpha: 0.25),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle,
            size: iconSize,
            color: Colors.greenAccent,
          ),
          SizedBox(width: isSmall ? 2 : 3),
          Text(
            L.of(context).common_installed,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: Colors.greenAccent,
              letterSpacing: 0.5,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _RaBadge extends StatelessWidget {
  final int count;
  final RaMatchType matchType;
  final bool isMastered;
  final bool isSmall;

  const _RaBadge({
    required this.count,
    required this.matchType,
    this.isMastered = false,
    required this.isSmall,
  });

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color accent, Color border) = switch ((matchType, isMastered)) {
      (RaMatchType.hashIncompatible, _) => (
          const Color(0xCC424242),
          Colors.grey,
          Colors.grey.withValues(alpha: 0.3),
        ),
      (_, true) => (
          const Color(0xCC0A3A0A),
          Colors.greenAccent,
          Colors.greenAccent.withValues(alpha: 0.4),
        ),
      _ => (
          const Color(0xDD5D4200),
          const Color(0xFFFFD54F),
          const Color(0xFFFFD54F).withValues(alpha: 0.4),
        ),
    };

    final fontSize = isSmall ? 8.0 : 10.0;
    final iconSize = isSmall ? 11.0 : 14.0;
    final hPad = isSmall ? 4.0 : 5.0;
    final vPad = isSmall ? 3.0 : 4.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: border, width: 1),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.3),
            blurRadius: isMastered ? 12 : 8,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            matchType == RaMatchType.hashIncompatible
                ? Icons.emoji_events_outlined
                : Icons.emoji_events,
            size: iconSize,
            color: accent,
          ),
          SizedBox(width: isSmall ? 2 : 3),
          Text(
            '$count',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tiny visual indicator drawn in the bottom-right corner of a game
/// cover, showing which top-level [Source] this game came from.
///
/// Owned source = solid circle in the source colour.
/// Borrowed source = hollow ring in the source colour with a small share
/// glyph in the centre. The glyph distinguishes "this game lives on a
/// friend's server" from "I downloaded this myself" without needing a
/// legend.
/// One source dot's worth of styling — colour + borrowed flag.
class SourceDotData {
  const SourceDotData({required this.color, this.borrowed = false});
  final Color color;
  final bool borrowed;
}

/// Renders the primary source dot plus up to 2 extras to its left, in
/// reverse order so the right-most dot is always the primary. Caps at 3
/// total to keep the corner readable; further sources just don't show.
class _SourceDotRow extends StatelessWidget {
  const _SourceDotRow({
    required this.primary,
    required this.extras,
    required this.isSmall,
  });

  final SourceDotData primary;
  final List<SourceDotData> extras;
  final bool isSmall;

  static const int _maxExtras = 2;

  @override
  Widget build(BuildContext context) {
    final visibleExtras = extras.take(_maxExtras).toList(growable: false);
    final spacing = isSmall ? 3.0 : 4.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final dot in visibleExtras.reversed) ...[
          _SourceDot(
            color: dot.color,
            borrowed: dot.borrowed,
            isSmall: isSmall,
          ),
          SizedBox(width: spacing),
        ],
        _SourceDot(
          color: primary.color,
          borrowed: primary.borrowed,
          isSmall: isSmall,
        ),
      ],
    );
  }
}

class _SourceDot extends StatelessWidget {
  const _SourceDot({
    required this.color,
    required this.borrowed,
    required this.isSmall,
  });

  final Color color;
  final bool borrowed;
  final bool isSmall;

  @override
  Widget build(BuildContext context) {
    final size = isSmall ? 10.0 : 12.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: borrowed ? Colors.transparent : color,
        border: Border.all(
          color: borrowed ? color : Colors.black.withValues(alpha: 0.5),
          width: borrowed ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: borrowed
          ? Center(
              child: Icon(
                Icons.share,
                size: size - 4,
                color: color,
              ),
            )
          : null,
    );
  }
}
