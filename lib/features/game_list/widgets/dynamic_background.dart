import 'package:flutter/material.dart';

class DynamicBackground extends StatelessWidget {
  final Color accentColor;

  const DynamicBackground({super.key, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor.withValues(alpha: 0.3),
            accentColor.withValues(alpha: 0.1),
            const Color(0xFF0A0A0A),
            Colors.black,
          ],
          stops: const [0.0, 0.2, 0.5, 1.0],
        ),
      ),
    );
  }
}
