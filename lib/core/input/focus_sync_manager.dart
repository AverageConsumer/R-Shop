import 'dart:async';
import 'package:flutter/material.dart';

import 'input.dart';

class FocusSyncManager {
  final ScrollController scrollController;
  final int Function() getCrossAxisCount;
  final int Function() getItemCount;
  final double Function() getGridRatio;
  final void Function(int newIndex) onSelectionChanged;
  final ValueNotifier<bool>? scrollSuppression;

  bool _isProgrammaticScroll = false;
  double _lastScrollOffset = 0;
  int _selectedIndex = 0;
  int? _targetColumn;
  static const int _hardwareInputTimeoutMs = 500;

  final Map<int, FocusNode> _focusNodes = {};
  bool _isScrolling = false;
  bool _isHardwareInput = false;
  Timer? _hardwareInputTimer;
  Timer? _velocityResetTimer;

  int get selectedIndex => _selectedIndex;
  bool get isProgrammaticScroll => _isProgrammaticScroll;
  set isProgrammaticScroll(bool value) {
    _isProgrammaticScroll = value;
    if (value) _isScrolling = true;
  }
  bool get isScrolling => _isScrolling;
  bool get isHardwareInput => _isHardwareInput;
  Map<int, FocusNode> get focusNodes => _focusNodes;

  FocusSyncManager({
    required this.scrollController,
    required this.getCrossAxisCount,
    required this.getItemCount,
    required this.getGridRatio,
    required this.onSelectionChanged,
    this.scrollSuppression,
  });

  void ensureFocusNodes(int count) {
    for (int i = 0; i < count; i++) {
      if (!_focusNodes.containsKey(i)) {
        _focusNodes[i] = FocusNode(debugLabel: 'GameCard_$i');
      }
    }
    final keysToRemove = _focusNodes.keys.where((k) => k >= count).toList();
    for (final key in keysToRemove) {
      _focusNodes[key]!.dispose();
      _focusNodes.remove(key);
    }
  }

  void setSelectedIndex(int index) {
    _selectedIndex = index;
    _targetColumn = null;
  }

  void validateState(int currentCrossAxisCount) {
    final totalItems = getItemCount();

    if (totalItems == 0) {
      _selectedIndex = 0;
      _targetColumn = null;
      return;
    }

    final wasClamped = _selectedIndex >= totalItems;
    _selectedIndex = _selectedIndex.clamp(0, totalItems - 1);

    if (wasClamped) {
      _targetColumn = null;
      onSelectionChanged(_selectedIndex);
    }
  }

  void _setHardwareInputActive() {
    _isHardwareInput = true;
    _hardwareInputTimer?.cancel();
    _hardwareInputTimer = Timer(
      const Duration(milliseconds: _hardwareInputTimeoutMs),
      () {
        _isHardwareInput = false;
      },
    );
  }

  bool handleScrollNotification(
      ScrollNotification notification, BuildContext context) {
    if (_isProgrammaticScroll) return false;

    if (notification is ScrollStartNotification) {
      _isScrolling = true;
    } else if (notification is ScrollEndNotification) {
      _isScrolling = false;
      final currentOffset = scrollController.offset;
      if ((currentOffset - _lastScrollOffset).abs() > 10) {
        if (!_isHardwareInput) {
          syncFocusToVisibleArea(context);
        }
        _lastScrollOffset = currentOffset;
      }
    }
    return false;
  }

  void syncFocusToVisibleArea(BuildContext context) {
    if (!scrollController.hasClients || _isScrolling || _isHardwareInput) {
      return;
    }

    final totalItems = getItemCount();
    if (totalItems == 0) return;

    final screenHeight = MediaQuery.of(context).size.height;
    final topPadding = MediaQuery.of(context).padding.top + 80 + 16;
    final crossAxisCount = getCrossAxisCount();

    final gridWidth = MediaQuery.of(context).size.width - 48;
    final itemWidth = (gridWidth - (crossAxisCount - 1) * 16) / crossAxisCount;
    final itemHeight = itemWidth / getGridRatio();
    final rowHeight = itemHeight + 16;

    final centerOffset =
        scrollController.offset + (screenHeight / 2) - (topPadding / 2);
    final targetRow = (centerOffset / rowHeight).floor();
    final targetIndex = (targetRow * crossAxisCount).clamp(0, totalItems - 1);

    if (targetIndex != _selectedIndex) {
      _selectedIndex = targetIndex;
      _targetColumn = null;
      onSelectionChanged(targetIndex);
    }
  }

