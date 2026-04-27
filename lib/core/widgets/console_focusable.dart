import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';

/// Shared focus-state machine for the ConsoleFocusable family. Owns the
/// FocusNode lifecycle, listens to focus changes, scrolls into view on focus,
/// and forwards A/Enter/Space to onSelect. Each visual variant only writes its
/// own build() and (optionally) drives its own AnimationController(s) via the
/// onFocusStateChanged hook.
mixin _FocusableSurfaceMixin<T extends StatefulWidget> on State<T> {
  late FocusNode _focusNode;
  bool _ownsNode = false;
  bool _isFocused = false;

  /// Subclass tells us which external FocusNode (if any) to wrap.
  FocusNode? get externalFocusNode;

  /// Subclass tells us what to invoke on A/Enter/Space.
  VoidCallback? get onSelect;

  /// Subclass reacts to focus changes — usually to drive its animations.
  void onFocusStateChanged(bool focused);

  bool get isFocused => _isFocused;
  FocusNode get focusNode => _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = externalFocusNode ?? FocusNode();
    _ownsNode = externalFocusNode == null;
    _focusNode.addListener(_updateFocusState);
  }

  /// Call this from didUpdateWidget when the external FocusNode swap happens.
  void didUpdateExternalNode(FocusNode? oldExternal) {
    if (externalFocusNode == oldExternal) return;
    _focusNode.removeListener(_updateFocusState);
    if (_ownsNode) _focusNode.dispose();
    _focusNode = externalFocusNode ?? FocusNode();
    _ownsNode = externalFocusNode == null;
    _focusNode.addListener(_updateFocusState);
    _updateFocusState();
  }

  @override
  void dispose() {
    _focusNode.removeListener(_updateFocusState);
    if (_ownsNode) _focusNode.dispose();
    super.dispose();
  }

  void _updateFocusState() {
    final hasFocus = _focusNode.hasFocus;
    if (hasFocus != _isFocused) {
      _isFocused = hasFocus;
      if (hasFocus) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Scrollable.ensureVisible(
              context,
              duration: const Duration(milliseconds: 200),
            );
          }
        });
      }
      onFocusStateChanged(hasFocus);
    }
  }

  /// Subclasses pass this to their Focus widget's onKeyEvent.
  KeyEventResult handleFocusableKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.gameButtonA ||
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter ||
        event.logicalKey == LogicalKeyboardKey.space) {
      onSelect?.call();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Subclasses use this for GestureDetector.onTap.
  void onTapFocusable() {
    _focusNode.requestFocus();
    onSelect?.call();
  }
}

class ConsoleFocusable extends ConsumerStatefulWidget {
  final Widget child;
  final FocusNode? focusNode;
  final VoidCallback? onSelect;
  final bool autofocus;
  final Color? focusBorderColor;
  final double focusScale;
  final Duration animationDuration;
  final double borderRadius;
  final double borderWidth;
  final double glowRadius;
  final bool showGlow;

  const ConsoleFocusable({
    super.key,
    required this.child,
    this.focusNode,
    this.onSelect,
    this.autofocus = false,
    this.focusBorderColor,
    this.focusScale = 1.03,
    this.animationDuration = const Duration(milliseconds: 150),
    this.borderRadius = 8.0,
    this.borderWidth = 2.0,
    this.glowRadius = 12.0,
    this.showGlow = true,
  });

  @override
  ConsumerState<ConsoleFocusable> createState() => _ConsoleFocusableState();
}

class _ConsoleFocusableState extends ConsumerState<ConsoleFocusable>
    with SingleTickerProviderStateMixin, _FocusableSurfaceMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _glowAnimation;

  @override
  FocusNode? get externalFocusNode => widget.focusNode;

  @override
  VoidCallback? get onSelect => widget.onSelect;

  @override
  void onFocusStateChanged(bool focused) {
    focused ? _controller.forward() : _controller.reverse();
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.focusScale)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(ConsoleFocusable oldWidget) {
    super.didUpdateWidget(oldWidget);
    didUpdateExternalNode(oldWidget.focusNode);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focusBorderColor = widget.focusBorderColor ?? AppTheme.focusColor;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: isFocused
                  ? Border.all(
                      color: focusBorderColor.withValues(
                        alpha: _glowAnimation.value * 0.95,
                      ),
                      width: widget.borderWidth,
                    )
                  : null,
              boxShadow: isFocused && widget.showGlow
                  ? [
                      BoxShadow(
                        color: focusBorderColor.withValues(
                          alpha: _glowAnimation.value * 0.3,
                        ),
                        blurRadius: widget.glowRadius,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTapFocusable,
              child: Focus(
                focusNode: focusNode,
                onKeyEvent: handleFocusableKeyEvent,
                autofocus: widget.autofocus,
                child: widget.child,
              ),
            ),
          ),
        );
      },
    );
  }
}

