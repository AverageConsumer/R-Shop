import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/input/overlay_scope.dart';
import '../../../core/responsive/responsive.dart';
import '../../../models/system_model.dart';
import '../../../providers/app_providers.dart';

void showSystemPickerDialog({
  required BuildContext context,
  required WidgetRef ref,
  required List<String> availableSystemIds,
  required void Function(String systemId) onSelect,
}) {
  if (availableSystemIds.isEmpty) return;
  showDialog(
    context: context,
    barrierColor: Colors.black54,
    builder: (ctx) => _SystemPickerDialog(
      availableSystemIds: availableSystemIds,
      onSelect: onSelect,
    ),
  );
}

class _SystemPickerDialog extends ConsumerStatefulWidget {
  final List<String> availableSystemIds;
  final void Function(String systemId) onSelect;

  const _SystemPickerDialog({
    required this.availableSystemIds,
    required this.onSelect,
  });

  @override
  ConsumerState<_SystemPickerDialog> createState() =>
      _SystemPickerDialogState();
}

class _SystemPickerDialogState extends ConsumerState<_SystemPickerDialog> {
  int _focusedIndex = 0;
  final FocusNode _focusNode = FocusNode(debugLabel: 'SystemPicker');
  final ScrollController _scrollController = ScrollController();

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
    _scrollController.dispose();
    super.dispose();
  }

  void _select(int index) {
    if (index < 0 || index >= widget.availableSystemIds.length) return;
    ref.read(feedbackServiceProvider).confirm();
    Navigator.pop(context);
    widget.onSelect(widget.availableSystemIds[index]);
  }

  void _scrollToFocused() {
    if (!_scrollController.hasClients) return;
    const itemHeight = 44.0;
    final targetOffset = _focusedIndex * itemHeight;
    final viewportHeight = _scrollController.position.viewportDimension;
    final currentOffset = _scrollController.offset;

    if (targetOffset < currentOffset) {
      _scrollController.animateTo(targetOffset,
          duration: const Duration(milliseconds: 150), curve: Curves.easeOut);
    } else if (targetOffset + itemHeight > currentOffset + viewportHeight) {
      _scrollController.animateTo(
          targetOffset + itemHeight - viewportHeight,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut);
    }
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
        _scrollToFocused();
        ref.read(feedbackServiceProvider).tick();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      if (_focusedIndex < widget.availableSystemIds.length - 1) {
        setState(() => _focusedIndex++);
        _scrollToFocused();
        ref.read(feedbackServiceProvider).tick();
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final systems = SystemModel.supportedSystems;

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
              width: rs.isPortrait ? rs.screenWidth * 0.8 : 320,
              constraints: const BoxConstraints(maxHeight: 400),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(rs.radius.lg),
                border: Border.all(
                  color: Colors.teal.withValues(alpha: 0.3),
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
                      'ASSIGN CONSOLE',
                      style: TextStyle(
                        color: Colors.teal.shade300,
                        fontSize: rs.isSmall ? 11 : 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  Flexible(
                    child: ListView.builder(
                      controller: _scrollController,
                      shrinkWrap: true,
                      padding: EdgeInsets.only(bottom: rs.spacing.md),
                      itemCount: widget.availableSystemIds.length,
                      itemBuilder: (context, index) {
                        final sysId = widget.availableSystemIds[index];
                        final system = systems
                            .where((s) => s.id == sysId)
                            .firstOrNull;
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
                                vertical: rs.isSmall ? 8 : 10,
                              ),
                              color: isFocused
                                  ? Colors.teal.withValues(alpha: 0.15)
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
                                          ? Colors.teal
                                          : Colors.transparent,
                                    ),
                                  ),
                                  SizedBox(width: rs.spacing.sm),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          system?.name ?? sysId,
                                          style: TextStyle(
                                            fontSize: rs.isSmall ? 12 : 13,
                                            fontWeight: isFocused
                                                ? FontWeight.w600
                                                : FontWeight.w400,
                                            color: isFocused
                                                ? Colors.white
                                                : Colors.white70,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          sysId,
                                          style: TextStyle(
                                            fontSize: rs.isSmall ? 9 : 10,
                                            color: Colors.grey.shade600,
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                      ],
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
