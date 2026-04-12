import 'package:flutter/material.dart';
import '../core/responsive/responsive.dart';
import '../l10n/app_localizations.dart';

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

  String _title(L l) {
    return switch (type) {
      ConfirmDialogType.delete => l.confirm_deleteTitle,
      ConfirmDialogType.exitApp => l.confirm_exitTitle,
      ConfirmDialogType.resetApp => l.confirm_resetTitle,
    };
  }

  String _message(L l) {
    return switch (type) {
      ConfirmDialogType.delete => l.confirm_deleteMessage(gameTitle ?? ''),
      ConfirmDialogType.exitApp => l.confirm_exitMessage,
      ConfirmDialogType.resetApp => l.confirm_resetMessage,
    };
  }

  String _primaryLabel(L l) {
    return switch (type) {
      ConfirmDialogType.delete => l.confirm_deleteButton,
      ConfirmDialogType.exitApp => l.confirm_exitButton,
      ConfirmDialogType.resetApp => l.confirm_resetButton,
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
    final l = L.of(context);
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
                _title(l),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: rs.spacing.sm),
              Text(
                _message(l),
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
                  Flexible(
                    child: _DialogButton(
                      label: l.common_cancelUpper,
                      color: Colors.grey,
                      isSelected: selection == 1,
                      onTap: onSecondary,
                      padding: buttonPadding,
                    ),
                  ),
                  SizedBox(width: rs.spacing.md),
                  Flexible(
                    child: _DialogButton(
                      label: _primaryLabel(l),
                    color: _primaryColor,
                    isSelected: selection == 0,
                      onTap: onPrimary,
                      padding: buttonPadding,
                    ),
                  ),
                ],
              ),
              SizedBox(height: rs.spacing.sm),
              Text(
                l.confirm_gamepadHint,
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
