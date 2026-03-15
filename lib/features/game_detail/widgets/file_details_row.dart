import 'package:flutter/material.dart';

import '../../../core/responsive/responsive.dart';
import '../../../models/game_metadata_info.dart';
import '../../../utils/game_metadata.dart';

/// Compact inline row showing region, language, format, and file size.
/// Displayed between badges and summary sections.
class FileDetailsRow extends StatelessWidget {
  final GameMetadataFull fileMetadata;
  final GameMetadataInfo? richMetadata;

  const FileDetailsRow({
    super.key,
    required this.fileMetadata,
    this.richMetadata,
  });

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final fontSize = rs.isSmall ? 11.0 : 13.0;
    final iconSize = rs.isSmall ? 14.0 : 16.0;

    return Wrap(
      spacing: rs.isSmall ? 10 : 14,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Region with flag
        _DetailChip(
          children: [
            Text(fileMetadata.region.flag,
                style: TextStyle(fontSize: fontSize)),
            const SizedBox(width: 4),
            Text(
              fileMetadata.region.name.toUpperCase(),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: rs.isSmall ? 9 : 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        // Languages
        if (fileMetadata.languages.isNotEmpty)
          _DetailChip(
            children: [
              Icon(Icons.language, color: Colors.white38, size: iconSize),
              const SizedBox(width: 4),
              ...fileMetadata.languages.take(2).map((lang) => Padding(
                    padding: const EdgeInsets.only(right: 2),
                    child:
                        Text(lang.flag, style: TextStyle(fontSize: fontSize)),
                  )),
              if (fileMetadata.languages.length > 2)
                Text(
                  '+${fileMetadata.languages.length - 2}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: rs.isSmall ? 9 : 10,
                  ),
                ),
            ],
          ),
        // File format
        Text(
          fileMetadata.fileType.toUpperCase(),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: rs.isSmall ? 10 : 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        // File size (from RomM)
        if (richMetadata?.formattedFileSize != null)
          Text(
            richMetadata!.formattedFileSize!,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: rs.isSmall ? 10 : 12,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}

class _DetailChip extends StatelessWidget {
  final List<Widget> children;

  const _DetailChip({required this.children});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}
