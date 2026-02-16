import 'package:flutter/material.dart';
class AnimatedBackground extends StatelessWidget {
  final Color accentColor;
  const AnimatedBackground({required this.accentColor, super.key});
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor.withValues(alpha: 0.25),
            accentColor.withValues(alpha: 0.12),
            const Color(0xFF080808),
            const Color(0xFF030303),
            Colors.black,
          ],
          stops: const [0.0, 0.15, 0.35, 0.6, 1.0],
        ),
      ),
    );
  }
}
