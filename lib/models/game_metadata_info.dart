class GameMetadataInfo {
  final String filename;
  final String systemSlug;
  final String? summary;
  final String? genres;
  final String? developer;
  final int? releaseYear;
  final String? gameModes;
  final double? rating;
  final int lastUpdated;

  const GameMetadataInfo({
    required this.filename,
    required this.systemSlug,
    this.summary,
    this.genres,
    this.developer,
    this.releaseYear,
    this.gameModes,
    this.rating,
    required this.lastUpdated,
  });

  bool get hasContent =>
      summary != null ||
      genres != null ||
      developer != null ||
      releaseYear != null;

  List<String> get genreList =>
      genres
          ?.split(',')
          .map((g) => g.trim())
          .where((g) => g.isNotEmpty)
          .toList() ??
      [];

  List<String> get gameModeList =>
      gameModes
          ?.split(',')
          .map((m) => m.trim())
          .where((m) => m.isNotEmpty)
          .toList() ??
      [];

  factory GameMetadataInfo.fromDbRow(Map<String, dynamic> row) {
    return GameMetadataInfo(
      filename: row['filename'] as String,
      systemSlug: row['system_slug'] as String,
      summary: row['summary'] as String?,
      genres: row['genres'] as String?,
      developer: row['developer'] as String?,
      releaseYear: row['release_year'] as int?,
      gameModes: row['game_modes'] as String?,
      rating: row['rating'] as double?,
      lastUpdated: row['last_updated'] as int,
    );
  }

  Map<String, dynamic> toDbRow() => {
        'filename': filename,
        'system_slug': systemSlug,
        'summary': summary,
        'genres': genres,
        'developer': developer,
        'release_year': releaseYear,
        'game_modes': gameModes,
        'rating': rating,
        'last_updated': lastUpdated,
      };
}
