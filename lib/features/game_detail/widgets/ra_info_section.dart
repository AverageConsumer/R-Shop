import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/responsive/responsive.dart';
import '../../../models/ra_models.dart';
import '../../../providers/ra_providers.dart';
import '../../../services/database_service.dart';
import '../../../services/ra_api_service.dart';

class RaInfoSection extends ConsumerWidget {
  final RaMatchResult match;
  final String? filename;
  final String? systemSlug;
  final VoidCallback? onViewAchievements;

  const RaInfoSection({
    super.key,
    required this.match,
    this.filename,
    this.systemSlug,
    this.onViewAchievements,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!match.hasMatch) return const SizedBox.shrink();

    final rs = context.rs;
    final progress = match.raGameId != null
        ? ref.watch(raGameProgressProvider(match.raGameId!))
        : null;

    return Container(
      padding: EdgeInsets.all(rs.isSmall ? 10 : 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(rs.radius.md),
        border: Border.all(
          color: _borderColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(rs),
          SizedBox(height: rs.spacing.sm),
          _buildMatchBadge(rs),
          if (progress != null)
            progress.when(
              data: (data) {
                if (data != null && data.achievements.isNotEmpty) {
                  _persistMasteredIfNeeded(ref, data);
                  return _buildProgressSection(rs, data);
                }
                return const SizedBox.shrink();
              },
              loading: () => Padding(
                padding: EdgeInsets.only(top: rs.spacing.sm),
                child: SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
              ),
              error: (_, __) => const SizedBox.shrink(),
            ),
          if (onViewAchievements != null && match.raGameId != null) ...[
            SizedBox(height: rs.spacing.sm),
            _buildViewButton(rs),
          ],
        ],
      ),
    );
  }

  Color get _borderColor {
    if (match.isMastered) return Colors.greenAccent;
    return switch (match.type) {
      RaMatchType.hashVerified => Colors.greenAccent,
      RaMatchType.hashIncompatible => Colors.grey,
      _ => const Color(0xFFFFD54F),
    };
  }

  /// Persists mastered/un-mastered status when live progress differs from DB.
  void _persistMasteredIfNeeded(WidgetRef ref, RaGameProgress progress) {
    if (filename == null || systemSlug == null) return;
    final shouldBeMastered = progress.isCompleted;
    if (shouldBeMastered == match.isMastered) return;
    Future.microtask(() {
      DatabaseService()
          .updateRaMastered(filename!, systemSlug!, shouldBeMastered)
          .then((_) {
        try {
          ref.read(raRefreshSignalProvider.notifier).state++;
        } catch (e) {
          debugPrint('RaInfoSection: could not bump refresh signal: $e');
        }
      });
    });
  }

