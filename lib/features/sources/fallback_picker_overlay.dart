import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/input/overlay_scope.dart';
import '../../models/config/source.dart';
import '../../providers/app_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/console_dialog.dart';
import '../../widgets/console_hud.dart';

/// Overlay for managing a source's multi-fallback chain.
///
/// Built matching the exact SourcesScreen Overlay Architecture (_SourceActionOverlay).
class FallbackPickerOverlay extends ConsumerStatefulWidget {
  const FallbackPickerOverlay({
    super.key,
    required this.sourceId,
    required this.onClose,
    this.onAddFreshSource,
  });

  final String sourceId;
  final VoidCallback onClose;
  final VoidCallback? onAddFreshSource;

  @override
  ConsumerState<FallbackPickerOverlay> createState() =>
      _FallbackPickerOverlayState();
}

class _FallbackPickerOverlayState
    extends ConsumerState<FallbackPickerOverlay> {
  final _scopeFocus = FocusNode(debugLabel: 'fallback_picker_overlay_scope');
  int _selectedIndex = 0;
  int? _sortingIndex;
  bool _isDeleteFocused = false;

  @override
  void dispose() {
    _scopeFocus.dispose();
    super.dispose();
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;

    final state = ref.read(sourcesProvider);
    final source =
        state.sources.where((s) => s.id == widget.sourceId).firstOrNull;
    if (source == null) return KeyEventResult.ignored;

    final fallbacks = [
      for (final fbId in source.fallbackSourceIds)
        ...state.sources.where((s) => s.id == fbId),
    ];
    final isSorting = _sortingIndex != null;
    final totalRows = 1 + fallbacks.length + 2; // Auto, fallbacks, AddFresh, PickExisting

    if (key == LogicalKeyboardKey.gameButtonB ||
        key == LogicalKeyboardKey.escape) {
      if (isSorting) {
        setState(() => _sortingIndex = null);
        return KeyEventResult.handled;
      }
      if (_isDeleteFocused) {
        setState(() => _isDeleteFocused = false);
        return KeyEventResult.handled;
      }
      widget.onClose();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowRight &&
        !isSorting &&
        _selectedIndex >= 1 &&
        _selectedIndex <= fallbacks.length) {
      setState(() => _isDeleteFocused = true);
      ref.read(feedbackServiceProvider).tick();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowLeft && _isDeleteFocused) {
      setState(() => _isDeleteFocused = false);
      ref.read(feedbackServiceProvider).tick();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowUp) {
      if (isSorting) {
        _moveFallback(source, fallbacks, _selectedIndex - 1, -1);
        return KeyEventResult.handled;
      }
      setState(() {
        _isDeleteFocused = false;
        _selectedIndex = (_selectedIndex - 1 + totalRows) % totalRows;
      });
      ref.read(feedbackServiceProvider).tick();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowDown) {
      if (isSorting) {
        _moveFallback(source, fallbacks, _selectedIndex - 1, 1);
        return KeyEventResult.handled;
      }
      setState(() {
        _isDeleteFocused = false;
        _selectedIndex = (_selectedIndex + 1) % totalRows;
      });
      ref.read(feedbackServiceProvider).tick();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.gameButtonA ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.space) {
      if (_isDeleteFocused &&
          _selectedIndex >= 1 &&
          _selectedIndex <= fallbacks.length) {
        final targetFb = fallbacks[_selectedIndex - 1];
        ref.read(sourcesProvider.notifier).removeFallbackSource(
              source.id,
              targetFb.id,
            );
        ref.read(feedbackServiceProvider).confirm();
        setState(() => _isDeleteFocused = false);
        return KeyEventResult.handled;
      }
      _activateRow(source, fallbacks, _selectedIndex);
      return KeyEventResult.handled;
    }

    if ((key == LogicalKeyboardKey.gameButtonX ||
            key == LogicalKeyboardKey.keyX) &&
        !isSorting) {
      if (_selectedIndex >= 1 && _selectedIndex <= fallbacks.length) {
        final targetFb = fallbacks[_selectedIndex - 1];
        ref.read(sourcesProvider.notifier).removeFallbackSource(
              source.id,
              targetFb.id,
            );
        ref.read(feedbackServiceProvider).confirm();
        return KeyEventResult.handled;
      }
    }

    if ((key == LogicalKeyboardKey.gameButtonY ||
            key == LogicalKeyboardKey.keyY) &&
        _selectedIndex >= 1 &&
        _selectedIndex <= fallbacks.length) {
      setState(() {
        _sortingIndex = isSorting ? null : _selectedIndex - 1;
      });
      ref.read(feedbackServiceProvider).tick();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _activateRow(Source source, List<Source> fallbacks, int rowIndex) {
    if (rowIndex == 0) {
      ref.read(sourcesProvider.notifier).setFallbackAutoSelect(
            source.id,
            !source.fallbackAutoSelect,
          );
      ref.read(feedbackServiceProvider).confirm();
    } else if (rowIndex >= 1 && rowIndex <= fallbacks.length) {
      setState(() {
        _sortingIndex = (_sortingIndex == rowIndex - 1) ? null : rowIndex - 1;
      });
      ref.read(feedbackServiceProvider).tick();
    } else if (rowIndex == fallbacks.length + 1) {
      ref.read(feedbackServiceProvider).confirm();
      widget.onClose();
      widget.onAddFreshSource?.call();
    } else if (rowIndex == fallbacks.length + 2) {
      ref.read(feedbackServiceProvider).confirm();
      _showPickExistingDialog(source, ref.read(sourcesProvider).sources);
    }
  }

  void _moveFallback(
    Source source,
    List<Source> fallbacks,
    int fromIndex,
    int delta,
  ) {
    final toIndex = fromIndex + delta;
    if (fromIndex < 0 || fromIndex >= fallbacks.length) return;
    if (toIndex < 0 || toIndex >= fallbacks.length) return;

    final updatedIds = fallbacks.map((s) => s.id).toList();
    final item = updatedIds.removeAt(fromIndex);
    updatedIds.insert(toIndex, item);

    ref.read(sourcesProvider.notifier).reorderFallbackSources(
          source.id,
          updatedIds,
        );
    setState(() {
      _selectedIndex = toIndex + 1;
      _sortingIndex = toIndex;
    });
    ref.read(feedbackServiceProvider).tick();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sourcesProvider);
    final source =
        state.sources.where((s) => s.id == widget.sourceId).firstOrNull;

    if (source == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onClose());
      return const SizedBox.shrink();
    }

    final fallbacks = [
      for (final fbId in source.fallbackSourceIds)
        ...state.sources.where((s) => s.id == fbId),
    ];

    final isSorting = _sortingIndex != null;

    return OverlayFocusScope(
      priority: OverlayPriority.dialog,
      isVisible: true,
      onClose: widget.onClose,
      child: Focus(
        focusNode: _scopeFocus,
        autofocus: true,
        onKeyEvent: _onKeyEvent,
        child: Container(
          color: Colors.black.withValues(alpha: 0.75),
          child: Center(
            child: Material(
              type: MaterialType.transparency,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1C),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title Bar
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${source.name} - 代理設定',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close,
                                  color: Colors.white54, size: 20),
                              onPressed: widget.onClose,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        if (!source.enabled)
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Colors.redAccent.withValues(alpha: 0.6)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.block,
                                    color: Colors.redAccent, size: 16),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '來源已停用，代理功能暫停',
                                    style: TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Row 0: Auto Select Toggle
                        _buildRow(
                          index: 0,
                          isSelected: _selectedIndex == 0,
                          child: Row(
                            children: [
                              Icon(
                                source.fallbackAutoSelect
                                    ? Icons.check_box
                                    : Icons.check_box_outline_blank,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '自動選擇',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      source.fallbackAutoSelect
                                          ? '自動探測並優先使用回應最快的代理'
                                          : '未勾選：依下方順序依次嘗試代理',
                                      style: const TextStyle(
                                          color: Colors.white70, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          onTap: () => _activateRow(source, fallbacks, 0),
                        ),

                        const SizedBox(height: 16),
                        const Text(
                          '代理來源清單（優先順序）',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),

                        if (fallbacks.isEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            alignment: Alignment.center,
                            child: const Text(
                              '尚未設定任何代理來源',
                              style: TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                          )
                        else
                          for (int i = 0; i < fallbacks.length; i++)
                            _buildFallbackRow(
                              source: source,
                              fallback: fallbacks[i],
                              index: i,
                              fallbacks: fallbacks,
                              isSelected: _selectedIndex == i + 1,
                              isSorting: _sortingIndex == i,
                            ),

                        const SizedBox(height: 16),

                        // Action 1: Add Fresh Source
                        _buildRow(
                          index: fallbacks.length + 1,
                          isSelected: _selectedIndex == fallbacks.length + 1,
                          child: const Center(
                            child: Text(
                              '+ 新建全新代理來源',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          onTap: () =>
                              _activateRow(source, fallbacks, fallbacks.length + 1),
                        ),
                        const SizedBox(height: 8),

                        // Action 2: Pick Existing Source
                        _buildRow(
                          index: fallbacks.length + 2,
                          isSelected: _selectedIndex == fallbacks.length + 2,
                          child: const Center(
                            child: Text(
                              '+ 從既有來源選擇代理',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          onTap: () =>
                              _activateRow(source, fallbacks, fallbacks.length + 2),
                        ),

                        const SizedBox(height: 16),

                        // HUD Hints embedded
                        ConsoleHud(
                          embedded: true,
                          dpad: (
                            label: (_selectedIndex >= 1 &&
                                    _selectedIndex <= fallbacks.length &&
                                    !isSorting)
                                ? '↑↓/→'
                                : '↑↓',
                            action: '導覽',
                          ),
                          a: HudAction(
                            isSorting
                                ? '完成'
                                : (_isDeleteFocused
                                    ? '刪除'
                                    : (_selectedIndex == 0
                                        ? '切換'
                                        : (_selectedIndex >= 1 &&
                                                _selectedIndex <=
                                                    fallbacks.length
                                            ? '排序'
                                            : '確定'))),
                            onTap: () {
                              if (_isDeleteFocused &&
                                  _selectedIndex >= 1 &&
                                  _selectedIndex <= fallbacks.length) {
                                final targetFb = fallbacks[_selectedIndex - 1];
                                ref
                                    .read(sourcesProvider.notifier)
                                    .removeFallbackSource(
                                      source.id,
                                      targetFb.id,
                                    );
                                ref.read(feedbackServiceProvider).confirm();
                                setState(() => _isDeleteFocused = false);
                                return;
                              }
                              _activateRow(source, fallbacks, _selectedIndex);
                            },
                          ),
                          b: HudAction(
                            isSorting ? '取消' : '關閉',
                            onTap: () {
                              if (isSorting) {
                                setState(() => _sortingIndex = null);
                              } else {
                                widget.onClose();
                              }
                            },
                          ),
                          x: (!isSorting &&
                                  _selectedIndex >= 1 &&
                                  _selectedIndex <= fallbacks.length)
                              ? HudAction('刪除', onTap: () {
                                  final targetFb = fallbacks[_selectedIndex - 1];
                                  ref
                                      .read(sourcesProvider.notifier)
                                      .removeFallbackSource(
                                        source.id,
                                        targetFb.id,
                                      );
                                  ref.read(feedbackServiceProvider).confirm();
                                })
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRow({
    required int index,
    required bool isSelected,
    required Widget child,
    required VoidCallback onTap,
  }) {
    final color = AppTheme.primaryColor;
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isSelected ? 0.25 : 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : color.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 12)]
              : null,
        ),
        child: child,
      ),
    );
  }

  Widget _buildFallbackRow({
    required Source source,
    required Source fallback,
    required int index,
    required List<Source> fallbacks,
    required bool isSelected,
    required bool isSorting,
  }) {
    final color = AppTheme.primaryColor;
    final isDeleteActive = isSelected && _isDeleteFocused;
    final bgColor = isSorting
        ? Colors.amber[900]!.withValues(alpha: 0.7)
        : color.withValues(alpha: isSelected ? 0.25 : 0.08);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: () => _activateRow(source, fallbacks, index + 1),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSorting
                  ? Colors.amber
                  : (isSelected ? color : color.withValues(alpha: 0.3)),
              width: isSelected || isSorting ? 2 : 1,
            ),
            boxShadow: (isSelected || isSorting)
                ? [
                    BoxShadow(
                      color: (isSorting ? Colors.amber : color)
                          .withValues(alpha: 0.35),
                      blurRadius: 12,
                    )
                  ]
                : null,
          ),
          child: Row(
            children: [
              Text(
                '#${index + 1}',
                style: const TextStyle(
                  color: Colors.amber,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            fallback.name,
                            style: TextStyle(
                              color: fallback.enabled
                                  ? Colors.white
                                  : Colors.white54,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (!fallback.enabled) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white12,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '已停用',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      '${fallback.type.shortLabel} - ${fallback.hostLabel}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (isSorting)
                const Icon(Icons.swap_vert, color: Colors.amber)
              else
                AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  decoration: BoxDecoration(
                    color: isDeleteActive
                        ? const Color(0xFFE50914)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: isDeleteActive
                        ? Border.all(color: Colors.white, width: 2)
                        : null,
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: isDeleteActive ? Colors.white : Colors.white70,
                      size: 20,
                    ),
                    onPressed: () {
                      ref
                          .read(sourcesProvider.notifier)
                          .removeFallbackSource(
                            source.id,
                            fallback.id,
                          );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPickExistingDialog(Source source, List<Source> allSources) {
    final candidates = allSources
        .where(
            (s) => s.id != source.id && !source.fallbackSourceIds.contains(s.id))
        .toList();

    if (candidates.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => const ConsoleDialog(
          title: '沒有可用的來源',
          message: '目前沒有其他未綁定的既有來源可供選擇。請選擇「新建全新代理來源」。',
          primaryLabel: '確定',
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => _PickExistingDialog(
        source: source,
        candidates: candidates,
      ),
    );
  }
}

class _PickExistingDialog extends ConsumerStatefulWidget {
  const _PickExistingDialog({
    required this.source,
    required this.candidates,
  });

  final Source source;
  final List<Source> candidates;

  @override
  ConsumerState<_PickExistingDialog> createState() =>
      _PickExistingDialogState();
}

class _PickExistingDialogState extends ConsumerState<_PickExistingDialog> {
  final FocusNode _scopeFocus = FocusNode(debugLabel: 'pick_existing_dialog');
  int _selectedIndex = 0;

  @override
  void dispose() {
    _scopeFocus.dispose();
    super.dispose();
  }

  void _confirmSelection() {
    if (widget.candidates.isEmpty) return;
    final cand = widget.candidates[_selectedIndex];
    Navigator.of(context).pop();
    ref.read(sourcesProvider.notifier).addFallbackSource(
          widget.source.id,
          cand.id,
        );
    ref.read(feedbackServiceProvider).confirm();
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final count = widget.candidates.length;

    if (key == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _selectedIndex = (_selectedIndex - 1 + count) % count;
      });
      ref.read(feedbackServiceProvider).tick();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _selectedIndex = (_selectedIndex + 1) % count;
      });
      ref.read(feedbackServiceProvider).tick();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.gameButtonA ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.space) {
      _confirmSelection();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.gameButtonB ||
        key == LogicalKeyboardKey.escape) {
      ref.read(feedbackServiceProvider).cancel();
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.primaryColor;
    return OverlayFocusScope(
      priority: OverlayPriority.dialog,
      isVisible: true,
      onClose: () => Navigator.of(context).pop(),
      child: Focus(
        focusNode: _scopeFocus,
        autofocus: true,
        onKeyEvent: _onKeyEvent,
        child: Container(
          color: Colors.black.withValues(alpha: 0.75),
          child: Center(
            child: Material(
              type: MaterialType.transparency,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1C),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '選擇既有來源作為代理',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 14),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 240),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: widget.candidates.length,
                          itemBuilder: (context, index) {
                            final cand = widget.candidates[index];
                            final isSelected = _selectedIndex == index;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              child: InkWell(
                                onTap: () {
                                  setState(() => _selectedIndex = index);
                                  _confirmSelection();
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 120),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: color.withValues(
                                        alpha: isSelected ? 0.35 : 0.08),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSelected
                                          ? color
                                          : color.withValues(alpha: 0.3),
                                      width: isSelected ? 2.0 : 1.0,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: color.withValues(
                                                  alpha: 0.35),
                                              blurRadius: 12,
                                            )
                                          ]
                                        : null,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        cand.name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '${cand.type.shortLabel} - ${cand.hostLabel}',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
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
                      const SizedBox(height: 14),
                      ConsoleHud(
                        embedded: true,
                        dpad: (label: '↑↓', action: '選擇'),
                        a: HudAction('確定', onTap: _confirmSelection),
                        b: HudAction('關閉',
                            onTap: () => Navigator.of(context).pop()),
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
