import 'package:flutter/material.dart';

import '../../../core/responsive/responsive.dart';
import '../../../l10n/app_localizations.dart';
import 'section_header.dart';

class ScreenshotsCarousel extends StatefulWidget {
  final List<String> screenshots;
  final int focusedIndex;
  final bool isSectionFocused;
  final Color accentColor;
  final VoidCallback onOpenViewer;

  const ScreenshotsCarousel({
    super.key,
    required this.screenshots,
    required this.focusedIndex,
    this.isSectionFocused = false,
    required this.accentColor,
    required this.onOpenViewer,
  });

  @override
  State<ScreenshotsCarousel> createState() => _ScreenshotsCarouselState();
}

class _ScreenshotsCarouselState extends State<ScreenshotsCarousel> {
  final Map<int, GlobalKey> _itemKeys = {};

  GlobalKey _keyFor(int index) =>
      _itemKeys.putIfAbsent(index, GlobalKey.new);

  @override
  void didUpdateWidget(ScreenshotsCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusedIndex != widget.focusedIndex) {
      _scrollToFocused();
    }
  }

  void _scrollToFocused() {
    final key = _itemKeys[widget.focusedIndex];
    if (key == null) return;
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      alignment: 0.3,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.screenshots.isEmpty) return const SizedBox.shrink();

    final rs = context.rs;
    final clampedIdx = widget.focusedIndex.clamp(0, widget.screenshots.length - 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(label: L.of(context).gameDetail_screenshots),
        SizedBox(
          height: rs.isSmall ? 80 : 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: widget.screenshots.length,
            separatorBuilder: (_, __) => SizedBox(width: rs.spacing.sm),
            itemBuilder: (context, index) {
              final isFocused = widget.isSectionFocused && index == clampedIdx;
              return GestureDetector(
                key: _keyFor(index),
                onTap: widget.onOpenViewer,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: rs.isSmall ? 140 : 170,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(rs.radius.sm),
                    border: Border.all(
                      color: isFocused
                          ? widget.accentColor.withValues(alpha: 0.7)
                          : Colors.white.withValues(alpha: 0.1),
                      width: isFocused ? 2 : 1,
                    ),
                    boxShadow: isFocused
                        ? [
                            BoxShadow(
                              color: widget.accentColor.withValues(alpha: 0.3),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(rs.radius.sm - 1),
                    child: Image.network(
                      widget.screenshots[index],
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.white.withValues(alpha: 0.05),
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white.withValues(alpha: 0.2),
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
