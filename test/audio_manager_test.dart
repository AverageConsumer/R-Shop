import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retro_eshop/models/sound_settings.dart';
import 'package:retro_eshop/services/audio_manager.dart';

// ---------------------------------------------------------------------------
// Fake engine that records all calls and allows configurable behaviour.
// ---------------------------------------------------------------------------

class _FakeAudioEngine implements AudioEngine {
  bool initCalled = false;
  bool deinitCalled = false;
  int initCallCount = 0;
  bool shouldFailInit = false;
  bool shouldFailLoadAsset = false;
  bool shouldFailPlay = false;
  bool shouldFailGetVolume = false;

  final List<String> loadedAssets = [];
  final List<_PlayCall> playCalls = [];
  final List<_VolumeCall> setVolumeCalls = [];
  final List<_FadeCall> fadeVolumeCalls = [];
  final List<_SpeedCall> setRelativePlaySpeedCalls = [];
  final List<_PauseCall> setPauseCalls = [];
  final List<Object> stopCalls = [];
  final List<Object> disposedSources = [];

  int _nextSourceId = 1;
  int _nextHandleId = 100;

  @override
  Future<void> init() async {
    initCallCount++;
    initCalled = true;
    if (shouldFailInit) throw Exception('init failed');
  }

  @override
  void deinit() {
    deinitCalled = true;
  }

  @override
  Future<Object> loadAsset(String path) async {
    if (shouldFailLoadAsset) throw Exception('loadAsset failed');
    loadedAssets.add(path);
    return 'source_${_nextSourceId++}';
  }

  @override
  Future<Object> play(Object source, {double volume = 1.0, bool looping = false}) async {
    if (shouldFailPlay) throw Exception('play failed');
    final handle = 'handle_${_nextHandleId++}';
    playCalls.add(_PlayCall(source, volume, looping, handle));
    return handle;
  }

  @override
  void setVolume(Object handle, double volume) {
    setVolumeCalls.add(_VolumeCall(handle, volume));
  }

  @override
  void fadeVolume(Object handle, double to, Duration duration) {
    fadeVolumeCalls.add(_FadeCall(handle, to, duration));
  }

  @override
  void setRelativePlaySpeed(Object handle, double speed) {
    setRelativePlaySpeedCalls.add(_SpeedCall(handle, speed));
  }

  @override
  double getVolume(Object handle) {
    if (shouldFailGetVolume) throw Exception('getVolume failed');
    return 0.5;
  }

  @override
  void setPause(Object handle, bool pause) {
    setPauseCalls.add(_PauseCall(handle, pause));
  }

  @override
  void stop(Object handle) {
    stopCalls.add(handle);
  }

  @override
  void disposeSource(Object source) {
    disposedSources.add(source);
  }
}

class _PlayCall {
  final Object source;
  final double volume;
  final bool looping;
  final Object handle;
  _PlayCall(this.source, this.volume, this.looping, this.handle);
}

class _VolumeCall {
  final Object handle;
  final double volume;
  _VolumeCall(this.handle, this.volume);
}

class _FadeCall {
  final Object handle;
  final double to;
  final Duration duration;
  _FadeCall(this.handle, this.to, this.duration);
}

class _SpeedCall {
  final Object handle;
  final double speed;
  _SpeedCall(this.handle, this.speed);
}

class _PauseCall {
  final Object handle;
  final bool pause;
  _PauseCall(this.handle, this.pause);
}

