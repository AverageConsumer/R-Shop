import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../utils/game_metadata.dart';

/// Downloads and caches the libretro thumbnail directory index per system,
/// then provides fuzzy matching against available thumbnail names.
class ThumbnailIndexService {
  static const Duration _cacheTtl = Duration(days: 7);
  static const double _matchThreshold = 0.85;
  static const String _baseUrl = 'https://thumbnails.libretro.com/';

  /// Characters that RetroArch replaces with underscore in thumbnail filenames.
  static final _libretroSanitizePattern = RegExp(r'[&*/:`"<>?\\|]');

  final _httpClient = HttpClient();

  /// In-memory cache: libretroId → list of thumbnail names (without .png).
  final Map<String, List<String>> _memoryCache = {};

  /// Returns the cached index for a system, or null if not loaded.
  List<String>? getIndex(String libretroId) => _memoryCache[libretroId];

  /// Loads the thumbnail index for a system. Uses disk cache if fresh,
  /// otherwise downloads from thumbnails.libretro.com.
  Future<List<String>?> loadIndex(String libretroId) async {
    // Check memory cache first
    if (_memoryCache.containsKey(libretroId)) {
      return _memoryCache[libretroId];
    }

    try {
      // Check disk cache
      final cacheFile = await _getCacheFile(libretroId);
      if (cacheFile.existsSync()) {
        final cached = await _readDiskCache(cacheFile);
        if (cached != null) {
          _memoryCache[libretroId] = cached;
          return cached;
        }
      }

      // Download fresh index
      final names = await _downloadIndex(libretroId);
      if (names != null && names.isNotEmpty) {
        _memoryCache[libretroId] = names;
        await _writeDiskCache(cacheFile, names);
        return names;
      }
      return null;
    } catch (e) {
      debugPrint('ThumbnailIndexService: loadIndex failed for $libretroId: $e');
      return null;
    }
  }

  /// Finds the best fuzzy match for [gameName] in the index for [libretroId].
  /// Returns the matched thumbnail name or null if no match above threshold.
  String? findBestMatch(String libretroId, String gameName) {
    final index = _memoryCache[libretroId];
    if (index == null || index.isEmpty) return null;

    final normalizedQuery = _normalizeForMatching(gameName);
    if (normalizedQuery.isEmpty) return null;

    String? bestMatch;
    double bestScore = 0;

    for (final candidate in index) {
      final normalizedCandidate = _normalizeForMatching(candidate);
      if (normalizedCandidate.isEmpty) continue;

      final score = tokenSetRatio(normalizedQuery, normalizedCandidate);
      if (score > bestScore) {
        bestScore = score;
        bestMatch = candidate;
      }
      // Perfect match — stop early
      if (score >= 1.0) break;
    }

    return bestScore >= _matchThreshold ? bestMatch : null;
  }

  /// Builds the full cover URL for a matched thumbnail name.
  static String buildUrl(String libretroId, String thumbnailName) {
    final encoded = Uri.encodeComponent(thumbnailName);
    return 'https://raw.githubusercontent.com/libretro-thumbnails/'
        '$libretroId/master/Named_Boxarts/$encoded.png';
  }

  // ---------------------------------------------------------------------------
  // Index download & parsing
  // ---------------------------------------------------------------------------

  Future<List<String>?> _downloadIndex(String libretroId) async {
    // thumbnails.libretro.com uses spaces, not underscores
    final systemName = libretroId.replaceAll('_', ' ');
    final url = '$_baseUrl${Uri.encodeComponent(systemName)}/Named_Boxarts/';

    try {
      final request = await _httpClient.getUrl(Uri.parse(url));
      final response = await request.close().timeout(
        const Duration(seconds: 30),
      );

      if (response.statusCode != 200) {
        await response.drain<void>();
        debugPrint(
            'ThumbnailIndexService: HTTP ${response.statusCode} for $url');
        return null;
      }

      final body = await response.transform(utf8.decoder).join();
      return parseDirectoryListing(body);
    } catch (e) {
      debugPrint('ThumbnailIndexService: download failed for $libretroId: $e');
      return null;
    }
  }

  /// Parses an Apache-style HTML directory listing, extracting .png filenames.
  @visibleForTesting
  static List<String> parseDirectoryListing(String html) {
    final names = <String>[];
    // Match href="...something.png" in anchor tags
    final hrefPattern = RegExp(r'href="([^"]*\.png)"', caseSensitive: false);

    for (final match in hrefPattern.allMatches(html)) {
      var href = match.group(1)!;

      // Security: skip directory traversal attempts
      if (href.contains('..') || href.contains('/')) continue;
      // Security: skip oversized hrefs (>300 chars)
      if (href.length > 300) continue;

      // URL-decode the href
      try {
        href = Uri.decodeComponent(href);
      } catch (e) {
        debugPrint('ThumbnailIndexService: failed to decode href: $e');
        continue;
      }

      // Security: skip control characters (check after URL-decoding)
      if (RegExp(r'[\x00-\x1F]').hasMatch(href)) continue;

      // Strip .png extension
      if (href.toLowerCase().endsWith('.png')) {
        href = href.substring(0, href.length - 4);
      }

      if (href.isNotEmpty) {
        names.add(href);
      }
    }

    return names;
  }

