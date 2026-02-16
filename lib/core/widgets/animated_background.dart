import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AnimatedBackground extends StatelessWidget {
  final Color? accentColor;
  
  const AnimatedBackground({
    super.key, 
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? AppTheme.primaryColor;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.25),
            color.withValues(alpha: 0.12),
            const Color(0xFF080808),
            const Color(0xFF030303),
            AppTheme.backgroundColor,
          ],
          stops: const [0.0, 0.15, 0.35, 0.6, 1.0],
        ),
      ),
    );
  }
}
