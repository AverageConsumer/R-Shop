import 'package:flutter/material.dart';

import '../../../core/responsive/responsive.dart';
import '../../../core/util/color_contrast.dart';
import '../../../models/game_metadata_info.dart';

/// Compact metadata card showing genres, date, credits, summary, and rating.
/// Full details (themes, franchise, etc.) are in the unified Game Info overlay.
class GameInfoCard extends StatelessWidget {
  final GameMetadataInfo metadata;
  final Color accentColor;

  const GameInfoCard({
    super.key,
    required this.metadata,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final genres = metadata.genreList;
    final hasTopRow = genres.isNotEmpty || metadata.releaseYear != null;
    final credits = metadata.creditsLine;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(rs.spacing.md),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(rs.radius.md),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasTopRow) ...[
            _buildTopRow(rs, genres),
            if (credits != null || metadata.rating != null)
              SizedBox(height: rs.spacing.sm),
          ],
          if (credits != null) ...[
            Text(
              credits,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: rs.isSmall ? 11 : 13,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (metadata.summary != null || metadata.rating != null)
              SizedBox(height: rs.spacing.sm),
          ],
          if (metadata.summary != null) ...[
            Text(
              metadata.summary!,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: rs.isSmall ? 11 : 13,
                height: 1.4,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            if (metadata.rating != null) SizedBox(height: rs.spacing.sm),
          ],
          if (metadata.rating != null) _buildRating(rs),
        ],
      ),
    );
  }

  Widget _buildTopRow(Responsive rs, List<String> genres) {
    return Row(
      children: [
        if (genres.isNotEmpty)
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: genres.take(3).map((genre) => _GenrePill(
                    label: genre,
                    accentColor: accentColor,
                    isSmall: rs.isSmall,
                  )).toList(),
            ),
          ),
        if (metadata.releaseYear != null) ...[
          if (genres.isNotEmpty) SizedBox(width: rs.spacing.sm),
          Text(
            _formatDate(rs),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: rs.isSmall ? 12 : 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  String _formatDate(Responsive rs) {
    final date = metadata.releaseDate;
    if (date != null && date.contains('-')) {
      final parts = date.split('-');
      if (parts.length >= 2) {
        const months = [
          '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
        ];
        final month = int.tryParse(parts[1]) ?? 0;
        final year = parts[0];
        if (month > 0 && month <= 12) {
          return '${months[month]} $year';
        }
      }
    }
    return '${metadata.releaseYear}';
  }

  Widget _buildRating(Responsive rs) {
    final rating = metadata.rating!;
    final normalized = (rating / 20).clamp(0.0, 5.0);
    final full = normalized.floor();
    final fraction = normalized - full;

    return Row(
      children: [
        for (var i = 0; i < 5; i++)
          Icon(
            i < full
                ? Icons.star_rounded
                : (i == full && fraction >= 0.5)
                    ? Icons.star_half_rounded
                    : Icons.star_outline_rounded,
            color: accentColor.forIcon,
            size: rs.isSmall ? 14 : 16,
          ),
        SizedBox(width: rs.spacing.xs),
        Text(
          '${rating.round()}',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: rs.isSmall ? 10 : 12,
          ),
        ),
      ],
    );
  }
}

class _GenrePill extends StatelessWidget {
  final String label;
  final Color accentColor;
  final bool isSmall;

  const _GenrePill({
    required this.label,
    required this.accentColor,
    required this.isSmall,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 6 : 8,
        vertical: isSmall ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(isSmall ? 4 : 6),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: accentColor.forText,
          fontSize: isSmall ? 9 : 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
