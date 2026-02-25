import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/custom_shelf.dart';
import '../services/storage_service.dart';
import 'app_providers.dart';

class CustomShelvesNotifier extends StateNotifier<List<CustomShelf>> {
  final StorageService _storage;

  CustomShelvesNotifier(this._storage) : super(_storage.getCustomShelves());

  void addShelf(CustomShelf shelf) {
    state = [...state, shelf];
    _persist();
  }

  void updateShelf(String id, CustomShelf updated) {
    state = [
      for (final s in state)
        if (s.id == id) updated else s,
    ];
    _persist();
  }

  void removeShelf(String id) {
    state = state.where((s) => s.id != id).toList();
    _persist();
  }

  void addGameToShelf(String shelfId, String filename) {
    state = [
      for (final s in state)
        if (s.id == shelfId)
          s.copyWith(
            manualGameIds: s.manualGameIds.contains(filename)
                ? s.manualGameIds
                : [...s.manualGameIds, filename],
            excludedGameIds: s.excludedGameIds.where((f) => f != filename).toList(),
          )
        else
          s,
    ];
    _persist();
  }

  void excludeGameFromShelf(String shelfId, String filename) {
    state = [
      for (final s in state)
        if (s.id == shelfId)
          s.copyWith(
            excludedGameIds: s.excludedGameIds.contains(filename)
                ? s.excludedGameIds
                : [...s.excludedGameIds, filename],
            manualGameIds: s.manualGameIds.where((f) => f != filename).toList(),
          )
        else
          s,
    ];
    _persist();
  }

  void removeGameFromShelf(String shelfId, String filename) {
    state = [
      for (final s in state)
        if (s.id == shelfId)
          s.copyWith(
            manualGameIds:
                s.manualGameIds.where((f) => f != filename).toList(),
          )
        else
          s,
    ];
    _persist();
  }

  void reorderGameInShelf(String shelfId, int oldIndex, int newIndex,
      {List<String>? resolvedOrder}) {
    state = [
      for (final s in state)
        if (s.id == shelfId)
          _reorder(s, oldIndex, newIndex, resolvedOrder: resolvedOrder)
        else
          s,
    ];
    _persist();
  }

  CustomShelf _reorder(CustomShelf shelf, int oldIndex, int newIndex,
      {List<String>? resolvedOrder}) {
    final ids = resolvedOrder != null
        ? List<String>.from(resolvedOrder)
        : List<String>.from(shelf.manualGameIds);
    if (oldIndex < 0 || oldIndex >= ids.length) return shelf;
    if (newIndex < 0 || newIndex >= ids.length) return shelf;
    final item = ids.removeAt(oldIndex);
    ids.insert(newIndex, item);
    return shelf.copyWith(manualGameIds: ids);
  }

  void _persist() {
    _storage.setCustomShelves(state);
  }
}

final customShelvesProvider =
    StateNotifierProvider<CustomShelvesNotifier, List<CustomShelf>>((ref) {
  return CustomShelvesNotifier(ref.read(storageServiceProvider));
});
