import 'package:flutter/material.dart';
import '../core/responsive/responsive.dart';

enum ConfirmDialogType { delete, exitApp, resetApp }

class ConfirmDialog extends StatelessWidget {
  final ConfirmDialogType type;
  final int selection;
  final String? gameTitle;
  final VoidCallback onPrimary;
  final VoidCallback onSecondary;

  const ConfirmDialog({
    super.key,
    required this.type,
    required this.selection,
    this.gameTitle,
    required this.onPrimary,
    required this.onSecondary,
  });

  String get _title {
    return switch (type) {
      ConfirmDialogType.delete => 'Delete ROM?',
      ConfirmDialogType.exitApp => 'Exit App?',
      ConfirmDialogType.resetApp => 'Reset App?',
    };
  }

  String get _message {
    return switch (type) {
      ConfirmDialogType.delete =>
        'Do you really want to delete this version of $gameTitle?',
      ConfirmDialogType.exitApp => 'Do you really want to exit Retro eShop?',
      ConfirmDialogType.resetApp => 'This will return to the onboarding screen.',
    };
  }

  String get _primaryLabel {
    return switch (type) {
      ConfirmDialogType.delete => 'DELETE',
      ConfirmDialogType.exitApp => 'EXIT',
      ConfirmDialogType.resetApp => 'RESET',
    };
  }

  Color get _primaryColor {
    return switch (type) {
      ConfirmDialogType.delete => Colors.redAccent,
      ConfirmDialogType.exitApp => Colors.orange,
      ConfirmDialogType.resetApp => Colors.red,
    };
  }

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final titleFontSize = rs.isSmall ? 18.0 : rs.typography.titleSmall;
    final messageFontSize = rs.isSmall ? 13.0 : rs.typography.bodySmall;
    final dialogPadding = rs.isSmall ? rs.spacing.md : rs.spacing.lg;
    final buttonPadding = rs.isSmall
        ? const EdgeInsets.symmetric(horizontal: 16, vertical: 10)
        : const EdgeInsets.symmetric(horizontal: 24, vertical: 12);

    return Container(
      color: Colors.black.withValues(alpha: 0.7),
      child: Center(
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: rs.spacing.xl),
          padding: EdgeInsets.all(dialogPadding),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(rs.radius.lg),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: rs.spacing.sm),
              Text(
                _message,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: messageFontSize,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: rs.spacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _DialogButton(
                    label: 'CANCEL',
                    color: Colors.grey,
                    isSelected: selection == 1,
                    onTap: onSecondary,
                    padding: buttonPadding,
                  ),
                  SizedBox(width: rs.spacing.md),
                  _DialogButton(
                    label: _primaryLabel,
                    color: _primaryColor,
                    isSelected: selection == 0,
                    onTap: onPrimary,
                    padding: buttonPadding,
                  ),
                ],
              ),
              SizedBox(height: rs.spacing.sm),
              Text(
                '← → Select   A Confirm   B Cancel',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: rs.typography.caption,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;
  final EdgeInsets padding;

  const _DialogButton({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
    required this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final fontSize = rs.isSmall ? 12.0 : rs.typography.bodySmall;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: padding,
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(rs.radius.md),
          border: Border.all(
            color: isSelected ? color : color.withValues(alpha: 0.5),
            width: 2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : color,
            fontWeight: FontWeight.bold,
            fontSize: fontSize,
          ),
        ),
      ),
    );
  }
}
