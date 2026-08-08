import 'dart:ui';
import 'package:flutter/foundation.dart';
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
import '../services/native_smb_service.dart';
import '../services/romm_pairing_service.dart';
import '../services/sources_notifier.dart';
import '../services/source_failover.dart';
import '../services/endpoint_probe_service.dart';
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

final nativeSmbServiceProvider = Provider<NativeSmbService>((ref) {
  return NativeSmbService();
});

final rommPairingServiceProvider = Provider<RommPairingService>((ref) {
  return RommPairingService();
});

final sourcesProvider =
    StateNotifierProvider<SourcesNotifier, SourcesState>((ref) {
  return SourcesNotifier(ref.read(configStorageServiceProvider));
});

final endpointProbeServiceProvider = Provider<EndpointProbeService>((ref) {
  return EndpointProbeService();
});

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

// ==========================================
// Hide Empty Consoles
// ==========================================
class HideEmptyConsolesNotifier extends StateNotifier<bool> {
  final StorageService _storage;

  HideEmptyConsolesNotifier(this._storage)
      : super(_storage.getHideEmptyConsoles());

  Future<void> toggle() async {
    final newValue = !state;
    state = newValue;
    await _storage.setHideEmptyConsoles(newValue);
  }
}

final hideEmptyConsolesProvider =
    StateNotifierProvider<HideEmptyConsolesNotifier, bool>((ref) {
  final storage = ref.read(storageServiceProvider);
  return HideEmptyConsolesNotifier(storage);
});

// ==========================================
// Locale Override (null = system default)
// ==========================================
class LocaleNotifier extends StateNotifier<Locale?> {
  final StorageService _storage;

  LocaleNotifier(this._storage) : super(_initLocale(_storage));

  static Locale? _initLocale(StorageService s) {
    final tag = s.getLocaleOverride();
    if (tag == null) return null;
    final parts = tag.split('-');
    if (parts.length > 1) {
      return Locale(parts[0], parts[1]);
    }
    return Locale(tag);
  }

  Future<void> cycle(List<Locale> supported) async {
    final tags = [null, ...supported.map((l) => l.toLanguageTag())];
    final current = state?.toLanguageTag();
    final idx = tags.indexOf(current);
    final next = tags[(idx + 1) % tags.length];

    if (next == null) {
      state = null;
    } else {
      final parts = next.split('-');
      state = parts.length > 1 ? Locale(parts[0], parts[1]) : Locale(next);
    }
    await _storage.setLocaleOverride(next);
  }
}

final localeProvider =
    StateNotifierProvider<LocaleNotifier, Locale?>((ref) {
  final storage = ref.read(storageServiceProvider);
  return LocaleNotifier(storage);
});

final favoriteGamesProvider =
    StateNotifierProvider<FavoriteGamesNotifier, List<String>>((ref) {
  return FavoriteGamesNotifier(ref.read(storageServiceProvider));
});

// --- Sync Timeout ---

const syncTimeoutSteps = [60, 120, 300, 600];

class SyncTimeoutNotifier extends StateNotifier<int> {
  final StorageService _storage;

  SyncTimeoutNotifier(this._storage)
      : super(_storage.getSyncTimeoutSeconds());

  Future<void> cycle() async {
    final currentIndex = syncTimeoutSteps.indexOf(state);
    final next = syncTimeoutSteps[(currentIndex + 1) % syncTimeoutSteps.length];
    state = next;
    await _storage.setSyncTimeoutSeconds(next);
  }
}

final syncTimeoutProvider =
    StateNotifierProvider<SyncTimeoutNotifier, int>((ref) {
  return SyncTimeoutNotifier(ref.read(storageServiceProvider));
});

String formatSyncTimeout(int seconds) => switch (seconds) {
      60 => '1 min',
      120 => '2 min',
      300 => '5 min',
      600 => '10 min',
      _ => '${seconds}s',
    };

// --- Sync Cooldown ---

const syncCooldownSteps = [0, 15, 30, 60, 120, 360];

class SyncCooldownNotifier extends StateNotifier<int> {
  final StorageService _storage;

  SyncCooldownNotifier(this._storage)
      : super(_storage.getSyncCooldownMinutes());

