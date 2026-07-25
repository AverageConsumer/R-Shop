import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/responsive/responsive.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/console_focusable.dart';
import '../l10n/app_localizations.dart';

/// A modal dialog designed for gamepad interaction.
///
/// Features:
/// - Maps 'B' button/Escape to cancel.
/// - Maps 'A' button/Enter to confirming the selected action.
/// - Horizontal navigation between Primary and Secondary buttons.
/// - Consistent visual style with the rest of the app.
class ConsoleDialog extends ConsumerStatefulWidget {
  final String title;
  final String message;
  final String? primaryLabel;
  final String? secondaryLabel;
  final bool isDestructive;

  const ConsoleDialog({
    super.key,
    required this.title,
    required this.message,
    this.primaryLabel,
    this.secondaryLabel,
    this.isDestructive = false,
  });

  @override
  ConsumerState<ConsoleDialog> createState() => _ConsoleDialogState();
}

class _ConsoleDialogState extends ConsumerState<ConsoleDialog> {
  final FocusNode _primaryFocus = FocusNode(debugLabel: 'dialog_primary');
  final FocusNode _secondaryFocus = FocusNode(debugLabel: 'dialog_secondary');
  final FocusNode _screenFocus = FocusNode(debugLabel: 'dialog_screen');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _primaryFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _primaryFocus.dispose();
    _secondaryFocus.dispose();
    _screenFocus.dispose();
    super.dispose();
  }

  void _handleBack() {
    Navigator.of(context).pop(false);
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.gameButtonB ||
        key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.backspace) {
      _handleBack();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowLeft) {
      _secondaryFocus.requestFocus();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      _primaryFocus.requestFocus();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final l = L.of(context);

    return Focus(
      focusNode: _screenFocus,
      onKeyEvent: _onKeyEvent,
      autofocus: true,
      child: Container(
        color: Colors.black.withValues(alpha: 0.75),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1C),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.message,
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _DialogButton(
                          focusNode: _secondaryFocus,
                          label: widget.secondaryLabel ?? l.common_cancel,
                          onSelect: () => Navigator.of(context).pop(false),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _DialogButton(
                          focusNode: _primaryFocus,
                          label: widget.primaryLabel ?? l.common_done,
                          isPrimary: true,
                          isDestructive: widget.isDestructive,
                          onSelect: () => Navigator.of(context).pop(true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  final FocusNode focusNode;
  final String label;
  final VoidCallback onSelect;
  final bool isPrimary;
  final bool isDestructive;

  const _DialogButton({
    required this.focusNode,
    required this.label,
    required this.onSelect,
    this.isPrimary = false,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: focusNode,
      builder: (context, child) {
        final isFocused = focusNode.hasFocus;
        final color = isFocused
            ? (isDestructive
                ? Colors.redAccent
                : (isPrimary ? AppTheme.primaryColor : Colors.white))
            : Colors.white60;

        return ConsoleFocusable(
          focusNode: focusNode,
          onSelect: onSelect,
          focusScale: 1.0,
          focusBorderColor: color,
          borderRadius: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Helper to show the gamepad-friendly dialog.
Future<bool?> showConsoleDialog(
  BuildContext context, {
  required String title,
  required String message,
  String? primaryLabel,
  String? secondaryLabel,
  bool isDestructive = false,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (context) => ConsoleDialog(
      title: title,
      message: message,
      primaryLabel: primaryLabel,
      secondaryLabel: secondaryLabel,
      isDestructive: isDestructive,
    ),
  );
}
