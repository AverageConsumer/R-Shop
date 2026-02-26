import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import '../models/sound_settings.dart';

enum SoundType { navigation, confirm, cancel, typing }

/// Thin abstraction over SoLoud so AudioManager can be tested with a fake.
/// Handles are [Object] because SoLoud's concrete types have @internal ctors.
abstract class AudioEngine {
  Future<void> init();
  void deinit();
  Future<Object> loadAsset(String path);
  Future<Object> play(Object source, {double volume, bool looping});
  void setVolume(Object handle, double volume);
  void fadeVolume(Object handle, double to, Duration duration);
  void setRelativePlaySpeed(Object handle, double speed);
  double getVolume(Object handle);
  void setPause(Object handle, bool pause);
  void stop(Object handle);
  void disposeSource(Object source);
}

class _SoLoudEngine implements AudioEngine {
  final SoLoud _soLoud = SoLoud.instance;

  @override
  Future<void> init() => _soLoud.init();

  @override
  void deinit() => _soLoud.deinit();

  @override
  Future<Object> loadAsset(String path) => _soLoud.loadAsset(path);

  @override
  Future<Object> play(Object source,
      {double volume = 1.0, bool looping = false}) async {
    final SoundHandle handle = await _soLoud.play(source as AudioSource,
        volume: volume, looping: looping);
    // SoundHandle is an extension type on int — box it as Object explicitly
    return handle as Object;
  }

  @override
  void setVolume(Object handle, double volume) =>
      _soLoud.setVolume(handle as SoundHandle, volume);

  @override
  void fadeVolume(Object handle, double to, Duration duration) =>
      _soLoud.fadeVolume(handle as SoundHandle, to, duration);

  @override
  void setRelativePlaySpeed(Object handle, double speed) =>
      _soLoud.setRelativePlaySpeed(handle as SoundHandle, speed);

  @override
  double getVolume(Object handle) =>
      _soLoud.getVolume(handle as SoundHandle);

  @override
  void setPause(Object handle, bool pause) =>
      _soLoud.setPause(handle as SoundHandle, pause);

  @override
  void stop(Object handle) => _soLoud.stop(handle as SoundHandle);

  @override
  void disposeSource(Object source) =>
      _soLoud.disposeSource(source as AudioSource);
}

class AudioManager {
  AudioEngine? _engine;
  final AudioEngine? _injectedEngine;
  Object? _bgmHandle;
  Object? _typingHandle;
  Object? _bgmSource;

  final Map<SoundType, Object> _soundSources = {};

  SoundSettings _settings = const SoundSettings();
  int _lastNavigationTime = 0;
  static const int _navigationDebounceMs = 60;
  static const double _pitchVarianceMin = 0.95;
  static const double _pitchVarianceMax = 1.05;

  final Random _random = Random();
  bool _isInitialized = false;
  bool _isInitializing = false;
  bool _isDisposed = false;
  bool _bgmStarted = false;
  bool _bgmStarting = false;
  bool _hasAttemptedReinit = false;
  Timer? _bgmStopTimer;

  AudioManager({AudioEngine? engine}) : _injectedEngine = engine;

  bool get isInitialized => _isInitialized;
  SoundSettings get settings => _settings;

