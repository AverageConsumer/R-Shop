import '../utils/game_metadata.dart';
import 'config/provider_config.dart';

class AlternativeSource {
  final String url;
  final ProviderConfig providerConfig;

  const AlternativeSource({required this.url, required this.providerConfig});
}

class GameItem {
  final String filename;
  final String displayName;
  final String url;
  final String? cachedCoverUrl;
  final ProviderConfig? providerConfig;
  final bool hasThumbnail;
  final List<AlternativeSource> alternativeSources;

  const GameItem({
    required this.filename,
    required this.displayName,
    required this.url,
    this.cachedCoverUrl,
    this.providerConfig,
    this.hasThumbnail = false,
    this.alternativeSources = const [],
  });

  GameItem copyWith({
    String? url,
    String? cachedCoverUrl,
    ProviderConfig? providerConfig,
    bool? hasThumbnail,
    List<AlternativeSource>? alternativeSources,
  }) {
    return GameItem(
      filename: filename,
      displayName: displayName,
      url: url ?? this.url,
      cachedCoverUrl: cachedCoverUrl ?? this.cachedCoverUrl,
      providerConfig: providerConfig ?? this.providerConfig,
      hasThumbnail: hasThumbnail ?? this.hasThumbnail,
      alternativeSources: alternativeSources ?? this.alternativeSources,
    );
  }

  factory GameItem.fromJson(Map<String, dynamic> json) {
    return GameItem(
      filename: json['filename'] as String,
      displayName: json['displayName'] as String,
      url: json['url'] as String,
      cachedCoverUrl: json['cachedCoverUrl'] as String?,
      providerConfig: json['providerConfig'] != null
          ? ProviderConfig.fromJson(
              json['providerConfig'] as Map<String, dynamic>)
          : null,
      hasThumbnail: json['hasThumbnail'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'filename': filename,
        'displayName': displayName,
        'url': url,
        if (cachedCoverUrl != null) 'cachedCoverUrl': cachedCoverUrl,
        if (providerConfig != null) 'providerConfig': providerConfig!.toJson(),
        if (hasThumbnail) 'hasThumbnail': hasThumbnail,
      };

  /// Re-injects auth credentials from system providers into games loaded
  /// from DB (which strips auth for security). Matches by provider type
  /// and connection details.
  static List<GameItem> rehydrateAuth(
    List<GameItem> games,
    List<ProviderConfig> providers,
  ) {
    if (providers.isEmpty) return games;
    return games.map((game) {
      final pc = game.providerConfig;
      if (pc == null || pc.auth != null) return game;
      final match = _findMatchingProvider(pc, providers);
      if (match?.auth == null) return game;
      return game.copyWith(providerConfig: pc.copyWith(auth: match!.auth));
    }).toList();
  }

  static ProviderConfig? _findMatchingProvider(
    ProviderConfig target,
    List<ProviderConfig> providers,
  ) {
    for (final p in providers) {
      if (p.type != target.type) continue;
      switch (target.type) {
        case ProviderType.web:
        case ProviderType.romm:
          if (p.url == target.url) return p;
        case ProviderType.smb:
          if (p.host == target.host && p.share == target.share) return p;
        case ProviderType.ftp:
          if (p.host == target.host) return p;
      }
    }
    return null;
  }

  static String cleanDisplayName(String filename) {
    return GameMetadata.cleanTitle(filename);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameItem && filename == other.filename && url == other.url;

  @override
  int get hashCode => Object.hash(filename, url);
}
