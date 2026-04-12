import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/download_item.dart';

/// Circular progress ring overlay for game cards.
/// Shows download progress as a thin arc over the cover image center.
class CardProgressRing extends StatefulWidget {
  final DownloadStatus status;
  final double progress;
  final Color accentColor;

  const CardProgressRing({
    super.key,
    required this.status,
    required this.progress,
    required this.accentColor,
  });

  @override
  State<CardProgressRing> createState() => _CardProgressRingState();
}

class _CardProgressRingState extends State<CardProgressRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _updateAnimation();
  }

  @override
  void didUpdateWidget(CardProgressRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) {
      _updateAnimation();
    }
  }

  void _updateAnimation() {
    final needsSpin = widget.status == DownloadStatus.queued ||
        widget.status == DownloadStatus.extracting ||
        widget.status == DownloadStatus.moving;
    if (needsSpin && !_spinController.isAnimating) {
      _spinController.repeat();
    } else if (!needsSpin && _spinController.isAnimating) {
      _spinController.stop();
    }
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isQueued = widget.status == DownloadStatus.queued;
    final isIndeterminate = widget.status == DownloadStatus.extracting ||
        widget.status == DownloadStatus.moving;
    final isDownloading = widget.status == DownloadStatus.downloading;

    final ringColor = isIndeterminate
        ? Colors.amber.withValues(alpha: 0.8)
        : widget.accentColor.withValues(alpha: 0.9);
    final trackColor = Colors.white.withValues(alpha: 0.15);

    const size = 52.0;
    const ringSize = 44.0;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background dim
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.5),
            ),
          ),
          // Ring
          if (isQueued || isIndeterminate)
            AnimatedBuilder(
              animation: _spinController,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _spinController.value * 2 * math.pi,
                  child: CustomPaint(
                    size: const Size(ringSize, ringSize),
                    painter: _RingPainter(
                      progress: 0.25,
                      ringColor: ringColor,
                      trackColor: trackColor,
                      strokeWidth: 2.5,
                    ),
                  ),
                );
              },
            )
          else if (isDownloading)
            TweenAnimationBuilder<double>(
              tween: Tween(end: widget.progress.clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
              builder: (context, value, _) {
                return CustomPaint(
                  size: const Size(ringSize, ringSize),
                  painter: _RingPainter(
                    progress: value,
                    ringColor: ringColor,
                    trackColor: trackColor,
                    strokeWidth: 2.5,
                  ),
                );
              },
            ),
          // Percentage text (only when downloading)
          if (isDownloading && widget.progress > 0.01)
            Text(
              (widget.progress * 100).toStringAsFixed(0),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            )
          else if (isQueued)
            Icon(
              Icons.schedule_rounded,
              size: 14,
              color: Colors.white.withValues(alpha: 0.7),
            )
          else if (isIndeterminate)
            Icon(
              Icons.unarchive_rounded,
              size: 14,
              color: Colors.amber.withValues(alpha: 0.8),
            ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color ringColor;
  final Color trackColor;
  final double strokeWidth;

  _RingPainter({
    required this.progress,
    required this.ringColor,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    // Progress arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // Start from top
      progress * 2 * math.pi,
      false,
      Paint()
        ..color = ringColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      progress != oldDelegate.progress ||
      ringColor != oldDelegate.ringColor;
}
