import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/input/overlay_scope.dart';
import '../core/responsive/responsive.dart';
import '../providers/app_providers.dart';
import 'gamepad_icons.dart';

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

  /// Maps a Nintendo-convention hint label to a gamepad button ID for SVG lookup.
  static const _hintToButtonId = {
    'A': 'a', 'B': 'b', 'X': 'x', 'Y': 'y',
    'L': 'l', 'R': 'r', 'ZL': 'zl', 'ZR': 'zr',
  };

  /// Returns the SVG asset path for a shortcut hint, or null if no SVG available.
  String? _hintSvgPath(String? hint) {
    if (hint == null) return null;
    final buttonId = _hintToButtonId[hint];
    if (buttonId == null) return null;
    final layout = ref.watch(controllerLayoutProvider);
    return GamepadIcons.assetPath(buttonId, layout);
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

  Widget _buildHintBadge(String? svgPath, bool isFocused, Responsive rs) {
    if (svgPath == null) return const SizedBox.shrink();
    final size = rs.isSmall ? 20.0 : 22.0;

    return Opacity(
      opacity: isFocused ? 1.0 : 0.5,
      child: SvgPicture.asset(
        svgPath,
        width: size,
        height: size,
      ),
    );
  }

  Widget _buildItem(int index, Responsive rs) {
    final item = widget.items[index]!;
    final isFocused = _focusedIndex == index;
    final hintSvg = _hintSvgPath(item.shortcutHint);
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
              if (hintSvg != null)
                _buildHintBadge(hintSvg, isFocused, rs),
            ],
          ),
        ),
      ),
    );
  }
}
