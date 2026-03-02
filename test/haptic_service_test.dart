import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:retro_eshop/services/haptic_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HapticService service;
  late List<String> hapticCalls;

  setUp(() {
    service = HapticService();
    hapticCalls = [];

    // Mock the platform channel to track HapticFeedback calls
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        hapticCalls.add(call.arguments as String);
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group('HapticService', () {
    test('enabled is true by default', () {
      expect(service.enabled, isTrue);
    });

    test('setEnabled changes state', () {
      service.setEnabled(false);
      expect(service.enabled, isFalse);
      service.setEnabled(true);
      expect(service.enabled, isTrue);
    });

    test('tick calls selectionClick when enabled', () {
      service.tick();
      expect(hapticCalls, contains('HapticFeedbackType.selectionClick'));
    });

    test('tick does nothing when disabled', () {
      service.setEnabled(false);
      service.tick();
      expect(hapticCalls, isEmpty);
    });

    test('select calls mediumImpact when enabled', () {
      service.select();
      expect(hapticCalls, contains('HapticFeedbackType.mediumImpact'));
    });

    test('select does nothing when disabled', () {
      service.setEnabled(false);
      service.select();
      expect(hapticCalls, isEmpty);
    });

    test('action calls mediumImpact', () {
      service.action();
      expect(hapticCalls, contains('HapticFeedbackType.mediumImpact'));
    });

    test('warning calls heavyImpact', () {
      service.warning();
      expect(hapticCalls, contains('HapticFeedbackType.heavyImpact'));
    });

    test('error calls heavyImpact', () {
      service.error();
      expect(hapticCalls, contains('HapticFeedbackType.heavyImpact'));
    });

    test('lightImpact calls lightImpact', () {
      service.lightImpact();
      expect(hapticCalls, contains('HapticFeedbackType.lightImpact'));
    });

    test('heavyImpact calls heavyImpact', () {
      service.heavyImpact();
      expect(hapticCalls, contains('HapticFeedbackType.heavyImpact'));
    });

    test('mediumImpact calls mediumImpact', () {
      service.mediumImpact();
      expect(hapticCalls, contains('HapticFeedbackType.mediumImpact'));
    });

    test('re-enabling after disable works', () {
      service.setEnabled(false);
      service.tick();
      expect(hapticCalls, isEmpty);

      service.setEnabled(true);
      service.tick();
      expect(hapticCalls, hasLength(1));
    });

    test('all methods respect disabled state', () {
      service.setEnabled(false);
      service.tick();
      service.select();
      service.action();
      service.success();
      service.warning();
      service.error();
      service.mediumImpact();
      service.lightImpact();
      service.heavyImpact();
      expect(hapticCalls, isEmpty);
    });
  });
}
