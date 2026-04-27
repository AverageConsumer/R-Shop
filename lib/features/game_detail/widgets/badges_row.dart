import 'package:flutter/material.dart';

import '../../../core/responsive/responsive.dart';
import '../../../core/util/color_contrast.dart';
import '../../../models/game_metadata_info.dart';

class BadgesRow extends StatelessWidget {
  final GameMetadataInfo metadata;
  final Color accentColor;

  const BadgesRow({
    super.key,
    required this.metadata,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final genres = metadata.genreList;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Genre pills
        ...genres.take(rs.isSmall ? 2 : 4).map((genre) => Container(
              padding: EdgeInsets.symmetric(
                horizontal: rs.isSmall ? 6 : 8,
                vertical: rs.isSmall ? 3 : 4,
              ),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(rs.isSmall ? 4 : 6),
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.35),
                ),
              ),
              child: Text(
                genre,
                style: TextStyle(
                  color: accentColor.forText,
                  fontSize: rs.isSmall ? 9 : 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )),
        // Age rating badges with icons
        ..._AgeRatingBadge.fromRatingString(
          metadata.ageRating,
          isSmall: rs.isSmall,
        ),
        // Star rating with numeric value
        if (metadata.rating != null)
          _CompactRating(
            rating: metadata.rating!,
            accentColor: accentColor,
          ),
        // Release date with label
        if (metadata.releaseYear != null)
          Text(
            'Release Date: ${_formatDate(metadata)}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: rs.isSmall ? 9 : 11,
              fontWeight: FontWeight.w500,
            ),
          ),
      ],
    );
  }

  static String _formatDate(GameMetadataInfo metadata) {
    final date = metadata.releaseDate;
    if (date != null && date.contains('-')) {
      final parts = date.split('-');
      if (parts.length >= 3) {
        const months = [
          '', 'Jan.', 'Feb.', 'Mar.', 'Apr.', 'May', 'Jun.',
          'Jul.', 'Aug.', 'Sep.', 'Oct.', 'Nov.', 'Dec.',
        ];
        final month = int.tryParse(parts[1]) ?? 0;
        final day = int.tryParse(parts[2]) ?? 0;
        final year = parts[0];
        if (month > 0 && month <= 12 && day > 0) {
          return '$day. ${months[month]} $year';
        }
      }
      if (parts.length >= 2) {
        const months = [
          '', 'Jan.', 'Feb.', 'Mar.', 'Apr.', 'May', 'Jun.',
          'Jul.', 'Aug.', 'Sep.', 'Oct.', 'Nov.', 'Dec.',
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
}

class _CompactRating extends StatelessWidget {
  final double rating;
  final Color accentColor;

  const _CompactRating({
    required this.rating,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final normalized = (rating / 20).clamp(0.0, 5.0);
    final full = normalized.floor();
    final fraction = normalized - full;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 5; i++)
          Icon(
            i < full
                ? Icons.star_rounded
                : (i == full && fraction >= 0.5)
                    ? Icons.star_half_rounded
                    : Icons.star_outline_rounded,
            color: accentColor.forIcon,
            size: rs.isSmall ? 12 : 14,
          ),
        SizedBox(width: rs.spacing.xs),
        Text(
          '${rating.toStringAsFixed(rating.truncateToDouble() == rating ? 0 : 2)} (Avg Rating)',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: rs.isSmall ? 9 : 11,
          ),
        ),
      ],
    );
  }
}

class _AgeRatingBadge extends StatelessWidget {
  final ({IconData icon, Color color, String label}) parsed;
  final bool isSmall;

  const _AgeRatingBadge({
    required this.parsed,
    required this.isSmall,
  });

