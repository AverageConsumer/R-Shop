import 'package:flutter/material.dart';
import '../../../core/responsive/responsive.dart';

class LibraryTab {
  final String label;
  final int count;

  const LibraryTab({required this.label, required this.count});
}

class LibraryTabs extends StatelessWidget {
  final int selectedTab;
  final List<LibraryTab> tabs;
  final Color accentColor;
  final ValueChanged<int>? onTap;

  const LibraryTabs({
    super.key,
    required this.selectedTab,
    required this.tabs,
    this.accentColor = Colors.cyanAccent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final fontSize = rs.isSmall ? 10.0 : 12.0;
    final countFontSize = rs.isSmall ? 8.0 : 10.0;
    final hPadding = rs.isSmall ? 10.0 : 14.0;
    final vPadding = rs.isSmall ? 4.0 : 6.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(tabs.length, (i) {
        final tab = tabs[i];
        final isActive = i == selectedTab;

        return Padding(
          padding: EdgeInsets.only(right: i < tabs.length - 1 ? 2.0 : 0.0),
          child: GestureDetector(
            onTap: onTap != null ? () => onTap!(i) : null,
            child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: EdgeInsets.symmetric(
              horizontal: hPadding,
              vertical: vPadding,
            ),
            decoration: BoxDecoration(
              color: isActive
                  ? accentColor.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isActive
                    ? accentColor.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tab.label.toUpperCase(),
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive ? accentColor : Colors.grey[500],
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? accentColor.withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${tab.count}',
                    style: TextStyle(
                      fontSize: countFontSize,
                      fontWeight: FontWeight.w600,
                      color: isActive
                          ? accentColor
                          : Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          ),
          ),
        );
      }),
    );
  }
}
