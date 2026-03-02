import 'package:flutter_test/flutter_test.dart';

import 'package:retro_eshop/services/audio_manager.dart';
import 'package:retro_eshop/services/feedback_service.dart';
import 'package:retro_eshop/services/haptic_service.dart';

// ─── Fakes ───────────────────────────────────────────────

class _TrackingHapticService extends HapticService {
  final List<String> calls = [];

  @override
  void tick() => calls.add('tick');
  @override
  void select() => calls.add('select');
  @override
  void action() => calls.add('action');
  @override
  void success() => calls.add('success');
  @override
  void warning() => calls.add('warning');
  @override
  void error() => calls.add('error');
  @override
  void mediumImpact() => calls.add('mediumImpact');
  @override
  void lightImpact() => calls.add('lightImpact');
  @override
  void heavyImpact() => calls.add('heavyImpact');
}

class _TrackingAudioManager extends AudioManager {
  final List<String> calls = [];

  @override
  void playNavigation() => calls.add('playNavigation');
  @override
  void playConfirm() => calls.add('playConfirm');
  @override
  void playCancel() => calls.add('playCancel');
}

// ─── Tests ───────────────────────────────────────────────

void main() {
  late _TrackingHapticService haptic;
  late _TrackingAudioManager audio;
  late FeedbackService service;

  setUp(() {
    haptic = _TrackingHapticService();
    audio = _TrackingAudioManager();
    service = FeedbackService(audio, haptic);
  });

  group('FeedbackService', () {
    test('tick triggers haptic.tick and audio.playNavigation', () {
      service.tick();
      expect(haptic.calls, ['tick']);
      expect(audio.calls, ['playNavigation']);
    });

    test('select triggers haptic.select and audio.playConfirm', () {
      service.select();
      expect(haptic.calls, ['select']);
      expect(audio.calls, ['playConfirm']);
    });

    test('action triggers haptic.action and audio.playConfirm', () {
      service.action();
      expect(haptic.calls, ['action']);
      expect(audio.calls, ['playConfirm']);
    });

    test('success triggers haptic.success and audio.playConfirm', () {
      service.success();
      expect(haptic.calls, ['success']);
      expect(audio.calls, ['playConfirm']);
    });

    test('warning triggers haptic.warning and audio.playCancel', () {
      service.warning();
      expect(haptic.calls, ['warning']);
      expect(audio.calls, ['playCancel']);
    });

    test('error triggers haptic.error and audio.playCancel', () {
      service.error();
      expect(haptic.calls, ['error']);
      expect(audio.calls, ['playCancel']);
    });

    test('confirm triggers haptic.mediumImpact and audio.playConfirm', () {
      service.confirm();
      expect(haptic.calls, ['mediumImpact']);
      expect(audio.calls, ['playConfirm']);
    });

    test('cancel triggers haptic.mediumImpact and audio.playCancel', () {
      service.cancel();
      expect(haptic.calls, ['mediumImpact']);
      expect(audio.calls, ['playCancel']);
    });

    test('mediumImpact triggers only haptic (no audio)', () {
      service.mediumImpact();
      expect(haptic.calls, ['mediumImpact']);
      expect(audio.calls, isEmpty);
    });

    test('lightImpact triggers only haptic (no audio)', () {
      service.lightImpact();
      expect(haptic.calls, ['lightImpact']);
      expect(audio.calls, isEmpty);
    });

    test('heavyImpact triggers only haptic (no audio)', () {
      service.heavyImpact();
      expect(haptic.calls, ['heavyImpact']);
      expect(audio.calls, isEmpty);
    });
  });
}
