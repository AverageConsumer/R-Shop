import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/config/source.dart';
import '../../providers/app_providers.dart';
import '../../widgets/console_hud.dart';

/// Overlay for managing a source's multi-entry fallback chain and auto-select toggle.
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
  ConsumerState<FallbackPickerOverlay> createState() => _FallbackPickerOverlayState();
}

class _FallbackPickerOverlayState extends ConsumerState<FallbackPickerOverlay> {
  int _focusedIndex = 0;
  int? _sortingIndex;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sourcesProvider);
    final source = state.sources.where((s) => s.id == widget.sourceId).firstOrNull;

    if (source == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onClose());
      return const SizedBox.shrink();
    }

    final fallbackSources = [
      for (final fbId in source.fallbackSourceIds)
        ...state.sources.where((s) => s.id == fbId),
    ];

    final isSorting = _sortingIndex != null;
    // Row 0: Auto Select toggle
    // Rows 1..N: Fallback items
    // Row N+1: Add Fresh Source button
    // Row N+2: Pick Existing Source button
    final totalRows = 1 + fallbackSources.length + 2;

    return FocusScope(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
          return KeyEventResult.ignored;
        }
        final key = event.logicalKey;

        if (key == LogicalKeyboardKey.gameButtonB ||
            key == LogicalKeyboardKey.escape ||
            key == LogicalKeyboardKey.backspace) {
          if (isSorting) {
            setState(() => _sortingIndex = null);
            return KeyEventResult.handled;
          }
          widget.onClose();
          return KeyEventResult.handled;
        }

        if (key == LogicalKeyboardKey.arrowUp) {
          if (isSorting) {
            _moveFallback(source, fallbackSources, _focusedIndex - 1, -1);
            return KeyEventResult.handled;
          }
          setState(() {
            _focusedIndex = (_focusedIndex - 1 + totalRows) % totalRows;
          });
          return KeyEventResult.handled;
        }

        if (key == LogicalKeyboardKey.arrowDown) {
          if (isSorting) {
            _moveFallback(source, fallbackSources, _focusedIndex - 1, 1);
            return KeyEventResult.handled;
          }
          setState(() {
            _focusedIndex = (_focusedIndex + 1) % totalRows;
          });
          return KeyEventResult.handled;
        }

        if (key == LogicalKeyboardKey.gameButtonA ||
            key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.space) {
          if (isSorting) {
            setState(() => _sortingIndex = null);
            return KeyEventResult.handled;
          }
          _activateRow(source, fallbackSources, _focusedIndex);
          return KeyEventResult.handled;
        }

        // [X] button removes fallback if focused on a fallback item
        if ((key == LogicalKeyboardKey.gameButtonX || key == LogicalKeyboardKey.keyX) && !isSorting) {
          if (_focusedIndex >= 1 && _focusedIndex <= fallbackSources.length) {
            final targetFb = fallbackSources[_focusedIndex - 1];
            ref.read(sourcesProvider.notifier).removeFallbackSource(
                  source.id,
                  targetFb.id,
                );
            return KeyEventResult.handled;
          }
        }

        return KeyEventResult.ignored;
      },
      child: Material(
        color: Colors.black87,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey[900],
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: widget.onClose,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${source.name} - 備援設定',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Content List
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Row 0: Auto Select Toggle
                  _buildAutoSelectRow(source, isFocused: _focusedIndex == 0),

                  const SizedBox(height: 16),
                  const Text(
                    '備援來源清單（優先順序）',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  if (fallbackSources.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      alignment: Alignment.center,
                      child: const Text(
                        '尚未設定任何備援來源',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    )
                  else
                    for (int i = 0; i < fallbackSources.length; i++)
                      _buildFallbackRow(
                        source: source,
                        fallback: fallbackSources[i],
                        index: i,
                        isFocused: _focusedIndex == i + 1,
                        isSorting: _sortingIndex == i + 1,
                      ),

                  const SizedBox(height: 24),

                  // Bottom Action Row 1: Add Fresh Source
                  _buildActionButton(
                    label: '+ 新建全新備援來源',
                    isFocused: _focusedIndex == fallbackSources.length + 1,
                    onTap: () {
                      widget.onClose();
                      widget.onAddFreshSource?.call();
                    },
                  ),

                  const SizedBox(height: 12),

                  // Bottom Action Row 2: Pick Existing Source
                  _buildActionButton(
                    label: '+ 從既有來源選擇備援',
                    isFocused: _focusedIndex == fallbackSources.length + 2,
                    onTap: () => _showPickExistingDialog(source, state.sources),
                  ),
                ],
              ),
            ),

            // HUD
            ConsoleHud(
              embedded: true,
              b: const HudAction('返回'),
              a: HudAction(isSorting ? '完成排序' : '確定 / 排序'),
              x: (_focusedIndex >= 1 && _focusedIndex <= fallbackSources.length && !isSorting)
                  ? const HudAction('移除備援')
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAutoSelectRow(Source source, {required bool isFocused}) {
    return InkWell(
      onTap: () {
        ref.read(sourcesProvider.notifier).setFallbackAutoSelect(
              source.id,
              !source.fallbackAutoSelect,
            );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isFocused ? Colors.red[900]!.withAlpha(90) : Colors.grey[850],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isFocused ? Colors.white : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              source.fallbackAutoSelect
                  ? Icons.check_box
                  : Icons.check_box_outline_blank,
              color: Colors.white,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '自動選擇',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    source.fallbackAutoSelect
                        ? '自動連線並優先使用回應最快的備援來源'
                        : '未勾選：依下方自訂順序依次嘗試備援來源',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackRow({
    required Source source,
    required Source fallback,
    required int index,
    required bool isFocused,
    required bool isSorting,
  }) {
    final bgColor = isSorting
        ? Colors.amber[900]!.withAlpha(180)
        : (isFocused ? Colors.red[900]!.withAlpha(90) : Colors.grey[850]);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          setState(() {
            _sortingIndex = isSorting ? null : index + 1;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isFocused ? Colors.white : Colors.transparent,
              width: 2,
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
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fallback.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
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
                  icon: const Icon(Icons.delete_outline, color: Colors.white70),
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

  Widget _buildActionButton({
    required String label,
    required bool isFocused,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isFocused ? Colors.red[900]!.withAlpha(90) : Colors.grey[800],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isFocused ? Colors.white : Colors.transparent,
            width: 2,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _activateRow(Source source, List<Source> fallbacks, int rowIndex) {
    if (rowIndex == 0) {
      ref.read(sourcesProvider.notifier).setFallbackAutoSelect(
            source.id,
            !source.fallbackAutoSelect,
          );
    } else if (rowIndex >= 1 && rowIndex <= fallbacks.length) {
      setState(() => _sortingIndex = rowIndex);
    } else if (rowIndex == fallbacks.length + 1) {
      widget.onClose();
      widget.onAddFreshSource?.call();
    } else if (rowIndex == fallbacks.length + 2) {
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
      _focusedIndex = toIndex + 1;
      _sortingIndex = toIndex + 1;
    });
  }

  void _showPickExistingDialog(Source source, List<Source> allSources) {
    final candidates = allSources
        .where((s) => s.id != source.id && !source.fallbackSourceIds.contains(s.id))
        .toList();

    if (candidates.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text('沒有可用的來源', style: TextStyle(color: Colors.white)),
          content: const Text(
            '目前沒有其他未綁定的既有來源可供選擇。請選擇「新建全新備援來源」。',
            style: TextStyle(color: Colors.grey),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('確定', style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('選擇既有來源作為備援', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: 300,
          height: 250,
          child: ListView.builder(
            itemCount: candidates.length,
            itemBuilder: (context, index) {
              final cand = candidates[index];
              return ListTile(
                title: Text(cand.name, style: const TextStyle(color: Colors.white)),
                subtitle: Text('${cand.type.shortLabel} - ${cand.hostLabel}',
                    style: const TextStyle(color: Colors.grey)),
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
