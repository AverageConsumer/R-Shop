import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/console_focusable.dart';
import '../../l10n/app_localizations.dart';
import '../../models/config/app_config.dart';
import '../../models/config/source.dart';
import '../../models/system_model.dart';
import '../../providers/app_providers.dart';
import '../../providers/game_providers.dart';

/// Per-system path mapping editor for a manual (non-RomM) [Source].
///
/// Lists every system that exists in the user's config, with a path
/// text field next to each. Empty fields mean "this source does not
/// serve that system". Saving rewrites every mapping for the source in
/// one atomic notifier call.
///
/// Controller layout mirrors [ManualPairingScreen]: the screen-level
/// Focus owns ↑/↓ traversal across rows + the Save button, A on a row
/// enters edit mode for the path field, B leaves editing or pops.
class SourceMappingsScreen extends ConsumerStatefulWidget {
  const SourceMappingsScreen({super.key, required this.source});

  final Source source;

  @override
  ConsumerState<SourceMappingsScreen> createState() =>
      _SourceMappingsScreenState();
}

class _SourceMappingsScreenState
    extends ConsumerState<SourceMappingsScreen> {
  final _screenFocus = FocusNode(debugLabel: 'mapping_screen');
  final _saveFocus = FocusNode(debugLabel: 'mapping_save');
  final ScrollController _scroll = ScrollController();

  /// One row per system in the user's config. Built once in initState
  /// from the bootstrapped config snapshot — adding systems while the
  /// editor is open is rare enough that we don't bother listening.
  late List<_MappingRow> _rows;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _rows = _buildRows();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_rows.isNotEmpty) {
        _rows.first.consoleFocus.requestFocus();
      } else {
        _saveFocus.requestFocus();
      }
    });
  }

  List<_MappingRow> _buildRows() {
    final config = ref.read(bootstrappedConfigProvider).valueOrNull ??
        AppConfig.empty;
    final rows = <_MappingRow>[];
    for (final system in config.systems) {
      final model = SystemModel.supportedSystems
          .where((m) => m.id == system.id)
          .firstOrNull;
      // Pull the existing mapping path for this source, if any.
      final existing = system.manualMappings
          .where((m) => m.sourceId == widget.source.id)
          .firstOrNull;
      rows.add(_MappingRow(
        systemId: system.id,
        label: model?.name ?? system.id,
        accent: model?.accentColor ?? Colors.grey,
        controller: TextEditingController(text: existing?.remotePath ?? ''),
      ));
    }
    return rows;
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    _saveFocus.dispose();
    _screenFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  bool get _isEditing => _rows.any((r) => r.textFocus.hasFocus);

  List<FocusNode> get _navOrder =>
      [..._rows.map((r) => r.consoleFocus), _saveFocus];

  KeyEventResult _handleScreenKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.gameButtonB ||
        key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack) {
      if (_isEditing) {
        for (final r in _rows) {
          if (r.textFocus.hasFocus) {
            r.consoleFocus.requestFocus();
            return KeyEventResult.handled;
          }
        }
      }
      Navigator.of(context).maybePop();
      return KeyEventResult.handled;
    }

    if (_isEditing) return KeyEventResult.ignored;

    if (key == LogicalKeyboardKey.arrowDown) {
      _moveFocus(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _moveFocus(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.gameButtonA ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.select) {
      _activateFocused();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _moveFocus(int delta) {
    final order = _navOrder;
    final cur = order.indexWhere((n) => n.hasFocus);
    final start = cur < 0 ? (delta > 0 ? -1 : order.length) : cur;
    final next = (start + delta).clamp(0, order.length - 1);
    if (next == cur) return;
    final target = order[next];
    if (target.canRequestFocus) {
      target.requestFocus();
      ref.read(feedbackServiceProvider).tick();
    }
  }

  void _activateFocused() {
    for (final r in _rows) {
      if (r.consoleFocus.hasFocus) {
        r.textFocus.requestFocus();
        return;
      }
    }
    if (_saveFocus.hasFocus && !_busy) _save();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final mappings = <String, String>{
      for (final r in _rows) r.systemId: r.controller.text,
    };
    try {
      await ref
          .read(sourcesProvider.notifier)
          .setMappingsForSource(widget.source.id, mappings);
      ref.invalidate(bootstrappedConfigProvider);
      ref.invalidate(gamesProvider);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Failed to save: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Focus(
          focusNode: _screenFocus,
          autofocus: true,
          onKeyEvent: _handleScreenKey,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      L.of(context).sourceMappings_title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.source.name} · ${widget.source.hostLabel}',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      L.of(context).sourceMappings_instruction,
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _rows.isEmpty
                          ? const Center(
                              child: Text(
                                'No systems configured yet — add one '
                                'from the home screen first.',
                                style: TextStyle(
                                    color: Colors.white54, fontSize: 13),
                                textAlign: TextAlign.center,
                              ),
                            )
                          : ListView.separated(
                              controller: _scroll,
                              itemCount: _rows.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (_, i) => _MappingRowWidget(
                                row: _rows[i],
                              ),
                            ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(_error!,
                          style: const TextStyle(
                              color: Colors.redAccent, fontSize: 13)),
                    ],
                    const SizedBox(height: 14),
                    ConsoleFocusable(
                      focusNode: _saveFocus,
                      onSelect: _busy ? null : _save,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppTheme.primaryColor, width: 2),
                        ),
                        child: _busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.primaryColor,
                                ),
                              )
                            : Text(
                                L.of(context).sourceMappings_save,
                                style: const TextStyle(
                                  color: AppTheme.primaryColor,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MappingRow {
  _MappingRow({
    required this.systemId,
    required this.label,
    required this.accent,
    required this.controller,
  })  : consoleFocus = FocusNode(debugLabel: 'mapping_${systemId}_wrap'),
        textFocus = FocusNode(
            skipTraversal: true, debugLabel: 'mapping_${systemId}_text');

  final String systemId;
  final String label;
  final Color accent;
  final TextEditingController controller;
  final FocusNode consoleFocus;
  final FocusNode textFocus;

  void dispose() {
    controller.dispose();
    consoleFocus.dispose();
    textFocus.dispose();
  }
}

class _MappingRowWidget extends StatelessWidget {
  const _MappingRowWidget({required this.row});
  final _MappingRow row;

  @override
  Widget build(BuildContext context) {
    return ConsoleFocusable(
      focusNode: row.consoleFocus,
      focusScale: 1.0,
      onSelect: row.textFocus.requestFocus,
      child: ListenableBuilder(
        listenable: row.textFocus,
        builder: (context, _) {
          final hasFocus = row.textFocus.hasFocus;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF252525),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: hasFocus
                    ? AppTheme.primaryColor
                    : row.accent.withValues(alpha: 0.4),
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 28,
                  decoration: BoxDecoration(
                    color: row.accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 120,
                  child: Text(
                    row.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: row.controller,
                    focusNode: row.textFocus,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontFamily: 'monospace',
                    ),
                    decoration: InputDecoration(
                      hintText: '/path/to/folder  (empty = skip)',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 13,
                        fontFamily: 'monospace',
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
