import 'package:flutter/material.dart';
class PixelMascot extends StatefulWidget {
  final double size;
  const PixelMascot({super.key, this.size = 48});
  @override
  State<PixelMascot> createState() => _PixelMascotState();
}
class _PixelMascotState extends State<PixelMascot>
with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _bounceAnimation;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _bounceAnimation = Tween<double>(begin: 0, end: -6).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _bounceAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _bounceAnimation.value),
          child: child,
        );
      },
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [
              Colors.redAccent.withValues(alpha: 0.3),
              Colors.transparent,
            ],
          ),
        ),
        child: CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _PixelMascotPainter(),
        ),
      ),
    );
  }
}
class _PixelMascotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final pixelSize = size.width / 8;
    void drawPixel(int x, int y, Color color) {
      final paint = Paint()..color = color;
      canvas.drawRect(
        Rect.fromLTWH(x * pixelSize, y * pixelSize, pixelSize, pixelSize),
        paint,
      );
    }
    final bodyColor = const Color(0xFFFF6B6B);
    final darkColor = const Color(0xFFCC5555);
    final eyeColor = const Color(0xFF1A1A2E);
    final highlightColor = const Color(0xFFFFB3B3);
    // Body (rounded blob shape)
    drawPixel(2, 2, bodyColor);
    drawPixel(3, 2, bodyColor);
    drawPixel(4, 2, bodyColor);
    drawPixel(5, 2, bodyColor);
    drawPixel(1, 3, bodyColor);
    drawPixel(2, 3, bodyColor);
    drawPixel(3, 3, bodyColor);
    drawPixel(4, 3, bodyColor);
    drawPixel(5, 3, bodyColor);
    drawPixel(6, 3, bodyColor);
    drawPixel(1, 4, bodyColor);
    drawPixel(2, 4, bodyColor);
    drawPixel(3, 4, bodyColor);
    drawPixel(4, 4, bodyColor);
    drawPixel(5, 4, bodyColor);
    drawPixel(6, 4, bodyColor);
    drawPixel(2, 5, bodyColor);
    drawPixel(3, 5, bodyColor);
    drawPixel(4, 5, bodyColor);
    drawPixel(5, 5, bodyColor);
    // Eyes
    drawPixel(2, 3, eyeColor);
    drawPixel(5, 3, eyeColor);
    // Highlight
    drawPixel(3, 2, highlightColor);
    // Shadow
    drawPixel(2, 5, darkColor);
    drawPixel(5, 5, darkColor);
    // Little antenna/tuft
    drawPixel(3, 1, bodyColor);
    drawPixel(4, 1, highlightColor);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
