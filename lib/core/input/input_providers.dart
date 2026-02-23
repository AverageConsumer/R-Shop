import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/input_debouncer.dart';

final inputDebouncerProvider = Provider<InputDebouncer>((ref) {
  return InputDebouncer();
});

enum OverlayPriority {
  none(0),
  dialog(1),
  search(2),
  downloadModal(3),
  fullScreen(4);

  final int level;
  const OverlayPriority(this.level);
}

class OverlayPriorityManager extends StateNotifier<OverlayPriority> {
  final List<({OverlayPriority priority, int token})> _stack = [];
  int _nextToken = 0;

  OverlayPriorityManager() : super(OverlayPriority.none);

  /// Claims a priority and returns a unique token for targeted release.
  int claim(OverlayPriority priority) {
    final token = _nextToken++;
    _stack.add((priority: priority, token: token));
    _updateState();
    return token;
  }

  /// Releases the exact entry identified by [token].
  /// Returns true if the token was found and removed.
  bool release(int token) {
    final before = _stack.length;
    _stack.removeWhere((e) => e.token == token);
    final didRemove = _stack.length < before;
    if (didRemove) _updateState();
    return didRemove;
  }

  /// Removes the first entry matching [priority].
  /// Use for suspend/resume patterns where no token is available.
  void releaseByPriority(OverlayPriority priority) {
    final idx = _stack.indexWhere((e) => e.priority == priority);
    if (idx >= 0) {
      _stack.removeAt(idx);
      _updateState();
    }
  }

  void _updateState() {
    if (_stack.isEmpty) {
      state = OverlayPriority.none;
    } else {
      state = _stack
          .map((e) => e.priority)
          .reduce((a, b) => a.level >= b.level ? a : b);
    }
  }
}

final overlayPriorityProvider =
    StateNotifierProvider<OverlayPriorityManager, OverlayPriority>((ref) {
  return OverlayPriorityManager();
});

final mainFocusRequestProvider = StateProvider<FocusNode?>((ref) {
  return null;
});

void restoreMainFocus(WidgetRef ref) {
  final focusNode = ref.read(mainFocusRequestProvider);
  if (focusNode != null && focusNode.canRequestFocus) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (focusNode.canRequestFocus) {
        focusNode.requestFocus();
      }
    });
  }
}

class FocusStateEntry {
  final String routeId;
  final int? selectedIndex;
  final String? focusedElementId;
  final FocusNode? savedFocusNode;
  final Map<String, dynamic> metadata;
  final DateTime savedAt;

  const FocusStateEntry({
    required this.routeId,
    this.selectedIndex,
    this.focusedElementId,
    this.savedFocusNode,
    this.metadata = const {},
    required this.savedAt,
  });

  FocusStateEntry copyWith({
    int? selectedIndex,
    String? focusedElementId,
    FocusNode? savedFocusNode,
    Map<String, dynamic>? metadata,
  }) {
    return FocusStateEntry(
      routeId: routeId,
      selectedIndex: selectedIndex ?? this.selectedIndex,
      focusedElementId: focusedElementId ?? this.focusedElementId,
      savedFocusNode: savedFocusNode ?? this.savedFocusNode,
      metadata: metadata ?? Map<String, dynamic>.from(this.metadata),
      savedAt: DateTime.now(),
    );
  }
}

class FocusStateManager extends StateNotifier<Map<String, FocusStateEntry>> {
  static const int _maxEntries = 10;

  FocusStateManager() : super({});

  void saveFocusState(
    String routeId, {
    int? selectedIndex,
    String? focusedElementId,
    FocusNode? savedFocusNode,
    Map<String, dynamic> metadata = const {},
  }) {
    final existing = state[routeId];
    state = {
      ...state,
      routeId: FocusStateEntry(
        routeId: routeId,
        selectedIndex: selectedIndex ?? existing?.selectedIndex,
        focusedElementId: focusedElementId ?? existing?.focusedElementId,
        savedFocusNode: savedFocusNode ?? existing?.savedFocusNode,
        metadata:
            metadata.isNotEmpty ? metadata : (existing?.metadata ?? const {}),
        savedAt: DateTime.now(),
      ),
    };
    _pruneOldEntries();
  }

  FocusStateEntry? getFocusState(String routeId) {
    return state[routeId];
  }

  void clearFocusState(String routeId) {
    final newState = Map<String, FocusStateEntry>.from(state);
    newState.remove(routeId);
    state = newState;
  }

  void _pruneOldEntries() {
    if (state.length <= _maxEntries) return;

    final sortedEntries = state.entries.toList()
      ..sort((a, b) => a.value.savedAt.compareTo(b.value.savedAt));

    final entriesToRemove = sortedEntries.take(state.length - _maxEntries);
    final newState = Map<String, FocusStateEntry>.from(state);
    for (final entry in entriesToRemove) {
      newState.remove(entry.key);
    }
    state = newState;
  }
}

final focusStateManagerProvider =
    StateNotifierProvider<FocusStateManager, Map<String, FocusStateEntry>>(
        (ref) {
  return FocusStateManager();
});

final searchRequestedProvider = StateProvider<DateTime?>((ref) => null);

final confirmRequestedProvider = StateProvider<DateTime?>((ref) => null);
