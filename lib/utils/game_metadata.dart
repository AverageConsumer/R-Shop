import 'package:flutter/material.dart';

enum TagType { version, build, disc, quality, other, secondary, hidden }

class TagInfo {
  final String raw;
  final String content;
  final TagType type;

  const TagInfo({
    required this.raw,
    required this.content,
    required this.type,
  });

  Color getColor() {
    switch (type) {
      case TagType.version:
        return Colors.blue;
      case TagType.build:
        return Colors.orange;
      case TagType.disc:
        return Colors.purple;
      case TagType.quality:
        return Colors.redAccent;
      case TagType.other:
        return Colors.teal;
      case TagType.secondary:
        return Colors.grey;
      case TagType.hidden:
        return Colors.transparent;
    }
  }

  String getCategoryLabel() {
    switch (type) {
      case TagType.version:
        return 'Version';
      case TagType.build:
        return 'Build';
      case TagType.disc:
        return 'Disc';
      case TagType.quality:
        return 'Quality';
      case TagType.other:
        return 'Info';
      case TagType.secondary:
        return 'Technical';
      case TagType.hidden:
        return 'Region/Language';
    }
  }
}

class GameMetadata {
  static String cleanTitle(String filename) {
    var name = filename;

    final extensions = [
      '.zip',
      '.7z',
      '.rvz',
      '.3ds',
      '.iso',
      '.rar',
      '.chd',
      '.z64',
      '.gba',
      '.gbc',
      '.gb',
      '.sfc',
      '.nds',
      '.nsp',
      '.xci',
      '.cso'
    ];
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

  static RegionInfo extractRegion(String filename) {
    final regionPatterns = _getOrderedRegionPatterns();

    // First try exact single-region patterns
    for (final entry in regionPatterns) {
      for (final pattern in entry.patterns) {
        if (RegExp(pattern, caseSensitive: false).hasMatch(filename)) {
          return RegionInfo(
            name: entry.regionName,
            flag: entry.flag,
          );
        }
      }
    }

    // Try comma-separated multi-region tags like (USA,Europe) or (Usa,Europe)
    final multiMatch =
        RegExp(r'\(([^)]+,[^)]+)\)', caseSensitive: false).firstMatch(filename);
    if (multiMatch != null) {
      final content = multiMatch.group(1)!;
      final parts = content.split(',').map((p) => p.trim()).toList();
      final matched = <_RegionPattern>[];
      for (final part in parts) {
        final region = _findRegionByName(part);
        if (region != null) {
          matched.add(region);
        }
      }
      if (matched.isNotEmpty && matched.length == parts.length) {
        return RegionInfo(
          name: matched.map((r) => r.regionName).join(' / '),
          flag: matched.map((r) => r.flag).join(''),
        );
      }
    }

    return const RegionInfo(name: 'Unknown', flag: '🌐');
  }

  static _RegionPattern? _findRegionByName(String name) {
    final lower = name.toLowerCase();
    for (final entry in _getOrderedRegionPatterns()) {
      if (entry.regionName.toLowerCase() == lower) return entry;
      // Also match short codes (JP, US, EUR, etc.)
      for (final pattern in entry.patterns) {
        // Extract the content from patterns like \(USA\) → USA
        final inner = RegExp(r'[(\[](.*?)[)\]]')
            .firstMatch(pattern.replaceAll(r'\', ''));
        if (inner != null && inner.group(1)!.toLowerCase() == lower) {
          return entry;
        }
      }
    }
    return null;
  }

  static List<_RegionPattern> _getOrderedRegionPatterns() {
    return const [
      _RegionPattern('Japan', '🇯🇵', [
        r'\(Japan\)',
        r'\(J\)',
        r'\(JP\)',
        r'\[Japan\]',
        r'\[J\]',
      ]),
      _RegionPattern('USA', '🇺🇸', [
        r'\(USA\)',
        r'\(U\)',
        r'\(US\)',
        r'\[USA\]',
        r'\[U\]',
      ]),
      _RegionPattern('Europe', '🇪🇺', [
        r'\(Europe\)',
        r'\(EUR\)',
        r'\(E\)',
        r'\(EU\)',
        r'\[Europe\]',
        r'\[EUR\]',
      ]),
      _RegionPattern('Germany', '🇩🇪', [
        r'\(Germany\)',
        r'\(DE\)',
        r'\[Germany\]',
      ]),
      _RegionPattern('France', '🇫🇷', [
        r'\(France\)',
        r'\(FR\)',
        r'\[France\]',
      ]),
      _RegionPattern('Spain', '🇪🇸', [
        r'\(Spain\)',
        r'\(ES\)',
        r'\[Spain\]',
      ]),
      _RegionPattern('Italy', '🇮🇹', [
        r'\(Italy\)',
        r'\(IT\)',
        r'\[Italy\]',
      ]),
      _RegionPattern('UK', '🇬🇧', [
        r'\(UK\)',
        r'\(United Kingdom\)',
        r'\[UK\]',
      ]),
      _RegionPattern('Australia', '🇦🇺', [
        r'\(Australia\)',
        r'\(AU\)',
        r'\[Australia\]',
      ]),
      _RegionPattern('Canada', '🇨🇦', [
        r'\(Canada\)',
        r'\(CA\)',
        r'\[Canada\]',
      ]),
      _RegionPattern('Brazil', '🇧🇷', [
        r'\(Brazil\)',
        r'\(BR\)',
        r'\[Brazil\]',
      ]),
      _RegionPattern('Korea', '🇰🇷', [
        r'\(Korea\)',
        r'\(KR\)',
        r'\[Korea\]',
      ]),
      _RegionPattern('China', '🇨🇳', [
        r'\(China\)',
        r'\(CH\)',
        r'\(CN\)',
        r'\[China\]',
      ]),
      _RegionPattern('Taiwan', '🇹🇼', [
        r'\(Taiwan\)',
        r'\(TW\)',
        r'\[Taiwan\]',
      ]),
      _RegionPattern('Hong Kong', '🇭🇰', [
        r'\(Hong Kong\)',
        r'\(HK\)',
        r'\[Hong Kong\]',
      ]),
      _RegionPattern('Norway', '🇳🇴', [
        r'\(Norway\)',
        r'\(NOR\)',
        r'\[Norway\]',
      ]),
      _RegionPattern('Sweden', '🇸🇪', [
        r'\(Sweden\)',
        r'\(SWE\)',
        r'\[Sweden\]',
      ]),
      _RegionPattern('Denmark', '🇩🇰', [
        r'\(Denmark\)',
        r'\(DK\)',
        r'\[Denmark\]',
      ]),
      _RegionPattern('Finland', '🇫🇮', [
        r'\(Finland\)',
        r'\(FI\)',
        r'\[Finland\]',
      ]),
      _RegionPattern('Netherlands', '🇳🇱', [
        r'\(Netherlands\)',
        r'\(NL\)',
        r'\[Netherlands\]',
      ]),
      _RegionPattern('World', '🌍', [
        r'\(World\)',
        r'\[World\]',
      ]),
    ];
  }

  static List<LanguageInfo> extractLanguages(String filename) {
    final languages = <LanguageInfo>[];

    final allMatches = RegExp(r'\(([A-Za-z,]+)\)').allMatches(filename);
    for (final match in allMatches) {
      final langStr = match.group(1) ?? '';
      final parts = langStr.split(',');

      for (final part in parts) {
        final trimmed = part.trim();
        final langInfo = _getLanguageByCode(trimmed);
        if (langInfo != null && !languages.any((l) => l.code == trimmed)) {
          languages.add(langInfo);
        }
      }
    }

    final languagePatterns = _getLanguagePatterns();
    for (final entry in languagePatterns) {
      if (!languages.any((l) => l.code == entry.code)) {
        for (final pattern in entry.patterns) {
          if (RegExp(pattern, caseSensitive: false).hasMatch(filename)) {
            languages.add(LanguageInfo(
              code: entry.code,
              name: entry.name,
              flag: entry.flag,
            ));
            break;
          }
        }
      }
    }

    if (languages.isEmpty) {
      final region = extractRegion(filename);
      if (region.name == 'Japan') {
        return [const LanguageInfo(code: 'Ja', name: 'Japanese', flag: '🇯🇵')];
      } else if (region.name == 'USA') {
        return [const LanguageInfo(code: 'En', name: 'English', flag: '🇬🇧')];
      } else if (region.name == 'Europe') {
        return [const LanguageInfo(code: 'En', name: 'English', flag: '🇬🇧')];
      }
    }

    return languages;
  }

  static LanguageInfo? _getLanguageByCode(String code) {
    final languages = _getLanguagePatterns();
    for (final lang in languages) {
      if (lang.code == code) {
        return LanguageInfo(
          code: lang.code,
          name: lang.name,
          flag: lang.flag,
        );
      }
    }
    return null;
  }

  static List<_LanguagePattern> _getLanguagePatterns() {
    return const [
      _LanguagePattern('En', 'English', '🇬🇧', [
        r'\(En[,)]',
        r'English',
      ]),
      _LanguagePattern('Ja', 'Japanese', '🇯🇵', [
        r'\(Ja[,)]',
        r'Japanese',
      ]),
      _LanguagePattern('Fr', 'French', '🇫🇷', [
        r'\(Fr[,)]',
        r'French',
      ]),
      _LanguagePattern('De', 'German', '🇩🇪', [
        r'\(De[,)]',
        r'German',
      ]),
      _LanguagePattern('Es', 'Spanish', '🇪🇸', [
        r'\(Es[,)]',
        r'Spanish',
      ]),
      _LanguagePattern('It', 'Italian', '🇮🇹', [
        r'\(It[,)]',
        r'Italian',
      ]),
      _LanguagePattern('Nl', 'Dutch', '🇳🇱', [
        r'\(Nl[,)]',
        r'Dutch',
      ]),
      _LanguagePattern('Pt', 'Portuguese', '🇵🇹', [
        r'\(Pt[,)]',
        r'Portuguese',
      ]),
      _LanguagePattern('Ru', 'Russian', '🇷🇺', [
        r'\(Ru[,)]',
        r'Russian',
      ]),
      _LanguagePattern('Zh', 'Chinese', '🇨🇳', [
        r'\(Zh[,)]',
        r'Chinese',
      ]),
      _LanguagePattern('Ko', 'Korean', '🇰🇷', [
        r'\(Ko[,)]',
        r'Korean',
      ]),
      _LanguagePattern('Pl', 'Polish', '🇵🇱', [
        r'\(Pl[,)]',
        r'Polish',
      ]),
      _LanguagePattern('Sv', 'Swedish', '🇸🇪', [
        r'\(Sv[,)]',
        r'Swedish',
      ]),
      _LanguagePattern('Da', 'Danish', '🇩🇰', [
        r'\(Da[,)]',
        r'Danish',
      ]),
      _LanguagePattern('No', 'Norwegian', '🇳🇴', [
        r'\(No[,)]',
        r'Norwegian',
      ]),
      _LanguagePattern('Fi', 'Finnish', '🇫🇮', [
        r'\(Fi[,)]',
        r'Finnish',
      ]),
    ];
  }

  static List<TagInfo> extractAllTags(String filename) {
    final tags = <TagInfo>[];
    final seen = <String>{};

    final parenMatches = RegExp(r'\(([^)]+)\)').allMatches(filename);
    for (final match in parenMatches) {
      final content = match.group(1) ?? '';
      final raw = '($content)';
      if (seen.contains(raw)) continue;
      seen.add(raw);
      tags.add(TagInfo(
        raw: raw,
        content: content,
        type: _categorizeTag(content),
      ));
    }

    final bracketMatches = RegExp(r'\[([^\]]+)\]').allMatches(filename);
    for (final match in bracketMatches) {
      final content = match.group(1) ?? '';
      final raw = '[$content]';
      if (seen.contains(raw)) continue;
      seen.add(raw);
      tags.add(TagInfo(
        raw: raw,
        content: content,
        type: _categorizeTag(content),
      ));
    }

    return tags;
  }

  static TagType _categorizeTag(String content) {
    final lower = content.toLowerCase().trim();

    if (_isRegionContent(lower) || _isLanguageContent(lower)) {
      return TagType.hidden;
    }

    if (_isSecondaryTag(content, lower)) {
      return TagType.secondary;
    }

    if (lower.startsWith('v') && RegExp(r'^v\d').hasMatch(lower)) {
      return TagType.version;
    }
    if (lower.startsWith('rev')) {
      return TagType.version;
    }

    if (lower.startsWith('beta')) {
      return TagType.build;
    }
    if (lower.startsWith('demo')) {
      return TagType.build;
    }
    if (lower.startsWith('proto')) {
      return TagType.build;
    }
    if (lower == 'sample' || lower.startsWith('sample')) {
      return TagType.build;
    }
    if (lower == 'debug') {
      return TagType.build;
    }
    if (lower == 'alpha' || lower.startsWith('alpha')) {
      return TagType.build;
    }

    if (lower.startsWith('disc')) {
      return TagType.disc;
    }
    if (lower.startsWith('side')) {
      return TagType.disc;
    }

    final qualityMarkers = [
      '!',
      'b1',
      'b2',
      'b3',
      'a1',
      'a2',
      'a3',
      'f1',
      'f2',
      'h1',
      'h2',
      'o1',
      'o2',
      'p1',
      'p2',
      't1',
      't2',
      'x',
      'x1',
      'x2',
      'c',
      'c1',
      'c2',
      'm1',
      'm2',
      'overdump',
      'underdump',
      'trained',
      'pirate',
    ];
    if (qualityMarkers.contains(lower)) {
      return TagType.quality;
    }

    return TagType.other;
  }

  static bool _isSecondaryTag(String content, String lower) {
    if (lower.contains('branches-')) return true;
    if (lower.contains('branch-')) return true;
    if (lower.startsWith('branch')) return true;
    if (lower == 'trunk') return true;
    if (lower.contains('trunk,')) return true;
    if (lower.startsWith('trunk')) return true;

    if (RegExp(r'^\d+[A-Za-z]?$').hasMatch(content)) return true;
    if (RegExp(r'^\d+,\s*\d+$').hasMatch(content)) return true;

    if (content.length > 20) return true;

    if (RegExp(r'\d{6,8}').hasMatch(content)) return true;

    if (lower.startsWith('commit')) return true;
    if (lower.startsWith('build')) return true;
    if (lower.startsWith('hash')) return true;

    return false;
  }

  static bool _isRegionContent(String content) {
    final regionCodes = {
      'japan',
      'j',
      'jp',
      'usa',
      'u',
      'us',
      'europe',
      'eur',
      'e',
      'eu',
      'germany',
      'de',
      'france',
      'fr',
      'spain',
      'es',
      'italy',
      'it',
      'uk',
      'united kingdom',
      'australia',
      'au',
      'canada',
      'ca',
      'brazil',
      'br',
      'korea',
      'kr',
      'china',
      'ch',
      'cn',
      'taiwan',
      'tw',
      'hong kong',
      'hk',
      'norway',
      'nor',
      'sweden',
      'swe',
      'denmark',
      'dk',
      'finland',
      'fi',
      'netherlands',
      'nl',
      'world',
    };
    if (regionCodes.contains(content)) return true;
    // Handle comma-separated multi-region like "usa,europe"
    if (content.contains(',')) {
      return content
          .split(',')
          .every((part) => regionCodes.contains(part.trim()));
    }
    return false;
  }

  static bool _isLanguageContent(String content) {
    if (content.contains(',')) {
      final parts = content.split(',');
      for (final part in parts) {
        final trimmed = part.trim().toLowerCase();
        if (!_isLanguageCode(trimmed)) return false;
      }
      return true;
    }
    return _isLanguageCode(content);
  }

  static bool _isLanguageCode(String code) {
    final langCodes = [
      'en',
      'ja',
      'fr',
      'de',
      'es',
      'it',
      'nl',
      'pt',
      'ru',
      'zh',
      'ko',
      'pl',
      'sv',
      'da',
      'no',
      'fi',
      'english',
      'japanese',
      'french',
      'german',
      'spanish',
      'italian',
      'dutch',
      'portuguese',
      'russian',
      'chinese',
      'korean',
      'polish',
      'swedish',
      'danish',
      'norwegian',
      'finnish',
    ];
    return langCodes.contains(code.toLowerCase());
  }

  static String getFileType(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    switch (ext) {
      case 'zip':
        return 'ZIP';
      case '7z':
        return '7Z';
      case 'rvz':
        return 'RVZ';
      case 'iso':
        return 'ISO';
      case 'chd':
        return 'CHD';
      case '3ds':
        return '3DS';
      case 'nds':
        return 'NDS';
      case 'gba':
        return 'GBA';
      case 'gbc':
        return 'GBC';
      case 'gb':
        return 'GB';
      case 'sfc':
        return 'SFC';
      case 'z64':
        return 'Z64';
      case 'nsp':
        return 'NSP';
      case 'xci':
        return 'XCI';
      case 'cso':
        return 'CSO';
      default:
        return ext.toUpperCase();
    }
  }

  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  static GameMetadataFull parse(String filename) {
    final allTags = extractAllTags(filename);

    return GameMetadataFull(
      cleanTitle: cleanTitle(filename),
      region: extractRegion(filename),
      languages: extractLanguages(filename),
      fileType: getFileType(filename),
      allTags: allTags,
    );
  }
}

class _RegionPattern {
  final String regionName;
  final String flag;
  final List<String> patterns;

  const _RegionPattern(this.regionName, this.flag, this.patterns);
}

class _LanguagePattern {
  final String code;
  final String name;
  final String flag;
  final List<String> patterns;

  const _LanguagePattern(this.code, this.name, this.flag, this.patterns);
}

class RegionInfo {
  final String name;
  final String flag;

  const RegionInfo({required this.name, required this.flag});
}

class LanguageInfo {
  final String code;
  final String name;
  final String flag;

  const LanguageInfo({
    required this.code,
    required this.name,
    required this.flag,
  });
}

class GameMetadataFull {
  final String cleanTitle;
  final RegionInfo region;
  final List<LanguageInfo> languages;
  final String fileType;
  final List<TagInfo> allTags;

  const GameMetadataFull({
    required this.cleanTitle,
    required this.region,
    required this.languages,
    required this.fileType,
    required this.allTags,
  });

  List<TagInfo> get visibleTags =>
      allTags.where((t) => t.type != TagType.hidden).toList();

  List<TagInfo> get primaryTags => allTags
      .where((t) => t.type != TagType.hidden && t.type != TagType.secondary)
      .toList();

  List<TagInfo> get secondaryTags =>
      allTags.where((t) => t.type == TagType.secondary).toList();

  List<TagInfo> get hiddenTags =>
      allTags.where((t) => t.type == TagType.hidden).toList();

  bool get hasSecondaryTags => secondaryTags.isNotEmpty;

  bool get hasHiddenTags => hiddenTags.isNotEmpty;

  bool get hasInfoDetails => hasSecondaryTags || hasHiddenTags;

  String get displayVersion {
    if (primaryTags.isEmpty) return 'Standard';
    return primaryTags.map((t) => t.raw).join(' · ');
  }
}