  void scrollToSelectedWithFallback({
    required GlobalKey? itemKey,
    required int crossAxisCount,
    bool instant = false,
    required bool Function() isMounted,
    required VoidCallback retryCallback,
  }) {
    if (itemKey?.currentContext != null) {
      scrollToSelected(itemKey, instant: instant);
      return;
    }
    final totalItems = getItemCount();
    if (totalItems == 0) return;
    final row = _selectedIndex ~/ crossAxisCount;
    final totalRows = (totalItems + crossAxisCount - 1) ~/ crossAxisCount;
    if (totalRows <= 1) return;
    final maxExtent = scrollController.position.maxScrollExtent;
    final estimatedOffset =
        (maxExtent * row / (totalRows - 1)).clamp(0.0, maxExtent);
    _isProgrammaticScroll = true;
    scrollController.jumpTo(estimatedOffset);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isMounted()) retryCallback();
    });
  }

  void scrollToSelected(GlobalKey? itemKey, {bool instant = false}) {
    if (itemKey?.currentContext == null) return;

    _isProgrammaticScroll = true;
    _isScrolling = true;
    Scrollable.ensureVisible(
      itemKey!.currentContext!,
      alignment: 0.5,
      duration: instant ? Duration.zero : const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    ).then((_) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _isProgrammaticScroll = false;
        _isScrolling = false;
      });
    });
  }

  int _getRow(int index, int crossAxisCount) => index ~/ crossAxisCount;

  int _getColumn(int index, int crossAxisCount) => index % crossAxisCount;

  int _indexFromRowCol(int row, int col, int crossAxisCount) =>
      row * crossAxisCount + col;

  int _getRowEndCol(int row, int crossAxisCount, int totalItems) {
    final rowStart = row * crossAxisCount;
    final rowEnd = (rowStart + crossAxisCount - 1).clamp(0, totalItems - 1);
    return rowEnd - rowStart;
  }

  int _getRowCount(int totalItems, int crossAxisCount) {
    if (totalItems == 0) return 0;
    return (totalItems + crossAxisCount - 1) ~/ crossAxisCount;
  }

  void _enforceFocus(int targetIndex) {
    if (_focusNodes.containsKey(targetIndex)) {
      _focusNodes[targetIndex]!.requestFocus();
    }
  }

  bool moveFocus(GridDirection direction) {
    _setHardwareInputActive();

    final crossAxisCount = getCrossAxisCount();
    final totalItems = getItemCount();

    if (totalItems == 0 || crossAxisCount <= 0) return false;

    _selectedIndex = _selectedIndex.clamp(0, totalItems - 1);

    final currentRow = _getRow(_selectedIndex, crossAxisCount);
    final currentCol = _getColumn(_selectedIndex, crossAxisCount);

    _targetColumn ??= currentCol;

    int targetRow = currentRow;
    int targetCol = currentCol;
    bool shouldMove = false;

    switch (direction) {
      case GridDirection.up:
        if (currentRow > 0) {
          targetRow = currentRow - 1;
          targetCol = _targetColumn!;
          shouldMove = true;
        }
        break;

      case GridDirection.down:
        final totalRows = _getRowCount(totalItems, crossAxisCount);
        if (currentRow < totalRows - 1) {
          targetRow = currentRow + 1;
          targetCol = _targetColumn!;
          shouldMove = true;
        }
        break;

      case GridDirection.left:
        if (currentCol > 0) {
          targetCol = currentCol - 1;
          targetRow = currentRow;
          _targetColumn = targetCol;
          shouldMove = true;
        }
        break;

      case GridDirection.right:
        final rowEndCol = _getRowEndCol(currentRow, crossAxisCount, totalItems);
        if (currentCol < rowEndCol) {
          targetCol = currentCol + 1;
          targetRow = currentRow;
          _targetColumn = targetCol;
          shouldMove = true;
        }
        break;
    }

    if (!shouldMove) {
      return false;
    }

    int targetIndex = _indexFromRowCol(targetRow, targetCol, crossAxisCount);

    final rowEndCol = _getRowEndCol(targetRow, crossAxisCount, totalItems);
    if (targetCol > rowEndCol) {
      targetCol = rowEndCol;
      targetIndex = _indexFromRowCol(targetRow, targetCol, crossAxisCount);

    }

    if (targetIndex < 0 || targetIndex >= totalItems) {
      return false;
    }



    _selectedIndex = targetIndex;
    _enforceFocus(targetIndex);
    onSelectionChanged(_selectedIndex);
    return true;
  }

  bool moveLeft() => moveFocus(GridDirection.left);

  bool moveRight() => moveFocus(GridDirection.right);

  bool moveUp() => moveFocus(GridDirection.up);

  bool moveDown() => moveFocus(GridDirection.down);

  void updateScrollVelocity(ScrollNotification notification) {
    if (scrollSuppression == null) return;
    if (notification is ScrollUpdateNotification) {
      final delta = notification.scrollDelta?.abs() ?? 0;
      if (delta > 20) {
        if (!scrollSuppression!.value) scrollSuppression!.value = true;
        _velocityResetTimer?.cancel();
        _velocityResetTimer = Timer(const Duration(milliseconds: 150), () {
          scrollSuppression!.value = false;
        });
      }
    } else if (notification is ScrollEndNotification) {
      _velocityResetTimer?.cancel();
      _velocityResetTimer = Timer(const Duration(milliseconds: 100), () {
        scrollSuppression!.value = false;
      });
    }
  }

  void reset(int newIndex) {
    _selectedIndex = newIndex;
    _targetColumn = null;
    _lastScrollOffset = 0;
    _isProgrammaticScroll = false;
    _isScrolling = false;
    _isHardwareInput = false;
    _hardwareInputTimer?.cancel();
  }

  void dispose() {
    _hardwareInputTimer?.cancel();
    _velocityResetTimer?.cancel();
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    _focusNodes.clear();
  }
}
