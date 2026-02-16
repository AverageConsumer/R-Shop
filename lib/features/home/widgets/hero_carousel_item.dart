import 'package:flutter/material.dart';
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
    ? (rs.isSmall ? rs.screenHeight * 0.25 : rs.screenHeight * 0.32)
    : (rs.isSmall ? rs.screenHeight * 0.4 : rs.screenHeight * 0.5);
    final accentColor = system.accentColor;
    final borderRadius = rs.isSmall ? 24.0 : 32.0;
    final innerBorderRadius = rs.isSmall ? 22.0 : 30.0;
    final padding = rs.isSmall ? 16.0 : 24.0;
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
              child: AspectRatio(
                aspectRatio: 1.0,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  margin: EdgeInsets.symmetric(horizontal: rs.spacing.md),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(borderRadius),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF1A1A1A),
                        Color(0xFF0F0F0F),
                      ],
                    ),
                    boxShadow: isSelected
                    ? [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.6),
                        blurRadius: rs.isSmall ? 30 : 60,
                        spreadRadius: rs.isSmall ? 5 : 10,
                      ),
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.4),
                        blurRadius: rs.isSmall ? 50 : 100,
                        spreadRadius: rs.isSmall ? 10 : 20,
                      ),
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.2),
                        blurRadius: rs.isSmall ? 75 : 150,
                        spreadRadius: rs.isSmall ? 20 : 40,
                      ),
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.1),
                        blurRadius: 30,
                        spreadRadius: 0,
                      ),
                    ]
                    : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.6),
                        blurRadius: 25,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(innerBorderRadius),
                    child: Stack(
                      children: [
                        if (isSelected)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: RadialGradient(
                                  center: Alignment.center,
                                  radius: 0.7,
                                  colors: [
                                    accentColor.withValues(alpha: 0.15),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.all(padding),
                            child: Image.asset(
                              system.iconAssetPath,
                              fit: BoxFit.contain,
                              cacheWidth: 256,
                              errorBuilder: (context, error, stackTrace) => Icon(
                                Icons.gamepad,
                                size: iconSize * 0.4,
                                color: Colors.grey.withValues(alpha: 0.3),
                              ),
                            ),
                          ),
                          if (isSelected)
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                height: rs.isSmall ? 1.5 : 2,
                                decoration: BoxDecoration(
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
            ),
          ),
        ),
      ),
    );
  }
}
