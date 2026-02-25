import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retro_eshop/services/input_debouncer.dart';

void main() {
  group('canPerformAction', () {
    test('first call returns true', () {
      final debouncer = InputDebouncer();
      expect(debouncer.canPerformAction(), isTrue);
      debouncer.dispose();
    });

    test('second immediate call returns false', () {
      final debouncer = InputDebouncer();
      expect(debouncer.canPerformAction(), isTrue);
      expect(debouncer.canPerformAction(), isFalse);
      debouncer.dispose();
    });
  });

  group('startHold', () {
    test('calls action immediately', () {
      final debouncer = InputDebouncer();
      var called = false;
      debouncer.startHold(() => called = true);
      expect(called, isTrue);
      debouncer.dispose();
    });

    test('sets isHolding to true', () {
      final debouncer = InputDebouncer();
      debouncer.startHold(() {});
      expect(debouncer.isHolding, isTrue);
      debouncer.dispose();
    });

    test('returns true on first call', () {
      final debouncer = InputDebouncer();
      final result = debouncer.startHold(() {});
      expect(result, isTrue);
      debouncer.dispose();
    });

    test('returns false if within cooldown', () {
      final debouncer = InputDebouncer();
      debouncer.startHold(() {});
      debouncer.stopHold();
      final result = debouncer.startHold(() {});
      expect(result, isFalse);
      debouncer.dispose();
    });

    test('repeats action after hold delay', () {
      FakeAsync().run((fakeAsync) {
        final debouncer = InputDebouncer();
        var count = 0;
        debouncer.startHold(() => count++);
        expect(count, 1);

        fakeAsync.elapse(const Duration(milliseconds: 300));
        expect(count, 2);

        debouncer.dispose();
      });
    });
  });

  group('stopHold', () {
    test('resets isHolding to false', () {
      final debouncer = InputDebouncer();
      debouncer.startHold(() {});
      debouncer.stopHold();
      expect(debouncer.isHolding, isFalse);
      debouncer.dispose();
    });

    test('cancels timer - no further actions after stop', () {
      FakeAsync().run((fakeAsync) {
        final debouncer = InputDebouncer();
        var count = 0;
        debouncer.startHold(() => count++);
        expect(count, 1);

        debouncer.stopHold();
        fakeAsync.elapse(const Duration(milliseconds: 500));

        expect(count, 1);
        debouncer.dispose();
      });
    });

    test('can be called without prior startHold', () {
      final debouncer = InputDebouncer();
      debouncer.stopHold(); // should not throw
      debouncer.dispose();
    });
  });
}
