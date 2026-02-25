import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:retro_eshop/models/custom_shelf.dart';

void main() {
  group('ShelfFilterRule', () {
    test('matches text query case-insensitively', () {
      const rule = ShelfFilterRule(textQuery: 'pokemon');
      expect(rule.matches('Pokemon Red', 'gba'), isTrue);
      expect(rule.matches('POKEMON Blue', 'gba'), isTrue);
      expect(rule.matches('Dragon Quest', 'nds'), isFalse);
    });

    test('matches system slugs', () {
      const rule = ShelfFilterRule(systemSlugs: ['gba', 'nds']);
      expect(rule.matches('Any Game', 'gba'), isTrue);
      expect(rule.matches('Any Game', 'nds'), isTrue);
      expect(rule.matches('Any Game', 'snes'), isFalse);
    });

    test('matches both text and system', () {
      const rule =
          ShelfFilterRule(textQuery: 'pokemon', systemSlugs: ['gba']);
      expect(rule.matches('Pokemon Red', 'gba'), isTrue);
      expect(rule.matches('Pokemon Red', 'nds'), isFalse);
      expect(rule.matches('Dragon Quest', 'gba'), isFalse);
    });

    test('empty rule matches everything', () {
      const rule = ShelfFilterRule();
      expect(rule.matches('Anything', 'any'), isTrue);
    });

    test('serialization round-trip', () {
      const rule =
          ShelfFilterRule(textQuery: 'mario', systemSlugs: ['nes', 'snes']);
      final json = rule.toJson();
      final restored = ShelfFilterRule.fromJson(json);
      expect(restored.textQuery, 'mario');
      expect(restored.systemSlugs, ['nes', 'snes']);
    });
  });

  group('CustomShelf', () {
    final now = DateTime(2026, 1, 1);

    CustomShelf makeShelf({
      List<ShelfFilterRule> filterRules = const [],
      List<String> manualGameIds = const [],
      List<String> excludedGameIds = const [],
      ShelfSortMode sortMode = ShelfSortMode.alphabetical,
    }) {
      return CustomShelf(
        id: 'test1',
        name: 'Test Shelf',
        filterRules: filterRules,
        manualGameIds: manualGameIds,
        excludedGameIds: excludedGameIds,
        sortMode: sortMode,
        createdAt: now,
      );
    }

    final allGames = [
      (filename: 'pokemon_red.gba', displayName: 'Pokemon Red', systemSlug: 'gba'),
      (filename: 'pokemon_blue.gba', displayName: 'Pokemon Blue', systemSlug: 'gba'),
      (filename: 'pokemon_diamond.nds', displayName: 'Pokemon Diamond', systemSlug: 'nds'),
      (filename: 'dragon_quest_8.ps2', displayName: 'Dragon Quest 8', systemSlug: 'ps2'),
      (filename: 'zelda_oot.n64', displayName: 'Zelda OOT', systemSlug: 'n64'),
    ];

    test('resolveFilenames with filter-only shelf', () {
      final shelf = makeShelf(
        filterRules: [const ShelfFilterRule(textQuery: 'pokemon')],
      );
      final result = shelf.resolveFilenames(allGames);
      expect(result, containsAll([
        'pokemon_red.gba',
        'pokemon_blue.gba',
        'pokemon_diamond.nds',
      ]));
      expect(result, isNot(contains('dragon_quest_8.ps2')));
    });

    test('resolveFilenames with manual-only shelf', () {
      final shelf = makeShelf(
        manualGameIds: ['zelda_oot.n64', 'dragon_quest_8.ps2'],
        sortMode: ShelfSortMode.manual,
      );
      final result = shelf.resolveFilenames(allGames);
      expect(result, ['zelda_oot.n64', 'dragon_quest_8.ps2']);
    });

    test('resolveFilenames with hybrid + manual sort', () {
      final shelf = makeShelf(
        filterRules: [const ShelfFilterRule(textQuery: 'pokemon', systemSlugs: ['gba'])],
        manualGameIds: ['dragon_quest_8.ps2'],
        sortMode: ShelfSortMode.manual,
      );
      final result = shelf.resolveFilenames(allGames);
      // Manual first, then new filter matches sorted
      expect(result.first, 'dragon_quest_8.ps2');
      expect(result.sublist(1)..sort(), result.sublist(1));
    });

    test('resolveFilenames with OR-linked filter rules', () {
      final shelf = makeShelf(
        filterRules: [
          const ShelfFilterRule(textQuery: 'pokemon'),
          const ShelfFilterRule(textQuery: 'dragon quest'),
        ],
      );
      final result = shelf.resolveFilenames(allGames);
      expect(result, containsAll([
        'pokemon_red.gba',
        'pokemon_blue.gba',
        'pokemon_diamond.nds',
        'dragon_quest_8.ps2',
      ]));
    });

    test('manual sort removes stale entries', () {
      final shelf = makeShelf(
        manualGameIds: ['deleted_game.gb', 'zelda_oot.n64'],
        sortMode: ShelfSortMode.manual,
      );
      final result = shelf.resolveFilenames(allGames);
      expect(result, ['zelda_oot.n64']);
    });

    test('isManualOnly / isFilterOnly / isHybrid', () {
      expect(makeShelf().isManualOnly, isTrue);
      expect(
        makeShelf(filterRules: [const ShelfFilterRule(textQuery: 'x')]).isFilterOnly,
        isTrue,
      );
      expect(
        makeShelf(
          filterRules: [const ShelfFilterRule(textQuery: 'x')],
          manualGameIds: ['a'],
        ).isHybrid,
        isTrue,
      );
    });

    test('serialization round-trip', () {
      final shelf = makeShelf(
        filterRules: [
          const ShelfFilterRule(textQuery: 'pokemon', systemSlugs: ['gba']),
        ],
        manualGameIds: ['zelda_oot.n64'],
        sortMode: ShelfSortMode.manual,
      );
      final json = shelf.toJson();
      final jsonStr = jsonEncode(json);
      final restored =
          CustomShelf.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
      expect(restored.id, shelf.id);
      expect(restored.name, shelf.name);
      expect(restored.sortMode, ShelfSortMode.manual);
      expect(restored.filterRules.length, 1);
      expect(restored.filterRules.first.textQuery, 'pokemon');
      expect(restored.manualGameIds, ['zelda_oot.n64']);
      expect(restored.createdAt, now);
    });

    test('copyWith preserves id and createdAt', () {
      final shelf = makeShelf();
      final updated = shelf.copyWith(name: 'New Name');
      expect(updated.id, shelf.id);
      expect(updated.createdAt, shelf.createdAt);
      expect(updated.name, 'New Name');
    });

    // --- excludedGameIds tests ---

    test('resolveFilenames excludes filter-matched games', () {
      final shelf = makeShelf(
        filterRules: [const ShelfFilterRule(textQuery: 'pokemon')],
        excludedGameIds: ['pokemon_blue.gba'],
      );
      final result = shelf.resolveFilenames(allGames);
      expect(result, contains('pokemon_red.gba'));
      expect(result, contains('pokemon_diamond.nds'));
      expect(result, isNot(contains('pokemon_blue.gba')));
    });

    test('resolveFilenames excludes manual games', () {
      final shelf = makeShelf(
        manualGameIds: ['zelda_oot.n64', 'dragon_quest_8.ps2'],
        excludedGameIds: ['zelda_oot.n64'],
        sortMode: ShelfSortMode.manual,
      );
      final result = shelf.resolveFilenames(allGames);
      expect(result, ['dragon_quest_8.ps2']);
      expect(result, isNot(contains('zelda_oot.n64')));
    });

    test('excludedGameIds serialization round-trip', () {
      final shelf = makeShelf(
        filterRules: [const ShelfFilterRule(textQuery: 'pokemon')],
        excludedGameIds: ['pokemon_blue.gba', 'pokemon_red.gba'],
      );
      final json = shelf.toJson();
      final jsonStr = jsonEncode(json);
      final restored =
          CustomShelf.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
      expect(restored.excludedGameIds, ['pokemon_blue.gba', 'pokemon_red.gba']);
    });

    test('fromJson without excludedGameIds defaults to empty', () {
      final json = {
        'id': 'test1',
        'name': 'Test',
        'filterRules': <dynamic>[],
        'manualGameIds': <dynamic>[],
        'sortMode': 'alphabetical',
        'createdAt': DateTime(2026, 1, 1).toIso8601String(),
      };
      final shelf = CustomShelf.fromJson(json);
      expect(shelf.excludedGameIds, isEmpty);
    });

    // --- containsGame tests ---

    test('containsGame returns true for manual game', () {
      final shelf = makeShelf(manualGameIds: ['zelda_oot.n64']);
      expect(shelf.containsGame('zelda_oot.n64', 'Zelda OOT', 'n64'), isTrue);
    });

    test('containsGame returns true for filter-matched game', () {
      final shelf = makeShelf(
        filterRules: [const ShelfFilterRule(textQuery: 'pokemon', systemSlugs: ['gba'])],
      );
      expect(shelf.containsGame('pokemon_red.gba', 'Pokemon Red', 'gba'), isTrue);
    });

    test('containsGame returns false for excluded game even if manual or filter-matched', () {
      final shelf = makeShelf(
        filterRules: [const ShelfFilterRule(textQuery: 'pokemon')],
        manualGameIds: ['pokemon_red.gba'],
        excludedGameIds: ['pokemon_red.gba'],
      );
      expect(shelf.containsGame('pokemon_red.gba', 'Pokemon Red', 'gba'), isFalse);
    });

    test('containsGame returns false for unrelated game', () {
      final shelf = makeShelf(
        filterRules: [const ShelfFilterRule(textQuery: 'pokemon', systemSlugs: ['gba'])],
        manualGameIds: ['zelda_oot.n64'],
      );
      expect(shelf.containsGame('dragon_quest_8.ps2', 'Dragon Quest 8', 'ps2'), isFalse);
    });

    test('copyWith preserves and replaces excludedGameIds', () {
      final shelf = makeShelf(excludedGameIds: ['a.gba', 'b.gba']);
      final preserved = shelf.copyWith(name: 'Updated');
      expect(preserved.excludedGameIds, ['a.gba', 'b.gba']);

      final replaced = shelf.copyWith(excludedGameIds: ['c.gba']);
      expect(replaced.excludedGameIds, ['c.gba']);
    });

    test('hybrid shelf: excludes on manual + filter games', () {
      final shelf = makeShelf(
        filterRules: [const ShelfFilterRule(textQuery: 'pokemon', systemSlugs: ['gba'])],
        manualGameIds: ['dragon_quest_8.ps2'],
        excludedGameIds: ['pokemon_red.gba', 'dragon_quest_8.ps2'],
      );
      final result = shelf.resolveFilenames(allGames);
      expect(result, contains('pokemon_blue.gba'));
      expect(result, isNot(contains('pokemon_red.gba')));
      expect(result, isNot(contains('dragon_quest_8.ps2')));
    });
  });
}
