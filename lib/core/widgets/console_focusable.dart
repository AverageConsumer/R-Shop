import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';

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
    with SingleTickerProviderStateMixin {
  late FocusNode _focusNode;
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _glowAnimation;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);

    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.focusScale,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _glowAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

  }

  @override
  void didUpdateWidget(ConsoleFocusable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      _focusNode.removeListener(_onFocusChange);
      if (oldWidget.focusNode == null) {
        _focusNode.dispose();
      }
      _focusNode = widget.focusNode ?? FocusNode();
      _focusNode.addListener(_onFocusChange);
      _updateFocusState();
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    _updateFocusState();
  }

  void _updateFocusState() {
    final hasFocus = _focusNode.hasFocus;
    if (hasFocus != _isFocused) {
      _isFocused = hasFocus;
      if (hasFocus) {
        _controller.forward();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Scrollable.ensureVisible(context,
                duration: const Duration(milliseconds: 200));
          }
        });
      } else {
        _controller.reverse();
      }
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) {
      return KeyEventResult.ignored;
    }

    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.gameButtonA ||
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter ||
        event.logicalKey == LogicalKeyboardKey.space) {
      widget.onSelect?.call();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
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
              border: _isFocused
                  ? Border.all(
                      color: focusBorderColor.withValues(
                        alpha: _glowAnimation.value * 0.95,
                      ),
                      width: widget.borderWidth,
                    )
                  : null,
              boxShadow: _isFocused && widget.showGlow
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
              onTap: () {
                _focusNode.requestFocus();
                widget.onSelect?.call();
              },
              child: Focus(
                focusNode: _focusNode,
                onKeyEvent: _handleKeyEvent,
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
    with SingleTickerProviderStateMixin {
  late FocusNode _focusNode;
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _glowAnimation;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);

    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.focusScale,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _glowAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
  }

  @override
  void didUpdateWidget(ConsoleFocusableCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      _focusNode.removeListener(_onFocusChange);
      if (oldWidget.focusNode == null) {
        _focusNode.dispose();
      }
      _focusNode = widget.focusNode ?? FocusNode();
      _focusNode.addListener(_onFocusChange);
      _updateFocusState();
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    _updateFocusState();
  }

  void _updateFocusState() {
    final hasFocus = _focusNode.hasFocus;
    if (hasFocus != _isFocused) {
      _isFocused = hasFocus;
      if (hasFocus) {
        _controller.forward();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Scrollable.ensureVisible(context,
                duration: const Duration(milliseconds: 200));
          }
        });
      } else {
        _controller.reverse();
      }
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) {
      return KeyEventResult.ignored;
    }

    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.gameButtonA ||
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter ||
        event.logicalKey == LogicalKeyboardKey.space) {
      widget.onSelect?.call();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
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
                color: _isFocused
                    ? focusColor.withValues(alpha: _glowAnimation.value * 0.95)
                    : Colors.white.withValues(alpha: 0.1),
                width: _isFocused ? widget.borderWidth : 1,
              ),
              boxShadow: _isFocused
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
              onTap: () {
                _focusNode.requestFocus();
                widget.onSelect?.call();
              },
              child: Focus(
                focusNode: _focusNode,
                onKeyEvent: _handleKeyEvent,
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
    with SingleTickerProviderStateMixin {
  late FocusNode _focusNode;
  late final AnimationController _controller;
  late final Animation<double> _highlightAnimation;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);

    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _highlightAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
  }

  @override
  void didUpdateWidget(ConsoleFocusableListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      _focusNode.removeListener(_onFocusChange);
      if (oldWidget.focusNode == null) {
        _focusNode.dispose();
      }
      _focusNode = widget.focusNode ?? FocusNode();
      _focusNode.addListener(_onFocusChange);
      _updateFocusState();
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    _updateFocusState();
  }

  void _updateFocusState() {
    final hasFocus = _focusNode.hasFocus;
    if (hasFocus != _isFocused) {
      _isFocused = hasFocus;
      if (hasFocus) {
        _controller.forward();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Scrollable.ensureVisible(context,
                duration: const Duration(milliseconds: 200));
          }
        });
      } else {
        _controller.reverse();
      }
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) {
      return KeyEventResult.ignored;
    }

    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.gameButtonA ||
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter ||
        event.logicalKey == LogicalKeyboardKey.space) {
      widget.onSelect?.call();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
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
              width: _isFocused ? 2 : 1,
            ),
          ),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              _focusNode.requestFocus();
              widget.onSelect?.call();
            },
            child: Focus(
              focusNode: _focusNode,
              onKeyEvent: _handleKeyEvent,
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