  /// Splits a comma-separated rating string into individual badge widgets.
  static List<Widget> fromRatingString(String? rating, {required bool isSmall}) {
    if (rating == null || rating.isEmpty) return const [];
    return rating
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .map((s) => _AgeRatingBadge(
              parsed: _parseRating(s),
              isSmall: isSmall,
            ))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final color = parsed.color;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 6 : 8,
        vertical: isSmall ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(isSmall ? 4 : 6),
        border: Border.all(
          color: color.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            parsed.icon,
            color: color.withValues(alpha: 0.85),
            size: isSmall ? 11 : 13,
          ),
          const SizedBox(width: 4),
          Text(
            parsed.label,
            style: TextStyle(
              color: color.withValues(alpha: 0.85),
              fontSize: isSmall ? 9 : 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // Rating lookup table: (pattern, icon, color, label)
  static const _green = Color(0xFF66BB6A);
  static const _yellow = Color(0xFFFFD54F);
  static const _orange = Color(0xFFFFA726);
  static const _red = Color(0xFFE53935);

  static ({IconData icon, Color color, String label}) _parseRating(
      String rating) {
    final lower = rating.toLowerCase().trim();

    // Try prefixed format first ("ESRB: E", "PEGI: 7", "CERO: A")
    // Then try bare values ("E10+", "T", "7", "18")

    // --- ESRB ---
    if (_matches(lower, 'ao', 'adults only')) {
      return (icon: Icons.no_adult_content, color: _red, label: 'AO');
    }
    if (_matches(lower, 'm', 'mature') && !lower.contains('e10')) {
      return (icon: Icons.shield_rounded, color: _red, label: 'M');
    }
    if (_matches(lower, 'e10', 'everyone 10')) {
      return (
        icon: Icons.escalator_warning_rounded,
        color: _yellow,
        label: 'E10+'
      );
    }
    if (_matches(lower, 't', 'teen')) {
      return (icon: Icons.person_rounded, color: _orange, label: 'T');
    }
    // "E" must come after E10+ and EC checks
    if (_matches(lower, 'ec', 'early childhood')) {
      return (icon: Icons.child_care_rounded, color: _green, label: 'EC');
    }
    if (_matchesE(lower)) {
      return (icon: Icons.family_restroom_rounded, color: _green, label: 'E');
    }

    // --- PEGI ---
    if (_matchesAge(lower, '18')) {
      return (icon: Icons.no_adult_content, color: _red, label: 'PEGI 18');
    }
    if (_matchesAge(lower, '16')) {
      return (icon: Icons.shield_rounded, color: _red, label: 'PEGI 16');
    }
    if (_matchesAge(lower, '12')) {
      return (icon: Icons.person_rounded, color: _orange, label: 'PEGI 12');
    }
    if (_matchesAge(lower, '7')) {
      return (
        icon: Icons.escalator_warning_rounded,
        color: _yellow,
        label: 'PEGI 7'
      );
    }
    if (_matchesAge(lower, '3')) {
      return (icon: Icons.child_care_rounded, color: _green, label: 'PEGI 3');
    }

    // --- CERO ---
    if (lower.contains('cero')) {
      if (lower.contains('z')) {
        return (icon: Icons.no_adult_content, color: _red, label: 'CERO Z');
      }
      if (lower.contains('d')) {
        return (icon: Icons.shield_rounded, color: _red, label: 'CERO D');
      }
      if (lower.contains('c')) {
        return (icon: Icons.person_rounded, color: _orange, label: 'CERO C');
      }
      if (lower.contains('b')) {
        return (
          icon: Icons.escalator_warning_rounded,
          color: _yellow,
          label: 'CERO B'
        );
      }
      if (lower.contains('a')) {
        return (icon: Icons.child_care_rounded, color: _green, label: 'CERO A');
      }
    }

    // --- USK ---
    if (lower.contains('usk')) {
      if (lower.contains('18')) {
        return (icon: Icons.no_adult_content, color: _red, label: 'USK 18');
      }
      if (lower.contains('16')) {
        return (icon: Icons.shield_rounded, color: _red, label: 'USK 16');
      }
      if (lower.contains('12')) {
        return (icon: Icons.person_rounded, color: _orange, label: 'USK 12');
      }
      if (lower.contains('6')) {
        return (
          icon: Icons.escalator_warning_rounded,
          color: _yellow,
          label: 'USK 6'
        );
      }
      if (lower.contains('0')) {
        return (icon: Icons.child_care_rounded, color: _green, label: 'USK 0');
      }
    }

    // Fallback: show original text with neutral styling
    return (
      icon: Icons.info_outline_rounded,
      color: Colors.white70,
      label: rating.trim(),
    );
  }

  /// Matches ESRB-style ratings: "ESRB: T", "Teen", or bare "T"
  static bool _matches(String lower, String code, String fullName) {
    if (lower.contains(fullName)) return true;
    if (lower.contains('esrb') && lower.contains(code)) return true;
    // Bare match: exact or with colon prefix
    if (lower == code) return true;
    return false;
  }

  /// Special match for "E" — must not match "E10+", "EC", "Teen", etc.
  static bool _matchesE(String lower) {
    if (lower.contains('everyone') &&
        !lower.contains('everyone 10') &&
        !lower.contains('e10')) {
      return true;
    }
    if (lower.contains('esrb') &&
        lower.contains('e') &&
        !lower.contains('e10') &&
        !lower.contains('ec')) {
      return true;
    }
    if (lower == 'e') return true;
    return false;
  }

  /// Matches PEGI/USK numeric ratings: "PEGI: 7", "PEGI 7", or bare "7"
  static bool _matchesAge(String lower, String age) {
    if (lower.contains('pegi') && lower.contains(age)) return true;
    if (lower == age) return true;
    return false;
  }
}
