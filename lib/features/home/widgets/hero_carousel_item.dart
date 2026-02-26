import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/responsive/responsive.dart';
import '../../../models/system_model.dart';
class HeroCarouselItem extends StatelessWidget {
  final SystemModel system;
  final double scale;
  final double opacity;
  final bool isSelected;
  final Responsive rs;
  final VoidCallback onTap;
  const HeroCarouselItem({
    required this.system,
    required this.scale,
    required this.opacity,
    required this.isSelected,
    required this.rs,
    required this.onTap,
    super.key,
  });
  @override
  Widget build(BuildContext context) {

    final iconSize = rs.isPortrait
    ? (rs.isSmall ? rs.screenHeight * 0.30 : rs.screenHeight * 0.38)
    : (rs.isSmall ? rs.screenHeight * 0.50 : rs.screenHeight * 0.60);
    final accentColor = system.accentColor;
    final padding = rs.isSmall ? 8.0 : 12.0;
    return GestureDetector(
      onTap: onTap,
      child: Center(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: opacity,
          child: AnimatedScale(
            scale: scale,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: SizedBox(
              height: iconSize,
              width: iconSize,
              child: Stack(
                children: [
                  if (isSelected)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment.center,
                            radius: 0.55,
                            colors: [
                              accentColor.withValues(alpha: 0.35),
                              accentColor.withValues(alpha: 0.1),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Padding(
                        padding: EdgeInsets.all(padding),
                        child: SvgPicture.asset(
                          system.iconAssetPath,
                          fit: BoxFit.contain,
                          colorFilter: ColorFilter.mode(system.iconColor, BlendMode.srcIn),
                          placeholderBuilder: (_) => Icon(
                            Icons.gamepad,
                            size: iconSize * 0.4,
                            color: Colors.grey.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HeroLibraryCarouselItem extends StatelessWidget {
  final double scale;
  final double opacity;
  final bool isSelected;
  final Responsive rs;
  final VoidCallback onTap;

  const HeroLibraryCarouselItem({
    required this.scale,
    required this.opacity,
    required this.isSelected,
    required this.rs,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final iconSize = rs.isPortrait
        ? (rs.isSmall ? rs.screenHeight * 0.30 : rs.screenHeight * 0.38)
        : (rs.isSmall ? rs.screenHeight * 0.50 : rs.screenHeight * 0.60);
    const accentColor = Colors.cyanAccent;
    final padding = rs.isSmall ? 8.0 : 12.0;

    return GestureDetector(
      onTap: onTap,
      child: Center(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: opacity,
          child: AnimatedScale(
            scale: scale,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: SizedBox(
              height: iconSize,
              width: iconSize,
              child: Stack(
                children: [
                  if (isSelected)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment.center,
                            radius: 0.55,
                            colors: [
                              accentColor.withValues(alpha: 0.35),
                              accentColor.withValues(alpha: 0.1),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                    ),
                  Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.all(padding),
                      child: Center(
                        child: Icon(
                          Icons.library_books_rounded,
                          size: iconSize * 0.45,
                          color: accentColor.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
