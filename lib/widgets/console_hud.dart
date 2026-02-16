import 'package:flutter/material.dart';
import '../core/responsive/responsive.dart';

export 'control_button.dart' show ControlButton;

/// Unified floating HUD that displays controller button hints.
///
/// Always sits bottom-right (landscape) or bottom-center (portrait).
/// Set [embedded] to true when used inside a modal (no Positioned wrapper).
class ConsoleHud extends StatelessWidget {
  final List<Widget> buttons;
  final bool embedded;

  const ConsoleHud({
    super.key,
    required this.buttons,
    this.embedded = false,
  });

  @override
  Widget build(BuildContext context) {
    if (buttons.isEmpty) return const SizedBox.shrink();

    final rs = context.rs;
    final content = _buildContent(rs);

    if (embedded) return Center(child: content);

    if (rs.isPortrait) {
      return Positioned(
        bottom: rs.safeAreaBottom + rs.spacing.sm,
        left: 0,
        right: 0,
        child: Center(child: content),
      );
    }

    return Positioned(
      bottom: rs.spacing.lg,
      right: rs.spacing.lg,
      child: content,
    );
  }

  Widget _buildContent(Responsive rs) {
    return Material(
      type: MaterialType.transparency,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: rs.isPortrait ? rs.spacing.md : rs.spacing.lg,
          vertical: rs.spacing.sm,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(rs.radius.round),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: _buildWithSpacing(rs),
        ),
      ),
    );
  }

  List<Widget> _buildWithSpacing(Responsive rs) {
    final spacing = rs.isSmall ? rs.spacing.sm : rs.spacing.md;
    final result = <Widget>[];
    for (var i = 0; i < buttons.length; i++) {
      if (i > 0) result.add(SizedBox(width: spacing));
      result.add(buttons[i]);
    }
    return result;
  }
}
