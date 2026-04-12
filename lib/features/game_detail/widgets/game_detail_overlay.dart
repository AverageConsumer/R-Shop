import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/game_metadata_info.dart';
import '../../../core/responsive/responsive.dart';
import '../../../utils/game_metadata.dart';

/// Unified game info overlay showing RomM metadata and filename tags.
/// Opened via Quick Menu → Game Info.
class GameDetailOverlay extends StatelessWidget {
  final GameMetadataInfo? richMetadata;
  final GameMetadataFull fileMetadata;
  final String gameTitle;
  final Color accentColor;
  final VoidCallback onClose;

  const GameDetailOverlay({
    super.key,
    required this.richMetadata,
    required this.fileMetadata,
    required this.gameTitle,
    required this.accentColor,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final l = L.of(context);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.gameButtonB,
            includeRepeats: false): onClose,
        const SingleActivator(LogicalKeyboardKey.escape,
            includeRepeats: false): onClose,
        const SingleActivator(LogicalKeyboardKey.goBack,
            includeRepeats: false): onClose,
      },
      child: Focus(
        autofocus: true,
        child: Container(
          color: Colors.black.withValues(alpha: 0.85),
          child: SafeArea(
            child: Center(
              child: Container(
                margin: const EdgeInsets.all(24),
                constraints: BoxConstraints(
                  maxWidth: (rs.screenWidth - 48).clamp(280, 520),
                  maxHeight: (rs.screenHeight - 48).clamp(300, 600),
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHeader(),
                    const Divider(color: Colors.grey, height: 1),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: _buildContent(l),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded,
              color: accentColor.withValues(alpha: 0.7), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              gameTitle,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: onClose,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.close, color: Colors.white54, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(L l) {
    final meta = richMetadata;
    final hasTags = fileMetadata.allTags.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- RomM metadata section ---
        if (meta != null) ...[
          // Credits + date row
          if (meta.creditsLine != null || meta.releaseYear != null)
            _buildCreditsRow(meta),

          // Rating
          if (meta.rating != null) ...[
            const SizedBox(height: 8),
            _buildRating(meta.rating!),
          ],

          // Summary
          if (meta.summary != null) ...[
            const SizedBox(height: 14),
            Text(
              meta.summary!,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],

          // Detail rows
          if (_hasDetailRows(meta)) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Divider(
                  color: Colors.white.withValues(alpha: 0.08), height: 1),
            ),
            if (meta.franchiseList.isNotEmpty)
              _buildDetailRow(l.gameDetail_franchise, meta.franchiseList.join(', ')),
            if (meta.gameModeList.isNotEmpty)
              _buildDetailRow(l.gameDetail_gameModes, meta.gameModeList.join(', ')),
            if (meta.playerPerspectiveList.isNotEmpty)
              _buildDetailRow(
                  l.gameDetail_perspective, meta.playerPerspectiveList.join(', ')),
            if (meta.ageRating != null)
              _buildDetailRow(l.gameDetail_ageRating, meta.ageRating!),
            if (meta.themeList.isNotEmpty)
              _buildDetailRow(l.gameDetail_themes, meta.themeList.join(', ')),
          ],

          // Full genre list
          if (meta.genreList.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: meta.genreList
                  .map((genre) => _GenreChip(
                        label: genre,
                        accentColor: accentColor,
                      ))
                  .toList(),
            ),
          ],
        ],

        // --- File tags section ---
        if (hasTags) ...[
          if (meta != null && meta.hasContent) ...[
            const SizedBox(height: 14),
            Divider(
                color: Colors.white.withValues(alpha: 0.08), height: 1),
            const SizedBox(height: 14),
          ],
          _buildSectionLabel(l.gameDetail_fileTags),
          const SizedBox(height: 8),
          _buildTagSection(l.gameDetail_tagVersion, TagType.version),
          _buildTagSection(l.gameDetail_tagBuild, TagType.build),
          _buildTagSection(l.gameDetail_tagDisc, TagType.disc),
          _buildTagSection(l.gameDetail_tagQuality, TagType.quality),
          _buildTagSection(l.gameDetail_tagInfo, TagType.other),
          _buildTagSection(l.gameDetail_tagTechnical, TagType.secondary),
          _buildHiddenTagsSection(),
        ],
      ],
    );
  }

  bool _hasDetailRows(GameMetadataInfo meta) =>
      meta.franchiseList.isNotEmpty ||
      meta.gameModeList.isNotEmpty ||
      meta.playerPerspectiveList.isNotEmpty ||
      meta.ageRating != null ||
      meta.themeList.isNotEmpty;

  Widget _buildCreditsRow(GameMetadataInfo meta) {
    final credits = meta.creditsLine;
    return Row(
      children: [
        if (credits != null)
          Expanded(
            child: Text(
              credits,
              style: TextStyle(
                color: accentColor.withValues(alpha: 0.8),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        if (meta.releaseDate != null || meta.releaseYear != null) ...[
          if (credits != null) const SizedBox(width: 8),
          Text(
            _formatDate(meta),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  String _formatDate(GameMetadataInfo meta) {
    final date = meta.releaseDate;
    if (date != null && date.contains('-')) {
      final parts = date.split('-');
      if (parts.length >= 3) {
        const months = [
          '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
        ];
        final month = int.tryParse(parts[1]) ?? 0;
        final day = int.tryParse(parts[2]) ?? 0;
        final year = parts[0];
        if (month > 0 && month <= 12 && day > 0) {
          return '${months[month]} $day, $year';
        }
      }
    }
    if (meta.releaseYear != null) return '${meta.releaseYear}';
    return '';
  }

  Widget _buildRating(double rating) {
    final normalized = (rating / 20).clamp(0.0, 5.0);
    final full = normalized.floor();
    final fraction = normalized - full;

    return Row(
      children: [
        for (var i = 0; i < 5; i++)
          Icon(
            i < full
                ? Icons.star_rounded
                : (i == full && fraction >= 0.5)
                    ? Icons.star_half_rounded
                    : Icons.star_outline_rounded,
            color: accentColor.withValues(alpha: 0.7),
            size: 16,
          ),
        const SizedBox(width: 6),
        Text(
          '${rating.round()}',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 95,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        color: Colors.grey.shade400,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildTagSection(String label, TagType type) {
    final tags = fileMetadata.allTags.where((t) => t.type == type).toList();
    if (tags.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: tags.map((tag) => _TagChip(tag: tag)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHiddenTagsSection() {
    final hiddenTags = fileMetadata.hiddenTags;
    if (hiddenTags.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Region/Language',
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hiddenTags.map((t) => t.raw).join(' '),
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _GenreChip extends StatelessWidget {
  final String label;
  final Color accentColor;

  const _GenreChip({required this.label, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: accentColor.withValues(alpha: 0.9),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final TagInfo tag;

  const _TagChip({required this.tag});

  @override
  Widget build(BuildContext context) {
    final color = tag.getColor();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
      ),
      child: Text(
        tag.raw,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
