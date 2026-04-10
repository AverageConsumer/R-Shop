import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/responsive/responsive.dart';
import '../../../models/system_model.dart';
import '../../../providers/game_providers.dart';

class HomeGridView extends ConsumerWidget {
  final List<SystemModel> systems;
  final int selectedIndex;
  final int columns;
  final ScrollController? scrollController;
  final Map<int, GlobalKey> itemKeys;
  final Function(int) onSelect;
  final VoidCallback onConfirm;
  final Responsive rs;

  const HomeGridView({
    super.key,
    required this.systems,
    required this.selectedIndex,
    required this.columns,
    this.scrollController,
    this.itemKeys = const {},
    required this.onSelect,
    required this.onConfirm,
    required this.rs,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (systems.isEmpty) return const SizedBox.shrink();

    final sourceCounts = ref.watch(systemSourceCountsProvider).valueOrNull;
    final spacing = rs.isSmall ? 16.0 : 24.0;
    final horizontalPadding = rs.isSmall ? 24.0 : 48.0;
    final bottomPadding = rs.isSmall ? 80.0 : 90.0;
    final totalItems = systems.length + 1; // +1 for library item

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: GridView.builder(
          controller: scrollController,
          padding: EdgeInsets.only(
            left: horizontalPadding,
            right: horizontalPadding,
            top: rs.safeAreaTop + 40.0,
            bottom: bottomPadding,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            childAspectRatio: 1.0,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
          ),
          itemCount: totalItems,
          itemBuilder: (context, index) {
            final isSelected = index == selectedIndex;
            if (index == systems.length) {
              // Library item — sum all system counts
              int totalRemote = 0;
              int totalLocal = 0;
              if (sourceCounts != null) {
                for (final c in sourceCounts.values) {
                  totalRemote += c.remote;
                  totalLocal += c.local;
                }
              }
              return RepaintBoundary(
                key: itemKeys[index],
                child: _buildLibraryItem(context, isSelected, index,
                    totalRemote: totalRemote, totalLocal: totalLocal),
              );
            }
            final system = systems[index];
            final counts = sourceCounts?[system.id];
            return RepaintBoundary(
              key: itemKeys[index],
              child: _buildGridItem(context, system, isSelected, index, counts),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLibraryItem(BuildContext context, bool isSelected, int index,
      {required int totalRemote, required int totalLocal}) {
    const accentColor = Colors.cyanAccent;
    final selectedScale = rs.isSmall ? 1.08 : 1.1;
    final borderSelected = rs.isSmall ? 2.0 : 3.0;
    final borderRadius = rs.isSmall ? 8.0 : 10.0;
    final innerBorderRadius = rs.isSmall ? 6.0 : 8.0;
    final titleFontSize =
        isSelected ? (rs.isSmall ? 11.0 : 13.0) : (rs.isSmall ? 10.0 : 12.0);
    final subFontSize = rs.isSmall ? 8.0 : 10.0;
    final padding = rs.isSmall ? 6.0 : 8.0;
    final iconSize = rs.isSmall ? 48.0 : 64.0;

    return GestureDetector(
      onTap: () {
        if (isSelected) {
          onConfirm();
        } else {
          onSelect(index);
        }
      },
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
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF0A1628),
                        Color(0xFF0F0F0F),
                      ],
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.library_books_rounded,
                      size: iconSize,
                      color: accentColor.withValues(alpha: 0.6),
                    ),
                  ),
                ),
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
                        if (totalRemote > 0 || totalLocal > 0)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (totalRemote > 0) _GridCountPill(
                                  icon: Icons.cloud_outlined,
                                  count: totalRemote,
                                  color: accentColor,
                                  isSmall: rs.isSmall,
                                ),
                                if (totalRemote > 0 && totalLocal > 0)
                                  const SizedBox(width: 4),
                                if (totalLocal > 0) _GridCountPill(
                                  icon: Icons.folder_outlined,
                                  count: totalLocal,
                                  color: accentColor,
                                  isSmall: rs.isSmall,
                                ),
                              ],
                            ),
                          ),
                        Text(
                          'ALL GAMES',
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
                        Text(
                          'Library',
                          style: TextStyle(
                            fontSize: subFontSize,
                            color: accentColor.withValues(alpha: 0.7),
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
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            accentColor,
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
  }

  Widget _buildGridItem(BuildContext context, SystemModel system, bool isSelected, int index,
      ({int remote, int local})? counts) {
    final accentColor = system.accentColor;
    final selectedScale = rs.isSmall ? 1.08 : 1.1;
    final borderSelected = rs.isSmall ? 2.0 : 3.0;
    final borderRadius = rs.isSmall ? 8.0 : 10.0;
    final innerBorderRadius = rs.isSmall ? 6.0 : 8.0;
    final padding = rs.isSmall ? 6.0 : 8.0;

    return GestureDetector(
      onTap: () {
        if (isSelected) {
          onConfirm();
        } else {
          onSelect(index);
        }
      },
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
                  padding: EdgeInsets.all(rs.isSmall ? 20.0 : 28.0),
                  child: SvgPicture.asset(
                    system.iconAssetPath,
                    fit: BoxFit.contain,
                    colorFilter: ColorFilter.mode(system.iconColor, BlendMode.srcIn),
                    placeholderBuilder: (_) => Icon(
                      Icons.gamepad,
                      size: 48,
                      color: Colors.grey.withValues(alpha: 0.3),
                    ),
                  ),
                ),
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
                        if (counts != null && (counts.remote > 0 || counts.local > 0))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (counts.remote > 0) _GridCountPill(
                                  icon: Icons.cloud_outlined,
                                  count: counts.remote,
                                  color: system.textAccentColor,
                                  isSmall: rs.isSmall,
                                ),
                                if (counts.remote > 0 && counts.local > 0)
                                  const SizedBox(width: 4),
                                if (counts.local > 0) _GridCountPill(
                                  icon: Icons.folder_outlined,
                                  count: counts.local,
                                  color: system.textAccentColor,
                                  isSmall: rs.isSmall,
                                ),
                              ],
                            ),
                          ),
                        Text(
                          '${system.manufacturer} \u00B7 ${system.releaseYear}',
                          style: TextStyle(
                            fontSize: rs.isSmall ? 8.0 : 10.0,
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
  }
}

class _GridCountPill extends StatelessWidget {
  final IconData icon;
  final int count;
  final Color color;
  final bool isSmall;

  const _GridCountPill({
    required this.icon,
    required this.count,
    required this.color,
    required this.isSmall,
  });

  @override
  Widget build(BuildContext context) {
    final iconSize = isSmall ? 8.0 : 9.0;
    final fontSize = isSmall ? 7.0 : 8.0;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 5 : 6,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: Color.lerp(Colors.black, color, 0.25)!.withValues(alpha: 0.80),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.60), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: color),
          const SizedBox(width: 2),
          Text(
            '$count',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
