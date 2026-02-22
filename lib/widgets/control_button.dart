import 'package:flutter/material.dart';
import '../core/responsive/responsive.dart';

class ControlButton extends StatelessWidget {
  final String label;
  final String action;
  final VoidCallback? onTap;
  final bool highlight;
  final IconData? icon;
  final Color? buttonColor;
  final CustomPainter? shapePainter;
  final Color? labelColor;

  const ControlButton({
    super.key,
    required this.label,
    required this.action,
    this.onTap,
    this.highlight = false,
    this.icon,
    this.buttonColor,
    this.shapePainter,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final buttonSize = rs.isSmall ? 24.0 : (rs.isMedium ? 28.0 : 32.0);
    final fontSize = rs.isSmall ? 10.0 : (rs.isMedium ? 12.0 : 13.0);
    final actionFontSize = rs.isSmall ? 10.0 : (rs.isMedium ? 12.0 : 13.0);
    final iconSize = rs.isSmall ? 14.0 : (rs.isMedium ? 16.0 : 18.0);
    final spacing = rs.spacing.sm;

    // Highlight always takes priority over custom colors
    final effectiveColor = highlight ? Colors.redAccent : buttonColor;
    final effectiveLabelColor =
        highlight ? Colors.redAccent : (labelColor ?? Colors.white);

    // Face buttons get circles, shoulder/trigger buttons get pill shape
    const faceButtons = {'A', 'B', 'X', 'Y', '✕', '○', '△', '□'};
    final usePill = !faceButtons.contains(label) && icon == null && shapePainter == null;
    final pillWidth = usePill ? buttonSize * 1.5 : buttonSize;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: pillWidth,
          height: buttonSize,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(usePill ? buttonSize * 0.35 : buttonSize),
            color: effectiveColor != null
                ? effectiveColor.withValues(alpha: 0.25)
                : Colors.white.withValues(alpha: 0.12),
            border: Border.all(
              color: effectiveColor != null
                  ? effectiveColor.withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.3),
              width: 1,
            ),
            boxShadow: effectiveColor != null && !highlight
                ? [
                    BoxShadow(
                      color: effectiveColor.withValues(alpha: 0.2),
                      blurRadius: 6,
                      spreadRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: shapePainter != null
                ? CustomPaint(
                    size: Size(iconSize, iconSize),
                    painter: highlight
                        ? _recolorPainter(shapePainter!, Colors.redAccent)
                        : shapePainter,
                  )
                : icon != null
                    ? Icon(icon,
                        size: iconSize, color: effectiveLabelColor)
                    : Text(
                        label,
                        style: TextStyle(
                          fontSize: usePill ? fontSize * 0.9 : fontSize,
                          fontWeight: FontWeight.bold,
                          color: effectiveLabelColor,
                        ),
                      ),
          ),
        ),
        SizedBox(width: spacing),
        Text(
          action,
          style: TextStyle(
            fontSize: actionFontSize,
            color: highlight
                ? Colors.redAccent.withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.7),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        canRequestFocus: false,
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        splashColor: Colors.white.withValues(alpha: 0.1),
        highlightColor: Colors.white.withValues(alpha: 0.05),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: rs.spacing.sm,
            vertical: rs.spacing.xs,
          ),
          child: content,
        ),
      ),
    );
  }
}

CustomPainter _recolorPainter(CustomPainter painter, Color color) {
  return switch (painter) {
    NintendoPlusPainter() => NintendoPlusPainter(color: color),
    NintendoMinusPainter() => NintendoMinusPainter(color: color),
    PSCrossPainter() => PSCrossPainter(color: color),
    PSCirclePainter() => PSCirclePainter(color: color),
    PSTrianglePainter() => PSTrianglePainter(color: color),
    PSSquarePainter() => PSSquarePainter(color: color),
    _ => painter,
  };
}

// -- PlayStation shape painters (stroke-style geometric shapes) --

class PSCrossPainter extends CustomPainter {
  final Color color;
  const PSCrossPainter({this.color = const Color(0xFF6E9FD6)});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.width * 0.14
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final m = size.width * 0.22; // margin
    canvas.drawLine(Offset(m, m), Offset(size.width - m, size.height - m), paint);
    canvas.drawLine(Offset(size.width - m, m), Offset(m, size.height - m), paint);
  }

  @override
  bool shouldRepaint(covariant PSCrossPainter old) => color != old.color;
}

class PSCirclePainter extends CustomPainter {
  final Color color;
  const PSCirclePainter({this.color = const Color(0xFFE8707A)});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.width * 0.12
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width * 0.35,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant PSCirclePainter old) => color != old.color;
}

class PSTrianglePainter extends CustomPainter {
  final Color color;
  const PSTrianglePainter({this.color = const Color(0xFF7BC8A4)});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.width * 0.12
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(size.width / 2, size.height * 0.12)
      ..lineTo(size.width * 0.88, size.height * 0.82)
      ..lineTo(size.width * 0.12, size.height * 0.82)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant PSTrianglePainter old) => color != old.color;
}

class PSSquarePainter extends CustomPainter {
  final Color color;
  const PSSquarePainter({this.color = const Color(0xFFA88BC7)});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.width * 0.12
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final m = size.width * 0.18;
    canvas.drawRect(Rect.fromLTRB(m, m, size.width - m, size.height - m), paint);
  }

  @override
  bool shouldRepaint(covariant PSSquarePainter old) => color != old.color;
}

// -- Nintendo +/− shape painters (filled shapes) --

class NintendoPlusPainter extends CustomPainter {
  final Color color;
  const NintendoPlusPainter({this.color = Colors.white});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final w = size.width;
    final h = size.height;
    final barW = w * 0.32;
    final r = Radius.circular(barW * 0.25);
    // Vertical bar
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(w / 2, h / 2), width: barW, height: h * 0.8),
        r,
      ),
      paint,
    );
    // Horizontal bar
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(w / 2, h / 2), width: w * 0.8, height: barW),
        r,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant NintendoPlusPainter old) => color != old.color;
}

class NintendoMinusPainter extends CustomPainter {
  final Color color;
  const NintendoMinusPainter({this.color = Colors.white});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final barH = size.height * 0.28;
    final r = Radius.circular(barH * 0.3);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(size.width / 2, size.height / 2),
          width: size.width * 0.75,
          height: barH,
        ),
        r,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant NintendoMinusPainter old) => color != old.color;
}
