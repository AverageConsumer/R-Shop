import 'package:flutter_test/flutter_test.dart';
import 'package:retro_eshop/services/cover_preload_service.dart';

void main() {
  group('CoverPreloadState', () {
    test('default constructor has all fields zero/false', () {
      const state = CoverPreloadState();
      expect(state.isRunning, isFalse);
      expect(state.total, 0);
      expect(state.completed, 0);
      expect(state.succeeded, 0);
      expect(state.failed, 0);
    });

    test('progress returns 0 when total is 0', () {
      const state = CoverPreloadState();
      expect(state.progress, 0.0);
    });

    test('progress calculates completed / total', () {
      const state = CoverPreloadState(total: 10, completed: 3);
      expect(state.progress, closeTo(0.3, 0.001));
    });

    test('progress returns 1.0 when all completed', () {
      const state = CoverPreloadState(total: 5, completed: 5);
      expect(state.progress, 1.0);
    });

    test('copyWith overrides specified fields, preserves others', () {
      const original = CoverPreloadState(
        isRunning: true,
        total: 100,
        completed: 50,
        succeeded: 45,
        failed: 5,
      );
      final copy = original.copyWith(completed: 60, succeeded: 55);
      expect(copy.isRunning, isTrue);
      expect(copy.total, 100);
      expect(copy.completed, 60);
      expect(copy.succeeded, 55);
      expect(copy.failed, 5);
    });
  });
}
