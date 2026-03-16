import 'package:flutter/material.dart';

import '../../../core/responsive/responsive.dart';
import '../../../models/game_item.dart';
import '../../../models/game_metadata_info.dart';
import '../../../widgets/marquee_text.dart';
import 'section_header.dart';

enum _VersionStatus { installed, available, notFound }

class _VersionEntry {
  final String name;
  final _VersionStatus status;

  const _VersionEntry({
    required this.name,
    required this.status,
  });
}

class OtherVersionsSection extends StatefulWidget {
  final List<SiblingInfo> siblings;
  final List<GameItem> variants;
  final bool isMultiRom;
  final int focusedIndex;
  final bool isSectionFocused;
  final Map<int, bool> installedStatus;
  final Color accentColor;

  const OtherVersionsSection({
    super.key,
    required this.siblings,
    required this.variants,
    required this.isMultiRom,
    required this.focusedIndex,
    this.isSectionFocused = false,
    required this.installedStatus,
    required this.accentColor,
  });

  /// Total number of sibling entries from RomM/IGDB.
  static int entryCount({
    required List<GameItem> variants,
    required List<SiblingInfo> siblings,
  }) {
    return siblings.length;
  }

  @override
  State<OtherVersionsSection> createState() => _OtherVersionsSectionState();
}

class _OtherVersionsSectionState extends State<OtherVersionsSection> {
  final Map<int, GlobalKey> _itemKeys = {};

  GlobalKey _keyFor(int index) =>
      _itemKeys.putIfAbsent(index, () => GlobalKey());

  @override
  void didUpdateWidget(OtherVersionsSection oldWidget) {
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

  List<_VersionEntry> _buildEntries() {
    final entries = <_VersionEntry>[];

    // Only show RomM/IGDB siblings — real variants are handled by the variant picker
    for (final s in widget.siblings) {
      entries.add(_VersionEntry(
        name: s.name,
        status: _VersionStatus.notFound,
      ));
    }

    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final entries = _buildEntries();
    if (entries.isEmpty) return const SizedBox.shrink();

    final rs = context.rs;
    final clampedIdx = widget.focusedIndex.clamp(0, entries.length - 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(label: 'Other Versions'),
        SizedBox(
          height: rs.isSmall ? 52 : 60,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: entries.length,
            separatorBuilder: (_, __) => SizedBox(width: rs.spacing.sm),
            itemBuilder: (context, index) {
              final entry = entries[index];
              final isFocused = widget.isSectionFocused && index == clampedIdx;
              return _buildItem(rs, entry, isFocused, index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildItem(Responsive rs, _VersionEntry entry, bool isFocused, int index) {
    final Color bgColor;
    final Color borderColor;
    final Color textColor;
    final String? subtitle;

    switch (entry.status) {
      case _VersionStatus.installed:
        bgColor = isFocused
            ? widget.accentColor.withValues(alpha: 0.12)
            : Colors.green.withValues(alpha: 0.06);
        borderColor = isFocused
            ? widget.accentColor.withValues(alpha: 0.5)
            : Colors.greenAccent.withValues(alpha: 0.3);
        textColor = Colors.white.withValues(alpha: isFocused ? 0.9 : 0.7);
        subtitle = 'Installed';
      case _VersionStatus.available:
        bgColor = isFocused
            ? widget.accentColor.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.06);
        borderColor = isFocused
            ? widget.accentColor.withValues(alpha: 0.5)
            : Colors.white.withValues(alpha: 0.1);
        textColor = Colors.white.withValues(alpha: isFocused ? 0.9 : 0.7);
        subtitle = null;
      case _VersionStatus.notFound:
        bgColor = Colors.white.withValues(alpha: isFocused ? 0.05 : 0.02);
        borderColor = isFocused
            ? Colors.white.withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.06);
        textColor = Colors.white.withValues(alpha: isFocused ? 0.35 : 0.2);
        subtitle = 'Not found';
    }

    final cardWidth = rs.isSmall ? 140.0 : 170.0;

    return AnimatedContainer(
      key: _keyFor(index),
      duration: const Duration(milliseconds: 150),
      width: cardWidth,
      padding: EdgeInsets.symmetric(
        horizontal: rs.isSmall ? 10 : 14,
        vertical: rs.isSmall ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(rs.radius.sm),
        border: Border.all(
          color: borderColor,
          width: isFocused ? 1.5 : 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MarqueeText(
            text: entry.name,
            animate: isFocused,
            style: TextStyle(
              color: textColor,
              fontSize: rs.isSmall ? 11 : 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: entry.status == _VersionStatus.installed
                    ? Colors.greenAccent.withValues(alpha: 0.7)
                    : Colors.white.withValues(alpha: 0.15),
                fontSize: rs.isSmall ? 8 : 10,
                fontWeight: entry.status == _VersionStatus.installed
                    ? FontWeight.w600
                    : FontWeight.w400,
              ),
            ),
          ],
        ],
      ),
    );
  }

}
