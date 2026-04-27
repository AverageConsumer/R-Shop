import 'package:flutter/material.dart';

import '../../../core/responsive/responsive.dart';
import '../../../l10n/app_localizations.dart';
import '../logic/filter_state.dart';

/// Switch-eShop-style filter chip strip that surfaces active filters at the
/// top of GameList. Each chip shows a label + ✕ to drop that filter; tapping
/// the trailing "Alle entfernen" pill clears all of them. The full picker
/// (regions + languages) still opens via the menu — this widget is the
/// always-visible state indicator + quick-remove affordance.
///
/// Touch / mouse only. D-pad navigation stays on the grid below; controller
/// users still toggle filters from the modal as before, but they can SEE
/// what's active without opening anything.
class FilterPillBar extends StatelessWidget {
  final ActiveFilters filters;
  final List<FilterOption> availableRegions;
  final List<FilterOption> availableLanguages;
  final Color accentColor;
  final void Function(String region) onToggleRegion;
  final void Function(String language) onToggleLanguage;
  final VoidCallback onToggleFavorites;
  final VoidCallback onToggleLocal;
  final VoidCallback onClearAll;

  const FilterPillBar({
    super.key,
    required this.filters,
    required this.availableRegions,
    required this.availableLanguages,
    required this.accentColor,
    required this.onToggleRegion,
    required this.onToggleLanguage,
    required this.onToggleFavorites,
    required this.onToggleLocal,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    if (filters.isEmpty) return const SizedBox.shrink();

    final rs = context.rs;
    final l = L.of(context);

    final chips = <Widget>[];

    if (filters.favoritesOnly) {
      chips.add(_FilterChip(
        accent: accentColor,
        rs: rs,
        icon: Icons.star_rounded,
        label: l.filter_favoritesOnly,
        onRemove: onToggleFavorites,
      ));
    }
    if (filters.localOnly) {
      chips.add(_FilterChip(
        accent: accentColor,
        rs: rs,
        icon: Icons.folder_outlined,
        label: l.filter_installedOnly,
        onRemove: onToggleLocal,
      ));
    }
    for (final region in filters.selectedRegions) {
      final opt = _findOption(availableRegions, region);
      chips.add(_FilterChip(
        accent: accentColor,
        rs: rs,
        flag: opt?.flag,
        label: opt?.label ?? region,
        onRemove: () => onToggleRegion(region),
      ));
    }
    for (final lang in filters.selectedLanguages) {
      final opt = _findOption(availableLanguages, lang);
      chips.add(_FilterChip(
        accent: accentColor,
        rs: rs,
        flag: opt?.flag,
        label: opt?.label ?? lang,
        onRemove: () => onToggleLanguage(lang),
      ));
    }

    if (chips.length > 1) {
      chips.add(_ClearAllChip(
        accent: accentColor,
        rs: rs,
        label: l.common_clear,
        onTap: onClearAll,
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
            for (int i = 0; i < chips.length; i++) ...[
              if (i > 0) SizedBox(width: rs.spacing.xs),
              chips[i],
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

class _FilterChip extends StatelessWidget {
  final Color accent;
  final Responsive rs;
  final IconData? icon;
  final String? flag;
  final String label;
  final VoidCallback onRemove;

  const _FilterChip({
    required this.accent,
    required this.rs,
    this.icon,
    this.flag,
    required this.label,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final fontSize = rs.isSmall ? 10.0 : 12.0;
    return GestureDetector(
      onTap: onRemove,
      behavior: HitTestBehavior.opaque,
      child: Container(
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
            const SizedBox(width: 4),
            Icon(
              Icons.close_rounded,
              size: fontSize + 2,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClearAllChip extends StatelessWidget {
  final Color accent;
  final Responsive rs;
  final String label;
  final VoidCallback onTap;

  const _ClearAllChip({
    required this.accent,
    required this.rs,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fontSize = rs.isSmall ? 10.0 : 12.0;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: rs.isSmall ? 8 : 10,
          vertical: rs.isSmall ? 4 : 5,
        ),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}
