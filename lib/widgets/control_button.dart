import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/responsive/responsive.dart';

class ControlButton extends StatelessWidget {
  final String label;
  final String action;
  final VoidCallback? onTap;
  final bool highlight;
  final IconData? icon;
  final Color? buttonColor;
  final Color? labelColor;
  final String? svgAsset;

  const ControlButton({
    super.key,
    required this.label,
    required this.action,
    this.onTap,
    this.highlight = false,
    this.icon,
    this.buttonColor,
    this.labelColor,
    this.svgAsset,
  });

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final buttonSize = rs.isSmall ? 24.0 : (rs.isMedium ? 28.0 : 32.0);
    final fontSize = rs.isSmall ? 10.0 : (rs.isMedium ? 12.0 : 13.0);
    final actionFontSize = rs.isSmall ? 10.0 : (rs.isMedium ? 12.0 : 13.0);
    final iconSize = rs.isSmall ? 14.0 : (rs.isMedium ? 16.0 : 18.0);
    final spacing = rs.spacing.sm;

    // SVG rendering: no container decoration, just the icon + action text
    if (svgAsset != null) {
      final svgSize = buttonSize;

      final svgWidget = SvgPicture.asset(
        svgAsset!,
        width: svgSize,
        height: svgSize,
      );

      final content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (highlight)
            Container(
              width: svgSize + 4,
              height: svgSize + 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.redAccent.withValues(alpha: 0.7),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.redAccent.withValues(alpha: 0.3),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Center(child: svgWidget),
            )
          else
            svgWidget,
          SizedBox(width: spacing),
          Text(
            action,
            style: TextStyle(
              fontSize: actionFontSize,
              color: highlight
                  ? Colors.redAccent.withValues(alpha: 0.7)
                  : Colors.white.withValues(alpha: 0.7),
              letterSpacing: 0.5,
            ),
          ),
        ],
      );

      if (onTap == null) return content;

      return Material(
        color: Colors.transparent,
        child: InkWell(
          canRequestFocus: false,
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          splashColor: Colors.white.withValues(alpha: 0.1),
          highlightColor: Colors.white.withValues(alpha: 0.05),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: rs.spacing.sm,
              vertical: rs.spacing.xs,
            ),
            child: content,
          ),
        ),
      );
    }

    // Legacy fallback: label/icon-based rendering
    final effectiveColor = highlight ? Colors.redAccent : buttonColor;
    final effectiveLabelColor =
        highlight ? Colors.redAccent : (labelColor ?? Colors.white);

    const faceButtons = {'A', 'B', 'X', 'Y'};
    final usePill = !faceButtons.contains(label) && icon == null;
    final pillWidth = usePill ? buttonSize * 1.5 : buttonSize;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: pillWidth,
          height: buttonSize,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(usePill ? buttonSize * 0.35 : buttonSize),
            color: effectiveColor != null
                ? effectiveColor.withValues(alpha: 0.25)
                : Colors.white.withValues(alpha: 0.12),
            border: Border.all(
              color: effectiveColor != null
                  ? effectiveColor.withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.3),
              width: 1,
            ),
            boxShadow: effectiveColor != null && !highlight
                ? [
                    BoxShadow(
                      color: effectiveColor.withValues(alpha: 0.2),
                      blurRadius: 6,
                      spreadRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: icon != null
                ? Icon(icon,
                    size: iconSize, color: effectiveLabelColor)
                : Text(
                    label,
                    style: TextStyle(
                      fontSize: usePill ? fontSize * 0.9 : fontSize,
                      fontWeight: FontWeight.bold,
                      color: effectiveLabelColor,
                    ),
                  ),
          ),
        ),
        SizedBox(width: spacing),
        Text(
          action,
          style: TextStyle(
            fontSize: actionFontSize,
            color: highlight
                ? Colors.redAccent.withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.7),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        canRequestFocus: false,
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        splashColor: Colors.white.withValues(alpha: 0.1),
        highlightColor: Colors.white.withValues(alpha: 0.05),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: rs.spacing.sm,
            vertical: rs.spacing.xs,
          ),
          child: content,
        ),
      ),
    );
  }
}
