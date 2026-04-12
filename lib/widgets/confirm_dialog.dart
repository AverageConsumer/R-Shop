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

  IconData get _icon {
    return switch (type) {
      ConfirmDialogType.delete => Icons.delete_outline_rounded,
      ConfirmDialogType.exitApp => Icons.power_settings_new_rounded,
      ConfirmDialogType.resetApp => Icons.restart_alt_rounded,
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

    return Container(
      color: Colors.black.withValues(alpha: 0.7),
      child: Center(
        child: Container(
          width: (rs.isSmall ? 300.0 : 400.0).clamp(0, rs.screenWidth * 0.85),
          padding: EdgeInsets.all(rs.isSmall ? 24 : 32),
          decoration: BoxDecoration(
            color: const Color(0xFF141414),
            borderRadius: BorderRadius.circular(rs.radius.lg),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 40,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: rs.isSmall ? 48 : 56,
                height: rs.isSmall ? 48 : 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _primaryColor.withValues(alpha: 0.1),
                  border: Border.all(
                    color: _primaryColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Icon(
                  _icon,
                  size: rs.isSmall ? 24 : 28,
                  color: _primaryColor.withValues(alpha: 0.8),
                ),
              ),
              SizedBox(height: rs.isSmall ? 14 : 18),
              // Title
              Text(
                _title(l),
                style: TextStyle(
                  fontSize: rs.isSmall ? 16 : 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: rs.spacing.sm),
              // Message
              Text(
                _message(l),
                style: TextStyle(
                  fontSize: rs.isSmall ? 12 : 14,
                  color: Colors.white.withValues(alpha: 0.5),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: rs.isSmall ? 18 : 24),
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: _ConfirmButton(
                      label: l.common_cancelUpper,
                      isSelected: selection == 1,
                      isDestructive: false,
                      isSmall: rs.isSmall,
                      onTap: onSecondary,
                    ),
                  ),
                  SizedBox(width: rs.isSmall ? 10 : 14),
                  Expanded(
                    child: _ConfirmButton(
                      label: _primaryLabel(l),
                      isSelected: selection == 0,
                      isDestructive: true,
                      destructiveColor: _primaryColor,
                      isSmall: rs.isSmall,
                      onTap: onPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfirmButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isDestructive;
  final Color? destructiveColor;
  final bool isSmall;
  final VoidCallback onTap;

  const _ConfirmButton({
    required this.label,
    required this.isSelected,
    required this.isDestructive,
    this.destructiveColor,
    required this.isSmall,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? (destructiveColor ?? Colors.redAccent) : Colors.white;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(vertical: isSmall ? 10 : 12),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDestructive
                  ? color.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.08))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? (isDestructive
                    ? color.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.3))
                : Colors.white.withValues(alpha: 0.08),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: (isDestructive ? color : Colors.white)
                        .withValues(alpha: 0.15),
                    blurRadius: 12,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? color : Colors.white.withValues(alpha: 0.4),
            fontSize: isSmall ? 13 : 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}
