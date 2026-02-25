import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/input/input.dart';
import '../../../core/responsive/responsive.dart';
import '../../../providers/app_providers.dart';
import '../../../utils/game_metadata.dart';

enum GameListOverlayMode { hidden, added }

class GameListOverlay extends ConsumerStatefulWidget {
  final GameListOverlayMode mode;
  final List<String> gameIds;
  final List<({String filename, String displayName, String systemSlug})> allGameRecords;
  final ValueChanged<String> onRemove;
  final VoidCallback onClearAll;
  final VoidCallback onClose;

  const GameListOverlay({
    super.key,
    required this.mode,
    required this.gameIds,
    required this.allGameRecords,
    required this.onRemove,
    required this.onClearAll,
    required this.onClose,
  });

  @override
  ConsumerState<GameListOverlay> createState() => _GameListOverlayState();
}

class _GameListOverlayState extends ConsumerState<GameListOverlay> {
  int _focusedIndex = 0;
  final FocusNode _focusNode = FocusNode(debugLabel: 'GameListOverlay');
  final ScrollController _scrollController = ScrollController();

  // Total items = game entries + "Clear All" (if non-empty)
  int get _itemCount =>
      widget.gameIds.isEmpty ? 0 : widget.gameIds.length + 1;

  bool get _isClearAllFocused =>
      widget.gameIds.isNotEmpty && _focusedIndex == widget.gameIds.length;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void didUpdateWidget(GameListOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Clamp index after removals
    if (_focusedIndex >= _itemCount && _itemCount > 0) {
      _focusedIndex = _itemCount - 1;
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToFocused() {
    if (!_scrollController.hasClients) return;
    const itemHeight = 56.0;
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
      widget.onClose();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.gameButtonA ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.space) {
      if (_itemCount == 0) return KeyEventResult.handled;
      ref.read(feedbackServiceProvider).tick();
      if (_isClearAllFocused) {
        widget.onClearAll();
      } else if (_focusedIndex < widget.gameIds.length) {
        widget.onRemove(widget.gameIds[_focusedIndex]);
      }
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowUp) {
      if (_focusedIndex > 0) {
        setState(() => _focusedIndex--);
        ref.read(feedbackServiceProvider).tick();
        _scrollToFocused();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      if (_focusedIndex < _itemCount - 1) {
        setState(() => _focusedIndex++);
        ref.read(feedbackServiceProvider).tick();
        _scrollToFocused();
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  String _displayNameFor(String filename) {
    for (final r in widget.allGameRecords) {
      if (r.filename == filename) return r.displayName;
    }
    return GameMetadata.cleanTitle(filename);
  }

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final isHidden = widget.mode == GameListOverlayMode.hidden;
    final title = isHidden ? 'HIDDEN GAMES' : 'ADDED GAMES';
    final accentColor = isHidden ? Colors.amber : Colors.tealAccent;
    final actionLabel = isHidden ? 'Restore' : 'Remove';

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
                  width: rs.isPortrait
                      ? rs.screenWidth * 0.9
                      : rs.screenWidth * 0.6,
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
                      // Header
                      Padding(
                        padding: EdgeInsets.all(rs.spacing.md),
                        child: Row(
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: rs.isSmall ? 12 : 14,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${widget.gameIds.length} game${widget.gameIds.length == 1 ? '' : 's'}',
                              style: TextStyle(
                                color: accentColor,
                                fontSize: rs.isSmall ? 10 : 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // List
                      if (widget.gameIds.isEmpty)
                        Padding(
                          padding: EdgeInsets.all(rs.spacing.lg),
                          child: Text(
                            'No games',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: rs.isSmall ? 12 : 14,
                            ),
                          ),
                        )
                      else
                        Flexible(
                          child: ListView.builder(
                            controller: _scrollController,
                            padding: EdgeInsets.fromLTRB(
                              rs.spacing.md,
                              0,
                              rs.spacing.md,
                              rs.spacing.md,
                            ),
                            itemCount: _itemCount,
                            itemBuilder: (context, index) {
                              // "Clear All" entry
                              if (index == widget.gameIds.length) {
                                final isFocused = _isClearAllFocused;
                                return Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() => _focusedIndex = index);
                                      widget.onClearAll();
                                    },
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 150),
                                      padding: EdgeInsets.symmetric(
                                        horizontal: rs.spacing.sm,
                                        vertical: rs.isSmall ? 8 : 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isFocused
                                            ? accentColor
                                                .withValues(alpha: 0.15)
                                            : Colors.white
                                                .withValues(alpha: 0.03),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: isFocused
                                              ? accentColor
                                                  .withValues(alpha: 0.5)
                                              : Colors.white
                                                  .withValues(alpha: 0.06),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.clear_all_rounded,
                                              size: 14, color: accentColor),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Clear All',
                                            style: TextStyle(
                                              fontSize: rs.isSmall ? 11 : 12,
                                              fontWeight: FontWeight.w600,
                                              color: accentColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }

                              // Game entry
                              final filename = widget.gameIds[index];
                              final displayName = _displayNameFor(filename);
                              final isFocused = _focusedIndex == index;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() => _focusedIndex = index);
                                    widget.onRemove(filename);
                                  },
                                  child: AnimatedContainer(
                                    duration:
                                        const Duration(milliseconds: 150),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: rs.spacing.sm,
                                      vertical: rs.isSmall ? 8 : 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isFocused
                                          ? accentColor
                                              .withValues(alpha: 0.1)
                                          : Colors.white
                                              .withValues(alpha: 0.03),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: isFocused
                                            ? accentColor
                                                .withValues(alpha: 0.5)
                                            : Colors.white
                                                .withValues(alpha: 0.06),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                displayName,
                                                style: TextStyle(
                                                  fontSize:
                                                      rs.isSmall ? 11 : 12,
                                                  color: isFocused
                                                      ? Colors.white
                                                      : Colors.white70,
                                                  fontWeight: isFocused
                                                      ? FontWeight.w600
                                                      : FontWeight.w400,
                                                ),
                                                overflow:
                                                    TextOverflow.ellipsis,
                                              ),
                                              Text(
                                                filename,
                                                style: TextStyle(
                                                  fontSize:
                                                      rs.isSmall ? 8 : 9,
                                                  color: Colors.grey[600],
                                                ),
                                                overflow:
                                                    TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (isFocused)
                                          Text(
                                            'A: $actionLabel',
                                            style: TextStyle(
                                              fontSize: 9,
                                              color: Colors.grey[500],
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
        ),
      ),
    );
  }
}
