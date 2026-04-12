import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/download_providers.dart';

/// Thin YouTube-style progress bar at the very top of the screen.
/// Shows aggregate download progress across all active downloads.
/// Renders above all content via the root Stack in main.dart.
class GlobalDownloadProgressBar extends ConsumerStatefulWidget {
  const GlobalDownloadProgressBar({super.key});

  @override
  ConsumerState<GlobalDownloadProgressBar> createState() =>
      _GlobalDownloadProgressBarState();
}

class _GlobalDownloadProgressBarState
    extends ConsumerState<GlobalDownloadProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  double _lastKnownProgress = 0.0;
  bool _holdingComplete = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(globalDownloadProgressProvider);
    final hasActive = ref.watch(hasActiveDownloadsProvider);

    if (hasActive && progress != null) {
      // Active downloads — show bar, cancel any pending fade-out.
      _holdingComplete = false;
      _lastKnownProgress = progress;
      if (_fadeController.status == AnimationStatus.forward ||
          _fadeController.status == AnimationStatus.completed) {
        _fadeController.reverse();
      }
    } else if (_lastKnownProgress > 0.01 && !_holdingComplete) {
      // Just finished — hold at 100% briefly, then fade out.
      _holdingComplete = true;
      _lastKnownProgress = 1.0;
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted && _holdingComplete) {
          _fadeController.forward();
        }
      });
    } else if (!_holdingComplete && _lastKnownProgress < 0.01) {
      // Never started or already faded — stay invisible.
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _fadeController,
        builder: (context, child) {
          final opacity = 1.0 - _fadeController.value;
          if (opacity <= 0) {
            // Fully faded — reset state for next download batch.
            if (_holdingComplete) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    _holdingComplete = false;
                    _lastKnownProgress = 0.0;
                  });
                }
              });
            }
            return const SizedBox.shrink();
          }
          return Opacity(opacity: opacity, child: child);
        },
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: _lastKnownProgress.clamp(0.0, 1.0)),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          builder: (context, value, _) {
            return SizedBox(
              height: 3,
              child: Stack(
                children: [
                  // Track (invisible — just for layout)
                  Container(height: 3),
                  // Filled portion
                  FractionallySizedBox(
                    widthFactor: value,
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF22C55E), Color(0xFF4ADE80)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF22C55E).withValues(alpha: 0.6),
                            blurRadius: 8,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