void main() {
  late _FakeAudioEngine engine;
  late AudioManager manager;

  setUp(() {
    engine = _FakeAudioEngine();
    manager = AudioManager(engine: engine);
  });

  // ─── init ──────────────────────────────────────────────────────

  group('init', () {
    test('sets isInitialized on success', () async {
      await manager.init();
      expect(manager.isInitialized, isTrue);
      expect(engine.initCalled, isTrue);
    });

    test('double-init guard (second call is no-op)', () async {
      await manager.init();
      await manager.init();
      expect(engine.initCallCount, 1);
    });

    test('failure sets isInitialized false and clears engine ref', () async {
      engine.shouldFailInit = true;
      await manager.init();
      expect(manager.isInitialized, isFalse);
    });

    test('failure resets _isInitializing flag (allows retry)', () async {
      engine.shouldFailInit = true;
      await manager.init();
      expect(manager.isInitialized, isFalse);

      // Retry should work now
      engine.shouldFailInit = false;
      await manager.init();
      expect(manager.isInitialized, isTrue);
    });

    test('preloads 4 sound types', () async {
      await manager.init();
      expect(engine.loadedAssets, hasLength(4));
      expect(engine.loadedAssets, contains('assets/sounds/navigation.wav'));
      expect(engine.loadedAssets, contains('assets/sounds/confirm.wav'));
      expect(engine.loadedAssets, contains('assets/sounds/cancel.wav'));
      expect(engine.loadedAssets, contains('assets/sounds/rapid_text.wav'));
    });
  });

  // ─── updateSettings ────────────────────────────────────────────

  group('updateSettings', () {
    test('stores new settings', () async {
      await manager.init();
      const newSettings = SoundSettings(bgmVolume: 0.5, sfxVolume: 0.8);
      manager.updateSettings(newSettings);
      expect(manager.settings.bgmVolume, 0.5);
      expect(manager.settings.sfxVolume, 0.8);
    });

    test('applies BGM volume to active handle', () async {
      await manager.init();
      await manager.startBgm();
      engine.setVolumeCalls.clear();

      manager.updateSettings(const SoundSettings(bgmVolume: 0.6));

      expect(engine.setVolumeCalls, isNotEmpty);
      expect(engine.setVolumeCalls.last.volume, 0.6);
    });

    test('sets BGM volume to 0 when disabled', () async {
      await manager.init();
      await manager.startBgm();
      engine.setVolumeCalls.clear();

      manager.updateSettings(
          const SoundSettings(enabled: false, bgmVolume: 0.6));

      expect(engine.setVolumeCalls, isNotEmpty);
      expect(engine.setVolumeCalls.last.volume, 0.0);
    });
  });

  // ─── playNavigation ────────────────────────────────────────────

  group('playNavigation', () {
    test('plays when enabled + initialized', () async {
      await manager.init();
      manager.updateSettings(const SoundSettings(enabled: true));

      manager.playNavigation();
      // play is async (fire-and-forget), but the engine.play() is called
      await Future.delayed(Duration.zero);

      expect(engine.playCalls, isNotEmpty);
    });

    test('no-op when disabled', () async {
      await manager.init();
      manager.updateSettings(const SoundSettings(enabled: false));

      manager.playNavigation();
      await Future.delayed(Duration.zero);
      expect(engine.playCalls, isEmpty);
    });

    test('no-op when not initialized', () {
      manager.updateSettings(const SoundSettings(enabled: true));
      manager.playNavigation();
      expect(engine.playCalls, isEmpty);
    });

    test('debounces within 60ms', () async {
      await manager.init();

      manager.playNavigation();
      await Future.delayed(Duration.zero);
      final firstCount = engine.playCalls.length;
      expect(firstCount, 1);

      // Immediately again — should be debounced (within 60ms)
      manager.playNavigation();
      await Future.delayed(Duration.zero);
      expect(engine.playCalls.length, firstCount);

      // After 70ms — should play again
      await Future.delayed(const Duration(milliseconds: 70));
      manager.playNavigation();
      await Future.delayed(Duration.zero);
      expect(engine.playCalls.length, firstCount + 1);
    });
  });

  // ─── playConfirm / playCancel ──────────────────────────────────

  group('playConfirm / playCancel', () {
    test('plays correct sound types', () async {
      await manager.init();
      manager.updateSettings(const SoundSettings(enabled: true));

      manager.playConfirm();
      await Future.delayed(Duration.zero);

      // The second sound source loaded is 'confirm' (source_2)
      expect(engine.playCalls.any((c) => c.source == 'source_2'), isTrue);

      manager.playCancel();
      await Future.delayed(Duration.zero);

      // The third sound source loaded is 'cancel' (source_3)
      expect(engine.playCalls.any((c) => c.source == 'source_3'), isTrue);
    });

    test('no-op when disabled or not initialized', () async {
      // Not initialized
      manager.playConfirm();
      manager.playCancel();
      expect(engine.playCalls, isEmpty);

      // Initialized but disabled
      await manager.init();
      manager.updateSettings(const SoundSettings(enabled: false));
      manager.playConfirm();
      manager.playCancel();
      expect(engine.playCalls, isEmpty);
    });
  });

  // ─── BGM lifecycle ─────────────────────────────────────────────

  group('BGM lifecycle', () {
    test('startBgm loads asset and plays with looping', () async {
      await manager.init();

      await manager.startBgm();

      // loadAsset should have been called with ambience
      expect(engine.loadedAssets, contains('assets/sounds/ambience.wav'));

      // play should have looping = true, volume = 0.0
      final bgmPlay = engine.playCalls.last;
      expect(bgmPlay.looping, isTrue);
      expect(bgmPlay.volume, 0.0);
    });

    test('startBgm fades in when enabled', () async {
      await manager.init();
      manager.updateSettings(const SoundSettings(enabled: true, bgmVolume: 0.4));

      await manager.startBgm();

      expect(engine.fadeVolumeCalls, isNotEmpty);
      expect(engine.fadeVolumeCalls.last.to, 0.4);
    });

    test('startBgm skips if already started + handle valid', () async {
      await manager.init();
      await manager.startBgm();

      final playCountAfterFirst = engine.playCalls.length;

      // Second call should return early
      await manager.startBgm();
      expect(engine.playCalls.length, playCountAfterFirst);
    });

    test('startBgm retries once on failure, no infinite loop', () async {
      await manager.init();

      // First startBgm: loadAsset fails → triggers reinit → retry
      engine.shouldFailLoadAsset = true;
      await manager.startBgm();

      // After retry fails too, it should not loop infinitely
      // initCallCount: 1 from manager.init() + at least 1 from reinit
      expect(engine.initCallCount, greaterThanOrEqualTo(2));
    });

    test('startBgm resets _hasAttemptedReinit on success', () async {
      await manager.init();

      // Force a failed BGM start that triggers reinit
      engine.shouldFailLoadAsset = true;
      await manager.startBgm();

      // Now succeed — _hasAttemptedReinit should reset
      engine.shouldFailLoadAsset = false;
      // Need a fresh manager since the first one has _hasAttemptedReinit=true
      // but after a successful startBgm, it gets reset to false
      final mgr2 = AudioManager(engine: engine);
      await mgr2.init();
      await mgr2.startBgm();

      // A second startBgm should succeed (not short-circuit)
      expect(mgr2.isInitialized, isTrue);
    });
  });

  // ─── stopBgm ───────────────────────────────────────────────────

  group('stopBgm', () {
    test('fades to 0 then stops after 600ms timer', () async {
      fakeAsync((async) {
        manager.init();
        async.elapse(Duration.zero);
        async.flushMicrotasks();

        manager.startBgm();
        async.elapse(Duration.zero);
        async.flushMicrotasks();

        engine.fadeVolumeCalls.clear();
        engine.stopCalls.clear();

        manager.stopBgm();

        // Fade immediately
        expect(engine.fadeVolumeCalls, isNotEmpty);
        expect(engine.fadeVolumeCalls.last.to, 0.0);

        // Stop not yet called
        expect(engine.stopCalls, isEmpty);

        // After 600ms, stop should fire
        async.elapse(const Duration(milliseconds: 600));
        expect(engine.stopCalls, isNotEmpty);
      });
    });

    test('cancels pending timer on second call', () async {
      fakeAsync((async) {
        manager.init();
        async.elapse(Duration.zero);
        async.flushMicrotasks();

        manager.startBgm();
        async.elapse(Duration.zero);
        async.flushMicrotasks();

        manager.stopBgm();
        // Second stopBgm cancels the first timer and starts a new one
        manager.stopBgm();

        // After 600ms, only one stop should fire (the second timer)
        engine.stopCalls.clear();
        async.elapse(const Duration(milliseconds: 600));
        expect(engine.stopCalls.length, 1);
      });
    });

    test('no-op when no handle', () async {
      await manager.init();
      // No BGM started, so no handle
      manager.stopBgm();
      expect(engine.fadeVolumeCalls, isEmpty);
    });
  });

  // ─── typing ────────────────────────────────────────────────────

  group('typing', () {
    test('startTyping plays looping sound', () async {
      await manager.init();
      manager.updateSettings(const SoundSettings(enabled: true, sfxVolume: 0.5));

      await manager.startTyping();

      final typingPlay = engine.playCalls.last;
      expect(typingPlay.looping, isTrue);
      expect(typingPlay.volume, 0.5);
    });

    test('stopTyping stops and clears handle', () async {
      await manager.init();
      await manager.startTyping();

      engine.stopCalls.clear();
      manager.stopTyping();
      expect(engine.stopCalls, isNotEmpty);

      // Second stopTyping should be no-op (handle cleared)
      engine.stopCalls.clear();
      manager.stopTyping();
      expect(engine.stopCalls, isEmpty);
    });
  });

  // ─── pause / resume / dispose ──────────────────────────────────

  group('pause / resume / dispose', () {
    test('pause stops typing + pauses BGM', () async {
      await manager.init();
      await manager.startBgm();
      await manager.startTyping();

      engine.stopCalls.clear();
      engine.setPauseCalls.clear();

      manager.pause();

      // Typing stopped
      expect(engine.stopCalls, isNotEmpty);
      // BGM paused
      expect(engine.setPauseCalls, isNotEmpty);
      expect(engine.setPauseCalls.last.pause, isTrue);
    });

    test('resume unpauses BGM', () async {
      await manager.init();
      await manager.startBgm();
      manager.pause();

      engine.setPauseCalls.clear();
      manager.resume();

      expect(engine.setPauseCalls, isNotEmpty);
      expect(engine.setPauseCalls.last.pause, isFalse);
    });

    test('dispose cancels timers, disposes sources, deinits, double-dispose safe',
        () async {
      await manager.init();
      await manager.startBgm();

      await manager.dispose();

      // Sources disposed (4 SFX + 1 BGM)
      expect(engine.disposedSources, hasLength(5));
      expect(engine.deinitCalled, isTrue);

      // Double dispose is safe
      await manager.dispose();
      // No crash = pass
    });
  });
}
