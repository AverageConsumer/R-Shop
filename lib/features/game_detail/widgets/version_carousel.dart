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
  final VoidCallback? onInfoTap;

  const VersionCarousel({
    super.key,
    required this.variants,
    required this.system,
    required this.selectedIndex,
    required this.installedStatus,
    this.parentFocusNode,
    required this.onSelectionChanged,
    this.onInfoTap,
  });

  @override
  State<VersionCarousel> createState() => _VersionCarouselState();
}

class _VersionCarouselState extends State<VersionCarousel> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(VersionCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.selectedIndex != oldWidget.selectedIndex) {
      _scrollToIndex(widget.selectedIndex);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToIndex(int index) {
    if (!_scrollController.hasClients) return;

    final rs = context.rs;
    final cardWidth = rs.isSmall ? 130.0 : 160.0;
    final gap = rs.isSmall ? 8.0 : 10.0;
    final screenWidth = MediaQuery.of(context).size.width;
    final targetOffset =
        (index * (cardWidth + gap)) - (screenWidth / 2) + (cardWidth / 2);

    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final cardWidth = rs.isSmall ? 130.0 : 160.0;
    final listHeight = rs.isSmall ? 80.0 : 110.0;
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
        SizedBox(
          height: listHeight,
          child: ListView.separated(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(
              horizontal: rs.spacing.xs,
              vertical: rs.spacing.xs,
            ),
            itemCount: widget.variants.length,
            separatorBuilder: (_, __) => SizedBox(width: rs.spacing.sm),
            itemBuilder: (context, index) {
              final variant = widget.variants[index];
              final isSelected = index == widget.selectedIndex;
              final isInstalled = widget.installedStatus[index] ?? false;

              return SizedBox(
                width: cardWidth,
                child: VersionCard(
                  variant: variant,
                  system: widget.system,
                  isSelected: isSelected,
                  isInstalled: isInstalled,
                  isFocused: isSelected,
                  onTap: () {
                    widget.onSelectionChanged(index);
                  },
                  onInfoTap: widget.onInfoTap,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class VersionCarouselCompact extends StatelessWidget {
  final List<GameItem> variants;
  final SystemModel system;
  final int selectedIndex;
  final Map<int, bool> installedStatus;
  final void Function(int index) onSelectionChanged;

  const VersionCarouselCompact({
    super.key,
    required this.variants,
    required this.system,
    required this.selectedIndex,
    required this.installedStatus,
    required this.onSelectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final fontSize = rs.isSmall ? 10.0 : 12.0;
    final iconSize = rs.isSmall ? 10.0 : 14.0;

    return Wrap(
      spacing: rs.spacing.sm,
      runSpacing: rs.spacing.sm,
      children: List.generate(variants.length, (index) {
        final variant = variants[index];
        final isSelected = index == selectedIndex;
        final isInstalled = installedStatus[index] ?? false;
        final metadata = variant.filename;

        return GestureDetector(
          onTap: () => onSelectionChanged(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: EdgeInsets.symmetric(
              horizontal: rs.spacing.sm,
              vertical: rs.spacing.xs,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? system.accentColor.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(rs.radius.md),
              border: Border.all(
                color: isSelected
                    ? system.accentColor
                    : Colors.white.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isInstalled)
                  Padding(
                    padding: EdgeInsets.only(right: rs.spacing.xs),
                    child: Icon(Icons.check_circle,
                        color: Colors.greenAccent, size: iconSize),
                  ),
                Text(
                  metadata,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.7),
                    fontSize: fontSize,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
