import 'package:flutter/material.dart';
import '../smart_cover_image.dart';

/// Game cover art thumbnail with status overlay
class CoverThumbnail extends StatelessWidget {
  final List<String> coverUrls;
  final String? cachedUrl;
  final Color accentColor;
  final double size;
  final bool isComplete;
  final bool isFailed;
  final bool isCancelled;

  const CoverThumbnail({
    super.key,
    required this.coverUrls,
    this.cachedUrl,
    required this.accentColor,
    required this.size,
    this.isComplete = false,
    this.isFailed = false,
    this.isCancelled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _borderColor.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Cover image or fallback
            _buildImage(),
            // Status overlay
            if (isComplete || isFailed || isCancelled) _buildStatusOverlay(),
          ],
        ),
      ),
    );
  }

  Color get _borderColor {
    if (isComplete) return Colors.green;
    if (isFailed) return Colors.red;
    if (isCancelled) return Colors.grey;
    return accentColor;
  }

  Widget _buildImage() {
    if (coverUrls.isEmpty && cachedUrl == null) {
      return _buildFallback();
    }

    return SmartCoverImage(
      urls: coverUrls,
      cachedUrl: cachedUrl,
      fit: BoxFit.cover,
      placeholder: _buildFallback(),
      errorWidget: _buildFallback(),
    );
  }

  Widget _buildFallback() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor.withValues(alpha: 0.3),
            accentColor.withValues(alpha: 0.1),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.videogame_asset_rounded,
          color: accentColor.withValues(alpha: 0.6),
          size: size * 0.45,
        ),
      ),
    );
  }

  Widget _buildStatusOverlay() {
    final (overlayColor, icon) = isComplete
        ? (Colors.green, Icons.check_rounded)
        : isFailed
            ? (Colors.red, Icons.error_outline_rounded)
            : (Colors.grey, Icons.block_rounded);

    return Container(
      decoration: BoxDecoration(
        color: overlayColor.withValues(alpha: 0.7),
      ),
      child: Center(
        child: Icon(
          icon,
          color: Colors.white,
          size: size * 0.4,
        ),
      ),
    );
  }
}