  Future<void> init() async {
    if (_isInitialized || _isInitializing) return;

    _isInitializing = true;
    _engine = _injectedEngine ?? _SoLoudEngine();

    try {
      await _initEngine();
      _isInitialized = true;
    } catch (e) {
      debugPrint('AudioManager: init failed: $e');
      _engine = null;
      _isInitialized = false;
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> _initEngine() async {
    await _engine!.init();
    await _preloadSounds();
  }

  Future<bool> _preloadSounds() async {
    if (_engine == null) return false;

    try {
      _soundSources[SoundType.navigation] =
          await _engine!.loadAsset('assets/sounds/navigation.wav');
      _soundSources[SoundType.confirm] =
          await _engine!.loadAsset('assets/sounds/confirm.wav');
      _soundSources[SoundType.cancel] =
          await _engine!.loadAsset('assets/sounds/cancel.wav');
      _soundSources[SoundType.typing] =
          await _engine!.loadAsset('assets/sounds/rapid_text.wav');
      return true;
    } catch (e) {
      debugPrint('AudioManager: preload sounds failed: $e');
      return false;
    }
  }

  void updateSettings(SoundSettings settings) {
    _settings = settings;
    _applyVolumes();
  }

  void _applyVolumes() {
    if (_engine == null || !_isInitialized) return;

    final bgmVolume = _settings.enabled ? _settings.bgmVolume : 0.0;

    if (_bgmHandle != null) {
      try {
        _engine!.setVolume(_bgmHandle!, bgmVolume);
      } catch (e) {
        debugPrint('AudioManager: setVolume failed: $e');
      }
    }
  }

  void playNavigation() {
    if (!_settings.enabled || !_isInitialized) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastNavigationTime < _navigationDebounceMs) return;
    _lastNavigationTime = now;

    final pitch = _pitchVarianceMin +
        _random.nextDouble() * (_pitchVarianceMax - _pitchVarianceMin);
    _playSound(SoundType.navigation, pitch: pitch);
  }

  void playConfirm() {
    if (!_settings.enabled || !_isInitialized) return;
    _playSound(SoundType.confirm);
  }

  void playCancel() {
    if (!_settings.enabled || !_isInitialized) return;
    _playSound(SoundType.cancel);
  }

  void _playSound(SoundType type, {double pitch = 1.0}) {
    final source = _soundSources[type];
    if (source == null || _engine == null || !_isInitialized) return;

    try {
      _engine!.play(source, volume: _settings.sfxVolume).then((handle) {
        if (pitch != 1.0 && _engine != null) {
          try {
            _engine!.setRelativePlaySpeed(handle, pitch);
          } catch (e) {
            debugPrint('AudioManager: setRelativePlaySpeed failed: $e');
          }
        }
      }).catchError((e) {
        debugPrint('AudioManager: play future failed: $e');
      });
    } catch (e) {
      debugPrint('AudioManager: playSound failed: $e');
    }
  }

  Future<void> startBgm() async {
    if (!_isInitialized || _engine == null || _bgmStarting) {
      return;
    }

    if (_bgmStarted && _bgmHandle != null) {
      try {
        _engine!.getVolume(_bgmHandle!);
        return;
      } catch (e) {
        debugPrint('AudioManager: BGM handle invalid, restarting: $e');
        _bgmSource = null;
        _bgmHandle = null;
        _bgmStarted = false;
      }
    }

    _bgmStarting = true;

    try {
      _bgmSource = await _engine!.loadAsset('assets/sounds/ambience.wav');
      _bgmHandle = await _engine!.play(_bgmSource!, volume: 0.0, looping: true);

      _bgmStarted = true;
      _bgmStarting = false;
      _hasAttemptedReinit = false;

      if (_settings.enabled) {
        _engine!.fadeVolume(
            _bgmHandle!, _settings.bgmVolume, const Duration(seconds: 2));
      }
    } catch (e) {
      debugPrint('AudioManager: startBgm failed: $e');
      _bgmStarting = false;
      _bgmStarted = false;
      if (!_hasAttemptedReinit) {
        final reinitOk = await _reinitializeAndRetryBgm();
        if (reinitOk) {
          // Retry BGM once after successful reinit (non-recursive: _hasAttemptedReinit is now true)
          await startBgm();
        }
      }
    }
  }

  Future<bool> _reinitializeAndRetryBgm() async {
    _hasAttemptedReinit = true;
    _isInitialized = false;
    _soundSources.clear();

    await Future.delayed(const Duration(milliseconds: 100));

    try {
      await _engine!.init();
      if (await _preloadSounds()) {
        _isInitialized = true;
        return true;
      }
    } catch (e) {
      debugPrint('AudioManager: reinit failed: $e');
    }
    return false;
  }

  void stopBgm() {
    if (_bgmHandle == null || _engine == null || !_isInitialized) return;

    try {
      _engine!.fadeVolume(_bgmHandle!, 0.0, const Duration(milliseconds: 500));
      _bgmStopTimer?.cancel();
      _bgmStopTimer = Timer(const Duration(milliseconds: 600), () {
        if (_isDisposed) return;
        if (_bgmHandle != null && _engine != null && _isInitialized) {
          try {
            _engine!.stop(_bgmHandle!);
          } catch (e) {
            debugPrint('AudioManager: stopBgm delayed stop failed: $e');
          }
        }
      });
    } catch (e) {
      debugPrint('AudioManager: stopBgm fadeVolume failed: $e');
    }
  }

  void setBgmVolume(double volume) {
    if (_bgmHandle == null || _engine == null || !_isInitialized) return;

    try {
      _engine!.setVolume(_bgmHandle!, _settings.enabled ? volume : 0.0);
    } catch (e) {
      debugPrint('AudioManager: setBgmVolume failed: $e');
    }
  }

  Future<void> startTyping() async {
    if (!_settings.enabled || !_isInitialized) return;

    final source = _soundSources[SoundType.typing];
    if (source == null) return;

    stopTyping();

    try {
      _typingHandle = await _engine!
          .play(source, volume: _settings.sfxVolume, looping: true);
    } catch (e) {
      debugPrint('AudioManager: startTyping failed: $e');
    }
  }

  void stopTyping() {
    if (_typingHandle == null || _engine == null) return;

    try {
      _engine!.stop(_typingHandle!);
    } catch (e) {
      debugPrint('AudioManager: stopTyping failed: $e');
    }
    _typingHandle = null;
  }

  void pause() {
    if (!_isInitialized || _engine == null) return;

    stopTyping();

    if (_bgmHandle != null && _bgmStarted) {
      try {
        _engine!.setPause(_bgmHandle!, true);
      } catch (e) {
        debugPrint('AudioManager: pause failed: $e');
      }
    }
  }

  void resume() {
    if (!_isInitialized || _engine == null) return;

    if (_bgmHandle != null && _bgmStarted) {
      try {
        _engine!.setPause(_bgmHandle!, false);
      } catch (e) {
        debugPrint('AudioManager: resume failed: $e');
      }
    }
  }

  void stopAll() {
    stopTyping();
    stopBgm();
  }

  Future<void> dispose() async {
    if (_isDisposed || !_isInitialized) return;
    _isDisposed = true;
    _bgmStopTimer?.cancel();

    try {
      stopTyping();
      stopBgm();
    } catch (e) {
      debugPrint('AudioManager: dispose stopAll failed: $e');
    }

    if (_engine != null) {
      try {
        for (final source in _soundSources.values) {
          _engine!.disposeSource(source);
        }
        if (_bgmSource != null) {
          _engine!.disposeSource(_bgmSource!);
        }
        _engine!.deinit();
      } catch (e) {
        debugPrint('AudioManager: dispose cleanup failed: $e');
      }
    }

    _soundSources.clear();
    _bgmSource = null;
    _bgmHandle = null;
    _typingHandle = null;
    _engine = null;
    _isInitialized = false;
    _bgmStarted = false;
    _bgmStarting = false;

  }
}
