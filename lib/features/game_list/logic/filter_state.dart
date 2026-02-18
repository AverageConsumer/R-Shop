import '../../../models/game_item.dart';
import '../../../utils/game_metadata.dart';

class FilterOption {
  final String id;
  final String label;
  final String flag;
  final int count;

  const FilterOption({
    required this.id,
    required this.label,
    required this.flag,
    required this.count,
  });
}

class ActiveFilters {
  final Set<String> selectedRegions;
  final Set<String> selectedLanguages;

  const ActiveFilters({
    this.selectedRegions = const {},
    this.selectedLanguages = const {},
  });

  bool get isEmpty => selectedRegions.isEmpty && selectedLanguages.isEmpty;
  bool get isNotEmpty => !isEmpty;

  int get activeCount => selectedRegions.length + selectedLanguages.length;

  ActiveFilters toggleRegion(String region) {
    final newRegions = Set<String>.from(selectedRegions);
    if (newRegions.contains(region)) {
      newRegions.remove(region);
    } else {
      newRegions.add(region);
    }
    return ActiveFilters(
      selectedRegions: newRegions,
      selectedLanguages: selectedLanguages,
    );
  }

  ActiveFilters toggleLanguage(String language) {
    final newLanguages = Set<String>.from(selectedLanguages);
    if (newLanguages.contains(language)) {
      newLanguages.remove(language);
    } else {
      newLanguages.add(language);
    }
    return ActiveFilters(
      selectedRegions: selectedRegions,
      selectedLanguages: newLanguages,
    );
  }

  ActiveFilters clearAll() {
    return const ActiveFilters();
  }
}

({List<FilterOption> regions, List<FilterOption> languages}) buildFilterOptions({
  required Map<String, List<GameItem>> groupedGames,
  required Map<String, RegionInfo> regionCache,
  required Map<String, List<LanguageInfo>> languageCache,
}) {
  final regionCounts = <String, _RegionAccum>{};
  final languageCounts = <String, _LangAccum>{};

  for (final entry in groupedGames.entries) {
    final groupRegions = <String>{};
    final groupLanguages = <String>{};

    for (final game in entry.value) {
      final region = regionCache[game.filename];
      if (region != null && region.name != 'Unknown') {
        groupRegions.add(region.name);
        regionCounts.putIfAbsent(
          region.name,
          () => _RegionAccum(region.name, region.flag),
        );
      }

      final languages = languageCache[game.filename];
      if (languages != null) {
        for (final lang in languages) {
          groupLanguages.add(lang.code);
          languageCounts.putIfAbsent(
            lang.code,
            () => _LangAccum(lang.code, lang.name, lang.flag),
          );
        }
      }
    }

    for (final r in groupRegions) {
      regionCounts[r]!.count++;
    }
    for (final l in groupLanguages) {
      languageCounts[l]!.count++;
    }
  }

  final regions = regionCounts.values
      .map((a) => FilterOption(id: a.name, label: a.name, flag: a.flag, count: a.count))
      .toList()
    ..sort((a, b) => b.count.compareTo(a.count));

  final languages = languageCounts.values
      .map((a) => FilterOption(id: a.code, label: a.label, flag: a.flag, count: a.count))
      .toList()
    ..sort((a, b) => b.count.compareTo(a.count));

  return (regions: regions, languages: languages);
}

class _RegionAccum {
  final String name;
  final String flag;
  int count = 0;
  _RegionAccum(this.name, this.flag);
}

class _LangAccum {
  final String code;
  final String label;
  final String flag;
  int count = 0;
  _LangAccum(this.code, this.label, this.flag);
}
