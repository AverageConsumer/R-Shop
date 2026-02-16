import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class VolumeSlider extends StatelessWidget {
  final double volume;
  final bool isSelected;

  const VolumeSlider({
    super.key,
    required this.volume,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    const totalBars = 20;
    final activeBars = (volume * totalBars).round();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(totalBars, (index) {
        final isActive = index < activeBars;
        // Calculate opacity/color based on index for a gradient effect
        final opacity = isActive ? 0.6 + (index / totalBars) * 0.4 : 0.2;
        final color = isSelected
            ? AppTheme.primaryColor.withOpacity(opacity)
            : Colors.white.withOpacity(opacity);

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: 6,
          height: 24, // Fixed height for consistency
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
            boxShadow: isActive && isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.5),
                      blurRadius: 4,
                      spreadRadius: 0,
                    )
                  ]
                : [],
          ),
        );
      }),
    );
  }
}