  Future<void> cycle() async {
    final currentIndex = syncCooldownSteps.indexOf(state);
    final next =
        syncCooldownSteps[(currentIndex + 1) % syncCooldownSteps.length];
    state = next;
    await _storage.setSyncCooldownMinutes(next);
  }
}

final syncCooldownProvider =
    StateNotifierProvider<SyncCooldownNotifier, int>((ref) {
  return SyncCooldownNotifier(ref.read(storageServiceProvider));
});

String formatSyncCooldown(int minutes) => switch (minutes) {
      0 => 'Always',
      15 => '15 min',
      30 => '30 min',
      60 => '1 hour',
      120 => '2 hours',
      360 => '6 hours',
      _ => '${minutes}m',
    };

// --- Haptic Enabled ---

class HapticEnabledNotifier extends StateNotifier<bool> {
  final StorageService _storage;
  final HapticService _haptic;

  HapticEnabledNotifier(this._storage, this._haptic)
      : super(_storage.getHapticEnabled());

  Future<void> toggle() async {
    final newValue = !state;
    state = newValue;
    _haptic.setEnabled(newValue);
    await _storage.setHapticEnabled(newValue);
    if (newValue) _haptic.tick();
  }
}

final hapticEnabledProvider =
    StateNotifierProvider<HapticEnabledNotifier, bool>((ref) {
  return HapticEnabledNotifier(
    ref.read(storageServiceProvider),
    ref.read(hapticServiceProvider),
  );
});

// --- Allow Non-LAN HTTP ---

class AllowNonLanHttpNotifier extends StateNotifier<bool> {
  final StorageService _storage;

  AllowNonLanHttpNotifier(this._storage)
      : super(_storage.getAllowNonLanHttp());

  Future<void> toggle() async {
    final newValue = !state;
    state = newValue;
    await _storage.setAllowNonLanHttp(newValue);
  }
}

final allowNonLanHttpProvider =
    StateNotifierProvider<AllowNonLanHttpNotifier, bool>((ref) {
  return AllowNonLanHttpNotifier(ref.read(storageServiceProvider));
});

final deviceMemoryProvider = Provider<DeviceMemoryInfo>((ref) {
  throw UnimplementedError('Must be overridden in main.dart');
});

final storageInfoProvider =
    FutureProvider.autoDispose.family<StorageInfo?, String>(
  (ref, path) => DiskSpaceService.getFreeSpace(path),
);


/// Which source the running (or most recent) sync is actually talking to.
///
/// Set when a sync resolves its source, so both the home header and the sync
/// badge can name the server — with two sources configured, "syncing 3/8" on
/// its own does not say *whose* library is being fetched.
///
/// [isFallback] is true when the selected source was unreachable and its
/// partner stood in. Null means no single answer applies: every source is in
/// view, or nothing has resolved yet.
final syncingSourceProvider =
    StateProvider<({String name, bool isFallback})?>((ref) => null);

class ActiveFailoverChoiceNotifier extends StateNotifier<SourceChoice?> {
  final Ref _ref;

  ActiveFailoverChoiceNotifier(this._ref) : super(null) {
    _ref.listen<SourcesState>(sourcesProvider, (previous, next) async {
      if (previous != null && !next.loading) {
        await refresh();
      }
    });
  }

  set choice(SourceChoice? value) => state = value;

  Future<void> refresh() async {
    try {
      final probe = _ref.read(endpointProbeServiceProvider);
      probe.invalidate();
      final configStorage = _ref.read(configStorageServiceProvider);
      final config = await configStorage.loadConfig();
      if (config != null) {
        final resolved = await resolveForSync(config: config, probe: probe);
        state = resolved.choice;
      }
    } catch (e) {
      debugPrint('Auto failover sync failed: $e');
    }
  }
}

/// Represents current failover choice state across the app.
/// When non-null and choice.isFallback is true, primary source failed to connect
/// and a fallback source is in active use.
final activeFailoverChoiceProvider =
    StateNotifierProvider<ActiveFailoverChoiceNotifier, SourceChoice?>((ref) {
  return ActiveFailoverChoiceNotifier(ref);
});
