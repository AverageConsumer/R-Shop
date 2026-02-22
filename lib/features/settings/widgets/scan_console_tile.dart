import 'package:flutter/material.dart';
import '../../../core/responsive/responsive.dart';
import '../../../models/system_model.dart';

enum ScanTileState { pending, scanning, complete }

class ScanConsoleTile extends StatelessWidget {
  final SystemModel system;
  final ScanTileState scanState;
  final int gameCount;
  final bool isFocused;

  const ScanConsoleTile({
    super.key,
    required this.system,
    required this.scanState,
    this.gameCount = 0,
    this.isFocused = false,
  });

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final iconSize = rs.isSmall ? 24.0 : 32.0;
    final nameFontSize = rs.isSmall ? 8.0 : 10.0;

    final isComplete = scanState == ScanTileState.complete;
    final isScanning = scanState == ScanTileState.scanning;
    final isPending = scanState == ScanTileState.pending;

    final double bgAlpha = isPending
        ? 0.03
        : isScanning
            ? 0.08
            : 0.15;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: isPending
            ? Colors.white.withValues(alpha: bgAlpha + (isFocused ? 0.05 : 0))
            : system.accentColor.withValues(alpha: bgAlpha + (isFocused ? 0.05 : 0)),
        borderRadius: BorderRadius.circular(rs.radius.md),
        border: Border.all(
          color: isFocused
              ? system.accentColor.withValues(alpha: 0.9)
              : isPending
                  ? Colors.white.withValues(alpha: 0.06)
                  : isScanning
                      ? system.accentColor.withValues(alpha: 0.6)
                      : system.accentColor.withValues(alpha: 0.8),
          width: isFocused || isScanning ? 2 : 1,
        ),
        boxShadow: [
          if (isFocused)
            BoxShadow(
              color: system.accentColor.withValues(alpha: 0.3),
              blurRadius: 16,
            ),
          if (isComplete)
            BoxShadow(
              color: system.accentColor.withValues(alpha: 0.25),
              blurRadius: 12,
              spreadRadius: 1,
            ),
        ],
      ),
      child: Stack(
        children: [
          // Scanning pulse overlay
          if (isScanning)
            Positioned.fill(
              child: _PulsingOverlay(color: system.accentColor),
            ),
          Center(
            child: Opacity(
              opacity: isPending ? 0.3 : 1.0,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(rs.radius.sm),
                    child: Image.asset(
                      system.iconAssetPath,
                      width: iconSize,
                      height: iconSize,
                      cacheWidth: 128,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.videogame_asset,
                        color: system.accentColor,
                        size: iconSize,
                      ),
                    ),
                  ),
                  SizedBox(height: rs.spacing.xs),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: rs.spacing.xs),
                    child: Text(
                      system.name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isPending ? Colors.white38 : Colors.white,
                        fontSize: nameFontSize,
                        fontWeight: isComplete ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Game count badge
          if (isComplete && gameCount > 0)
            Positioned(
              top: rs.spacing.xs,
              right: rs.spacing.xs,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: system.accentColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$gameCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          // Scanning indicator
          if (isScanning)
            Positioned(
              top: rs.spacing.xs,
              right: rs.spacing.xs,
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: system.accentColor,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PulsingOverlay extends StatefulWidget {
  final Color color;

  const _PulsingOverlay({required this.color});

  @override
  State<_PulsingOverlay> createState() => _PulsingOverlayState();
}

class _PulsingOverlayState extends State<_PulsingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
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
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: widget.color.withValues(alpha: _controller.value * 0.08),
          ),
        );
      },
    );
  }
}
