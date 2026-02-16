import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class RadialGlow extends StatelessWidget {
  final Color? color;
  
  const RadialGlow({
    super.key, 
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final glowColor = color ?? AppTheme.primaryColor;
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0.0, -0.2),
              radius: 1.0,
              colors: [
                glowColor.withValues(alpha: 0.35),
                glowColor.withValues(alpha: 0.15),
                glowColor.withValues(alpha: 0.05),
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
