class GameItem {
  final String filename;
  final String displayName;
  final String url;
  final String? cachedCoverUrl;

  const GameItem({
    required this.filename,
    required this.displayName,
    required this.url,
    this.cachedCoverUrl,
  });

  GameItem copyWith({String? cachedCoverUrl}) {
    return GameItem(
      filename: filename,
      displayName: displayName,
      url: url,
      cachedCoverUrl: cachedCoverUrl ?? this.cachedCoverUrl,
    );
  }

  static String cleanDisplayName(String filename) {
    var name = filename;

    final extensions = ['.zip', '.7z', '.3ds', '.rar', '.iso'];
    for (final ext in extensions) {
      if (name.toLowerCase().endsWith(ext)) {
        name = name.substring(0, name.length - ext.length);
        break;
      }
    }

    name = name.replaceAll(RegExp(r'\s*\([^)]*\)'), '');
    name = name.replaceAll(RegExp(r'\s*\[[^\]]*\]'), '');

    name = name.replaceAll('_', ' ');
    name = name.replaceAll(RegExp(r'\s+'), ' ').trim();

    return name;
  }
}
