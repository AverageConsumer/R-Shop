import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'animated_background.dart';
import 'radial_glow.dart';

class ScreenLayout extends StatelessWidget {
  final Widget body;
  final Color? accentColor;
  final Color? backgroundColor;
  final bool useSafeArea;
  final EdgeInsetsGeometry? padding;
  final Widget? floatingActionButton;

  const ScreenLayout({
    super.key,
    required this.body,
    this.accentColor,
    this.backgroundColor,
    this.useSafeArea = true,
    this.padding,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor ?? AppTheme.backgroundColor,
      body: Stack(
        children: [
          AnimatedBackground(accentColor: accentColor),
          RadialGlow(color: accentColor),
          if (useSafeArea)
            SafeArea(
              child: Padding(
                padding: padding ?? EdgeInsets.zero,
                child: body,
              ),
            )
          else
            Padding(
              padding: padding ?? EdgeInsets.zero,
              child: body,
            ),
        ],
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}
