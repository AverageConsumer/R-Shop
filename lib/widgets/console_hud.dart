import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/responsive/responsive.dart';
import '../providers/download_providers.dart';
import 'control_button.dart';
import 'download_overlay.dart';

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
/// [D-pad] [−] [+] [Y] [X] [B] [A]  [Downloads]
class ConsoleHud extends ConsumerWidget {
  final HudAction? a, b, x, y, start, select;
  final ({String label, String action})? dpad;
  final bool showDownloads;
  final bool embedded;

  const ConsoleHud({
    super.key,
    this.a,
    this.b,
    this.x,
    this.y,
    this.start,
    this.select,
    this.dpad,
    this.showDownloads = true,
    this.embedded = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buttons = <Widget>[];

    // Fixed order: dpad, select(−), start(+), Y, X, B, A
    if (dpad != null) {
      buttons.add(ControlButton(
        label: dpad!.label,
        action: dpad!.action,
      ));
    }
    if (select != null) {
      buttons.add(ControlButton(
        label: '\u2212',
        action: select!.action,
        onTap: select!.onTap,
        highlight: select!.highlight,
      ));
    }
    if (start != null) {
      buttons.add(ControlButton(
        label: '+',
        action: start!.action,
        onTap: start!.onTap,
        highlight: start!.highlight,
      ));
    }
    if (y != null) {
      buttons.add(ControlButton(
        label: 'Y',
        action: y!.action,
        onTap: y!.onTap,
        highlight: y!.highlight,
      ));
    }
    if (x != null) {
      buttons.add(ControlButton(
        label: 'X',
        action: x!.action,
        onTap: x!.onTap,
        highlight: x!.highlight,
      ));
    }
    if (b != null) {
      buttons.add(ControlButton(
        label: 'B',
        action: b!.action,
        onTap: b!.onTap,
        highlight: b!.highlight,
      ));
    }
    if (a != null) {
      buttons.add(ControlButton(
        label: 'A',
        action: a!.action,
        onTap: a!.onTap,
        highlight: a!.highlight,
      ));
    }

    // Auto-inject downloads button
    if (showDownloads && ref.watch(downloadCountProvider) > 0) {
      buttons.add(ControlButton(
        label: '',
        action: 'Downloads',
        icon: Icons.play_arrow_rounded,
        highlight: true,
        onTap: () => toggleDownloadOverlay(ref),
      ));
    }

    if (buttons.isEmpty) return const SizedBox.shrink();

    final rs = context.rs;
    final content = _buildContent(rs, buttons);

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

  Widget _buildContent(Responsive rs, List<Widget> buttons) {
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
