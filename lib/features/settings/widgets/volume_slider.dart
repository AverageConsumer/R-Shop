import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class VolumeSlider extends StatelessWidget {
  final double volume;
  final bool isSelected;
  final ValueChanged<double>? onChanged;

  const VolumeSlider({
    super.key,
    required this.volume,
    this.isSelected = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const totalBars = 20;
    const barWidth = 6.0;
    const barMargin = 2.0;
    const totalWidth = totalBars * (barWidth + barMargin * 2);
    final activeBars = (volume * totalBars).round();

    Widget slider = Row(
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
          margin: const EdgeInsets.symmetric(horizontal: barMargin),
          width: barWidth,
          height: 24,
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

    if (onChanged != null) {
      slider = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) {
          final newVolume =
              (details.localPosition.dx / totalWidth).clamp(0.0, 1.0);
          onChanged!(newVolume);
        },
        onHorizontalDragUpdate: (details) {
          final newVolume =
              (details.localPosition.dx / totalWidth).clamp(0.0, 1.0);
          onChanged!(newVolume);
        },
        child: slider,
      );
    }

    return slider;
  }
}
