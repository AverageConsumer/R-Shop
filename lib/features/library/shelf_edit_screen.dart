import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/input/input.dart';
import '../../core/responsive/responsive.dart';
import '../../models/custom_shelf.dart';
import '../../providers/app_providers.dart';
import '../../providers/shelf_providers.dart';
import '../../widgets/console_hud.dart';
import 'widgets/game_list_overlay.dart';
import 'widgets/system_selector_overlay.dart';
import 'widgets/text_input_dialog.dart';

class ShelfEditScreen extends ConsumerStatefulWidget {
  final CustomShelf? shelf;
  final List<({String filename, String displayName, String systemSlug})> allGameRecords;
  const ShelfEditScreen({super.key, this.shelf, this.allGameRecords = const []});

  @override
  ConsumerState<ShelfEditScreen> createState() => _ShelfEditScreenState();
}

class _ShelfEditScreenState extends ConsumerState<ShelfEditScreen>
    with ConsoleScreenMixin {
  late String _name;
  late List<ShelfFilterRule> _filterRules;
  late List<String> _excludedGameIds;
  late List<String> _manualGameIds;
  int _focusedField = 0;
  bool _showSystemSelector = false;
  int _systemSelectorRuleIndex = -1;
  bool _showGameListOverlay = false;
  GameListOverlayMode _gameListOverlayMode = GameListOverlayMode.hidden;

  bool get _isEditing => widget.shelf != null;

  // --- Computed: truly-manual game IDs ---

  List<String> get _trulyManualGameIds {
    if (_filterRules.isEmpty) return _manualGameIds;
    final filterMatched = <String>{};
    for (final r in widget.allGameRecords) {
      if (_filterRules.any((rule) => rule.matches(r.displayName, r.systemSlug))) {
        filterMatched.add(r.filename);
      }
    }
    return _manualGameIds.where((id) => !filterMatched.contains(id)).toList();
  }

  bool get _hasReorderArtifacts =>
      _manualGameIds.isNotEmpty &&
      _filterRules.isNotEmpty &&
      _manualGameIds.length != _trulyManualGameIds.length;

  // --- Field indices ---

  int get _addFilterIndex => 1 + _filterRules.length;

  int get _hiddenGamesIndex =>
      _excludedGameIds.isNotEmpty ? _addFilterIndex + 1 : -1;

  int get _addedGamesIndex {
    if (_trulyManualGameIds.isEmpty) return -1;
    return (_hiddenGamesIndex >= 0 ? _hiddenGamesIndex : _addFilterIndex) + 1;
  }

  int get _resetOrderIndex {
    if (!_hasReorderArtifacts) return -1;
    return (_addedGamesIndex >= 0
            ? _addedGamesIndex
            : _hiddenGamesIndex >= 0
                ? _hiddenGamesIndex
                : _addFilterIndex) +
        1;
  }

  int get _saveIndex =>
      (_resetOrderIndex >= 0
              ? _resetOrderIndex
              : _addedGamesIndex >= 0
                  ? _addedGamesIndex
                  : _hiddenGamesIndex >= 0
                      ? _hiddenGamesIndex
                      : _addFilterIndex) +
      1;

  int get _deleteIndex => _isEditing ? _saveIndex + 1 : -1;
  int get _fieldCount => _isEditing ? _deleteIndex + 1 : _saveIndex + 1;

  @override
  String get routeId => 'shelf_edit';

  @override
  Map<Type, Action<Intent>> get screenActions => {
        NavigateIntent: OverlayGuardedAction<NavigateIntent>(ref,
          onInvoke: (intent) { _navigate(intent.direction); return null; },
        ),
        ConfirmIntent: OverlayGuardedAction<ConfirmIntent>(ref,
          onInvoke: (_) { _confirm(); return null; },
        ),
        BackIntent: CallbackAction<BackIntent>(
          onInvoke: (_) { _handleBack(); return null; },
        ),
        ToggleOverlayIntent: ToggleOverlayAction(ref, onToggle: () {}),
      };

  @override
  void initState() {
    super.initState();
    final shelf = widget.shelf;
    _name = shelf?.name ?? '';
    _filterRules = shelf != null ? List.from(shelf.filterRules) : [];
    _excludedGameIds = shelf != null ? List.from(shelf.excludedGameIds) : [];
    _manualGameIds = shelf != null ? List.from(shelf.manualGameIds) : [];
  }

  void _navigate(GridDirection direction) {
    switch (direction) {
      case GridDirection.up:
        if (_focusedField > 0) {
          setState(() => _focusedField--);
          ref.read(feedbackServiceProvider).tick();
        }
      case GridDirection.down:
        if (_focusedField < _fieldCount - 1) {
          setState(() => _focusedField++);
          ref.read(feedbackServiceProvider).tick();
        }
      case GridDirection.left:
        if (_focusedField > 0 && _focusedField <= _filterRules.length) {
          _editFilterText(_focusedField - 1);
        }
      case GridDirection.right:
        if (_focusedField > 0 && _focusedField <= _filterRules.length) {
          _openSystemSelector(_focusedField - 1);
        }
    }
  }

  void _confirm() {
    if (_focusedField == 0) {
      _editName();
    } else if (_focusedField > 0 && _focusedField <= _filterRules.length) {
      _editFilterText(_focusedField - 1);
    } else if (_focusedField == _addFilterIndex) {
      _addFilter();
    } else if (_focusedField == _hiddenGamesIndex) {
      _openGameListOverlay(GameListOverlayMode.hidden);
    } else if (_focusedField == _addedGamesIndex) {
      _openGameListOverlay(GameListOverlayMode.added);
    } else if (_focusedField == _resetOrderIndex) {
      _resetManualOrder();
    } else if (_focusedField == _saveIndex) {
      _save();
    } else if (_focusedField == _deleteIndex) {
      _confirmDeleteShelf();
    }
  }

  void _handleBack() {
    if (_showGameListOverlay) {
      setState(() => _showGameListOverlay = false);
      return;
    }
    if (_showSystemSelector) {
      setState(() => _showSystemSelector = false);
      return;
    }
    ref.read(feedbackServiceProvider).cancel();
    Navigator.pop(context);
  }

  void _openGameListOverlay(GameListOverlayMode mode) {
    ref.read(feedbackServiceProvider).tick();
    setState(() {
      _gameListOverlayMode = mode;
      _showGameListOverlay = true;
    });
  }

  void _resetManualOrder() {
    ref.read(feedbackServiceProvider).tick();
    setState(() {
      _manualGameIds = List.from(_trulyManualGameIds);
      // Clamp focus if reset removed the field
      if (_focusedField >= _fieldCount) {
        _focusedField = _fieldCount - 1;
      }
    });
  }

  Future<void> _editName() async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => TextInputDialog(
        title: 'Shelf Name',
        initialValue: _name,
        onSubmit: (value) => Navigator.pop(ctx, value),
      ),
    );
    if (result != null && mounted) {
      setState(() => _name = result);
    }
    requestScreenFocus();
  }

  Future<void> _editFilterText(int index) async {
    final rule = _filterRules[index];
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => TextInputDialog(
        title: 'Filter Text',
        hintText: 'e.g. Pokemon',
        initialValue: rule.textQuery ?? '',
        onSubmit: (value) => Navigator.pop(ctx, value),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _filterRules[index] = rule.copyWith(
          textQuery: result.isEmpty ? null : result,
        );
      });
    }
    requestScreenFocus();
  }

  void _openSystemSelector(int ruleIndex) {
    setState(() {
      _showSystemSelector = true;
      _systemSelectorRuleIndex = ruleIndex;
    });
  }

  void _addFilter() {
    ref.read(feedbackServiceProvider).tick();
    setState(() {
      _filterRules.add(const ShelfFilterRule());
      _focusedField = _filterRules.length; // Focus new rule
    });
  }

  void _confirmDeleteShelf() {
    final shelf = widget.shelf;
    if (shelf == null) return;
    ref.read(feedbackServiceProvider).warning();
    ref.read(customShelvesProvider.notifier).removeShelf(shelf.id);
    Navigator.pop(context);
  }

  void _save() {
    if (_name.trim().isEmpty) {
      _editName();
      return;
    }
    ref.read(feedbackServiceProvider).confirm();
    final shelf = CustomShelf(
      id: widget.shelf?.id ??
          DateTime.now().millisecondsSinceEpoch.toRadixString(36),
      name: _name.trim(),
      filterRules: _filterRules,
      manualGameIds: _manualGameIds,
      excludedGameIds: _excludedGameIds,
      sortMode: widget.shelf?.sortMode ?? ShelfSortMode.alphabetical,
      createdAt: widget.shelf?.createdAt ?? DateTime.now(),
    );
    Navigator.pop(context, shelf);
  }

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;

    return buildWithActions(
      PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _handleBack();
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              SafeArea(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: rs.spacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: rs.spacing.md),
                      Text(
                        _isEditing ? 'EDIT SHELF' : 'NEW SHELF',
                        style: TextStyle(
                          fontSize: rs.isSmall ? 18 : 22,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 4,
                        ),
                      ),
                      SizedBox(height: rs.spacing.lg),
                      Expanded(
                        child: ListView(
                          children: [
                            _buildField(
                              index: 0,
                              label: 'NAME',
                              value: _name.isEmpty ? 'Tap to set...' : _name,
                              icon: Icons.label_rounded,
                              rs: rs,
                            ),
                            SizedBox(height: rs.spacing.md),
                            // Filter rules header
                            Text(
                              'FILTER RULES',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: rs.isSmall ? 9 : 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                            SizedBox(height: rs.spacing.sm),
                            for (int i = 0; i < _filterRules.length; i++)
                              _buildFilterRuleField(i, rs),
                            _buildField(
                              index: _addFilterIndex,
                              label: '+ ADD FILTER',
                              value: '',
                              icon: Icons.add_rounded,
                              rs: rs,
                              isAction: true,
                            ),
                            if (_hiddenGamesIndex >= 0)
                              Padding(
                                padding: EdgeInsets.only(top: rs.spacing.sm),
                                child: _buildField(
                                  index: _hiddenGamesIndex,
                                  label: 'Hidden Games (${_excludedGameIds.length})',
                                  value: '',
                                  icon: Icons.visibility_off_rounded,
                                  rs: rs,
                                  accentColor: Colors.amber,
                                ),
                              ),
                            if (_addedGamesIndex >= 0)
                              Padding(
                                padding: EdgeInsets.only(top: rs.spacing.sm),
                                child: _buildField(
                                  index: _addedGamesIndex,
                                  label: 'Added Games (${_trulyManualGameIds.length})',
                                  value: '',
                                  icon: Icons.playlist_add_check_rounded,
                                  rs: rs,
                                  accentColor: Colors.tealAccent,
                                ),
                              ),
                            if (_resetOrderIndex >= 0)
                              Padding(
                                padding: EdgeInsets.only(top: rs.spacing.sm),
                                child: _buildField(
                                  index: _resetOrderIndex,
                                  label: 'Reset Manual Order',
                                  value: '',
                                  icon: Icons.restart_alt_rounded,
                                  rs: rs,
                                  isAction: true,
                                  accentColor: Colors.orangeAccent,
                                ),
                              ),
                            SizedBox(height: rs.spacing.lg),
                            _buildField(
                              index: _saveIndex,
                              label: 'SAVE',
                              value: '',
                              icon: Icons.check_rounded,
                              rs: rs,
                              isAction: true,
                              accentColor: Colors.greenAccent,
                            ),
                            if (_isEditing) ...[
                              SizedBox(height: rs.spacing.sm),
                              _buildField(
                                index: _deleteIndex,
                                label: 'DELETE SHELF',
                                value: '',
                                icon: Icons.delete_rounded,
                                rs: rs,
                                isAction: true,
                                accentColor: Colors.redAccent,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_showGameListOverlay)
                GameListOverlay(
                  mode: _gameListOverlayMode,
                  gameIds: _gameListOverlayMode == GameListOverlayMode.hidden
                      ? _excludedGameIds
                      : _trulyManualGameIds,
                  allGameRecords: widget.allGameRecords,
                  onRemove: (id) {
                    setState(() {
                      if (_gameListOverlayMode == GameListOverlayMode.hidden) {
                        _excludedGameIds.remove(id);
                        if (_excludedGameIds.isEmpty) _showGameListOverlay = false;
                      } else {
                        _manualGameIds.remove(id);
                        if (_trulyManualGameIds.isEmpty) _showGameListOverlay = false;
                      }
                    });
                  },
                  onClearAll: () {
                    setState(() {
                      if (_gameListOverlayMode == GameListOverlayMode.hidden) {
                        _excludedGameIds.clear();
                      } else {
                        // Remove only truly-manual IDs from manualGameIds
                        final toRemove = _trulyManualGameIds.toSet();
                        _manualGameIds.removeWhere((id) => toRemove.contains(id));
                      }
                      _showGameListOverlay = false;
                    });
                  },
                  onClose: () => setState(() => _showGameListOverlay = false),
                ),
              if (_showSystemSelector)
                SystemSelectorOverlay(
                  selectedSlugs: _filterRules[_systemSelectorRuleIndex].systemSlugs,
                  onChanged: (slugs) {
                    setState(() {
                      _filterRules[_systemSelectorRuleIndex] =
                          _filterRules[_systemSelectorRuleIndex]
                              .copyWith(systemSlugs: slugs);
                    });
                  },
                  onClose: () => setState(() => _showSystemSelector = false),
                ),
              if (!_showSystemSelector && !_showGameListOverlay)
                ConsoleHud(
                  a: HudAction('Select', onTap: _confirm),
                  b: HudAction('Back', onTap: _handleBack),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterRuleField(int ruleIndex, Responsive rs) {
    final rule = _filterRules[ruleIndex];
    final fieldIndex = 1 + ruleIndex;
    final isFocused = _focusedField == fieldIndex;
    final textPart = rule.textQuery?.isNotEmpty == true
        ? '"${rule.textQuery}"'
        : 'Any text';
    final systemPart = rule.systemSlugs.isEmpty
        ? 'All systems'
        : rule.systemSlugs.map((s) => s.toUpperCase()).join(', ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: GestureDetector(
        onTap: () {
          setState(() => _focusedField = fieldIndex);
          _editFilterText(ruleIndex);
        },
        onLongPress: () {
          // Remove filter rule
          ref.read(feedbackServiceProvider).tick();
          setState(() {
            _filterRules.removeAt(ruleIndex);
            if (_focusedField >= _fieldCount) {
              _focusedField = _fieldCount - 1;
            }
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(
            horizontal: rs.spacing.md,
            vertical: rs.isSmall ? 10 : 12,
          ),
          decoration: BoxDecoration(
            color: isFocused
                ? Colors.cyanAccent.withValues(alpha: 0.1)
                : Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isFocused
                  ? Colors.cyanAccent.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.06),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.filter_alt_rounded,
                size: 16,
                color: isFocused ? Colors.cyanAccent : Colors.grey[600],
              ),
              SizedBox(width: rs.spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      textPart,
                      style: TextStyle(
                        fontSize: rs.isSmall ? 12 : 13,
                        color: isFocused ? Colors.white : Colors.white70,
                        fontWeight: isFocused ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    Text(
                      systemPart,
                      style: TextStyle(
                        fontSize: rs.isSmall ? 9 : 10,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              if (isFocused)
                Text(
                  '\u2190 Text  Sys \u2192',
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
  }

  Widget _buildField({
    required int index,
    required String label,
    required String value,
    required IconData icon,
    required Responsive rs,
    bool isAction = false,
    bool showArrows = false,
    Color? accentColor,
  }) {
    final isFocused = _focusedField == index;
    final color = accentColor ?? Colors.cyanAccent;

    return GestureDetector(
      onTap: () {
        setState(() => _focusedField = index);
        _confirm();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(
          horizontal: rs.spacing.md,
          vertical: rs.isSmall ? 10 : 12,
        ),
        decoration: BoxDecoration(
          color: isFocused
              ? color.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isFocused
                ? color.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isFocused ? color : Colors.grey[600],
            ),
            SizedBox(width: rs.spacing.sm),
            Text(
              label,
              style: TextStyle(
                fontSize: rs.isSmall ? 10 : 11,
                fontWeight: FontWeight.w600,
                color: isFocused ? color : Colors.grey[400],
                letterSpacing: 1,
              ),
            ),
            if (value.isNotEmpty) ...[
              SizedBox(width: rs.spacing.sm),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: rs.isSmall ? 12 : 13,
                    color: isFocused ? Colors.white : Colors.white70,
                    fontWeight: isFocused ? FontWeight.w600 : FontWeight.w400,
                  ),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                ),
              ),
            ] else
              const Spacer(),
            if (showArrows && isFocused)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  '\u2190 \u2192',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
