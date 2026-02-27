import '../models/system_model.dart';

class ImageHelper {
  static final _gameExtensions = SystemModel.allGameExtensions;
  static const String _baseUrl =
      'https://raw.githubusercontent.com/libretro-thumbnails/';

  static const _fallbackRegions = ['(USA)', '(Europe)', '(Japan)'];

  /// Characters that RetroArch replaces with underscore in thumbnail filenames.
  static final _libretroSanitizePattern = RegExp(r'[&*/:`"<>?\\|]');

  /// Leading articles that No-Intro convention moves to end of title.
  static const _articles = ['The', 'A', 'An'];

  static List<String> getCoverUrls(SystemModel system, List<String> filenames) {
    if (system.libretroId.isEmpty) return [];

    final urls = <String>[];
    final seen = <String>{};

    void addUrl(String name) {
      if (name.isEmpty) return;
      final encoded = Uri.encodeComponent(name);
      final url =
          '$_baseUrl${system.libretroId}/master/Named_Boxarts/$encoded.png';
      if (seen.add(url)) urls.add(url);
    }

    void addWithVariants(String name) {
      if (name.isEmpty) return;
      addUrl(name);
      final inverted = _invertArticle(name);
      if (inverted != null) addUrl(inverted);
      final colonFixed = _colonToHyphen(name);
      if (colonFixed != null) {
        addUrl(colonFixed);
        final colonInverted = _invertArticle(colonFixed);
        if (colonInverted != null) addUrl(colonInverted);
      }
      final sanitized = _sanitizeForLibretro(name);
      if (sanitized != name) {
        addUrl(sanitized);
        final sanitizedInverted = _invertArticle(sanitized);
        if (sanitizedInverted != null) addUrl(sanitizedInverted);
      }
    }

    if (filenames.isNotEmpty) {
      final regionClean = _getRegionCleanName(filenames.first);
      final primaryRegion = _getPrimaryRegionName(filenames.first);
      final naive = _getNaiveCleanName(filenames.first);

      // 1. Region-clean + variants (most common match)
      addWithVariants(regionClean);
      // 2. Primary region + variants
      addWithVariants(primaryRegion);
      // 3. Naive clean + variants
      addWithVariants(naive);
    }

    // 4. Raw filenames
    for (final filename in filenames) {
      addUrl(_removeExtension(filename));
    }

    if (filenames.isNotEmpty) {
      final naive = _getNaiveCleanName(filenames.first);

      // 5. Fallback regions (when no parenthetical info)
      if (!_hasParens(filenames.first)) {
        for (final region in _fallbackRegions) {
          addWithVariants('$naive $region');
        }
      }

      // 6. Extended region combinations
      final regionClean = _getRegionCleanName(filenames.first);
      if (regionClean.isNotEmpty) {
        final combo = _getExtendedRegionName(filenames.first);
        if (combo != null) addWithVariants(combo);
      }
    }

    return urls;
  }

  static List<String> getCoverUrlsForSingle(
      SystemModel system, String gameFilename) {
    if (system.libretroId.isEmpty) return [];

    final urls = <String>[];
    final seen = <String>{};

    void addUrl(String name) {
      if (name.isEmpty) return;
      final encoded = Uri.encodeComponent(name);
      final url =
          '$_baseUrl${system.libretroId}/master/Named_Boxarts/$encoded.png';
      if (seen.add(url)) urls.add(url);
    }

    void addWithVariants(String name) {
      if (name.isEmpty) return;
      addUrl(name);
      final inverted = _invertArticle(name);
      if (inverted != null) addUrl(inverted);
      final colonFixed = _colonToHyphen(name);
      if (colonFixed != null) {
        addUrl(colonFixed);
        final colonInverted = _invertArticle(colonFixed);
        if (colonInverted != null) addUrl(colonInverted);
      }
      final sanitized = _sanitizeForLibretro(name);
      if (sanitized != name) {
        addUrl(sanitized);
        final sanitizedInverted = _invertArticle(sanitized);
        if (sanitizedInverted != null) addUrl(sanitizedInverted);
      }
    }

    final regionClean = _getRegionCleanName(gameFilename);
    final primaryRegion = _getPrimaryRegionName(gameFilename);
    final naive = _getNaiveCleanName(gameFilename);

    // 1. Region-clean + variants
    addWithVariants(regionClean);
    // 2. Primary region + variants
    addWithVariants(primaryRegion);
    // 3. Naive clean + variants
    addWithVariants(naive);
    // 4. Raw filename
    addUrl(_removeExtension(gameFilename));

    // 5. Fallback regions
    if (!_hasParens(gameFilename)) {
      for (final region in _fallbackRegions) {
        addWithVariants('$naive $region');
      }
    }

    // 6. Extended region combinations
    if (regionClean.isNotEmpty) {
      final combo = _getExtendedRegionName(gameFilename);
      if (combo != null) addWithVariants(combo);
    }

    return urls;
  }

