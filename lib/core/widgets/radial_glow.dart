import 'package:flutter/material.dart';
import '../responsive/responsive.dart';
import '../theme/app_theme.dart';

class RadialGlow extends StatelessWidget {
  final Color? color;
  final double intensity;
  final Alignment? center;
  final double? radius;

  const RadialGlow({
    super.key,
    this.color,
    this.intensity = 1.0,
    this.center,
    this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final glowColor = color ?? AppTheme.primaryColor;

    final resolvedCenter = center ??
        (rs.isPortrait
            ? const Alignment(0.0, -0.45)
            : const Alignment(0.0, -0.2));
    final resolvedRadius = radius ?? (rs.isPortrait ? 0.85 : 1.0);

    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: resolvedCenter,
              radius: resolvedRadius,
              colors: [
                glowColor.withValues(alpha: 0.35 * intensity),
                glowColor.withValues(alpha: 0.15 * intensity),
                glowColor.withValues(alpha: 0.05 * intensity),
                Colors.transparent,
              ],
              stops: const [0.0, 0.3, 0.6, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}
