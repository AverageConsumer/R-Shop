import 'package:flutter/material.dart';

import '../../../models/game_item.dart';
import '../../../models/system_model.dart';
import '../../../utils/game_metadata.dart';
import '../../../widgets/installed_indicator.dart';
import '../../../widgets/smart_cover_image.dart';

class CoverSection extends StatelessWidget {
  final GameItem game;
  final SystemModel system;
  final List<String> coverUrls;
  final String? cachedUrl;
  final GameMetadataFull metadata;
  final bool isFavorite;
  final bool isInstalled;
  final bool hasThumbnail;

  const CoverSection({
    super.key,
    required this.game,
    required this.system,
    required this.coverUrls,
    this.cachedUrl,
    required this.metadata,
    this.isFavorite = false,
    this.isInstalled = false,
    this.hasThumbnail = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: Hero(
                  tag: game.filename,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: system.accentColor.withValues(alpha: 0.3),
                          blurRadius: 40,
                          spreadRadius: -5,
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          blurRadius: 25,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: SmartCoverImage(
                          urls: coverUrls,
                          cachedUrl: cachedUrl,
                          fit: BoxFit.contain,
                          hasThumbnail: hasThumbnail,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (isFavorite)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.redAccent.withValues(alpha: 0.5),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.favorite,
                      size: 18,
                      color: Colors.redAccent,
                    ),
                  ),
                ),
              if (isInstalled)
                const Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: InstalledLedStrip(
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
