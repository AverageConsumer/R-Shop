import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/input/overlay_scope.dart';
import '../../../core/responsive/responsive.dart';
import '../../../models/system_model.dart';
import '../../../providers/app_providers.dart';

class SystemSelectorOverlay extends ConsumerStatefulWidget {
  final List<String> selectedSlugs;
  final ValueChanged<List<String>> onChanged;
  final VoidCallback onClose;

  const SystemSelectorOverlay({
    super.key,
    required this.selectedSlugs,
    required this.onChanged,
    required this.onClose,
  });

  @override
  ConsumerState<SystemSelectorOverlay> createState() =>
      _SystemSelectorOverlayState();
}

class _SystemSelectorOverlayState
    extends ConsumerState<SystemSelectorOverlay> {
  late Set<String> _selected;
  int _focusedIndex = 0;
  final FocusNode _focusNode = FocusNode(debugLabel: 'SystemSelector');

  static const _systems = SystemModel.supportedSystems;

  @override
  void initState() {
    super.initState();
    _selected = widget.selectedSlugs.toSet();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _toggle(int index) {
    final slug = _systems[index].id;
    setState(() {
      if (_selected.contains(slug)) {
        _selected.remove(slug);
      } else {
        _selected.add(slug);
      }
    });
    widget.onChanged(_selected.toList());
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.gameButtonB ||
        key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.backspace) {
      ref.read(feedbackServiceProvider).cancel();
      widget.onClose();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.gameButtonA ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.space) {
      ref.read(feedbackServiceProvider).tick();
      _toggle(_focusedIndex);
      return KeyEventResult.handled;
    }

    const cols = 4;
    if (key == LogicalKeyboardKey.arrowUp) {
      if (_focusedIndex >= cols) {
        setState(() => _focusedIndex -= cols);
        ref.read(feedbackServiceProvider).tick();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      if (_focusedIndex + cols < _systems.length) {
        setState(() => _focusedIndex += cols);
        ref.read(feedbackServiceProvider).tick();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (_focusedIndex > 0) {
        setState(() => _focusedIndex--);
        ref.read(feedbackServiceProvider).tick();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      if (_focusedIndex < _systems.length - 1) {
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
      onClose: widget.onClose,
      child: Focus(
        focusNode: _focusNode,
        onKeyEvent: _handleKeyEvent,
        autofocus: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onClose,
          child: Container(
            color: Colors.black.withValues(alpha: 0.7),
            child: Center(
              child: GestureDetector(
                onTap: () {},
                child: Container(
                  width: rs.isPortrait ? rs.screenWidth * 0.9 : rs.screenWidth * 0.6,
                  constraints: const BoxConstraints(maxHeight: 400),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(rs.radius.lg),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: EdgeInsets.all(rs.spacing.md),
                        child: Row(
                          children: [
                            Text(
                              'SELECT SYSTEMS',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: rs.isSmall ? 12 : 14,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${_selected.length} selected',
                              style: TextStyle(
                                color: Colors.cyanAccent,
                                fontSize: rs.isSmall ? 10 : 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Flexible(
                        child: GridView.builder(
                          padding: EdgeInsets.fromLTRB(
                            rs.spacing.md,
                            0,
                            rs.spacing.md,
                            rs.spacing.md,
                          ),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            childAspectRatio: 2.0,
                            crossAxisSpacing: 6,
                            mainAxisSpacing: 6,
                          ),
                          itemCount: _systems.length,
                          itemBuilder: (context, index) {
                            final system = _systems[index];
                            final isSelected = _selected.contains(system.id);
                            final isFocused = _focusedIndex == index;

                            return GestureDetector(
                              onTap: () {
                                setState(() => _focusedIndex = index);
                                _toggle(index);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? system.accentColor
                                          .withValues(alpha: 0.25)
                                      : Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isFocused
                                        ? Colors.cyanAccent
                                        : isSelected
                                            ? system.accentColor
                                                .withValues(alpha: 0.5)
                                            : Colors.white
                                                .withValues(alpha: 0.08),
                                    width: isFocused ? 2 : 1,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    system.id.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: rs.isSmall ? 9 : 10,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? system.accentColor
                                          : Colors.grey[500],
                                    ),
                                    textAlign: TextAlign.center,
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
        ),
      ),
    );
  }
}
