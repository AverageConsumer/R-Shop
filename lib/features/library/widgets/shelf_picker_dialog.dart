import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/input/overlay_scope.dart';
import '../../../core/responsive/responsive.dart';
import '../../../models/custom_shelf.dart';
import '../../../providers/app_providers.dart';

void showShelfPickerDialog({
  required BuildContext context,
  required WidgetRef ref,
  required List<CustomShelf> shelves,
  required void Function(String shelfId) onSelect,
}) {
  showDialog(
    context: context,
    barrierColor: Colors.black54,
    builder: (ctx) => _ShelfPickerDialog(
      shelves: shelves,
      onSelect: onSelect,
    ),
  );
}

class _ShelfPickerDialog extends ConsumerStatefulWidget {
  final List<CustomShelf> shelves;
  final void Function(String shelfId) onSelect;

  const _ShelfPickerDialog({
    required this.shelves,
    required this.onSelect,
  });

  @override
  ConsumerState<_ShelfPickerDialog> createState() =>
      _ShelfPickerDialogState();
}

class _ShelfPickerDialogState extends ConsumerState<_ShelfPickerDialog> {
  int _focusedIndex = 0;
  final FocusNode _focusNode = FocusNode(debugLabel: 'ShelfPicker');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _select(int index) {
    if (index < 0 || index >= widget.shelves.length) return;
    ref.read(feedbackServiceProvider).confirm();
    Navigator.pop(context);
    widget.onSelect(widget.shelves[index].id);
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.gameButtonB ||
        key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.backspace) {
      ref.read(feedbackServiceProvider).cancel();
      Navigator.pop(context);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.gameButtonA ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.space) {
      _select(_focusedIndex);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowUp) {
      if (_focusedIndex > 0) {
        setState(() => _focusedIndex--);
        ref.read(feedbackServiceProvider).tick();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      if (_focusedIndex < widget.shelves.length - 1) {
        setState(() => _focusedIndex++);
        ref.read(feedbackServiceProvider).tick();
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;

    return OverlayFocusScope(
      priority: OverlayPriority.dialog,
      isVisible: true,
      onClose: () => Navigator.pop(context),
      child: Focus(
        focusNode: _focusNode,
        onKeyEvent: _handleKeyEvent,
        autofocus: true,
        child: Center(
          child: Material(
            type: MaterialType.transparency,
            child: Container(
            width: rs.isPortrait ? rs.screenWidth * 0.8 : 300,
            constraints: const BoxConstraints(maxHeight: 350),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(rs.radius.lg),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 24,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.all(rs.spacing.md),
                  child: Text(
                    'ADD TO SHELF',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: rs.isSmall ? 12 : 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.only(bottom: rs.spacing.md),
                    itemCount: widget.shelves.length,
                    itemBuilder: (context, index) {
                      final shelf = widget.shelves[index];
                      final isFocused = _focusedIndex == index;

                      return GestureDetector(
                        onTap: () => _select(index),
                        child: MouseRegion(
                          onEnter: (_) =>
                              setState(() => _focusedIndex = index),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: EdgeInsets.symmetric(
                              horizontal: rs.spacing.md,
                              vertical: rs.isSmall ? 10 : 12,
                            ),
                            color: isFocused
                                ? Colors.cyanAccent.withValues(alpha: 0.12)
                                : Colors.transparent,
                            child: Row(
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  width: 3,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(2),
                                    color: isFocused
                                        ? Colors.cyanAccent
                                        : Colors.transparent,
                                  ),
                                ),
                                SizedBox(width: rs.spacing.sm),
                                Icon(
                                  Icons.collections_bookmark_rounded,
                                  size: 16,
                                  color: isFocused
                                      ? Colors.cyanAccent
                                      : Colors.grey[500],
                                ),
                                SizedBox(width: rs.spacing.sm),
                                Expanded(
                                  child: Text(
                                    shelf.name,
                                    style: TextStyle(
                                      fontSize: rs.isSmall ? 13 : 14,
                                      fontWeight: isFocused
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      color: isFocused
                                          ? Colors.white
                                          : Colors.white70,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          ),
        ),
      ),
    );
  }
}
