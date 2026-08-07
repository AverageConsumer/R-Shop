import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/console_focusable.dart';
import '../../models/config/source.dart';
import '../../providers/app_providers.dart';
import '../../widgets/console_dialog.dart';
import '../../widgets/console_hud.dart';

/// Source screen architecture overlay for managing a source's multi-fallback chain.
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
  final _screenFocus = FocusScopeNode(debugLabel: 'fallback_overlay_screen');
  final _backFocus = FocusNode(debugLabel: 'fallback_overlay_back');
  final _autoSelectFocus = FocusNode(debugLabel: 'fallback_overlay_autoselect');
  final _addFreshFocus = FocusNode(debugLabel: 'fallback_overlay_add_fresh');
  final _pickExistingFocus = FocusNode(debugLabel: 'fallback_overlay_pick_existing');

  final Map<String, FocusNode> _fallbackFocusNodes = {};
  int? _sortingIndex;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _autoSelectFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _screenFocus.dispose();
    _backFocus.dispose();
    _autoSelectFocus.dispose();
    _addFreshFocus.dispose();
    _pickExistingFocus.dispose();
    for (final fn in _fallbackFocusNodes.values) {
      fn.dispose();
    }
    super.dispose();
  }

  FocusNode _focusForFallback(String id) {
    return _fallbackFocusNodes.putIfAbsent(
      id,
      () => FocusNode(debugLabel: 'fallback_item_$id'),
    );
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

    final fallbackSources = [
      for (final fbId in source.fallbackSourceIds)
        ...state.sources.where((s) => s.id == fbId),
    ];

    final isSorting = _sortingIndex != null;

    return FocusScope(
      node: _screenFocus,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
          return KeyEventResult.ignored;
        }
        final key = event.logicalKey;

        if (key == LogicalKeyboardKey.gameButtonB ||
            key == LogicalKeyboardKey.escape) {
          if (isSorting) {
            setState(() => _sortingIndex = null);
            return KeyEventResult.handled;
          }
          widget.onClose();
          return KeyEventResult.handled;
        }

        return KeyEventResult.ignored;
      },
      child: Material(
        color: const Color(0xFF141414),
        child: Column(
          children: [
            // Top Header matching Source Screen Architecture
            Container(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
              color: Colors.black26,
              child: Row(
                children: [
                  ConsoleFocusable(
                    focusNode: _backFocus,
                    onSelect: widget.onClose,
                    borderRadius: 20.0,
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.arrow_back, color: Colors.white, size: 26),
                    ),
                  ),
                  const SizedBox(width: 12),
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

            // Main Content List
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Row 0: Auto Select Toggle
                  ConsoleFocusable(
                    focusNode: _autoSelectFocus,
                    onSelect: () {
                      ref.read(sourcesProvider.notifier).setFallbackAutoSelect(
                            source.id,
                            !source.fallbackAutoSelect,
                          );
                    },
                    borderRadius: 8.0,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: source.fallbackAutoSelect
                            ? const Color(0xFFE50914).withAlpha(90)
                            : Colors.grey[850],
                        borderRadius: BorderRadius.circular(8),
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
                                      ? '自動探測並優先使用回應最快的備援來源'
                                      : '未勾選：依下方自訂順序依次嘗試備援來源',
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
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
                        fallbacks: fallbackSources,
                        isSorting: _sortingIndex == i,
                      ),

                  const SizedBox(height: 24),

                  // Bottom Action 1: Add Fresh Source
                  ConsoleFocusable(
                    focusNode: _addFreshFocus,
                    onSelect: () {
                      widget.onClose();
                      widget.onAddFreshSource?.call();
                    },
                    borderRadius: 8.0,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        '+ 新建全新備援來源',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Bottom Action 2: Pick Existing Source
                  ConsoleFocusable(
                    focusNode: _pickExistingFocus,
                    onSelect: () =>
                        _showPickExistingDialog(source, state.sources),
                    borderRadius: 8.0,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        '+ 從既有來源選擇備援',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Standard Console HUD
            ConsoleHud(
              embedded: true,
              b: const HudAction('返回'),
              a: HudAction(isSorting ? '完成排序' : '確定 / 排序'),
              x: (!isSorting && fallbackSources.isNotEmpty)
                  ? const HudAction('移除備援')
                  : null,
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
    required List<Source> fallbacks,
    required bool isSorting,
  }) {
    final fn = _focusForFallback(fallback.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: FocusScope(
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
            return KeyEventResult.ignored;
          }
          final key = event.logicalKey;

          if (isSorting) {
            if (key == LogicalKeyboardKey.arrowUp) {
              _moveFallback(source, fallbacks, index, -1);
              return KeyEventResult.handled;
            }
            if (key == LogicalKeyboardKey.arrowDown) {
              _moveFallback(source, fallbacks, index, 1);
              return KeyEventResult.handled;
            }
          }

          if ((key == LogicalKeyboardKey.gameButtonX ||
                  key == LogicalKeyboardKey.keyX) &&
              !isSorting) {
            ref.read(sourcesProvider.notifier).removeFallbackSource(
                  source.id,
                  fallback.id,
                );
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: ConsoleFocusable(
          focusNode: fn,
          onSelect: () {
            setState(() {
              _sortingIndex = isSorting ? null : index;
            });
          },
          borderRadius: 8.0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSorting
                  ? Colors.amber[900]!.withAlpha(180)
                  : Colors.grey[850],
              borderRadius: BorderRadius.circular(8),
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
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (isSorting)
                  const Icon(Icons.swap_vert, color: Colors.amber)
                else
                  IconButton(
                    icon:
                        const Icon(Icons.delete_outline, color: Colors.white70),
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
      ),
    );
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
      _sortingIndex = toIndex;
    });
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
        backgroundColor: const Color(0xFF141414),
        title: const Text('選擇既有來源作為備援',
            style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: 300,
          height: 250,
          child: ListView.builder(
            itemCount: candidates.length,
            itemBuilder: (context, index) {
              final cand = candidates[index];
              return ListTile(
                title: Text(cand.name,
                    style: const TextStyle(color: Colors.white)),
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
