import 'dart:ui';
import 'package:flutter/material.dart';

class GlassOverlay extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final Color tint;

  const GlassOverlay({
    super.key,
    required this.child,
    this.blur = 10.0,
    this.opacity = 0.2,
    this.tint = Colors.black,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            color: tint.withOpacity(opacity),
          ),
          child: child,
        ),
      ),
    );
  }
}
