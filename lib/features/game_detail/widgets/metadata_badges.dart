import 'package:flutter/material.dart';

import '../../../utils/game_metadata.dart';

class RegionBadge extends StatelessWidget {
  final RegionInfo region;
  final double fontSize;

  const RegionBadge({
    super.key,
    required this.region,
    this.fontSize = 14,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(region.flag, style: TextStyle(fontSize: fontSize)),
          const SizedBox(width: 6),
          Text(
            region.name,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class LanguageBadges extends StatelessWidget {
  final List<LanguageInfo> languages;
  final int maxVisible;

  const LanguageBadges({
    super.key,
    required this.languages,
    this.maxVisible = 5,
  });

  @override
  Widget build(BuildContext context) {
    final visible = languages.take(maxVisible).toList();
    final remaining = languages.length - maxVisible;

    return ClipRect(
      child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...visible.map((lang) => Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Tooltip(
                message: lang.name,
                child: Text(lang.flag, style: const TextStyle(fontSize: 16)),
              ),
            )),
        if (remaining > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '+$remaining',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
      ),
    );
  }
}

class TagBadges extends StatelessWidget {
  final List<TagInfo> tags;
  final int maxVisible;
  final bool compact;

  const TagBadges({
    super.key,
    required this.tags,
    this.maxVisible = 3,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) {
      return Text(
        'Standard',
        style: TextStyle(
          color: Colors.grey.shade500,
          fontSize: compact ? 10 : 12,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    final visible = tags.take(maxVisible).toList();
    final remaining = tags.length - maxVisible;

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        ...visible.map((tag) => _TagBadge(tag: tag, compact: compact)),
        if (remaining > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '+$remaining',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: compact ? 9 : 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }
}

class _TagBadge extends StatelessWidget {
  final TagInfo tag;
  final bool compact;

  const _TagBadge({
    required this.tag,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = tag.getColor();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(compact ? 4 : 6),
        border: Border.all(
          color: color.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Text(
        tag.raw,
        style: TextStyle(
          color: color.withValues(alpha: 0.9),
          fontSize: compact ? 9 : 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class FileTypeBadge extends StatelessWidget {
  final String fileType;

  const FileTypeBadge({
    super.key,
    required this.fileType,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      child: Text(
        fileType.toUpperCase(),
        style: TextStyle(
          color: Colors.grey.shade400,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class InstalledBadge extends StatelessWidget {
  final bool isInstalled;
  final double size;

  const InstalledBadge({
    super.key,
    required this.isInstalled,
    this.size = 18,
  });

  @override
  Widget build(BuildContext context) {
    if (!isInstalled) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.greenAccent.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Icon(
        Icons.check,
        color: Colors.greenAccent,
        size: size - 6,
      ),
    );
  }
}
