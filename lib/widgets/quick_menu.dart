import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/input/overlay_scope.dart';
import '../core/responsive/responsive.dart';
import '../providers/app_providers.dart';

class QuickMenuItem {
  final String label;
  final IconData icon;
  final String? shortcutHint;
  final VoidCallback onSelect;
  final bool highlight;

  const QuickMenuItem({
    required this.label,
    required this.icon,
    this.shortcutHint,
    required this.onSelect,
    this.highlight = false,
  });
}

class QuickMenuOverlay extends ConsumerStatefulWidget {
  final List<QuickMenuItem?> items;
  final VoidCallback onClose;

  const QuickMenuOverlay({
    super.key,
    required this.items,
    required this.onClose,
  });

  @override
  ConsumerState<QuickMenuOverlay> createState() => _QuickMenuOverlayState();
}

class _QuickMenuOverlayState extends ConsumerState<QuickMenuOverlay>
    with SingleTickerProviderStateMixin {
  int _focusedIndex = 0;
  final FocusNode _menuFocusNode = FocusNode(debugLabel: 'QuickMenu');
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
    _animController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _menuFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _menuFocusNode.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _close() {
    _animController.reverse().then((_) {
      if (mounted) widget.onClose();
    });
  }

  List<int> get _selectableIndices => [
        for (int i = 0; i < widget.items.length; i++)
          if (widget.items[i] != null) i,
      ];

  void _selectItem(int index) {
    if (index < 0 || index >= widget.items.length) return;
    final item = widget.items[index];
    if (item == null) return;
    // Close first, then invoke action after overlay priority releases
    _animController.reverse().then((_) {
      if (!mounted) return;
      widget.onClose();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        item.onSelect();
      });
    });
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;

    // Close: B, Escape, Start
    if (key == LogicalKeyboardKey.gameButtonB ||
        key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.backspace) {
      ref.read(feedbackServiceProvider).cancel();
      _close();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.gameButtonStart) {
      ref.read(feedbackServiceProvider).tick();
      _close();
      return KeyEventResult.handled;
    }

    // Select: A, Enter
    if (key == LogicalKeyboardKey.gameButtonA ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.space) {
      ref.read(feedbackServiceProvider).confirm();
      _selectItem(_focusedIndex);
      return KeyEventResult.handled;
    }

    // Navigate: Up/Down (skip separators)
    if (key == LogicalKeyboardKey.arrowUp) {
      final indices = _selectableIndices;
      final pos = indices.indexOf(_focusedIndex);
      if (pos > 0) {
        setState(() => _focusedIndex = indices[pos - 1]);
        ref.read(feedbackServiceProvider).tick();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      final indices = _selectableIndices;
      final pos = indices.indexOf(_focusedIndex);
      if (pos >= 0 && pos < indices.length - 1) {
        setState(() => _focusedIndex = indices[pos + 1]);
        ref.read(feedbackServiceProvider).tick();
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  /// Swap shortcut hints based on controller layout
  String? _swapHint(String? hint) {
    if (hint == null) return null;
    final layout = ref.watch(controllerLayoutProvider);
    if (layout == ControllerLayout.nintendo) return hint;

    if (layout == ControllerLayout.playstation) {
      return switch (hint) {
        'A' => '✕', 'B' => '○', 'X' => '□', 'Y' => '△',
        'L' => 'L1', 'R' => 'R1', 'ZL' => 'L2', 'ZR' => 'R2',
        _ => hint,
      };
    }
    // Xbox
    return switch (hint) {
      'Y' => 'X', 'X' => 'Y', 'A' => 'B', 'B' => 'A',
      'L' => 'LB', 'R' => 'RB', 'ZL' => 'LT', 'ZR' => 'RT',
      _ => hint,
    };
  }

  /// Returns a tint color for the hint badge based on controller layout.
  /// The original hint (before swap) is the Nintendo label.
  Color? _hintColor(String? originalHint) {
    if (originalHint == null) return null;
    final layout = ref.watch(controllerLayoutProvider);

    if (layout == ControllerLayout.xbox) {
      return switch (originalHint) {
        'A' => const Color(0xFF6DC849),  // green
        'B' => const Color(0xFFE24C3A),  // red
        'X' => const Color(0xFF4C87CB),  // blue
        'Y' => const Color(0xFFF3B735),  // yellow
        _ => null,
      };
    }
    if (layout == ControllerLayout.playstation) {
      return switch (originalHint) {
        'A' => const Color(0xFF6E9FD6),  // ✕ blue
        'B' => const Color(0xFFE8707A),  // ○ pink
        'X' => const Color(0xFFA88BC7),  // □ purple
        'Y' => const Color(0xFF7BC8A4),  // △ green
        _ => null,
      };
    }
    return null; // Nintendo: no special colors
  }

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;

    return OverlayFocusScope(
      priority: OverlayPriority.dialog,
      isVisible: true,
      onClose: _close,
      child: Focus(
        focusNode: _menuFocusNode,
        onKeyEvent: _handleKeyEvent,
        autofocus: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _close,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Stack(
              children: [
                // Semi-transparent backdrop
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.4),
                  ),
                ),
                // Menu panel positioned above HUD
                Positioned(
                  bottom: rs.isPortrait
                      ? rs.safeAreaBottom + 60
                      : rs.spacing.lg + 60,
                  right: rs.isPortrait ? null : rs.spacing.lg,
                  left: rs.isPortrait ? rs.spacing.lg : null,
                  child: rs.isPortrait
                      ? Center(child: _buildPanel(rs))
                      : _buildPanel(rs),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPanel(Responsive rs) {
    return SlideTransition(
      position: _slideAnimation,
      child: GestureDetector(
        onTap: () {}, // Block tap-through to backdrop
        child: Container(
          width: rs.isSmall ? 220 : 260,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(rs.radius.lg),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(rs.radius.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _buildItems(rs),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildItems(Responsive rs) {
    final widgets = <Widget>[];
    for (int i = 0; i < widget.items.length; i++) {
      final item = widget.items[i];
      if (item == null) {
        // Separator
        widgets.add(Padding(
          padding: EdgeInsets.symmetric(vertical: 4, horizontal: rs.spacing.md),
          child: Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.12),
          ),
        ));
      } else {
        if (i > 0 && widget.items[i - 1] != null) {
          widgets.add(Container(
            height: 1,
            margin: EdgeInsets.symmetric(horizontal: rs.spacing.md),
            color: Colors.white.withValues(alpha: 0.06),
          ));
        }
        widgets.add(_buildItem(i, rs));
      }
    }
    return widgets;
  }

  Widget _buildHintBadge(String hint, Color? tint, bool isFocused, Responsive rs) {
    // Face buttons get circles, everything else gets pill shape
    const faceButtons = {'A', 'B', 'X', 'Y', '✕', '○', '△', '□'};
    final isCircle = faceButtons.contains(hint);
    final size = rs.isSmall ? 20.0 : 22.0;
    final fontSize = rs.isSmall ? 10.0 : 11.0;

    final bgColor = tint != null
        ? tint.withValues(alpha: isFocused ? 0.25 : 0.12)
        : Colors.white.withValues(alpha: isFocused ? 0.12 : 0.06);
    final borderColor = tint != null
        ? tint.withValues(alpha: isFocused ? 0.5 : 0.25)
        : Colors.white.withValues(alpha: isFocused ? 0.2 : 0.08);
    final textColor = tint != null
        ? tint.withValues(alpha: isFocused ? 0.9 : 0.6)
        : Colors.white.withValues(alpha: isFocused ? 0.7 : 0.4);

    if (isCircle) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: bgColor,
          border: Border.all(color: borderColor),
          boxShadow: tint != null
              ? [BoxShadow(color: tint.withValues(alpha: 0.15), blurRadius: 4)]
              : null,
        ),
        child: Center(
          child: Text(
            hint,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: textColor,
              height: 1.0,
            ),
          ),
        ),
      );
    }

    // Pill shape for multi-char hints (LB, ZL, L1, etc.)
    return Container(
      height: size,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.35),
        color: bgColor,
        border: Border.all(color: borderColor),
      ),
      child: Center(
        child: Text(
          hint,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: textColor,
            letterSpacing: 0.5,
            height: 1.0,
          ),
        ),
      ),
    );
  }

  Widget _buildItem(int index, Responsive rs) {
    final item = widget.items[index]!;
    final isFocused = _focusedIndex == index;
    final hint = _swapHint(item.shortcutHint);
    final hintTint = _hintColor(item.shortcutHint);
    final accentColor = item.highlight ? Colors.greenAccent : Colors.cyanAccent;

    return GestureDetector(
      onTap: () => _selectItem(index),
      child: MouseRegion(
        onEnter: (_) => setState(() => _focusedIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(
            horizontal: rs.spacing.md,
            vertical: rs.isSmall ? 10 : 12,
          ),
          decoration: BoxDecoration(
            color: isFocused
                ? accentColor.withValues(alpha: 0.12)
                : Colors.transparent,
          ),
          child: Row(
            children: [
              // Focus indicator
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 3,
                height: rs.isSmall ? 18 : 22,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: isFocused
                      ? accentColor
                      : Colors.transparent,
                ),
              ),
              SizedBox(width: rs.spacing.sm),
              // Icon
              Icon(
                item.icon,
                size: rs.isSmall ? 16 : 18,
                color: isFocused
                    ? (item.highlight ? Colors.greenAccent : Colors.white)
                    : (item.highlight
                        ? Colors.greenAccent.withValues(alpha: 0.7)
                        : Colors.white60),
              ),
              SizedBox(width: rs.spacing.sm),
              // Label
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    fontSize: rs.isSmall ? 13 : 14,
                    fontWeight: isFocused ? FontWeight.w600 : FontWeight.w400,
                    color: isFocused
                        ? (item.highlight ? Colors.greenAccent : Colors.white)
                        : (item.highlight
                            ? Colors.greenAccent.withValues(alpha: 0.7)
                            : Colors.white70),
                  ),
                ),
              ),
              // Shortcut hint
              if (hint != null)
                _buildHintBadge(hint, hintTint, isFocused, rs),
            ],
          ),
        ),
      ),
    );
  }
}
