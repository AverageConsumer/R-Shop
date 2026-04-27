import 'package:flutter/material.dart';

/// Shared shimmer animation controller — single source of truth for
/// skeleton animation timing, so every placeholder pulses in sync.
///
/// Usage: any skeleton widget can wrap itself in `_ShimmerLayer(child: ...)`
/// to get a consistent base color + animated highlight sweep.

/// A solid-color rectangle that shimmers — the building block for every
/// other skeleton.
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double? height;
  final BorderRadius borderRadius;

  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(6)),
  });

  @override
  Widget build(BuildContext context) {
    return _ShimmerLayer(
      borderRadius: borderRadius,
      child: SizedBox(
        width: width,
        height: height,
      ),
    );
  }
}

/// Several stacked SkeletonBox lines, with the last one short — mimics
/// the visual rhythm of a paragraph or a multi-line title.
class SkeletonText extends StatelessWidget {
  final int lines;
  final double height;
  final double spacing;
  final double lastLineWidthFactor;

  const SkeletonText({
    super.key,
    this.lines = 1,
    this.height = 12,
    this.spacing = 6,
    this.lastLineWidthFactor = 0.6,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fullWidth = constraints.maxWidth;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: List.generate(lines, (i) {
            final isLast = i == lines - 1;
            final width = (lines > 1 && isLast)
                ? fullWidth * lastLineWidthFactor
                : fullWidth;
            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : spacing),
              child: SkeletonBox(width: width, height: height),
            );
          }),
        );
      },
    );
  }
}

/// A skeleton mimicking a GameCard layout — a cover-area rectangle plus a
/// short text strip at the bottom. Used to fill grids while real cards load,
/// preserving spatial expectations so there's no layout jump on transition.
class SkeletonCard extends StatelessWidget {
  final double aspectRatio;
  final BorderRadius borderRadius;

  const SkeletonCard({
    super.key,
    this.aspectRatio = 0.75,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: SkeletonBox(borderRadius: borderRadius),
    );
  }
}

/// A grid of SkeletonCards — direct drop-in for "we're still loading the
/// real game grid" states.
class SkeletonGrid extends StatelessWidget {
  final int columns;
  final int count;
  final double aspectRatio;
  final double spacing;
  final EdgeInsets padding;

  const SkeletonGrid({
    super.key,
    required this.columns,
    this.count = 12,
    this.aspectRatio = 0.75,
    this.spacing = 12,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: padding,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        childAspectRatio: aspectRatio,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
      ),
      itemCount: count,
      itemBuilder: (context, _) => const SkeletonCard(),
    );
  }
}

/// Internal: a base-color rectangle with an animated diagonal highlight
/// sweep. Single shared AnimationController (per widget instance) keeps
/// the implementation tiny.
class _ShimmerLayer extends StatefulWidget {
  final Widget child;
  final BorderRadius borderRadius;

  const _ShimmerLayer({
    required this.child,
    required this.borderRadius,
  });

  @override
  State<_ShimmerLayer> createState() => _ShimmerLayerState();
}

class _ShimmerLayerState extends State<_ShimmerLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value;
          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(-1.0 + 2.0 * t, -0.3),
                end: Alignment(1.0 + 2.0 * t, 0.3),
                colors: const [
                  Color(0xFF161616),
                  Color(0xFF222222),
                  Color(0xFF161616),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}
