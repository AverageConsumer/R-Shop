import 'package:flutter/material.dart';

import '../../../core/responsive/responsive.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/game_metadata.dart';
import 'metadata_badges.dart';
import 'section_header.dart';

/// Shows file tags (version, build, disc, quality, etc.) in a card.
/// Region/language/format/size are handled by FileDetailsRow inline.
class DetailsSection extends StatelessWidget {
  final GameMetadataFull fileMetadata;

  const DetailsSection({
    super.key,
    required this.fileMetadata,
  });

  @override
  Widget build(BuildContext context) {
    if (fileMetadata.primaryTags.isEmpty) return const SizedBox.shrink();

    final rs = context.rs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(label: L.of(context).gameDetail_details),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(rs.spacing.md),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(rs.radius.md),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: TagBadges(
            tags: fileMetadata.primaryTags,
            maxVisible: 6,
          ),
        ),
      ],
    );
  }
}
