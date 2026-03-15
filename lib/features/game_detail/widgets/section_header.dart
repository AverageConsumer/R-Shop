import 'package:flutter/material.dart';

import '../../../core/responsive/responsive.dart';

class SectionHeader extends StatelessWidget {
  final String label;

  const SectionHeader({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;

    return Padding(
      padding: EdgeInsets.only(
        top: rs.spacing.md,
        bottom: rs.spacing.sm,
        left: rs.spacing.xs,
      ),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: rs.isSmall ? 10 : 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
          SizedBox(width: rs.spacing.md),
          Expanded(
            child: Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.06),
            ),
          ),
        ],
      ),
    );
  }
}
