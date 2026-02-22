import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/responsive/responsive.dart';
import '../providers/app_providers.dart';
import 'control_button.dart';

class HudAction {
  const HudAction(this.action, {this.onTap, this.highlight = false});
  final String action;
  final VoidCallback? onTap;
  final bool highlight;
}

/// Unified floating HUD that displays controller button hints.
///
/// Always sits bottom-right (landscape) or bottom-center (portrait).
/// Set [embedded] to true when used inside a modal (no Positioned wrapper).
///
/// Slots are rendered in fixed Switch-convention order (left to right):
/// [D-pad] [L] [R] [ZL] [ZR] [−] [+] [Y] [X] [B] [A]  [Downloads]
class ConsoleHud extends ConsumerWidget {
  final HudAction? a, b, x, y, start, select, lb, rb, lt, rt;
  final ({String label, String action})? dpad;
  final bool embedded;

  const ConsoleHud({
    super.key,
    this.a,
    this.b,
    this.x,
    this.y,
    this.start,
    this.select,
    this.lb,
    this.rb,
    this.lt,
    this.rt,
    this.dpad,
    this.embedded = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buttons = <Widget>[];
    final layout = ref.watch(controllerLayoutProvider);

    // Xbox and PlayStation swap positions (confirm = bottom, back = right)
    final bool swapPositions = layout != ControllerLayout.nintendo;
    final displayA = swapPositions ? b : a;
    final displayB = swapPositions ? a : b;
    final displayX = swapPositions ? y : x;
    final displayY = swapPositions ? x : y;

    final (labelA, labelB, labelX, labelY) = switch (layout) {
      ControllerLayout.nintendo => ('A', 'B', 'X', 'Y'),
      ControllerLayout.xbox => ('B', 'A', 'Y', 'X'),
      ControllerLayout.playstation => ('', '', '', ''),
    };

    // Xbox face button colors
    const xbGreen = Color(0xFF6DC849);
    const xbRed = Color(0xFFE24C3A);
    const xbBlue = Color(0xFF4C87CB);
    const xbYellow = Color(0xFFF3B735);

    // Per-layout button styling: (colorA, colorB, colorX, colorY, painterA, painterB, painterX, painterY)
    final (Color? colorA, Color? colorB, Color? colorX, Color? colorY,
           CustomPainter? painterA, CustomPainter? painterB,
           CustomPainter? painterX, CustomPainter? painterY) = switch (layout) {
      ControllerLayout.nintendo => (null, null, null, null, null, null, null, null),
      ControllerLayout.xbox => (xbGreen, xbRed, xbBlue, xbYellow, null, null, null, null),
      ControllerLayout.playstation => (
        const Color(0xFFE8707A), const Color(0xFF6E9FD6),
        const Color(0xFF7BC8A4), const Color(0xFFA88BC7),
        const PSCirclePainter(), const PSCrossPainter(),
        const PSTrianglePainter(), const PSSquarePainter(),
      ),
    };

    // Start/Select styling
    final (IconData? iconStart, String labelStart,
           CustomPainter? painterStart) = switch (layout) {
      ControllerLayout.nintendo => (null, '', const NintendoPlusPainter()),
      ControllerLayout.playstation => (Icons.menu_rounded, '', null),
      ControllerLayout.xbox => (Icons.menu_rounded, '', null),
    };

    final (IconData? iconSelect, String labelSelect,
           CustomPainter? painterSelect) = switch (layout) {
      ControllerLayout.nintendo => (null, '', const NintendoMinusPainter()),
      ControllerLayout.playstation => (Icons.share_rounded, '', null),
      ControllerLayout.xbox => (Icons.filter_none, '', null),
    };

    final (labelLB, labelRB, labelLT, labelRT) = switch (layout) {
      ControllerLayout.nintendo => ('L', 'R', 'ZL', 'ZR'),
      ControllerLayout.xbox => ('LB', 'RB', 'LT', 'RT'),
      ControllerLayout.playstation => ('L1', 'R1', 'L2', 'R2'),
    };

    // Fixed order: dpad, LB, RB, select(−), start(+), Y, X, B, A
    if (dpad != null) {
      buttons.add(ControlButton(
        label: dpad!.label,
        action: dpad!.action,
      ));
    }
    if (lb != null) {
      buttons.add(ControlButton(
        label: labelLB,
        action: lb!.action,
        onTap: lb!.onTap,
        highlight: lb!.highlight,
      ));
    }
    if (rb != null) {
      buttons.add(ControlButton(
        label: labelRB,
        action: rb!.action,
        onTap: rb!.onTap,
        highlight: rb!.highlight,
      ));
    }
    if (lt != null) {
      buttons.add(ControlButton(
        label: labelLT,
        action: lt!.action,
        onTap: lt!.onTap,
        highlight: lt!.highlight,
      ));
    }
    if (rt != null) {
      buttons.add(ControlButton(
        label: labelRT,
        action: rt!.action,
        onTap: rt!.onTap,
        highlight: rt!.highlight,
      ));
    }
    if (select != null) {
      buttons.add(ControlButton(
        label: labelSelect,
        icon: iconSelect,
        shapePainter: painterSelect,
        action: select!.action,
        onTap: select!.onTap,
        highlight: select!.highlight,
      ));
    }
    if (start != null) {
      buttons.add(ControlButton(
        label: labelStart,
        icon: iconStart,
        shapePainter: painterStart,
        action: start!.action,
        onTap: start!.onTap,
        highlight: start!.highlight,
      ));
    }
    if (displayY != null) {
      buttons.add(ControlButton(
        label: labelY,
        action: displayY.action,
        onTap: displayY.onTap,
        highlight: displayY.highlight,
        buttonColor: colorY,
        shapePainter: painterY,
      ));
    }
    if (displayX != null) {
      buttons.add(ControlButton(
        label: labelX,
        action: displayX.action,
        onTap: displayX.onTap,
        highlight: displayX.highlight,
        buttonColor: colorX,
        shapePainter: painterX,
      ));
    }
    if (displayB != null) {
      buttons.add(ControlButton(
        label: labelB,
        action: displayB.action,
        onTap: displayB.onTap,
        highlight: displayB.highlight,
        buttonColor: colorB,
        shapePainter: painterB,
      ));
    }
    if (displayA != null) {
      buttons.add(ControlButton(
        label: labelA,
        action: displayA.action,
        onTap: displayA.onTap,
        highlight: displayA.highlight,
        buttonColor: colorA,
        shapePainter: painterA,
      ));
    }

    if (buttons.isEmpty) return const SizedBox.shrink();

    final rs = context.rs;
    final content = _buildContent(rs, buttons);

    if (embedded) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: rs.spacing.lg, vertical: rs.spacing.sm),
        child: Align(
          alignment: rs.isPortrait ? Alignment.center : Alignment.centerRight,
          child: content,
        ),
      );
    }

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

  Widget _buildContent(Responsive rs, List<Widget> buttons) {
    return Material(
      type: MaterialType.transparency,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: rs.isPortrait ? rs.spacing.md : rs.spacing.lg,
          vertical: rs.spacing.sm,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(rs.radius.round),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: _buildWithSpacing(rs, buttons),
        ),
      ),
    );
  }

  List<Widget> _buildWithSpacing(Responsive rs, List<Widget> buttons) {
    final spacing = rs.isSmall ? rs.spacing.sm : rs.spacing.md;
    final result = <Widget>[];
    for (var i = 0; i < buttons.length; i++) {
      if (i > 0) result.add(SizedBox(width: spacing));
      result.add(buttons[i]);
    }
    return result;
  }
}
