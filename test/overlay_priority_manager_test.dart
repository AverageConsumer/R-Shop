import 'package:flutter_test/flutter_test.dart';
import 'package:retro_eshop/core/input/input_providers.dart';

void main() {
  late OverlayPriorityManager manager;

  setUp(() {
    manager = OverlayPriorityManager();
  });

  group('OverlayPriorityManager', () {
    test('starts at OverlayPriority.none', () {
      expect(manager.state, OverlayPriority.none);
    });

    test('claim sets state to claimed priority', () {
      manager.claim(OverlayPriority.dialog);
      expect(manager.state, OverlayPriority.dialog);
    });

    test('claim returns unique tokens', () {
      final t1 = manager.claim(OverlayPriority.dialog);
      final t2 = manager.claim(OverlayPriority.search);
      expect(t1, isNot(equals(t2)));
    });

    test('state is highest priority when multiple claimed', () {
      manager.claim(OverlayPriority.dialog);
      manager.claim(OverlayPriority.fullScreen);
      manager.claim(OverlayPriority.search);
      expect(manager.state, OverlayPriority.fullScreen);
    });

    test('release by token removes exact entry', () {
      final t1 = manager.claim(OverlayPriority.dialog);
      final t2 = manager.claim(OverlayPriority.search);

      final removed = manager.release(t1);
      expect(removed, isTrue);
      expect(manager.state, OverlayPriority.search);

      manager.release(t2);
      expect(manager.state, OverlayPriority.none);
    });

    test('release returns false for unknown token', () {
      manager.claim(OverlayPriority.dialog);
      final removed = manager.release(999);
      expect(removed, isFalse);
      expect(manager.state, OverlayPriority.dialog);
    });

    test('release is idempotent — same token cannot be released twice', () {
      final token = manager.claim(OverlayPriority.dialog);
      expect(manager.release(token), isTrue);
      expect(manager.release(token), isFalse);
      expect(manager.state, OverlayPriority.none);
    });

    test('releaseByPriority removes first matching entry', () {
      manager.claim(OverlayPriority.dialog);
      final t2 = manager.claim(OverlayPriority.dialog);

      manager.releaseByPriority(OverlayPriority.dialog);
      // One dialog claim remains
      expect(manager.state, OverlayPriority.dialog);

      manager.release(t2);
      expect(manager.state, OverlayPriority.none);
    });

    test('releaseByPriority is no-op when priority not found', () {
      manager.claim(OverlayPriority.dialog);
      manager.releaseByPriority(OverlayPriority.fullScreen);
      expect(manager.state, OverlayPriority.dialog);
    });

    test('mixed claim/release maintains correct highest priority', () {
      final tDialog = manager.claim(OverlayPriority.dialog);
      manager.claim(OverlayPriority.search);
      final tDownload = manager.claim(OverlayPriority.downloadModal);

      expect(manager.state, OverlayPriority.downloadModal);

      manager.release(tDownload);
      expect(manager.state, OverlayPriority.search);

      manager.release(tDialog);
      expect(manager.state, OverlayPriority.search);
    });

    test('releasing all claims returns to none', () {
      final tokens = <int>[];
      for (final p in [
        OverlayPriority.dialog,
        OverlayPriority.search,
        OverlayPriority.downloadModal,
        OverlayPriority.fullScreen,
      ]) {
        tokens.add(manager.claim(p));
      }

      for (final t in tokens) {
        manager.release(t);
      }
      expect(manager.state, OverlayPriority.none);
    });

    test('claim after full release works correctly', () {
      final t = manager.claim(OverlayPriority.fullScreen);
      manager.release(t);
      expect(manager.state, OverlayPriority.none);

      manager.claim(OverlayPriority.dialog);
      expect(manager.state, OverlayPriority.dialog);
    });

    test('duplicate priority levels stack independently', () {
      final t1 = manager.claim(OverlayPriority.search);
      final t2 = manager.claim(OverlayPriority.search);
      final t3 = manager.claim(OverlayPriority.search);

      manager.release(t1);
      expect(manager.state, OverlayPriority.search);

      manager.release(t2);
      expect(manager.state, OverlayPriority.search);

      manager.release(t3);
      expect(manager.state, OverlayPriority.none);
    });
  });

  group('OverlayPriority', () {
    test('levels are ordered correctly', () {
      expect(OverlayPriority.none.level, lessThan(OverlayPriority.dialog.level));
      expect(OverlayPriority.dialog.level, lessThan(OverlayPriority.search.level));
      expect(OverlayPriority.search.level, lessThan(OverlayPriority.downloadModal.level));
      expect(OverlayPriority.downloadModal.level, lessThan(OverlayPriority.fullScreen.level));
    });
  });
}
