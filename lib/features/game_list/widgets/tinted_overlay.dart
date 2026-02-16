import 'package:flutter/material.dart';

class TintedOverlay extends StatelessWidget {
  final Color accentColor;

  const TintedOverlay({
    super.key,
    this.accentColor = Colors.black,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor.withValues(alpha: 0.25),
            Colors.black.withValues(alpha: 0.6),
            Colors.black.withValues(alpha: 0.85),
            Colors.black,
          ],
          stops: const [0.0, 0.3, 0.6, 1.0],
        ),
      ),
    );
  }
}
