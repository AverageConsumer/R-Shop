import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/input/input.dart';
import '../../widgets/console_hud.dart';
import '../../l10n/app_localizations.dart';
import '../../models/config/app_config.dart';
import '../../models/config/source.dart';
import '../../providers/app_providers.dart';
import '../../widgets/console_dialog.dart';

/// Creates and edits the group [source] belongs to.
///
/// A group is the user saying "these sources are the same server, reached
/// different ways". It replaces the old one-way fallback pairing: there is no
/// stand-in to name any more, there is a set of addresses and a rule for
/// picking between them.
///
/// The overlay has two faces, because the source is either in a group or not:
///
/// * **not grouped** — the list of sources it could be grouped with. Only ones
///   of the same type and not already in a group: two protocols cannot be the
///   one server the group claims they are.
/// * **grouped** — the mode (first to answer / the user's order) and the
///   members in order, each with move-up, move-down and leave.
///
/// Every row answers to a tap and every action has a key, because the device
/// has both and a control that only takes one of them reads as broken.
class GroupPickerOverlay extends ConsumerStatefulWidget {
  const GroupPickerOverlay({
    super.key,
    required this.source,
    required this.onClose,
  });

  final Source source;
  final VoidCallback onClose;

  @override
  ConsumerState<GroupPickerOverlay> createState() => _GroupPickerOverlayState();
}

