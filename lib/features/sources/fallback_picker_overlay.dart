import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/input/overlay_scope.dart';
import '../../models/config/source.dart';
import '../../providers/app_providers.dart';
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
      widget.onClose();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowUp) {
      if (isSorting) {
        _moveFallback(source, fallbacks, _selectedIndex - 1, -1);
        return KeyEventResult.handled;
      }
      setState(() {
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
        _selectedIndex = (_selectedIndex + 1) % totalRows;
      });
      ref.read(feedbackServiceProvider).tick();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.gameButtonA ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.space) {
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
                    border: Border.all(color: Colors.white12),
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
                                '${source.name} - 備援設定',
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
                                          ? '自動探測並優先使用回應最快的備援'
                                          : '未勾選：依下方順序依次嘗試備援',
                                      style: const TextStyle(
                                          color: Colors.grey, fontSize: 12),
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
                          '備援來源清單（優先順序）',
                          style: TextStyle(
                            color: Colors.grey,
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
                              '尚未設定任何備援來源',
                              style: TextStyle(color: Colors.grey, fontSize: 14),
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
                              '+ 新建全新備援來源',
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
                              '+ 從既有來源選擇備援',
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
                          b: const HudAction('關閉'),
                          a: HudAction(isSorting ? '完成排序' : '確定 / 排序'),
                          x: (!isSorting &&
                                  _selectedIndex >= 1 &&
                                  _selectedIndex <= fallbacks.length)
                              ? const HudAction('移除備援')
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
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFE50914).withAlpha(90)
              : Colors.white10,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 1.5,
          ),
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
    final bgColor = isSorting
        ? Colors.amber[900]!.withAlpha(180)
        : (isSelected
            ? const Color(0xFFE50914).withAlpha(90)
            : Colors.white10);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: () => _activateRow(source, fallbacks, index + 1),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? Colors.white : Colors.transparent,
              width: 1.5,
            ),
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
                    Text(
                      fallback.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${fallback.type.shortLabel} - ${fallback.hostLabel}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (isSorting)
                const Icon(Icons.swap_vert, color: Colors.amber)
              else
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.white70, size: 20),
                  onPressed: () {
                    ref.read(sourcesProvider.notifier).removeFallbackSource(
                          source.id,
                          fallback.id,
                        );
                  },
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
          message: '目前沒有其他未綁定的既有來源可供選擇。請選擇「新建全新備援來源」。',
          primaryLabel: '確定',
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1C),
        title: const Text('選擇既有來源作為備援',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: SizedBox(
          width: 300,
          height: 220,
          child: ListView.builder(
            itemCount: candidates.length,
            itemBuilder: (context, index) {
              final cand = candidates[index];
              return ListTile(
                title: Text(cand.name,
                    style: const TextStyle(color: Colors.white, fontSize: 14)),
                subtitle: Text('${cand.type.shortLabel} - ${cand.hostLabel}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  ref.read(sourcesProvider.notifier).addFallbackSource(
                        source.id,
                        cand.id,
                      );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('關閉', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }
}
