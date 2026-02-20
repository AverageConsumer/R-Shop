import 'package:flutter/material.dart';

import '../../../core/responsive/responsive.dart';
import '../../../models/system_model.dart';

class GameListHeader extends StatelessWidget {
  final SystemModel system;
  final int gameCount;
  final bool hasActiveFilters;
  final bool isLocalOnly;
  final String targetFolder;

  const GameListHeader({
    super.key,
    required this.system,
    required this.gameCount,
    this.hasActiveFilters = false,
    this.isLocalOnly = false,
    this.targetFolder = '',
  });

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final titleFontSize = rs.isSmall ? 18.0 : (rs.isMedium ? 21.0 : 24.0);
    final subtitleFontSize = rs.isSmall ? 9.0 : 11.0;
    final badgeFontSize = rs.isSmall ? 11.0 : 13.0;
    final iconSize = rs.isSmall ? 12.0 : 14.0;
    final horizontalPadding = rs.isSmall ? rs.spacing.md : rs.spacing.lg;
    final topPadding = rs.safeAreaTop + (rs.isSmall ? 8 : 12);

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: topPadding,
          left: horizontalPadding,
          right: horizontalPadding,
          bottom: rs.isSmall ? 8 : 12,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.9),
              Colors.black.withValues(alpha: 0.6),
              Colors.transparent,
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        system.name.toUpperCase(),
                        style: TextStyle(
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: rs.isSmall ? 2 : 4,
                          shadows: [
                            Shadow(
                              color: system.accentColor.withValues(alpha: 0.8),
                              blurRadius: rs.isSmall ? 12 : 20,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: rs.spacing.xs),
                      Text(
                        '${system.manufacturer} · ${system.releaseYear}',
                        style: TextStyle(
                          fontSize: subtitleFontSize,
                          color: Colors.grey[500],
                          letterSpacing: 2,
                        ),
                      ),
                      if (targetFolder.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.folder_outlined,
                              size: rs.isSmall ? 10 : 12,
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                _shortenPath(targetFolder),
                                style: TextStyle(
                                  fontSize: rs.isSmall ? 8 : 10,
                                  color: Colors.white.withValues(alpha: 0.2),
                                  fontFamily: 'monospace',
                                  letterSpacing: 0.5,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: rs.isSmall ? 8 : 12,
                    vertical: rs.isSmall ? 5 : 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(rs.isSmall ? 14 : 20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasActiveFilters) ...[
                        Icon(
                          Icons.filter_list,
                          size: iconSize,
                          color: system.accentColor,
                        ),
                        SizedBox(width: rs.isSmall ? 4 : 6),
                      ],
                      Icon(
                        Icons.games,
                        size: iconSize,
                        color: system.accentColor,
                      ),
                      SizedBox(width: rs.isSmall ? 4 : 8),
                      Text(
                        '$gameCount Games',
                        style: TextStyle(
                          fontSize: badgeFontSize,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (isLocalOnly) ...[
              SizedBox(height: rs.spacing.sm),
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: rs.isSmall ? 8 : 12,
                  vertical: rs.isSmall ? 4 : 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(rs.isSmall ? 6 : 8),
                  border: Border.all(
                    color: Colors.amber.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  'Local files only \u00B7 Add a provider to download more',
                  style: TextStyle(
                    fontSize: rs.isSmall ? 9.0 : 11.0,
                    color: Colors.amber.shade200,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _shortenPath(String path) {
    const prefixes = [
      '/storage/emulated/0/',
      '/sdcard/',
    ];
    for (final prefix in prefixes) {
      if (path.startsWith(prefix)) {
        return path.substring(prefix.length);
      }
    }
    return path;
  }
}
