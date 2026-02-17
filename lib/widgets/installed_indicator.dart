import 'package:flutter/material.dart';

import '../core/responsive/responsive.dart';

/// Green LED strip at the bottom edge — like a console power indicator.
class InstalledLedStrip extends StatelessWidget {
  final BorderRadius? borderRadius;

  const InstalledLedStrip({super.key, this.borderRadius});

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final height = rs.isSmall ? 2.5 : 3.5;

    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: const LinearGradient(
          colors: [
            Colors.transparent,
            Colors.greenAccent,
            Colors.transparent,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.greenAccent.withValues(alpha: 0.6),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
    );
  }
}

/// "INSTALLED" badge with check icon — retro monospace style.
class InstalledBadge extends StatelessWidget {
  final bool compact;

  const InstalledBadge({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final iconSize = compact ? 10.0 : 14.0;
    final fontSize = compact ? 7.0 : 10.0;
    final hPad = compact ? 4.0 : 6.0;
    final vPad = compact ? 2.0 : 3.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: Colors.greenAccent.withValues(alpha: 0.6),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.greenAccent.withValues(alpha: 0.25),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle,
            color: Colors.greenAccent,
            size: iconSize,
          ),
          SizedBox(width: compact ? 3 : 4),
          Text(
            'INSTALLED',
            style: TextStyle(
              color: Colors.greenAccent,
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