  // ---------------------------------------------------------------------------
  // Disk caching
  // ---------------------------------------------------------------------------

  Future<File> _getCacheFile(String libretroId) async {
    final cacheDir = await getTemporaryDirectory();
    final indexDir = Directory('${cacheDir.path}/thumbnail_indexes');
    if (!indexDir.existsSync()) {
      indexDir.createSync(recursive: true);
    }
    return File('${indexDir.path}/$libretroId.json');
  }

  Future<List<String>?> _readDiskCache(File file) async {
    try {
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;

      final timestamp = json['timestamp'] as int?;
      if (timestamp == null) return null;

      final cachedAt = DateTime.fromMillisecondsSinceEpoch(timestamp);
      if (DateTime.now().difference(cachedAt) > _cacheTtl) return null;

      final names = (json['names'] as List<dynamic>?)?.cast<String>();
      return names;
    } catch (e) {
      debugPrint('ThumbnailIndexService: disk cache read failed: $e');
      return null;
    }
  }

  Future<void> _writeDiskCache(File file, List<String> names) async {
    try {
      final json = jsonEncode({
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'names': names,
      });
      await file.writeAsString(json);
    } catch (e) {
      debugPrint('ThumbnailIndexService: disk cache write failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Fuzzy matching: Token Set Ratio
  // ---------------------------------------------------------------------------

  /// Normalizes a game name for fuzzy comparison:
  /// lowercase, strip region tags/brackets, remove diacritics, sanitize.
  @visibleForTesting
  static String normalizeForMatching(String name) =>
      _normalizeForMatching(name);

  static String _normalizeForMatching(String name) {
    // Strip region tags and brackets
    var normalized = name.replaceAll(RegExp(r'\s*\([^)]*\)'), '');
    normalized = normalized.replaceAll(RegExp(r'\s*\[[^\]]*\]'), '');
    // Remove diacritics
    normalized = GameMetadata.removeDiacritics(normalized);
    // Lowercase
    normalized = normalized.toLowerCase();
    // RetroArch sanitization characters → space (for tokenization)
    normalized = normalized.replaceAll(_libretroSanitizePattern, ' ');
    // Collapse whitespace
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized;
  }

  /// Token Set Ratio: fuzzy comparison that handles word reordering.
  /// Returns a value between 0.0 (no match) and 1.0 (perfect match).
  @visibleForTesting
  static double tokenSetRatio(String a, String b) {
    final tokensA = _tokenize(a);
    final tokensB = _tokenize(b);

    if (tokensA.isEmpty && tokensB.isEmpty) return 1.0;
    if (tokensA.isEmpty || tokensB.isEmpty) return 0.0;

    // Compute intersection and differences
    final intersection = tokensA.intersection(tokensB).toList()..sort();
    final diffA = tokensA.difference(tokensB).toList()..sort();
    final diffB = tokensB.difference(tokensA).toList()..sort();

    final intersectionStr = intersection.join(' ');
    final combinedA = [intersectionStr, ...diffA].join(' ').trim();
    final combinedB = [intersectionStr, ...diffB].join(' ').trim();

    // Compute Levenshtein ratio on three combinations
    final r1 = _levenshteinRatio(intersectionStr, combinedA);
    final r2 = _levenshteinRatio(intersectionStr, combinedB);
    final r3 = _levenshteinRatio(combinedA, combinedB);

    return math.max(r1, math.max(r2, r3));
  }

  static Set<String> _tokenize(String s) {
    return s.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toSet();
  }

  /// Returns similarity ratio: 1.0 for identical strings, 0.0 for completely different.
  @visibleForTesting
  static double levenshteinRatio(String a, String b) =>
      _levenshteinRatio(a, b);

  static double _levenshteinRatio(String a, String b) {
    if (a == b) return 1.0;
    final maxLen = math.max(a.length, b.length);
    if (maxLen == 0) return 1.0;
    final dist = _levenshteinDistance(a, b);
    return 1.0 - (dist / maxLen);
  }

  /// Standard Levenshtein distance using two-row optimization.
  static int _levenshteinDistance(String a, String b) {
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    // Ensure a is the shorter string for space optimization
    if (a.length > b.length) {
      final temp = a;
      a = b;
      b = temp;
    }

    final m = a.length;
    final n = b.length;
    var prev = List<int>.generate(m + 1, (i) => i);
    var curr = List<int>.filled(m + 1, 0);

    for (var j = 1; j <= n; j++) {
      curr[0] = j;
      for (var i = 1; i <= m; i++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        curr[i] = math.min(
          math.min(curr[i - 1] + 1, prev[i] + 1),
          prev[i - 1] + cost,
        );
      }
      final temp = prev;
      prev = curr;
      curr = temp;
    }

    return prev[m];
  }

  void dispose() {
    _httpClient.close(force: true);
    _memoryCache.clear();
  }
}
