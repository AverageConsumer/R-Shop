import 'package:flutter/material.dart';

import '../../../core/responsive/responsive.dart';
import '../../../l10n/app_localizations.dart';
import '../logic/filter_state.dart';

/// A horizontal status strip showing which filters are currently active on
/// GameList. Read-only — the pills are NOT tappable / focusable, because
/// R-Shop is a controller-first app and the only honest way to remove a
/// filter is via the existing modal (open via Quick Menu → Filter).
///
/// This widget exists so users always SEE what's filtered without having
/// to open the modal to check. Removal still happens in the modal.
class FilterPillBar extends StatelessWidget {
  final ActiveFilters filters;
  final List<FilterOption> availableRegions;
  final List<FilterOption> availableLanguages;
  final Color accentColor;

  const FilterPillBar({
    super.key,
    required this.filters,
    required this.availableRegions,
    required this.availableLanguages,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    if (filters.isEmpty) return const SizedBox.shrink();

    final rs = context.rs;
    final l = L.of(context);

    final pills = <Widget>[];

    if (filters.favoritesOnly) {
      pills.add(_FilterPill(
        accent: accentColor,
        rs: rs,
        icon: Icons.star_rounded,
        label: l.filter_favoritesOnly,
      ));
    }
    if (filters.localOnly) {
      pills.add(_FilterPill(
        accent: accentColor,
        rs: rs,
        icon: Icons.folder_outlined,
        label: l.filter_installedOnly,
      ));
    }
    for (final region in filters.selectedRegions) {
      final opt = _findOption(availableRegions, region);
      pills.add(_FilterPill(
        accent: accentColor,
        rs: rs,
        flag: opt?.flag,
        label: opt?.label ?? region,
      ));
    }
    for (final lang in filters.selectedLanguages) {
      final opt = _findOption(availableLanguages, lang);
      pills.add(_FilterPill(
        accent: accentColor,
        rs: rs,
        flag: opt?.flag,
        label: opt?.label ?? lang,
      ));
    }

    return Container(
      padding: EdgeInsets.fromLTRB(
        rs.spacing.lg,
        rs.spacing.xs,
        rs.spacing.lg,
        rs.spacing.sm,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            for (int i = 0; i < pills.length; i++) ...[
              if (i > 0) SizedBox(width: rs.spacing.xs),
              pills[i],
            ],
          ],
        ),
      ),
    );
  }

  static FilterOption? _findOption(List<FilterOption> options, String id) {
    for (final o in options) {
      if (o.id == id) return o;
    }
    return null;
  }
}

class _FilterPill extends StatelessWidget {
  final Color accent;
  final Responsive rs;
  final IconData? icon;
  final String? flag;
  final String label;

  const _FilterPill({
    required this.accent,
    required this.rs,
    this.icon,
    this.flag,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final fontSize = rs.isSmall ? 10.0 : 12.0;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: rs.isSmall ? 8 : 10,
        vertical: rs.isSmall ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(rs.isSmall ? 12 : 16),
        border: Border.all(
          color: accent.withValues(alpha: 0.55),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (flag != null && flag!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                flag!,
                style: TextStyle(fontSize: fontSize + 2),
              ),
            )
          else if (icon != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(
                icon,
                size: fontSize + 2,
                color: Colors.white,
              ),
            ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
