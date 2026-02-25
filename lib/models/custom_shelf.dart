import '../utils/game_metadata.dart';

enum ShelfSortMode { alphabetical, bySystem, manual }

class ShelfFilterRule {
  final String? textQuery;
  final List<String> systemSlugs;

  const ShelfFilterRule({this.textQuery, this.systemSlugs = const []});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShelfFilterRule &&
          textQuery == other.textQuery &&
          _listEquals(systemSlugs, other.systemSlugs);

  @override
  int get hashCode => Object.hash(textQuery, Object.hashAll(systemSlugs));

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  bool matches(String displayName, String systemSlug) {
    final textOk = textQuery == null ||
        textQuery!.isEmpty ||
        GameMetadata.normalizeForSearch(displayName).contains(GameMetadata.normalizeForSearch(textQuery!));
    final systemOk =
        systemSlugs.isEmpty || systemSlugs.contains(systemSlug);
    return textOk && systemOk;
  }

  Map<String, dynamic> toJson() => {
        if (textQuery != null) 'textQuery': textQuery,
        if (systemSlugs.isNotEmpty) 'systemSlugs': systemSlugs,
      };

  factory ShelfFilterRule.fromJson(Map<String, dynamic> json) {
    return ShelfFilterRule(
      textQuery: json['textQuery'] as String?,
      systemSlugs: (json['systemSlugs'] as List<dynamic>?)
              ?.cast<String>() ??
          const [],
    );
  }

  ShelfFilterRule copyWith({String? textQuery, List<String>? systemSlugs}) {
    return ShelfFilterRule(
      textQuery: textQuery ?? this.textQuery,
      systemSlugs: systemSlugs ?? this.systemSlugs,
    );
  }
}

class CustomShelf {
  final String id;
  final String name;
  final List<ShelfFilterRule> filterRules;
  final List<String> manualGameIds;
  final List<String> excludedGameIds;
  final ShelfSortMode sortMode;
  final DateTime createdAt;

  const CustomShelf({
    required this.id,
    required this.name,
    this.filterRules = const [],
    this.manualGameIds = const [],
    this.excludedGameIds = const [],
    this.sortMode = ShelfSortMode.alphabetical,
    required this.createdAt,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomShelf && id == other.id;

  @override
  int get hashCode => id.hashCode;

  bool get isManualOnly => filterRules.isEmpty;
  bool get isFilterOnly => manualGameIds.isEmpty && filterRules.isNotEmpty;
  bool get isHybrid => manualGameIds.isNotEmpty && filterRules.isNotEmpty;
  bool get hasManualComponent => manualGameIds.isNotEmpty;

  /// Checks whether a single game would be contained in this shelf.
  bool containsGame(String filename, String displayName, String systemSlug) {
    if (excludedGameIds.contains(filename)) return false;
    if (manualGameIds.contains(filename)) return true;
    return filterRules.any((r) => r.matches(displayName, systemSlug));
  }

  /// Resolves which filenames belong to this shelf.
  List<String> resolveFilenames(
    List<({String filename, String displayName, String systemSlug})> allGames,
  ) {
    final allFilenames = allGames.map((g) => g.filename).toSet();
    final filterMatches = allGames
        .where(
            (g) => filterRules.any((r) => r.matches(g.displayName, g.systemSlug)))
        .map((g) => g.filename)
        .toSet();
    final manual = manualGameIds.where((f) => allFilenames.contains(f)).toSet();
    final combined = {...manual, ...filterMatches};
    combined.removeAll(excludedGameIds);

    if (sortMode == ShelfSortMode.manual) {
      final result = [
        ...manualGameIds.where((f) => combined.contains(f)),
      ];
      final newFilterOnly = filterMatches.difference(manual).toList()..sort();
      result.addAll(newFilterOnly);
      return result;
    }
    return combined.toList();
  }

  CustomShelf copyWith({
    String? name,
    List<ShelfFilterRule>? filterRules,
    List<String>? manualGameIds,
    List<String>? excludedGameIds,
    ShelfSortMode? sortMode,
  }) {
    return CustomShelf(
      id: id,
      name: name ?? this.name,
      filterRules: filterRules ?? this.filterRules,
      manualGameIds: manualGameIds ?? this.manualGameIds,
      excludedGameIds: excludedGameIds ?? this.excludedGameIds,
      sortMode: sortMode ?? this.sortMode,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'filterRules': filterRules.map((r) => r.toJson()).toList(),
        'manualGameIds': manualGameIds,
        'excludedGameIds': excludedGameIds,
        'sortMode': sortMode.name,
        'createdAt': createdAt.toIso8601String(),
      };

  factory CustomShelf.fromJson(Map<String, dynamic> json) {
    return CustomShelf(
      id: json['id'] as String,
      name: json['name'] as String,
      filterRules: (json['filterRules'] as List<dynamic>?)
              ?.map((e) =>
                  ShelfFilterRule.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      manualGameIds:
          (json['manualGameIds'] as List<dynamic>?)?.cast<String>() ??
              const [],
      excludedGameIds:
          (json['excludedGameIds'] as List<dynamic>?)?.cast<String>() ??
              const [],
      sortMode: ShelfSortMode.values.firstWhere(
        (e) => e.name == json['sortMode'],
        orElse: () => ShelfSortMode.alphabetical,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
