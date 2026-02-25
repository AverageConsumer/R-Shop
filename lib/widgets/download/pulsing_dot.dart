import 'package:flutter/material.dart';

/// Pulsing green dot for the header
class PulsingDot extends StatefulWidget {
  final bool isActive;
  const PulsingDot({super.key, required this.isActive});

  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    if (widget.isActive) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(PulsingDot old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isActive && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final glowVal = widget.isActive ? _controller.value : 0.0;
        return Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.isActive
                ? Colors.green
                : Colors.grey.shade700,
            boxShadow: widget.isActive
                ? [
                    BoxShadow(
                      color: Colors.green.withValues(alpha: 0.3 + glowVal * 0.5),
                      blurRadius: 8 + glowVal * 8,
                      spreadRadius: glowVal * 3,
                    ),
                  ]
                : null,
          ),
        );
      },
    );
  }
}
