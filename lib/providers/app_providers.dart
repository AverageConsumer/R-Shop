import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/storage_service.dart';
export '../services/storage_service.dart' show ControllerLayout;
import '../services/haptic_service.dart';
import '../services/audio_manager.dart';
import '../services/feedback_service.dart';
import '../services/crash_log_service.dart';
import '../services/disk_space_service.dart';
import '../models/sound_settings.dart';
import '../utils/game_metadata.dart';

export '../core/input/input_providers.dart'
    show
        mainFocusRequestProvider,
        restoreMainFocus,
        inputDebouncerProvider,
        overlayPriorityProvider,
        OverlayPriority,
        OverlayPriorityManager,
        focusStateManagerProvider,
        FocusStateManager,
        FocusStateEntry,
        searchRequestedProvider,
        confirmRequestedProvider;

final crashLogServiceProvider = Provider<CrashLogService>((ref) {
  return CrashLogService();
});

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

final hapticServiceProvider = Provider<HapticService>((ref) {
  return HapticService();
});

final audioManagerProvider = Provider<AudioManager>((ref) {
  return AudioManager();
});

final feedbackServiceProvider = Provider<FeedbackService>((ref) {
  return FeedbackService(
    ref.read(audioManagerProvider),
    ref.read(hapticServiceProvider),
  );
});

class SoundSettingsNotifier extends StateNotifier<SoundSettings> {
  final StorageService _storage;
  final AudioManager _audioManager;

  SoundSettingsNotifier(this._storage, this._audioManager)
      : super(_storage.getSoundSettings());

  @override
  void dispose() {
    _audioManager.stopAll();
    super.dispose();
  }

  Future<void> setEnabled(bool enabled) async {
    state = state.copyWith(enabled: enabled);
    await _storage.setSoundSettings(state);
    _audioManager.updateSettings(state);
  }

  Future<void> setBgmVolume(double volume) async {
    state = state.copyWith(bgmVolume: volume);
    await _storage.setSoundSettings(state);
    _audioManager.updateSettings(state);
    _audioManager.setBgmVolume(volume);
  }

  Future<void> setSfxVolume(double volume) async {
    state = state.copyWith(sfxVolume: volume);
    await _storage.setSoundSettings(state);
    _audioManager.updateSettings(state);
  }

  Future<void> updateSettings(SoundSettings settings) async {
    state = settings;
    await _storage.setSoundSettings(state);
    _audioManager.updateSettings(state);
  }
}

final soundSettingsProvider =
    StateNotifierProvider<SoundSettingsNotifier, SoundSettings>((ref) {
  return SoundSettingsNotifier(
    ref.read(storageServiceProvider),
    ref.read(audioManagerProvider),
  );
});

class GridColumnsNotifier extends StateNotifier<int> {
  final StorageService _storage;
  final String _systemName;
  final int minColumns;
  final int maxColumns;

  GridColumnsNotifier(this._storage, this._systemName,
      {this.minColumns = 3, this.maxColumns = 8})
      : assert(minColumns > 0, 'minColumns must be positive'),
        assert(maxColumns >= minColumns, 'maxColumns must be >= minColumns'),
        super(
            _storage.getGridColumns(_systemName).clamp(minColumns, maxColumns));

  void setColumns(int columns) {
    final clamped = columns.clamp(minColumns, maxColumns);
    state = clamped;
    _storage.setGridColumns(_systemName, clamped);
  }

  void increaseColumns() {
    if (state < maxColumns) {
      setColumns(state + 1);
    }
  }

  void decreaseColumns() {
    if (state > minColumns) {
      setColumns(state - 1);
    }
  }
}

final gridColumnsProvider =
    StateNotifierProvider.family<GridColumnsNotifier, int, String>(
  (ref, systemName) => GridColumnsNotifier(
    ref.read(storageServiceProvider),
    systemName,
  ),
);

final homeGridColumnsProvider =
    StateNotifierProvider<GridColumnsNotifier, int>(
  (ref) => GridColumnsNotifier(
    ref.read(storageServiceProvider),
    'home',
    minColumns: 2,
    maxColumns: 6,
  ),
);

class FavoriteGamesNotifier extends StateNotifier<List<String>> {
  final StorageService _storage;

  FavoriteGamesNotifier(this._storage) : super(_storage.getFavorites()) {
    _migrateFavoriteNames();
  }

  void _migrateFavoriteNames() {
    final current = state;
    final migrated = current.map(GameMetadata.cleanTitle).toSet().toList();
    if (migrated.length != current.length ||
        !_listEquals(current, migrated)) {
      _storage.setFavorites(migrated);
      state = migrated;
    }
  }

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void toggleFavorite(String gameId) {
    _storage.toggleFavorite(gameId);
    state = _storage.getFavorites();
  }

  bool isFavorite(String gameId) {
    return state.contains(gameId);
  }
}

// ==========================================
// Controller Layout
// ==========================================
class ControllerLayoutNotifier extends StateNotifier<ControllerLayout> {
  final StorageService _storage;

  ControllerLayoutNotifier(this._storage) : super(_storage.getControllerLayout());

  Future<void> cycle() async {
    final next = switch (state) {
      ControllerLayout.nintendo => ControllerLayout.xbox,
      ControllerLayout.xbox => ControllerLayout.playstation,
      ControllerLayout.playstation => ControllerLayout.nintendo,
    };
    await _storage.setControllerLayout(next);
    state = next;
  }

  Future<void> setLayout(ControllerLayout layout) async {
    await _storage.setControllerLayout(layout);
    state = layout;
  }
}

final controllerLayoutProvider =
    StateNotifierProvider<ControllerLayoutNotifier, ControllerLayout>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return ControllerLayoutNotifier(storage);
});

// ==========================================
// Home Layout
// ==========================================
class HomeLayoutNotifier extends StateNotifier<bool> {
  final StorageService _storage;

  HomeLayoutNotifier(this._storage) : super(_storage.getHomeLayoutIsGrid());

  Future<void> toggle() async {
    final newValue = !state;
    await _storage.setHomeLayoutIsGrid(newValue);
    state = newValue;
  }
}

final homeLayoutProvider = StateNotifierProvider<HomeLayoutNotifier, bool>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return HomeLayoutNotifier(storage);
});

final favoriteGamesProvider =
    StateNotifierProvider<FavoriteGamesNotifier, List<String>>((ref) {
  return FavoriteGamesNotifier(ref.read(storageServiceProvider));
});

final storageInfoProvider =
    FutureProvider.autoDispose.family<StorageInfo?, String>(
  (ref, path) => DiskSpaceService.getFreeSpace(path),
);

