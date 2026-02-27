import '../models/ra_models.dart';
import 'game_metadata.dart';

class RaNameMatcher {
  /// Normalize a name for RA matching.
  /// Strips extensions, regions, versions, brackets, and noise.
  static String normalize(String name) {
    // Strip file extension using existing utility
    var n = GameMetadata.cleanTitle(name);
    n = n.toLowerCase();
    // Replace common separators with spaces
    n = n.replaceAll(RegExp(r'[-_.]'), ' ');
    // Remove common noise words
    n = n.replaceAll(RegExp(r'\bthe\b'), '');
    // Collapse multiple spaces
    n = n.replaceAll(RegExp(r'\s+'), ' ').trim();
    return n;
  }

  /// Normalize a No-Intro ROM filename for matching.
  /// Strips the extension + region/version tags in parentheses.
  static String normalizeRomName(String romName) {
    var n = romName;
    // Strip extension
    final dotIdx = n.lastIndexOf('.');
    if (dotIdx > 0) n = n.substring(0, dotIdx);
    n = n.toLowerCase();
    // Remove parenthesized and bracketed content
    n = n.replaceAll(RegExp(r'\s*\([^)]*\)'), '');
    n = n.replaceAll(RegExp(r'\s*\[[^\]]*\]'), '');
    // Replace separators
    n = n.replaceAll(RegExp(r'[-_.]'), ' ');
    n = n.replaceAll(RegExp(r'\bthe\b'), '');
    n = n.replaceAll(RegExp(r'\s+'), ' ').trim();
    return n;
  }

  /// Find the best RA match for a ROM filename.
  /// Tries: exact match, contains match, ROM filename match, then fuzzy.
  static RaMatchResult? findBestMatch(
    String romFilename,
    List<RaGame> raGames, {
    Map<int, List<String>>? romNames,
  }) {
    final normalizedRom = normalize(romFilename);
    if (normalizedRom.isEmpty) return null;

    // 1. Exact match on normalized RA game title
    for (final game in raGames) {
      if (game.numAchievements <= 0) continue;
      final normalizedTitle = normalize(game.title);
      if (normalizedTitle == normalizedRom) {
        return RaMatchResult.nameMatch(game);
      }
    }

    // 2. Contains match (one contains the other, min 4 chars)
    if (normalizedRom.length >= 4) {
      RaGame? bestContains;
      int bestLen = 0;
      for (final game in raGames) {
        if (game.numAchievements <= 0) continue;
        final normalizedTitle = normalize(game.title);
        if (normalizedTitle.length < 4) continue;

        if (normalizedRom.contains(normalizedTitle) ||
            normalizedTitle.contains(normalizedRom)) {
          // Prefer the closest length match
          final lenDiff =
              (normalizedRom.length - normalizedTitle.length).abs();
          if (bestContains == null || lenDiff < bestLen) {
            bestContains = game;
            bestLen = lenDiff;
          }
        }
      }
      if (bestContains != null) {
        return RaMatchResult.nameMatch(bestContains);
      }
    }

    // 3. Match against No-Intro ROM filenames (from ra_hashes table)
    if (romNames != null) {
      for (final game in raGames) {
        if (game.numAchievements <= 0) continue;
        final names = romNames[game.raGameId];
        if (names == null) continue;
        for (final name in names) {
          final normalizedName = normalizeRomName(name);
          if (normalizedName == normalizedRom) {
            return RaMatchResult.nameMatch(game);
          }
        }
      }
    }

    // 4. Fuzzy match via Levenshtein (only for reasonable lengths)
    if (normalizedRom.length >= 3) {
      RaGame? bestFuzzy;
      double bestScore = 1.0;
      for (final game in raGames) {
        if (game.numAchievements <= 0) continue;
        final normalizedTitle = normalize(game.title);
        if (normalizedTitle.length < 3) continue;

        // Only compare if lengths are within 40% of each other
        final maxLen = normalizedRom.length > normalizedTitle.length
            ? normalizedRom.length
            : normalizedTitle.length;
        final minLen = normalizedRom.length < normalizedTitle.length
            ? normalizedRom.length
            : normalizedTitle.length;
        if (minLen < maxLen * 0.6) continue;

        final distance = levenshteinDistance(normalizedRom, normalizedTitle);
        final score = distance / maxLen;
        if (score < 0.2 && score < bestScore) {
          bestFuzzy = game;
          bestScore = score;
        }
      }
      if (bestFuzzy != null) {
        return RaMatchResult.nameMatch(bestFuzzy);
      }
    }

    return null;
  }

  /// Levenshtein distance between two strings.
  static int levenshteinDistance(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    // Use two-row optimization
    var prev = List.generate(t.length + 1, (i) => i);
    var curr = List.filled(t.length + 1, 0);

    for (var i = 1; i <= s.length; i++) {
      curr[0] = i;
      for (var j = 1; j <= t.length; j++) {
        final cost = s[i - 1] == t[j - 1] ? 0 : 1;
        curr[j] = _min3(
          prev[j] + 1,
          curr[j - 1] + 1,
          prev[j - 1] + cost,
        );
      }
      final temp = prev;
      prev = curr;
      curr = temp;
    }

    return prev[t.length];
  }

  static int _min3(int a, int b, int c) {
    if (a <= b && a <= c) return a;
    if (b <= c) return b;
    return c;
  }
}
