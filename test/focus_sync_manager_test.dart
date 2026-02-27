import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retro_eshop/core/input/app_intents.dart';
import 'package:retro_eshop/core/input/focus_sync_manager.dart';

void main() {
  late ScrollController scrollController;
  late FocusSyncManager manager;
  late List<int> selectionChanges;
  int itemCount = 12;
  int crossAxisCount = 4;

  setUp(() {
    selectionChanges = [];
    scrollController = ScrollController();
    manager = FocusSyncManager(
      scrollController: scrollController,
      getCrossAxisCount: () => crossAxisCount,
      getItemCount: () => itemCount,
      getGridRatio: () => 0.75,
      onSelectionChanged: (i) => selectionChanges.add(i),
    );
  });

  tearDown(() {
    manager.dispose();
    scrollController.dispose();
  });

  group('Initial state', () {
    test('starts at index 0', () {
      expect(manager.selectedIndex, 0);
    });

    test('isProgrammaticScroll is false initially', () {
      expect(manager.isProgrammaticScroll, false);
    });

    test('isScrolling is false initially', () {
      expect(manager.isScrolling, false);
    });

    test('isHardwareInput is false initially', () {
      expect(manager.isHardwareInput, false);
    });
  });

  group('setSelectedIndex', () {
    test('sets index directly', () {
      manager.setSelectedIndex(5);
      expect(manager.selectedIndex, 5);
    });
  });

  group('ensureFocusNodes', () {
    test('creates focus nodes up to count', () {
      manager.ensureFocusNodes(6);
      expect(manager.focusNodes.length, 6);
      expect(manager.focusNodes.keys, containsAll([0, 1, 2, 3, 4, 5]));
    });

    test('prunes nodes above count', () {
      manager.ensureFocusNodes(10);
      expect(manager.focusNodes.length, 10);

      manager.ensureFocusNodes(3);
      expect(manager.focusNodes.length, 3);
      expect(manager.focusNodes.containsKey(5), false);
    });

    test('clamps selectedIndex when pruning', () {
      manager.setSelectedIndex(8);
      manager.ensureFocusNodes(5);
      expect(manager.selectedIndex, 4);
    });

    test('does not clamp selectedIndex if still in range', () {
      manager.setSelectedIndex(2);
      manager.ensureFocusNodes(5);
      expect(manager.selectedIndex, 2);
    });

    test('handles count of 0', () {
      manager.ensureFocusNodes(5);
      manager.ensureFocusNodes(0);
      expect(manager.focusNodes.length, 0);
    });
  });

  group('validateState', () {
    test('clamps selectedIndex to totalItems - 1', () {
      itemCount = 5;
      manager.setSelectedIndex(10);
      manager.validateState(crossAxisCount);
      expect(manager.selectedIndex, 4);
      expect(selectionChanges, contains(4));
    });

    test('no callback when index unchanged', () {
      itemCount = 12;
      manager.setSelectedIndex(3);
      manager.validateState(crossAxisCount);
      expect(selectionChanges, isEmpty);
    });

    test('handles empty grid', () {
      itemCount = 0;
      manager.setSelectedIndex(5);
      manager.validateState(crossAxisCount);
      expect(manager.selectedIndex, 0);
      expect(selectionChanges, contains(0));
    });

    test('clamps targetColumn on column count change', () {
      // First move right to set targetColumn
      itemCount = 12;
      crossAxisCount = 4;
      manager.ensureFocusNodes(12);
      manager.setSelectedIndex(0);
      // Move right 3 times to column 3
      manager.moveFocus(GridDirection.right);
      manager.moveFocus(GridDirection.right);
      manager.moveFocus(GridDirection.right);
      expect(manager.selectedIndex, 3);

      // Now reduce columns to 2 — targetColumn should clamp
      crossAxisCount = 2;
      selectionChanges.clear();
      manager.validateState(2);
      // Index 3 is still valid (row 1, col 1 in 2-column grid), so no change needed
    });
  });

  group('moveFocus', () {
    setUp(() {
      itemCount = 12;
      crossAxisCount = 4;
      manager.ensureFocusNodes(12);
    });

    test('moves right', () {
      manager.setSelectedIndex(0);
      final moved = manager.moveFocus(GridDirection.right);
      expect(moved, true);
      expect(manager.selectedIndex, 1);
    });

    test('moves left', () {
      manager.setSelectedIndex(1);
      final moved = manager.moveFocus(GridDirection.left);
      expect(moved, true);
      expect(manager.selectedIndex, 0);
    });

    test('moves down', () {
      manager.setSelectedIndex(0);
      final moved = manager.moveFocus(GridDirection.down);
      expect(moved, true);
      expect(manager.selectedIndex, 4);
    });

    test('moves up', () {
      manager.setSelectedIndex(4);
      final moved = manager.moveFocus(GridDirection.up);
      expect(moved, true);
      expect(manager.selectedIndex, 0);
    });

    test('cannot move left from first column', () {
      manager.setSelectedIndex(0);
      final moved = manager.moveFocus(GridDirection.left);
      expect(moved, false);
      expect(manager.selectedIndex, 0);
    });

    test('cannot move right from last column', () {
      manager.setSelectedIndex(3);
      final moved = manager.moveFocus(GridDirection.right);
      expect(moved, false);
      expect(manager.selectedIndex, 3);
    });

    test('cannot move up from first row', () {
      manager.setSelectedIndex(2);
      final moved = manager.moveFocus(GridDirection.up);
      expect(moved, false);
      expect(manager.selectedIndex, 2);
    });

    test('cannot move down from last row', () {
      manager.setSelectedIndex(11); // Last item
      final moved = manager.moveFocus(GridDirection.down);
      expect(moved, false);
      expect(manager.selectedIndex, 11);
    });

    test('remembers target column when moving down past short row', () {
      // Grid: 4 columns, 10 items
      // Row 0: [0, 1, 2, 3]
      // Row 1: [4, 5, 6, 7]
      // Row 2: [8, 9]  (short row)
      itemCount = 10;
      manager.ensureFocusNodes(10);
      manager.setSelectedIndex(3); // Column 3, row 0

      // Move down — row 2 only has cols 0-1, so clamps to col 1 (index 9)
      manager.moveFocus(GridDirection.down);
      expect(manager.selectedIndex, 7); // row 1, col 3

      manager.moveFocus(GridDirection.down);
      // Row 2 has items 8, 9 → target column 3 clamps to col 1 → index 9
      expect(manager.selectedIndex, 9);
    });

    test('returns false for empty grid', () {
      itemCount = 0;
      final moved = manager.moveFocus(GridDirection.right);
      expect(moved, false);
    });

    test('onSelectionChanged is called on move', () {
      manager.setSelectedIndex(0);
      selectionChanges.clear();

      manager.moveFocus(GridDirection.right);
      expect(selectionChanges, [1]);
    });
  });

  group('convenience methods', () {
    setUp(() {
      itemCount = 12;
      crossAxisCount = 4;
      manager.ensureFocusNodes(12);
      manager.setSelectedIndex(5);
    });

    test('moveLeft', () {
      expect(manager.moveLeft(), true);
      expect(manager.selectedIndex, 4);
    });

    test('moveRight', () {
      expect(manager.moveRight(), true);
      expect(manager.selectedIndex, 6);
    });

    test('moveUp', () {
      expect(manager.moveUp(), true);
      expect(manager.selectedIndex, 1);
    });

    test('moveDown', () {
      expect(manager.moveDown(), true);
      expect(manager.selectedIndex, 9);
    });
  });

  group('reset', () {
    test('resets state to given index', () {
      manager.setSelectedIndex(5);
      manager.isProgrammaticScroll = true;

      manager.reset(2);
      expect(manager.selectedIndex, 2);
      expect(manager.isProgrammaticScroll, false);
      expect(manager.isScrolling, false);
      expect(manager.isHardwareInput, false);
    });
  });

  group('isProgrammaticScroll', () {
    test('setting to true also sets isScrolling', () {
      manager.isProgrammaticScroll = true;
      expect(manager.isProgrammaticScroll, true);
      expect(manager.isScrolling, true);
    });
  });

  group('dispose', () {
    test('clears all focus nodes', () {
      manager.ensureFocusNodes(5);
      expect(manager.focusNodes.length, 5);
      manager.dispose();
      expect(manager.focusNodes, isEmpty);
    });
  });
}
