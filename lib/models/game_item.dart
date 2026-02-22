import '../utils/game_metadata.dart';
import 'config/provider_config.dart';

class GameItem {
  final String filename;
  final String displayName;
  final String url;
  final String? cachedCoverUrl;
  final ProviderConfig? providerConfig;
  final bool hasThumbnail;

  const GameItem({
    required this.filename,
    required this.displayName,
    required this.url,
    this.cachedCoverUrl,
    this.providerConfig,
    this.hasThumbnail = false,
  });

  GameItem copyWith({
    String? cachedCoverUrl,
    ProviderConfig? providerConfig,
    bool? hasThumbnail,
  }) {
    return GameItem(
      filename: filename,
      displayName: displayName,
      url: url,
      cachedCoverUrl: cachedCoverUrl ?? this.cachedCoverUrl,
      providerConfig: providerConfig ?? this.providerConfig,
      hasThumbnail: hasThumbnail ?? this.hasThumbnail,
    );
  }

  static String cleanDisplayName(String filename) {
    return GameMetadata.cleanTitle(filename);
  }
}
