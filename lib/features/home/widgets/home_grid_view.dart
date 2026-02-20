import 'package:flutter/material.dart';
import '../../../core/responsive/responsive.dart';
import '../../../models/system_model.dart';

class HomeGridView extends StatelessWidget {
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
  Widget build(BuildContext context) {
    if (systems.isEmpty) return const SizedBox.shrink();

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
              // Library item
              return RepaintBoundary(
                key: itemKeys[index],
                child: _buildLibraryItem(context, isSelected, index),
              );
            }
            final system = systems[index];
            return RepaintBoundary(
              key: itemKeys[index],
              child: _buildGridItem(context, system, isSelected, index),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLibraryItem(BuildContext context, bool isSelected, int index) {
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

  Widget _buildGridItem(BuildContext context, SystemModel system, bool isSelected, int index) {
    final accentColor = system.accentColor;
    final selectedScale = rs.isSmall ? 1.08 : 1.1;
    final borderSelected = rs.isSmall ? 2.0 : 3.0;
    final borderRadius = rs.isSmall ? 8.0 : 10.0;
    final innerBorderRadius = rs.isSmall ? 6.0 : 8.0;
    final titleFontSize =
        isSelected ? (rs.isSmall ? 11.0 : 13.0) : (rs.isSmall ? 10.0 : 12.0);
    final subFontSize = rs.isSmall ? 8.0 : 10.0;
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
                  child: Image.asset(
                    system.iconAssetPath,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Icon(
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
                        Text(
                          system.name.toUpperCase(),
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
                          '${system.manufacturer} \u00B7 ${system.releaseYear}',
                          style: TextStyle(
                            fontSize: subFontSize,
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