  Widget _buildHeader(Responsive rs) {
    final iconSize = rs.isSmall ? 28.0 : 36.0;
    final titleFontSize = rs.isSmall ? 10.0 : 12.0;
    final subtitleFontSize = rs.isSmall ? 8.0 : 9.0;

    return Row(
      children: [
        if (match.imageIcon != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: CachedNetworkImage(
              imageUrl: RetroAchievementsService.gameIconUrl(match.imageIcon!),
              width: iconSize,
              height: iconSize,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                width: iconSize,
                height: iconSize,
                color: Colors.white.withValues(alpha: 0.08),
                child: Icon(
                  Icons.emoji_events,
                  size: iconSize * 0.5,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
              ),
              errorWidget: (_, __, ___) => Container(
                width: iconSize,
                height: iconSize,
                color: Colors.white.withValues(alpha: 0.08),
                child: Icon(
                  Icons.emoji_events,
                  size: iconSize * 0.5,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
              ),
            ),
          )
        else
          Container(
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              Icons.emoji_events,
              size: iconSize * 0.5,
              color: Colors.white.withValues(alpha: 0.2),
            ),
          ),
        SizedBox(width: rs.spacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'RETROACHIEVEMENTS',
                style: TextStyle(
                  fontSize: subtitleFontSize,
                  fontWeight: FontWeight.w700,
                  color: _borderColor.withValues(alpha: 0.8),
                  letterSpacing: 1.0,
                ),
              ),
              if (match.raTitle != null)
                Text(
                  match.raTitle!,
                  style: TextStyle(
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.9),
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        if (match.achievementCount != null && match.achievementCount! > 0)
          _StatPill(
            icon: Icons.emoji_events,
            value: '${match.achievementCount}',
            color: _borderColor,
            isSmall: rs.isSmall,
          ),
      ],
    );
  }

  Widget _buildMatchBadge(Responsive rs) {
    final (String label, Color color, IconData icon) = switch (match.type) {
      RaMatchType.hashVerified => (
          'ROM Verified',
          Colors.greenAccent,
          Icons.verified,
        ),
      RaMatchType.hashIncompatible => (
          'Incompatible ROM',
          Colors.redAccent,
          Icons.warning_amber_rounded,
        ),
      RaMatchType.nameMatch => (
          'Game Has Achievements',
          const Color(0xFFFFD54F),
          Icons.emoji_events_outlined,
        ),
      RaMatchType.none => ('', Colors.transparent, Icons.block),
    };

    if (match.type == RaMatchType.none) return const SizedBox.shrink();

    final fontSize = rs.isSmall ? 8.0 : 9.0;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: rs.isSmall ? 6 : 8,
        vertical: rs.isSmall ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: rs.isSmall ? 10 : 12, color: color),
          SizedBox(width: rs.isSmall ? 3 : 4),
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection(Responsive rs, RaGameProgress progress) {
    final earned = progress.earnedCount;
    final total = progress.numAchievements;
    final pct = progress.completionPercent;
    final fontSize = rs.isSmall ? 8.0 : 10.0;
    final isMastered = progress.isCompleted;

    return Padding(
      padding: EdgeInsets.only(top: rs.spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isMastered) _buildMasteredBanner(rs),
          Row(
            children: [
              Text(
                '$earned / $total',
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                  color: isMastered
                      ? Colors.greenAccent
                      : Colors.white.withValues(alpha: 0.9),
                ),
              ),
              SizedBox(width: rs.isSmall ? 4 : 6),
              Text(
                '${(pct * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                  color: pct >= 1.0
                      ? Colors.greenAccent
                      : Colors.white.withValues(alpha: 0.5),
                ),
              ),
              if (progress.earnedPoints > 0) ...[
                SizedBox(width: rs.isSmall ? 4 : 6),
                Text(
                  '${progress.earnedPoints} pts',
                  style: TextStyle(
                    fontSize: fontSize - 1,
                    color: isMastered
                        ? Colors.greenAccent.withValues(alpha: 0.6)
                        : Colors.white.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: rs.isSmall ? 4 : 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: pct.clamp(0.0, 1.0),
              minHeight: rs.isSmall ? 4 : 6,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation(
                pct >= 1.0 ? Colors.greenAccent : _borderColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMasteredBanner(Responsive rs) {
    final fontSize = rs.isSmall ? 9.0 : 11.0;
    return Padding(
      padding: EdgeInsets.only(bottom: rs.spacing.sm),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: rs.isSmall ? 8 : 10,
          vertical: rs.isSmall ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: Colors.greenAccent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: Colors.greenAccent.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.military_tech,
              size: rs.isSmall ? 14 : 16,
              color: Colors.greenAccent,
            ),
            SizedBox(width: rs.isSmall ? 4 : 6),
            Text(
              'MASTERED',
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                color: Colors.greenAccent,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewButton(Responsive rs) {
    final fontSize = rs.isSmall ? 9.0 : 10.0;

    return GestureDetector(
      onTap: onViewAchievements,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: rs.isSmall ? 8 : 10,
          vertical: rs.isSmall ? 5 : 6,
        ),
        decoration: BoxDecoration(
          color: _borderColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _borderColor.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.list_alt_rounded,
              size: rs.isSmall ? 12 : 14,
              color: _borderColor,
            ),
            SizedBox(width: rs.isSmall ? 4 : 5),
            Text(
              'View Achievements',
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: _borderColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;
  final bool isSmall;

  const _StatPill({
    required this.icon,
    required this.value,
    required this.color,
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
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: isSmall ? 10 : 12, color: color),
          SizedBox(width: isSmall ? 3 : 4),
          Text(
            value,
            style: TextStyle(
              fontSize: isSmall ? 9.0 : 11.0,
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
