import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/responsive/responsive.dart';
import '../providers/app_providers.dart';
import 'control_button.dart';
import 'gamepad_icons.dart';

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
/// [D-pad] [L] [R] [ZL] [ZR] [-] [+] [Y] [X] [B] [A]  [Downloads]
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

    String svg(String id) => GamepadIcons.assetPath(id, layout);

    // Fixed order: dpad, LB, RB, LT, RT, select(-), start(+), Y, X, B, A
    if (dpad != null) {
      buttons.add(ControlButton(
        label: dpad!.label,
        action: dpad!.action,
        svgAsset: svg('dpad'),
      ));
    }
    if (lb != null) {
      buttons.add(ControlButton(
        label: '',
        action: lb!.action,
        onTap: lb!.onTap,
        highlight: lb!.highlight,
        svgAsset: svg('l'),
      ));
    }
    if (rb != null) {
      buttons.add(ControlButton(
        label: '',
        action: rb!.action,
        onTap: rb!.onTap,
        highlight: rb!.highlight,
        svgAsset: svg('r'),
      ));
    }
    if (lt != null) {
      buttons.add(ControlButton(
        label: '',
        action: lt!.action,
        onTap: lt!.onTap,
        highlight: lt!.highlight,
        svgAsset: svg('zl'),
      ));
    }
    if (rt != null) {
      buttons.add(ControlButton(
        label: '',
        action: rt!.action,
        onTap: rt!.onTap,
        highlight: rt!.highlight,
        svgAsset: svg('zr'),
      ));
    }
    if (select != null) {
      buttons.add(ControlButton(
        label: '',
        action: select!.action,
        onTap: select!.onTap,
        highlight: select!.highlight,
        svgAsset: svg('minus'),
      ));
    }
    if (start != null) {
      buttons.add(ControlButton(
        label: '',
        action: start!.action,
        onTap: start!.onTap,
        highlight: start!.highlight,
        svgAsset: svg('plus'),
      ));
    }
    if (displayY != null) {
      buttons.add(ControlButton(
        label: '',
        action: displayY.action,
        onTap: displayY.onTap,
        highlight: displayY.highlight,
        svgAsset: svg('y'),
      ));
    }
    if (displayX != null) {
      buttons.add(ControlButton(
        label: '',
        action: displayX.action,
        onTap: displayX.onTap,
        highlight: displayX.highlight,
        svgAsset: svg('x'),
      ));
    }
    if (displayB != null) {
      buttons.add(ControlButton(
        label: '',
        action: displayB.action,
        onTap: displayB.onTap,
        highlight: displayB.highlight,
        svgAsset: svg('b'),
      ));
    }
    if (displayA != null) {
      buttons.add(ControlButton(
        label: '',
        action: displayA.action,
        onTap: displayA.onTap,
        highlight: displayA.highlight,
        svgAsset: svg('a'),
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
