import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/storage_service.dart';
import '../services/repo_manager.dart';
import '../services/haptic_service.dart';
import '../services/audio_manager.dart';
import '../services/feedback_service.dart';
import '../models/sound_settings.dart';

export '../core/input/input_providers.dart'
    show
        mainFocusRequestProvider,
        restoreMainFocus,
        inputDebouncerProvider,
        overlayPriorityProvider,
        OverlayPriority,
        focusStateManagerProvider,
        FocusStateManager,
        FocusStateEntry,
        searchRequestedProvider,
        confirmRequestedProvider;

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

final repoManagerProvider = Provider<RepoManager>((ref) {
  return RepoManager(ref.read(storageServiceProvider));
});

class SoundSettingsNotifier extends StateNotifier<SoundSettings> {
  final StorageService _storage;
  final AudioManager _audioManager;

  SoundSettingsNotifier(this._storage, this._audioManager)
      : super(_storage.getSoundSettings());

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
      : super(
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
