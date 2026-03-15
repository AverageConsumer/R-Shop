import 'dart:convert';

class SiblingInfo {
  final String name;
  final String? filename;

  const SiblingInfo({required this.name, this.filename});

  factory SiblingInfo.fromJson(Map<String, dynamic> json) {
    return SiblingInfo(
      name: json['name'] as String? ?? '',
      filename: json['filename'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        if (filename != null) 'filename': filename,
      };
}

class GameMetadataInfo {
  final String filename;
  final String systemSlug;
  final String? summary;
  final String? genres;
  final String? developer;
  final String? publisher;
  final int? releaseYear;
  final String? releaseDate;
  final String? gameModes;
  final double? rating;
  final String? franchises;
  final String? themes;
  final String? playerPerspectives;
  final String? ageRating;
  final String? screenshots;
  final int? fileSizeBytes;
  final String? siblings;
  final int lastUpdated;

  const GameMetadataInfo({
    required this.filename,
    required this.systemSlug,
    this.summary,
    this.genres,
    this.developer,
    this.publisher,
    this.releaseYear,
    this.releaseDate,
    this.gameModes,
    this.rating,
    this.franchises,
    this.themes,
    this.playerPerspectives,
    this.ageRating,
    this.screenshots,
    this.fileSizeBytes,
    this.siblings,
    required this.lastUpdated,
  });

  bool get hasContent =>
      summary != null ||
      genres != null ||
      developer != null ||
      releaseYear != null ||
      rating != null ||
      franchises != null ||
      themes != null ||
      screenshots != null;

  /// Whether enough metadata exists to show the compact card.
  bool get hasCardContent =>
      summary != null ||
      genres != null ||
      developer != null ||
      publisher != null ||
      releaseYear != null ||
      rating != null;

  /// Combined credits line: "Developer / Publisher" or just developer.
  String? get creditsLine {
    if (developer == null) return publisher;
    if (publisher == null) return developer;
    return '$developer / $publisher';
  }

  List<String> get genreList => _splitCsv(genres);

  List<String> get gameModeList => _splitCsv(gameModes);

  List<String> get franchiseList => _splitCsv(franchises);

  List<String> get themeList => _splitCsv(themes);

  List<String> get playerPerspectiveList => _splitCsv(playerPerspectives);

  /// Screenshot URLs from RomM (comma-separated in DB).
  List<String> get screenshotUrlList => _splitCsv(screenshots);

  /// Parsed sibling info from RomM (JSON array in DB).
  List<SiblingInfo> get siblingList {
    if (siblings == null || siblings!.isEmpty) return const [];
    try {
      final list = jsonDecode(siblings!) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map((e) => SiblingInfo.fromJson(e))
          .toList();
    } catch (e) {
      return const [];
    }
  }

  /// Formatted file size string (e.g. "256 MB").
  String? get formattedFileSize {
    if (fileSizeBytes == null) return null;
    final bytes = fileSizeBytes!;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  static List<String> _splitCsv(String? value) =>
      value
          ?.split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList() ??
      [];

  factory GameMetadataInfo.fromDbRow(Map<String, dynamic> row) {
    return GameMetadataInfo(
      filename: row['filename'] as String,
      systemSlug: row['system_slug'] as String,
      summary: row['summary'] as String?,
      genres: row['genres'] as String?,
      developer: row['developer'] as String?,
      publisher: row['publisher'] as String?,
      releaseYear: row['release_year'] as int?,
      releaseDate: row['release_date'] as String?,
      gameModes: row['game_modes'] as String?,
      rating: row['rating'] as double?,
      franchises: row['franchises'] as String?,
      themes: row['themes'] as String?,
      playerPerspectives: row['player_perspectives'] as String?,
      ageRating: row['age_rating'] as String?,
      screenshots: row['screenshots'] as String?,
      fileSizeBytes: row['file_size'] as int?,
      siblings: row['siblings'] as String?,
      lastUpdated: row['last_updated'] as int,
    );
  }

  Map<String, dynamic> toDbRow() => {
        'filename': filename,
        'system_slug': systemSlug,
        'summary': summary,
        'genres': genres,
        'developer': developer,
        'publisher': publisher,
        'release_year': releaseYear,
        'release_date': releaseDate,
        'game_modes': gameModes,
        'rating': rating,
        'franchises': franchises,
        'themes': themes,
        'player_perspectives': playerPerspectives,
        'age_rating': ageRating,
        'screenshots': screenshots,
        'file_size': fileSizeBytes,
        'siblings': siblings,
        'last_updated': lastUpdated,
      };
}