class _GroupPickerOverlayState extends ConsumerState<GroupPickerOverlay>
    with SingleTickerProviderStateMixin {
  final FocusNode _scopeFocus = FocusNode(debugLabel: 'group_picker');
  int _selectedIndex = 0;

  /// One key per row so the cursor can be scrolled into view. Without this the
  /// selection walks off the bottom of the panel and the pad appears to stop
  /// responding — the rows are there, they are just below the fold.
  final Map<int, GlobalKey> _rowKeys = {};

  GlobalKey _keyFor(int index) =>
      _rowKeys.putIfAbsent(index, () => GlobalKey());

  void _scrollToSelected() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _rowKeys[_selectedIndex]?.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.5,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
      );
    });
  }

  /// True while the "add a source" list is showing over a group that exists.
  bool _adding = false;

  /// Which control on the selected row has the cursor: 0 is the row itself,
  /// 1..n are the small icons at its right end.
  ///
  /// ▶ walks onto them, ◀ walks back. This is instead of a submenu: the user
  /// asked for exactly this — "不是開視窗，是那邊會有小圖示，我焦點移到小圖示
  /// 上面" — and it keeps every action visible on the row it belongs to.
  int _actionIndex = 0;

  /// True while ↑↓ moves the selected member instead of the cursor.
  ///
  /// [A] on a member enters it and [A] again leaves: reordering is the thing
  /// people do repeatedly, so it gets the whole d-pad rather than one press
  /// per step through the icons.
  bool _sorting = false;

  /// Slides the row that just moved from where it was to where it now is.
  ///
  /// A reorder is otherwise a single frame in which two rows swap: the list is
  /// correct and nothing appears to have happened. The offset is measured, not
  /// assumed — rows have a hint line under them and are not all the same
  /// height, so a guessed row height would slide by the wrong amount.
  late final AnimationController _slide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );
  String? _slidingId;
  double _slideFrom = 0;

  /// The top of row [index] in global coordinates, or null if it is not laid
  /// out (scrolled far out of view).
  double? _yOf(int index) {
    final ctx = _rowKeys[index]?.currentContext;
    final box = ctx?.findRenderObject() as RenderBox?;
    return box?.localToGlobal(Offset.zero).dy;
  }

  /// True while a merge or hand-over is running. Joining a group rewrites the
  /// cached library, which is fast but not instant on a large one — and a
  /// second tap during it would start a second merge over half-moved rows.
  bool _busy = false;

  SourceGroup? get _group =>
      ref.read(sourcesProvider).groupContaining(widget.source.id);

  /// Sources this one could be grouped with: same type, not already spoken
  /// for. `sanitizeGroups` would drop a source claimed twice anyway, so
  /// offering it here would only produce a choice that quietly does nothing.
  List<Source> get _candidates {
    final state = ref.read(sourcesProvider);
    return state.sources
        .where((s) =>
            s.id != widget.source.id &&
            s.type == widget.source.type &&
            state.groupContaining(s.id) == null)
        .toList();
  }

  List<Source> _membersOf(SourceGroup group) {
    final byId = {for (final s in ref.read(sourcesProvider).sources) s.id: s};
    return [
      for (final id in group.memberIds)
        if (byId[id] != null) byId[id]!,
    ];
  }

  @override
  void dispose() {
    _slide.dispose();
    _scopeFocus.dispose();
    super.dispose();
  }

  // --- row layout -----------------------------------------------------------
  //
  // The rows are built as a list of intents rather than drawn twice, so the
  // key handler and the tap handler cannot disagree about what row 3 does.

  List<_GroupRow> _rows(L l) {
    final group = _group;
    if (group == null || _adding) {
      final candidates = _candidates;
      return [
        for (final s in candidates)
          _GroupRow(
            icon: Icons.dns_outlined,
            title: s.name,
            subtitle: s.hostLabel,
            onActivate: () => _addOrCreate(s.id),
          ),
        if (candidates.isEmpty)
          _GroupRow(
            icon: Icons.info_outline,
            title: l.sources_groupNoCandidates,
            subdued: true,
            onActivate: _close,
          ),
        _GroupRow(
          icon: Icons.close,
          title: l.common_cancel,
          subdued: true,
          onActivate: _close,
        ),
      ];
    }

    final members = _membersOf(group);

    return [
      // One tickbox, not two mutually exclusive rows: there are only two
      // states, and turning the first off was done by picking the second —
      // a tickbox written the long way. Unticked, the list below **is** the
      // order, so it needs no row to describe it.
      _GroupRow(
        icon: group.mode == SourceGroupMode.auto
            ? Icons.check_box
            : Icons.check_box_outline_blank,
        title: l.sources_groupModeAuto,
        subtitle: group.mode == SourceGroupMode.auto
            ? l.sources_groupModeAutoHint
            : l.sources_groupModeOrderedHint,
        active: group.mode == SourceGroupMode.auto,
        onActivate: () => _setMode(group.mode == SourceGroupMode.auto
            ? SourceGroupMode.ordered
            : SourceGroupMode.auto),
      ),
      for (var i = 0; i < members.length; i++)
        _GroupRow(
          icon: Icons.dns_outlined,
          title: members[i].name,
          subtitle: i == 0 ? l.sources_groupPreferred : members[i].hostLabel,
          member: members[i].id,
          // One tickbox above the members now, so they start at index one.
          hint: _sorting && _selectedIndex == i + 1
              ? l.sources_reorderHint
              : l.sources_groupMemberHint,
          canMoveUp: i > 0,
          canMoveDown: i < members.length - 1,
          // [A] on a member turns the d-pad into a reorder control. The
          // other things it can be put through are on the icons at its end.
          onActivate: () => _toggleSorting(members[i].id),
        ),
      if (_candidates.isNotEmpty)
        _GroupRow(
          icon: Icons.add,
          title: l.sources_groupAddMember,
          onActivate: () => setState(() {
            _adding = true;
            _selectedIndex = 0;
          }),
        ),
      _GroupRow(
        icon: Icons.link_off,
        title: l.sources_groupDissolve,
        subdued: true,
        onActivate: _confirmDissolve,
      ),
      _GroupRow(
        icon: Icons.close,
        title: l.common_cancel,
        subdued: true,
        onActivate: _close,
      ),
    ];
  }

  /// The icons on [row], in the order they are drawn. One list, read by both
  /// the key handler and the row widget, so ▶ and a finger can never land on
  /// different things.
  List<_RowAction> _actionsFor(_GroupRow row) {
    final id = row.member;
    if (id == null) return const [];
    final l = L.of(context);
    final sortingThis = _sorting && _sortingId == id;
    if (sortingThis) {
      // While the d-pad is moving this row, the icons become the finger's
      // version of the same thing — otherwise reordering would be a pad-only
      // feature the moment the standing arrows went away.
      return [
        if (row.canMoveUp)
          _RowAction(
            icon: Icons.keyboard_arrow_up,
            label: l.sources_moveUp,
            run: () => _move(id, -1),
          ),
        if (row.canMoveDown)
          _RowAction(
            icon: Icons.keyboard_arrow_down,
            label: l.sources_moveDown,
            run: () => _move(id, 1),
          ),
        _RowAction(
          icon: Icons.check,
          label: l.common_done,
          run: () => setState(() {
            _sorting = false;
            _sortingId = null;
          }),
        ),
      ];
    }
    return [
      _RowAction(
        icon: Icons.drag_handle,
        label: l.sources_moveUp,
        run: () => _toggleSorting(id),
      ),
      _RowAction(
        icon: Icons.logout,
        label: l.sources_groupLeave,
        run: () => _confirmLeave(id),
      ),
    ];
  }

  /// The member the d-pad is currently moving, or null.
  String? _sortingId;

  // --- actions --------------------------------------------------------------

  void _close() {
    ref.read(feedbackServiceProvider).cancel();
    widget.onClose();
  }

  /// Takes the focus back after a write.
  ///
  /// Belt and braces alongside the guard in the sources screen: writing a
  /// group rebuilds the list underneath, and anything that re-homes focus
  /// during that rebuild leaves this overlay on screen but deaf to the pad.
  void _toggleSorting(String memberId) {
    ref.read(feedbackServiceProvider).confirm();
    setState(() {
      _sorting = !_sorting;
      _sortingId = _sorting ? memberId : null;
      // The icons swap to arrows, so the cursor must not stay on whichever
      // slot it happened to be in.
      _actionIndex = 0;
    });
  }

  void _reclaimFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _scopeFocus.hasFocus) return;
      _scopeFocus.requestFocus();
    });
  }

  Future<void> _addOrCreate(String otherId) async {
    if (_busy) return;
    ref.read(feedbackServiceProvider).confirm();
    setState(() => _busy = true);
    final notifier = ref.read(sourcesProvider.notifier);
    final group = _group;
    try {
      if (group == null) {
        // The source the user opened this from goes first: they were looking
        // at it, so it is the one they mean by "preferred".
        await notifier.createGroup(memberIds: [widget.source.id, otherId]);
      } else {
        await notifier.addToGroup(group.id, otherId);
      }
    } catch (e) {
      debugPrint('GroupPicker: grouping failed: $e');
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _adding = false;
      _actionIndex = 0;
      _selectedIndex = 0;
    });
    _reclaimFocus();
  }

  Future<void> _setMode(SourceGroupMode mode) async {
    final group = _group;
    if (group == null) return;
    ref.read(feedbackServiceProvider).confirm();
    try {
      await ref.read(sourcesProvider.notifier).setGroupMode(group.id, mode);
    } catch (e) {
      debugPrint('GroupPicker: setGroupMode failed: $e');
    }
    if (mounted) setState(() {});
    _reclaimFocus();
  }

  Future<void> _move(String memberId, int delta) async {
    final group = _group;
    if (group == null) return;
    final index = group.indexOf(memberId);
    if (index < 0) return;
    final target = index + delta;
    if (target < 0 || target >= group.memberIds.length) return;
    ref.read(feedbackServiceProvider).tick();
    final fromY = _yOf(_selectedIndex);
    try {
      await ref
          .read(sourcesProvider.notifier)
          .moveGroupMember(group.id, memberId, target);
    } catch (e) {
      debugPrint('GroupPicker: moveGroupMember failed: $e');
    }
    if (!mounted) return;
    // Follow the row that moved, and keep the cursor on the arrow so the next
    // press moves the same member again.
    setState(() => _selectedIndex += delta);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final toY = _yOf(_selectedIndex);
      if (fromY == null || toY == null || (fromY - toY).abs() < 0.5) return;
      setState(() {
        _slidingId = memberId;
        _slideFrom = fromY - toY;
      });
      _slide.forward(from: 0);
    });
    _reclaimFocus();
  }

  /// Leaving costs the member its whole cached list, so it asks first.
  /// `showConsoleDialog` rather than a raw dialog: it is the only modal in
  /// this project that keeps gamepad focus (`AGENTS.md` §4).
  Future<void> _confirmLeave(String memberId) async {
    final l = L.of(context);
    ref.read(feedbackServiceProvider).tick();
    final ok = await showConsoleDialog(
      context,
      title: l.sources_groupLeaveTitle,
      message: l.sources_groupLeaveConfirm(_nameOf(memberId)),
      primaryLabel: l.sources_groupLeave,
      isDestructive: true,
    );
    if (ok != true || !mounted) return;
    await _leave(memberId);
  }

  Future<void> _confirmDissolve() async {
    final l = L.of(context);
    final group = _group;
    if (group == null) return;
    ref.read(feedbackServiceProvider).tick();
    final ok = await showConsoleDialog(
      context,
      title: l.sources_groupDissolveTitle,
      message: l.sources_groupDissolveConfirm(_nameOf(group.cacheOwnerId)),
      primaryLabel: l.sources_groupDissolve,
      isDestructive: true,
    );
    if (ok != true || !mounted) return;
    await _dissolve();
  }

  Future<void> _leave(String memberId) async {
    final group = _group;
    if (group == null || _busy) return;
    setState(() => _busy = true);
    ref.read(feedbackServiceProvider).confirm();
    try {
      await ref
          .read(sourcesProvider.notifier)
          .removeFromGroup(group.id, memberId);
    } catch (e) {
      debugPrint('GroupPicker: removeFromGroup failed: $e');
    }
    if (!mounted) return;
    // Losing the group (a pair leaves one member, which is not a group) leaves
    // nothing here to edit.
    if (_group == null) {
      widget.onClose();
      return;
    }
    setState(() {
      _busy = false;
      _actionIndex = 0;
      _selectedIndex = 0;
    });
    _reclaimFocus();
  }

  Future<void> _dissolve() async {
    final group = _group;
    if (group == null) return;
    ref.read(feedbackServiceProvider).confirm();
    try {
      await ref.read(sourcesProvider.notifier).dissolveGroup(group.id);
    } catch (e) {
      debugPrint('GroupPicker: dissolveGroup failed: $e');
    }
    widget.onClose();
  }

  // --- input ----------------------------------------------------------------

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final l = L.of(context);
    final rows = _rows(l);
    if (rows.isEmpty) return KeyEventResult.ignored;
    final row = rows[_selectedIndex.clamp(0, rows.length - 1)];

    final sortingId = _sorting ? row.member : null;
    if (sortingId != null) {
      if (key == LogicalKeyboardKey.arrowUp) {
        _move(sortingId, -1);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowDown) {
        _move(sortingId, 1);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.gameButtonA ||
          key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.select ||
          key == LogicalKeyboardKey.gameButtonB ||
          key == LogicalKeyboardKey.escape ||
          key == LogicalKeyboardKey.goBack) {
        ref.read(feedbackServiceProvider).confirm();
        setState(() {
          _sorting = false;
          _sortingId = null;
        });
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    if (key == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _selectedIndex = (_selectedIndex - 1 + rows.length) % rows.length;
        _actionIndex = 0;
        _sorting = false;
        _sortingId = null;
      });
      ref.read(feedbackServiceProvider).tick();
      _scrollToSelected();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _selectedIndex = (_selectedIndex + 1) % rows.length;
        _actionIndex = 0;
        _sorting = false;
        _sortingId = null;
      });
      ref.read(feedbackServiceProvider).tick();
      _scrollToSelected();
      return KeyEventResult.handled;
    }
    // [X] and [Y] reorder the selected member. The order is the setting in
    // `ordered` mode, so it needs a key of its own — going through a submenu
    // to move one row would be worse than the problem.
    // ▶ ◀ walk the cursor along the icons at the end of the row.
    final actions = _actionsFor(row);
    if (key == LogicalKeyboardKey.arrowRight) {
      if (_actionIndex < actions.length) {
        setState(() => _actionIndex++);
        ref.read(feedbackServiceProvider).tick();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (_actionIndex > 0) {
        setState(() => _actionIndex--);
        ref.read(feedbackServiceProvider).tick();
      }
      return KeyEventResult.handled;
    }
    // Leaving a group costs the member its cached list, so it sits on a
    // shoulder button rather than next to reorder — and it asks first.
    if ((key == LogicalKeyboardKey.gameButtonLeft1 ||
            key == LogicalKeyboardKey.gameButtonRight1) &&
        row.member != null) {
      _confirmLeave(row.member!);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.gameButtonX && row.canMoveUp) {
      _move(row.member!, -1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.gameButtonY && row.canMoveDown) {
      _move(row.member!, 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.gameButtonA ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.select) {
      if (_actionIndex > 0 && _actionIndex <= actions.length) {
        actions[_actionIndex - 1].run();
      } else {
        row.onActivate();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.gameButtonB ||
        key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack) {
      if (_adding && _group != null) {
        setState(() {
          _adding = false;
          _selectedIndex = 0;
        });
        return KeyEventResult.handled;
      }
      _close();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final group = _group;
    final rows = _rows(l);
    if (_selectedIndex >= rows.length) _selectedIndex = rows.length - 1;

    final onMember =
        _selectedIndex < rows.length && rows[_selectedIndex].member != null;
    final memberId = onMember ? rows[_selectedIndex].member : null;

    final title = group == null || _adding
        ? l.sources_groupPickMember
        : l.sources_groupManage;
    final subtitle = group == null || _adding
        ? l.sources_groupSameTypeOnly
        : '${group.name} · ${l.sources_groupMembersCount(group.memberIds.length)}';

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
                constraints: const BoxConstraints(maxWidth: 420, maxHeight: 420),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1C),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Scrollable: a group of four on a 3.92" screen already
                      // overflows, and an overflow here is the yellow-and-black
                      // stripe the user has reported before.
                      Flexible(
                        child: IgnorePointer(
                          ignoring: _busy,
                          child: Opacity(
                            opacity: _busy ? 0.4 : 1,
                            child: SingleChildScrollView(
                              // The hint row below is pinned, so without this
                              // the last row sat underneath it.
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (var i = 0; i < rows.length; i++) ...[
                                    if (i > 0) const SizedBox(height: 8),
                                    _SlideIn(
                                      controller: _slide,
                                      from: rows[i].member != null &&
                                              rows[i].member == _slidingId
                                          ? _slideFrom
                                          : 0,
                                      child: _Row(
                                      key: _keyFor(i),
                                      row: rows[i],
                                      selected: i == _selectedIndex,
                                      sorting: _sorting && i == _selectedIndex,
                                      actions: _actionsFor(rows[i]),
                                      focusedAction: i == _selectedIndex
                                          ? _actionIndex
                                          : 0,
                                      onAction: (a) {
                                        setState(() {
                                          _selectedIndex = i;
                                          _actionIndex = 0;
                                        });
                                        a.run();
                                      },
                                      onTap: () {
                                        setState(() => _selectedIndex = i);
                                        rows[i].onActivate();
                                      },
                                    ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Real buttons, not typed-out letters: ConsoleHud
                      // draws them per the user's controller layout, so the
                      // hint says ZL/ZR or LT/RT when that is what their pad
                      // has. It is also the touch half — every hint is a
                      // button.
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: ConsoleHud(
                          embedded: true,
                          a: HudAction(
                            l.common_select,
                            onTap: () {
                              final row = rows[_selectedIndex];
                              final acts = _actionsFor(row);
                              if (_actionIndex > 0 &&
                                  _actionIndex <= acts.length) {
                                acts[_actionIndex - 1].run();
                              } else {
                                row.onActivate();
                              }
                            },
                          ),
                          b: HudAction(l.common_back, onTap: _close),
                          x: onMember
                              ? HudAction(l.sources_moveUp,
                                  onTap: () => _move(memberId!, -1))
                              : null,
                          y: onMember
                              ? HudAction(l.sources_moveDown,
                                  onTap: () => _move(memberId!, 1))
                              : null,
                          rb: onMember
                              ? HudAction(l.sources_groupLeave,
                                  onTap: () => _confirmLeave(memberId!))
                              : null,
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

  String _nameOf(String? id) =>
      ref
          .read(sourcesProvider)
          .sources
          .where((s) => s.id == id)
          .firstOrNull
          ?.name ??
      (id ?? '');
}

/// One row's worth of intent: what it says, what it does, and whether it is a
/// member that can be moved.
class _GroupRow {
  _GroupRow({
    required this.icon,
    required this.title,
    required this.onActivate,
    this.subtitle,
    this.active = false,
    this.subdued = false,
    this.member,
    this.canMoveUp = false,
    this.canMoveDown = false,
    this.hint,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onActivate;
  final bool active;
  final bool subdued;
  final String? member;
  final bool canMoveUp;
  final bool canMoveDown;

  /// A line under the row saying what can be done to it, including how to
  /// reach the icons. Without it the icons are a discovery problem.
  final String? hint;
}

/// One action drawn at the right end of a row: an icon the cursor can land on
/// with ▶ and a finger can hit directly.
class _RowAction {
  const _RowAction({
    required this.icon,
    required this.label,
    required this.run,
  });

  final IconData icon;
  final String label;
  final VoidCallback run;
}

class _Row extends StatelessWidget {
  const _Row({
    super.key,
    required this.row,
    required this.selected,
    required this.onTap,
    this.sorting = false,
    this.actions = const [],
    this.focusedAction = 0,
    this.onAction,
  });

  final _GroupRow row;
  final bool selected;

  /// True while the d-pad is moving this row rather than the cursor. It gets
  /// its own colour: "where I am" and "what I am dragging" are different
  /// states and the red selection cannot say both.
  final bool sorting;
  final VoidCallback onTap;

  /// Icons at the right end. 0 means the cursor is on the row body; 1..n put
  /// it on one of these.
  final List<_RowAction> actions;
  final int focusedAction;
  final void Function(_RowAction action)? onAction;

  @override
  Widget build(BuildContext context) {
    final fg = row.subdued ? Colors.white54 : Colors.white;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: sorting
              ? const Color(0xFFB8860B).withValues(alpha: 0.35)
              : selected
                  ? const Color(0xFF8B0000).withValues(alpha: 0.35)
                  : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: sorting
                ? const Color(0xFFFFC107)
                : selected
                    ? Colors.white
                    : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(row.icon, size: 18, color: selected ? Colors.white : fg),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? Colors.white : fg,
                      fontSize: 14,
                      fontWeight:
                          row.active ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                  if (row.subtitle != null)
                    Text(
                      row.subtitle!,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            ),
            // The finger half of [X]/[Y]. Small icons in the corner rather
            // than rows of their own: another row per member would not fit.
            for (var i = 0; i < actions.length; i++)
              _ActionIcon(
                action: actions[i],
                focused: selected && focusedAction == i + 1,
                onTap: () => onAction?.call(actions[i]),
              ),
            if (row.active)
              const Icon(Icons.check, size: 16, color: Color(0xFF7BC67B)),
          ],
        ),
      ),
    );
  }
}

/// An icon at the end of a row. Drawn with its own focus ring so ▶ landing on
/// it is visible, and tappable on its own so a finger does not have to walk
/// there first.
class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.action,
    required this.focused,
    required this.onTap,
  });

  final _RowAction action;
  final bool focused;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(left: 4),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: focused
              ? const Color(0xFF8B0000).withValues(alpha: 0.5)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: focused ? Colors.white : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Icon(
          action.icon,
          size: 18,
          color: focused ? Colors.white : Colors.white54,
        ),
      ),
    );
  }
}

/// Slides [child] in from [from] pixels above or below its final position.
///
/// Kept separate from the row so the row itself stays a plain widget: only the
/// one that moved is ever animated, and every other row rebuilds as before.
class _SlideIn extends StatelessWidget {
  const _SlideIn({
    required this.controller,
    required this.from,
    required this.child,
  });

  final AnimationController controller;
  final double from;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (from == 0) return child;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, inner) => Transform.translate(
        offset: Offset(0, from * (1 - Curves.easeOut.transform(controller.value))),
        child: inner,
      ),
      child: child,
    );
  }
}
