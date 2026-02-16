import 'package:flutter/material.dart';
class RadialGlow extends StatelessWidget {
  final Color color;
  const RadialGlow({required this.color, super.key});
  @override
  Widget build(BuildContext context) {
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
                color.withValues(alpha: 0.35),
                color.withValues(alpha: 0.15),
                color.withValues(alpha: 0.05),
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
