import 'package:flutter/material.dart';
import '../../../core/responsive/responsive.dart';
import '../../../models/game_item.dart';
import '../../../models/system_model.dart';
import 'version_card.dart';

class VersionCarousel extends StatefulWidget {
  final List<GameItem> variants;
  final SystemModel system;
  final int selectedIndex;
  final Map<int, bool> installedStatus;
  final FocusNode? parentFocusNode;
  final void Function(int index) onSelectionChanged;

  const VersionCarousel({
    super.key,
    required this.variants,
    required this.system,
    required this.selectedIndex,
    required this.installedStatus,
    this.parentFocusNode,
    required this.onSelectionChanged,
  });

  @override
  State<VersionCarousel> createState() => _VersionCarouselState();
}

class _VersionCarouselState extends State<VersionCarousel> {
  final Map<int, GlobalKey> _cardKeys = {};

  @override
  void initState() {
    super.initState();
    _ensureKeys();
    if (widget.selectedIndex != 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSelected();
      });
    }
  }

  @override
  void didUpdateWidget(VersionCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _ensureKeys();
    if (widget.selectedIndex != oldWidget.selectedIndex) {
      final goingDown = widget.selectedIndex > oldWidget.selectedIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSelected(goingDown: goingDown);
      });
    }
  }

  void _ensureKeys() {
    for (int i = 0; i < widget.variants.length; i++) {
      _cardKeys.putIfAbsent(i, () => GlobalKey());
    }
  }

  void _scrollToSelected({bool goingDown = true}) {
    final key = _cardKeys[widget.selectedIndex];
    if (key == null) return;
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      alignmentPolicy: goingDown
          ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
          : ScrollPositionAlignmentPolicy.keepVisibleAtStart,
    );
  }

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final labelFontSize = rs.isSmall ? 10.0 : 12.0;
    final countFontSize = rs.isSmall ? 9.0 : 11.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: rs.spacing.sm),
          child: Row(
            children: [
              Text(
                'VERSIONS',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: labelFontSize,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              SizedBox(width: rs.spacing.sm),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: rs.spacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: widget.system.accentColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(rs.radius.sm),
                ),
                child: Text(
                  '${widget.variants.length}',
                  style: TextStyle(
                    color: widget.system.accentColor,
                    fontSize: countFontSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        ...List.generate(widget.variants.length, (index) {
          final variant = widget.variants[index];
          final isSelected = index == widget.selectedIndex;
          final isInstalled = widget.installedStatus[index] ?? false;

          return Padding(
            key: _cardKeys[index],
            padding: EdgeInsets.only(
              bottom: index < widget.variants.length - 1 ? rs.spacing.sm : 0,
            ),
            child: SingleVersionDisplay(
              variant: variant,
              system: widget.system,
              isInstalled: isInstalled,
              isSelected: isSelected,
              isFocused: isSelected,
              onTap: () => widget.onSelectionChanged(index),
            ),
          );
        }),
      ],
    );
  }
}