class ConsoleFocusableCard extends ConsumerStatefulWidget {
  final Widget child;
  final FocusNode? focusNode;
  final VoidCallback? onSelect;
  final bool autofocus;
  final Color? focusColor;
  final Color? backgroundColor;
  final double focusScale;
  final Duration animationDuration;
  final double borderRadius;
  final double borderWidth;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const ConsoleFocusableCard({
    super.key,
    required this.child,
    this.focusNode,
    this.onSelect,
    this.autofocus = false,
    this.focusColor,
    this.backgroundColor,
    this.focusScale = 1.02,
    this.animationDuration = const Duration(milliseconds: 150),
    this.borderRadius = 12.0,
    this.borderWidth = 2.0,
    this.padding,
    this.margin,
  });

  @override
  ConsumerState<ConsoleFocusableCard> createState() =>
      _ConsoleFocusableCardState();
}

class _ConsoleFocusableCardState extends ConsumerState<ConsoleFocusableCard>
    with SingleTickerProviderStateMixin, _FocusableSurfaceMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _glowAnimation;

  @override
  FocusNode? get externalFocusNode => widget.focusNode;

  @override
  VoidCallback? get onSelect => widget.onSelect;

  @override
  void onFocusStateChanged(bool focused) {
    focused ? _controller.forward() : _controller.reverse();
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.focusScale)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(ConsoleFocusableCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    didUpdateExternalNode(oldWidget.focusNode);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focusColor = widget.focusColor ?? AppTheme.focusColor;
    final bgColor =
        widget.backgroundColor ?? AppTheme.cardColor.withValues(alpha: 0.6);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            margin: widget.margin,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: Border.all(
                color: isFocused
                    ? focusColor.withValues(alpha: _glowAnimation.value * 0.95)
                    : Colors.white.withValues(alpha: 0.1),
                width: isFocused ? widget.borderWidth : 1,
              ),
              boxShadow: isFocused
                  ? [
                      BoxShadow(
                        color: focusColor.withValues(
                          alpha: _glowAnimation.value * 0.25,
                        ),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTapFocusable,
              child: Focus(
                focusNode: focusNode,
                onKeyEvent: handleFocusableKeyEvent,
                autofocus: widget.autofocus,
                child: Padding(
                  padding: widget.padding ?? EdgeInsets.zero,
                  child: widget.child,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class ConsoleFocusableListItem extends ConsumerStatefulWidget {
  final Widget child;
  final FocusNode? focusNode;
  final VoidCallback? onSelect;
  final bool autofocus;
  final Color? focusColor;
  final Color? backgroundColor;
  final Duration animationDuration;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const ConsoleFocusableListItem({
    super.key,
    required this.child,
    this.focusNode,
    this.onSelect,
    this.autofocus = false,
    this.focusColor,
    this.backgroundColor,
    this.animationDuration = const Duration(milliseconds: 100),
    this.borderRadius = 8.0,
    this.padding,
    this.margin,
  });

  @override
  ConsumerState<ConsoleFocusableListItem> createState() =>
      _ConsoleFocusableListItemState();
}

class _ConsoleFocusableListItemState
    extends ConsumerState<ConsoleFocusableListItem>
    with SingleTickerProviderStateMixin, _FocusableSurfaceMixin {
  late final AnimationController _controller;
  late final Animation<double> _highlightAnimation;

  @override
  FocusNode? get externalFocusNode => widget.focusNode;

  @override
  VoidCallback? get onSelect => widget.onSelect;

  @override
  void onFocusStateChanged(bool focused) {
    focused ? _controller.forward() : _controller.reverse();
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    _highlightAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(ConsoleFocusableListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    didUpdateExternalNode(oldWidget.focusNode);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focusColor = widget.focusColor ?? AppTheme.focusColor;
    final bgColor =
        widget.backgroundColor ?? AppTheme.cardColor.withValues(alpha: 0.4);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          margin: widget.margin,
          decoration: BoxDecoration(
            color: Color.lerp(bgColor, Colors.white.withValues(alpha: 0.15),
                _highlightAnimation.value),
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(
              color: Color.lerp(
                    Colors.white.withValues(alpha: 0.08),
                    focusColor.withValues(alpha: 0.95),
                    _highlightAnimation.value,
                  ) ??
                  Colors.white.withValues(alpha: 0.08),
              width: isFocused ? 2 : 1,
            ),
          ),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTapFocusable,
            child: Focus(
              focusNode: focusNode,
              onKeyEvent: handleFocusableKeyEvent,
              autofocus: widget.autofocus,
              child: Padding(
                padding: widget.padding ?? EdgeInsets.zero,
                child: widget.child,
              ),
            ),
          ),
        );
      },
    );
  }
}
