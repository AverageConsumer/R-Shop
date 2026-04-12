import 'package:flutter/material.dart';

import '../../../core/responsive/responsive.dart';
import '../../../core/util/color_contrast.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/game_metadata_info.dart';

class SummarySection extends StatelessWidget {
  final GameMetadataInfo metadata;
  final Color accentColor;
  final bool isExpanded;
  final VoidCallback onToggle;

  static const int _maxLines = 4;

  const SummarySection({
    super.key,
    required this.metadata,
    required this.accentColor,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final credits = metadata.creditsLine;
    final summaryStyle = TextStyle(
      color: Colors.white.withValues(alpha: 0.7),
      fontSize: rs.isSmall ? 11 : 13,
      height: 1.4,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (credits != null) ...[
          Text(
            credits,
            style: TextStyle(
              color: accentColor.forText,
              fontSize: rs.isSmall ? 11 : 13,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: rs.spacing.xs),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            final textSpan = TextSpan(
              text: metadata.summary!,
              style: summaryStyle,
            );
            final textPainter = TextPainter(
              text: textSpan,
              maxLines: _maxLines,
              textDirection: TextDirection.ltr,
            )..layout(maxWidth: constraints.maxWidth);
            final overflows = textPainter.didExceedMaxLines;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metadata.summary!,
                  style: summaryStyle,
                  maxLines: isExpanded ? null : _maxLines,
                  overflow: isExpanded ? null : TextOverflow.ellipsis,
                ),
                if (overflows) ...[
                  SizedBox(height: rs.spacing.xs),
                  GestureDetector(
                    onTap: onToggle,
                    child: Text(
                      isExpanded ? L.of(context).gameDetail_showLess : L.of(context).gameDetail_readMore,
                      style: TextStyle(
                        color: accentColor.forText,
                        fontSize: rs.isSmall ? 10 : 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}
