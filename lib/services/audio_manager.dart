import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import '../models/sound_settings.dart';

enum SoundType { navigation, confirm, cancel, typing }

class AudioManager {
  SoLoud? _soLoud;
  SoundHandle? _bgmHandle;
  SoundHandle? _typingHandle;
  AudioSource? _bgmSource;

  final Map<SoundType, AudioSource> _soundSources = {};

  SoundSettings _settings = const SoundSettings();
  int _lastNavigationTime = 0;
  static const int _navigationDebounceMs = 60;
  static const double _pitchVarianceMin = 0.95;
  static const double _pitchVarianceMax = 1.05;

  final Random _random = Random();
  bool _isInitialized = false;
  bool _isInitializing = false;
  bool _bgmStarted = false;
  bool _bgmStarting = false;
  bool _hasAttemptedReinit = false;

  bool get isInitialized => _isInitialized;
  SoundSettings get settings => _settings;

  Future<void> init() async {
    if (_isInitialized || _isInitializing) return;

    _isInitializing = true;
    _soLoud = SoLoud.instance;

    try {
      await _initSoLoud();
      _isInitialized = true;
    } catch (e) {
      debugPrint('AudioManager: init failed: $e');
      _soLoud = null;
      _isInitialized = false;
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> _initSoLoud() async {
    await _soLoud!.init();
    await _preloadSounds();
  }

  Future<bool> _preloadSounds() async {
    if (_soLoud == null) return false;

    try {
      _soundSources[SoundType.navigation] =
          await _soLoud!.loadAsset('assets/sounds/navigation.wav');
      _soundSources[SoundType.confirm] =
          await _soLoud!.loadAsset('assets/sounds/confirm.wav');
      _soundSources[SoundType.cancel] =
          await _soLoud!.loadAsset('assets/sounds/cancel.wav');
      _soundSources[SoundType.typing] =
          await _soLoud!.loadAsset('assets/sounds/rapid_text.wav');
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
    if (_soLoud == null || !_isInitialized) return;

    final bgmVolume = _settings.enabled ? _settings.bgmVolume : 0.0;

    if (_bgmHandle != null) {
      try {
        _soLoud!.setVolume(_bgmHandle!, bgmVolume);
      } catch (_) {}
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
    if (source == null || _soLoud == null || !_isInitialized) return;

    try {
      _soLoud!.play(source, volume: _settings.sfxVolume).then((handle) {
        if (pitch != 1.0) {
          try {
            _soLoud!.setRelativePlaySpeed(handle, pitch);
          } catch (_) {}
        }
      });
    } catch (_) {}

  }

  Future<void> startBgm() async {
    if (!_isInitialized || _soLoud == null || _bgmStarting) {
      return;
    }

    if (_bgmStarted && _bgmHandle != null) {
      try {
        _soLoud!.getVolume(_bgmHandle!);
        return;
      } catch (_) {
        _bgmSource = null;
        _bgmHandle = null;
        _bgmStarted = false;
      }
    }

    _bgmStarting = true;

    try {
      _bgmSource = await _soLoud!.loadAsset('assets/sounds/ambience.wav');
      _bgmHandle = await _soLoud!.play(_bgmSource!, volume: 0.0, looping: true);

      _bgmStarted = true;
      _bgmStarting = false;

      if (_settings.enabled) {
        _soLoud!.fadeVolume(
            _bgmHandle!, _settings.bgmVolume, const Duration(seconds: 2));
      }
    } catch (e) {
      debugPrint('AudioManager: startBgm failed: $e');
      _bgmStarting = false;
      _bgmStarted = false;
      if (!_hasAttemptedReinit) {
        await _reinitializeAndRetryBgm();
      }
    }
  }

  Future<void> _reinitializeAndRetryBgm() async {
    _hasAttemptedReinit = true;
    _isInitialized = false;
    _soundSources.clear();

    await Future.delayed(const Duration(milliseconds: 100));

    try {
      await _soLoud!.init();
      if (await _preloadSounds()) {
        _isInitialized = true;
        await startBgm();
      }
    } catch (e) {
      debugPrint('AudioManager: reinit failed: $e');
    }
  }

  void stopBgm() {
    if (_bgmHandle == null || _soLoud == null || !_isInitialized) return;

    try {
      _soLoud!.fadeVolume(_bgmHandle!, 0.0, const Duration(milliseconds: 500));
      Future.delayed(const Duration(milliseconds: 600), () {
        if (_bgmHandle != null && _soLoud != null && _isInitialized) {
          try {
            _soLoud!.stop(_bgmHandle!);
          } catch (_) {}
        }
      });
    } catch (_) {}
  }

  void setBgmVolume(double volume) {
    if (_bgmHandle == null || _soLoud == null || !_isInitialized) return;

    try {
      _soLoud!.setVolume(_bgmHandle!, _settings.enabled ? volume : 0.0);
    } catch (_) {}
  }

  Future<void> startTyping() async {
    if (!_settings.enabled || !_isInitialized) return;

    final source = _soundSources[SoundType.typing];
    if (source == null) return;

    stopTyping();

    try {
      _typingHandle = await _soLoud!
          .play(source, volume: _settings.sfxVolume, looping: true);
    } catch (_) {}
  }

  void stopTyping() {
    if (_typingHandle == null || _soLoud == null) return;

    try {
      _soLoud!.stop(_typingHandle!);
    } catch (_) {}
    _typingHandle = null;
  }

  void pause() {
    if (!_isInitialized || _soLoud == null) return;

    stopTyping();

    if (_bgmHandle != null && _bgmStarted) {
      try {
        _soLoud!.setPause(_bgmHandle!, true);
      } catch (_) {}
    }
  }

  void resume() {
    if (!_isInitialized || _soLoud == null) return;

    if (_bgmHandle != null && _bgmStarted) {
      try {
        _soLoud!.setPause(_bgmHandle!, false);
      } catch (_) {}
    }
  }

  void stopAll() {
    stopTyping();
    stopBgm();
  }

  Future<void> dispose() async {
    if (!_isInitialized) return;

    try {
      stopTyping();
      stopBgm();
    } catch (_) {}

    if (_soLoud != null) {
      try {
        for (final source in _soundSources.values) {
          _soLoud!.disposeSource(source);
        }
        if (_bgmSource != null) {
          _soLoud!.disposeSource(_bgmSource!);
        }
        _soLoud!.deinit();
      } catch (e) {
        debugPrint('AudioManager: dispose cleanup failed: $e');
      }
    }

    _soundSources.clear();
    _bgmSource = null;
    _bgmHandle = null;
    _typingHandle = null;
    _soLoud = null;
    _isInitialized = false;
    _bgmStarted = false;
    _bgmStarting = false;

  }
}