  /// RetroArch sanitization: replaces &*/:`"<>?\| with underscore.
  static String _sanitizeForLibretro(String name) {
    return name.replaceAll(_libretroSanitizePattern, '_');
  }

  /// Inverts leading article: "The Legend of Zelda (USA)" → "Legend of Zelda, The (USA)".
  /// Works on the title part only (before any parenthetical region tag).
  /// Returns null if no article found or name already has trailing article.
  static String? _invertArticle(String name) {
    // Split into title and region parts
    final parenIndex = name.indexOf('(');
    final title = parenIndex >= 0 ? name.substring(0, parenIndex).trim() : name;
    final suffix = parenIndex >= 0 ? ' ${name.substring(parenIndex)}' : '';

    for (final article in _articles) {
      if (title.startsWith('$article ') && title.length > article.length + 1) {
        final rest = title.substring(article.length + 1);
        return '$rest, $article$suffix';
      }
    }
    return null;
  }

  /// Converts colons to " - ": "Castlevania: Symphony" → "Castlevania - Symphony".
  /// Returns null if no colon found.
  static String? _colonToHyphen(String name) {
    if (!name.contains(':')) return null;
    // Replace ": " or ":" with " - "
    return name.replaceAll(RegExp(r':\s*'), ' - ');
  }

  /// For single-region names, tries the combined "USA, Europe" form.
  /// "(USA)" → "(USA, Europe)", "(Europe)" → "(USA, Europe)".
  /// Returns null if not applicable.
  static String? _getExtendedRegionName(String filename) {
    var name = _removeExtension(filename);
    final match = RegExp(r'\(([^)]*)\)').firstMatch(name);
    if (match == null) return null;
    final content = match.group(1)!;
    // Only extend single-region tags
    if (content.contains(',')) return null;
    final region = content.trim();
    final baseName = name.substring(0, match.start).trim();
    if (region == 'USA') {
      return '$baseName (USA, Europe)';
    } else if (region == 'Europe') {
      return '$baseName (USA, Europe)';
    }
    return null;
  }

  static bool _hasParens(String filename) =>
      RegExp(r'\(').hasMatch(_removeExtension(filename));

  /// Keeps only the first parenthetical group (usually region like "(USA)"),
  /// strips all other parens and brackets.
  /// Normalizes comma spacing: "(USA,Europe)" → "(USA, Europe)".
  static String _getRegionCleanName(String filename) {
    var name = _removeExtension(filename);
    final match = RegExp(r'\(([^)]*)\)').firstMatch(name);
    if (match == null) return '';
    final baseName = name.substring(0, match.start).trim();
    var content = match.group(1)!;
    // Normalize: add space after commas if missing (libretro uses "USA, Europe")
    content = content.replaceAll(RegExp(r',(?!\s)'), ', ');
    return '$baseName ($content)';
  }

  /// For multi-region tags like "(USA,Europe)", extracts just the first region "(USA)".
  static String _getPrimaryRegionName(String filename) {
    var name = _removeExtension(filename);
    final match = RegExp(r'\(([^)]*)\)').firstMatch(name);
    if (match == null) return '';
    final content = match.group(1)!;
    if (!content.contains(',')) return '';
    final primaryRegion = content.split(',').first.trim();
    final baseName = name.substring(0, match.start).trim();
    return '$baseName ($primaryRegion)';
  }

  static String _getNaiveCleanName(String filename) {
    var name = _removeExtension(filename);

    name = name.replaceAll(RegExp(r'\s*\([^)]*\)'), '');
    name = name.replaceAll(RegExp(r'\s*\[[^\]]*\]'), '');
    name = name.replaceAll(RegExp(r'\s+'), ' ').trim();

    return name;
  }

  static String _removeExtension(String filename) {
    var name = filename;

    for (final ext in _gameExtensions) {
      if (name.toLowerCase().endsWith(ext)) {
        name = name.substring(0, name.length - ext.length);
        break;
      }
    }

    return name.trim();
  }
}
