import 'package:flutter/material.dart';
import '../core/responsive/responsive.dart';

class ControlButton extends StatelessWidget {
  static int _lastTapTime = 0;
  static const int _tapCooldownMs = 300;

  final String label;
  final String action;
  final VoidCallback? onTap;
  final bool highlight;
  final IconData? icon;

  const ControlButton({
    super.key,
    required this.label,
    required this.action,
    this.onTap,
    this.highlight = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final buttonSize = rs.isSmall ? 24.0 : (rs.isMedium ? 28.0 : 32.0);
    final fontSize = rs.isSmall ? 10.0 : (rs.isMedium ? 12.0 : 13.0);
    final actionFontSize = rs.isSmall ? 10.0 : (rs.isMedium ? 12.0 : 13.0);
    final iconSize = rs.isSmall ? 14.0 : (rs.isMedium ? 16.0 : 18.0);
    final spacing = rs.spacing.sm;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: buttonSize,
          height: buttonSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: highlight
                ? Colors.redAccent.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.08),
            border: Border.all(
              color: highlight
                  ? Colors.redAccent.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Center(
            child: icon != null
                ? Icon(icon,
                    size: iconSize,
                    color: highlight ? Colors.redAccent : Colors.white70)
                : Text(
                    label,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                      color: highlight ? Colors.redAccent : Colors.white70,
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
                : Colors.white.withValues(alpha: 0.5),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap == null ? null : () {
          final now = DateTime.now().millisecondsSinceEpoch;
          if (now - _lastTapTime < _tapCooldownMs) return;
          _lastTapTime = now;
          onTap!();
        },
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

