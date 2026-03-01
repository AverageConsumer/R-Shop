import 'package:flutter/material.dart';

import '../../../core/responsive/responsive.dart';

enum DownloadButtonState { download, adding, delete, installed, unavailable }

class DownloadActionButton extends StatelessWidget {
  final DownloadButtonState state;
  final Color accentColor;
  final int? variantCount;
  final VoidCallback? onTap;

  const DownloadActionButton({
    super.key,
    required this.state,
    required this.accentColor,
    this.variantCount,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final isMulti = variantCount != null && variantCount! > 1;

    final Color bgColor;
    final Color borderColor;
    final Color textColor;
    final IconData icon;
    final String label;

    switch (state) {
      case DownloadButtonState.download:
        bgColor = accentColor.withValues(alpha: 0.2);
        borderColor = accentColor.withValues(alpha: 0.5);
        textColor = accentColor;
        icon = Icons.download_rounded;
        label = 'Download';
      case DownloadButtonState.adding:
        bgColor = accentColor.withValues(alpha: 0.15);
        borderColor = accentColor.withValues(alpha: 0.3);
        textColor = accentColor.withValues(alpha: 0.7);
        icon = Icons.download_rounded;
        label = 'Adding...';
      case DownloadButtonState.delete:
        bgColor = Colors.red.withValues(alpha: 0.12);
        borderColor = Colors.red.withValues(alpha: 0.35);
        textColor = Colors.redAccent;
        icon = Icons.delete_outline_rounded;
        label = 'Delete';
      case DownloadButtonState.installed:
        bgColor = Colors.green.withValues(alpha: 0.1);
        borderColor = Colors.greenAccent.withValues(alpha: 0.3);
        textColor = Colors.greenAccent;
        icon = Icons.check_circle_outline_rounded;
        label = 'Installed';
      case DownloadButtonState.unavailable:
        bgColor = Colors.white.withValues(alpha: 0.04);
        borderColor = Colors.white.withValues(alpha: 0.08);
        textColor = Colors.white.withValues(alpha: 0.3);
        icon = Icons.block_rounded;
        label = 'Unavailable';
    }

    final isDisabled =
        state == DownloadButtonState.adding ||
        state == DownloadButtonState.unavailable;

    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: rs.spacing.md,
          vertical: rs.isSmall ? 12 : 14,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(rs.radius.md),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (state == DownloadButtonState.adding)
              SizedBox(
                width: rs.isSmall ? 16 : 18,
                height: rs.isSmall ? 16 : 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: textColor,
                ),
              )
            else
              Icon(icon, color: textColor, size: rs.isSmall ? 18 : 20),
            SizedBox(width: rs.spacing.sm),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: rs.isSmall ? 14 : 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            if (isMulti && state == DownloadButtonState.download) ...[
              SizedBox(width: rs.spacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$variantCount',
                  style: TextStyle(
                    color: accentColor,
                    fontSize: rs.isSmall ? 10 : 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
