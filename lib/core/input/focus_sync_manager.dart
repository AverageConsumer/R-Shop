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
  bool _disposed = false;
  Timer? _hardwareInputTimer;
  Timer? _velocityResetTimer;
  Timer? _scrollResetTimer;
  Timer? _scrollSafetyTimer;
  int _scrollRetryCount = 0;
  static const int _maxScrollRetries = 3;

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
    // Clamp selected index after pruning to avoid pointing at disposed node
    if (count > 0 && _selectedIndex >= count) {
      _selectedIndex = count - 1;
      _targetColumn = null;
    }
  }

  void setSelectedIndex(int index) {
    _selectedIndex = index;
    _targetColumn = null;
  }

  void validateState(int currentCrossAxisCount) {
    final totalItems = getItemCount();
    final oldIndex = _selectedIndex;

    if (totalItems == 0) {
      _selectedIndex = 0;
      _targetColumn = null;
      if (oldIndex != 0) onSelectionChanged(0);
      return;
    }

    _selectedIndex = _selectedIndex.clamp(0, totalItems - 1);

    // Clamp target column when column count changes
    if (_targetColumn != null && currentCrossAxisCount > 0) {
      _targetColumn = _targetColumn!.clamp(0, currentCrossAxisCount - 1);
    }

    if (_selectedIndex != oldIndex) {
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
        if (_disposed) return;
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
    if (crossAxisCount <= 0) return;

    final gridWidth = MediaQuery.of(context).size.width - 48;
    final itemWidth = (gridWidth - (crossAxisCount - 1) * 16) / crossAxisCount;
    final ratio = getGridRatio();
    final itemHeight = ratio > 0 ? (itemWidth / ratio) : itemWidth;
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
      _scrollRetryCount = 0;
      scrollToSelected(itemKey, instant: instant);
      return;
    }
    if (_scrollRetryCount >= _maxScrollRetries) {
      _scrollRetryCount = 0;
      _isProgrammaticScroll = false;
      return;
    }
    _scrollRetryCount++;
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
    final context = itemKey?.currentContext;
    if (context == null) return;

    _isProgrammaticScroll = true;
    _isScrolling = true;
    Scrollable.ensureVisible(
      context,
      alignment: 0.5,
      duration: instant ? Duration.zero : const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    ).then((_) {
      if (_disposed) return;
      _scrollResetTimer?.cancel();
      _scrollResetTimer = Timer(const Duration(milliseconds: 100), () {
        if (_disposed) return;
        _isProgrammaticScroll = false;
        _isScrolling = false;
      });
    });
    // Safety fallback: reset after max 2 seconds if animation was aborted
    _scrollSafetyTimer?.cancel();
    _scrollSafetyTimer = Timer(const Duration(seconds: 2), () {
      if (_disposed) return;
      if (_isProgrammaticScroll) {
        _isProgrammaticScroll = false;
        _isScrolling = false;
      }
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
    final node = _focusNodes[targetIndex];
    if (node != null) {
      node.requestFocus();
    } else {
      // Node not yet built — schedule focus request for after next frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_disposed) return;
        final deferredNode = _focusNodes[targetIndex];
        if (deferredNode != null && deferredNode.canRequestFocus) {
          deferredNode.requestFocus();
        }
      });
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
          if (_disposed) return;
          scrollSuppression!.value = false;
        });
      }
    } else if (notification is ScrollEndNotification) {
      _velocityResetTimer?.cancel();
      _velocityResetTimer = Timer(const Duration(milliseconds: 100), () {
        if (_disposed) return;
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
    _scrollRetryCount = 0;
    _hardwareInputTimer?.cancel();
    _velocityResetTimer?.cancel();
    _scrollResetTimer?.cancel();
    _scrollSafetyTimer?.cancel();
  }

  void dispose() {
    _disposed = true;
    _hardwareInputTimer?.cancel();
    _velocityResetTimer?.cancel();
    _scrollResetTimer?.cancel();
    _scrollSafetyTimer?.cancel();
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    _focusNodes.clear();
  }
}
