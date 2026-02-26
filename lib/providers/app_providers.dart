import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/storage_service.dart';
export '../services/storage_service.dart' show ControllerLayout;
import '../services/haptic_service.dart';
import '../services/audio_manager.dart';
import '../services/feedback_service.dart';
import '../services/crash_log_service.dart';
import '../services/device_info_service.dart';
import '../services/config_storage_service.dart';
import '../services/disk_space_service.dart';
import '../models/game_item.dart';
import '../models/sound_settings.dart';

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

final configStorageServiceProvider = Provider<ConfigStorageService>((ref) {
  return ConfigStorageService();
});

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
  Set<String>? _pendingMigrationNames;

  FavoriteGamesNotifier(this._storage) : super(_storage.getFavorites()) {
    if (_storage.getFavoritesVersion() == 0 && state.isNotEmpty) {
      _pendingMigrationNames = state.toSet();
    }
  }

  /// Maps old displayName-based favorites to filenames. Idempotent.
  void migrateIfNeeded(List<GameItem> allGames) {
    final pending = _pendingMigrationNames;
    if (pending == null) return;
    _pendingMigrationNames = null;

    // Build displayName → filenames map
    final nameToFilenames = <String, List<String>>{};
    for (final game in allGames) {
      nameToFilenames
          .putIfAbsent(game.displayName, () => [])
          .add(game.filename);
    }

    final migrated = <String>{};
    for (final oldName in pending) {
      final filenames = nameToFilenames[oldName];
      if (filenames != null) {
        migrated.addAll(filenames);
      }
    }

    _storage.setFavorites(migrated.toList());
    _storage.setFavoritesVersion(1);
    state = migrated.toList();
  }

  void toggleFavorite(String filename) {
    _storage.toggleFavorite(filename);
    state = _storage.getFavorites();
  }

  bool isFavorite(String filename) {
    return state.contains(filename);
  }

  bool isAnyFavorite(List<String> filenames) {
    for (final f in filenames) {
      if (state.contains(f)) return true;
    }
    return false;
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
  final storage = ref.read(storageServiceProvider);
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
    state = newValue;
    await _storage.setHomeLayoutIsGrid(newValue);
  }
}

final homeLayoutProvider = StateNotifierProvider<HomeLayoutNotifier, bool>((ref) {
  final storage = ref.read(storageServiceProvider);
  return HomeLayoutNotifier(storage);
});

final favoriteGamesProvider =
    StateNotifierProvider<FavoriteGamesNotifier, List<String>>((ref) {
  return FavoriteGamesNotifier(ref.read(storageServiceProvider));
});

final deviceMemoryProvider = Provider<DeviceMemoryInfo>((ref) {
  throw UnimplementedError('Must be overridden in main.dart');
});

final storageInfoProvider =
    FutureProvider.autoDispose.family<StorageInfo?, String>(
  (ref, path) => DiskSpaceService.getFreeSpace(path),
);

