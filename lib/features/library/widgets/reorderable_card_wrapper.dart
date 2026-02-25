import 'package:flutter/material.dart';

class ReorderableCardWrapper extends StatefulWidget {
  final Widget child;
  final bool isJiggling;
  final bool isGrabbed;

  const ReorderableCardWrapper({
    super.key,
    required this.child,
    required this.isJiggling,
    required this.isGrabbed,
  });

  @override
  State<ReorderableCardWrapper> createState() =>
      _ReorderableCardWrapperState();
}

class _ReorderableCardWrapperState extends State<ReorderableCardWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    if (widget.isJiggling && !widget.isGrabbed) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(ReorderableCardWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isGrabbed) {
      _controller.stop();
    } else if (widget.isJiggling && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isJiggling) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isGrabbed) {
      return Transform.scale(
        scale: 1.12,
        child: Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.cyanAccent.withValues(alpha: 0.4),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: widget.child,
        ),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final angle = (_controller.value - 0.5) * 0.04;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.rotationZ(angle),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
