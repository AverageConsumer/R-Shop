import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/input/input.dart';
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

class _GroupPickerOverlayState extends ConsumerState<GroupPickerOverlay> {
  final FocusNode _scopeFocus = FocusNode(debugLabel: 'group_picker');
  int _selectedIndex = 0;

  /// True while the "add a source" list is showing over a group that exists.
  bool _adding = false;

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
      _GroupRow(
        icon: Icons.bolt,
        title: l.sources_groupModeAuto,
        subtitle: l.sources_groupModeAutoHint,
        active: group.mode == SourceGroupMode.auto,
        onActivate: () => _setMode(SourceGroupMode.auto),
      ),
      _GroupRow(
        icon: Icons.format_list_numbered,
        title: l.sources_groupModeOrdered,
        subtitle: l.sources_groupModeOrderedHint,
        active: group.mode == SourceGroupMode.ordered,
        onActivate: () => _setMode(SourceGroupMode.ordered),
      ),
      for (var i = 0; i < members.length; i++)
        _GroupRow(
          icon: Icons.dns_outlined,
          title: members[i].name,
          subtitle: i == 0 ? l.sources_groupPreferred : members[i].hostLabel,
          member: members[i].id,
          canMoveUp: i > 0,
          canMoveDown: i < members.length - 1,
          onActivate: () => _confirmLeave(members[i].id),
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

  // --- actions --------------------------------------------------------------

  void _close() {
    ref.read(feedbackServiceProvider).cancel();
    widget.onClose();
  }

  Future<void> _addOrCreate(String otherId) async {
    ref.read(feedbackServiceProvider).confirm();
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
      _adding = false;
      _selectedIndex = 0;
    });
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
  }

  Future<void> _move(String memberId, int delta) async {
    final group = _group;
    if (group == null) return;
    final index = group.indexOf(memberId);
    if (index < 0) return;
    final target = index + delta;
    if (target < 0 || target >= group.memberIds.length) return;
    ref.read(feedbackServiceProvider).tick();
    try {
      await ref
          .read(sourcesProvider.notifier)
          .moveGroupMember(group.id, memberId, target);
    } catch (e) {
      debugPrint('GroupPicker: moveGroupMember failed: $e');
    }
    if (!mounted) return;
    // Follow the row that moved, otherwise the selection lands on whichever
    // member swapped into the old slot and the next press moves the wrong one.
    setState(() => _selectedIndex += delta);
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
    if (group == null) return;
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
    setState(() => _selectedIndex = 0);
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

    if (key == LogicalKeyboardKey.arrowUp) {
      setState(() =>
          _selectedIndex = (_selectedIndex - 1 + rows.length) % rows.length);
      ref.read(feedbackServiceProvider).tick();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      setState(() => _selectedIndex = (_selectedIndex + 1) % rows.length);
      ref.read(feedbackServiceProvider).tick();
      return KeyEventResult.handled;
    }
    final row = rows[_selectedIndex.clamp(0, rows.length - 1)];
    // [X] and [Y] reorder the selected member. The order is the setting in
    // `ordered` mode, so it needs a key of its own — going through a submenu
    // to move one row would be worse than the problem.
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
      row.onActivate();
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
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (var i = 0; i < rows.length; i++) ...[
                                if (i > 0) const SizedBox(height: 8),
                                _Row(
                                  row: rows[i],
                                  selected: i == _selectedIndex,
                                  onTap: () {
                                    setState(() => _selectedIndex = i);
                                    rows[i].onActivate();
                                  },
                                  onMoveUp: () {
                                    setState(() => _selectedIndex = i);
                                    _move(rows[i].member!, -1);
                                  },
                                  onMoveDown: () {
                                    setState(() => _selectedIndex = i);
                                    _move(rows[i].member!, 1);
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          group == null || _adding
                              ? '↑↓ · [A] · [B]'
                              : '↑↓ · [A] · [X]/[Y] ${l.sources_moveUp}/${l.sources_moveDown} · [B]',
                          style: const TextStyle(
                            color: Colors.white30,
                            fontSize: 10,
                            letterSpacing: 0.5,
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
}

class _Row extends StatelessWidget {
  const _Row({
    required this.row,
    required this.selected,
    required this.onTap,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final _GroupRow row;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  @override
  Widget build(BuildContext context) {
    final fg = row.subdued ? Colors.white54 : Colors.white;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF8B0000).withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? Colors.white : Colors.transparent,
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
            if (row.canMoveUp)
              _IconButton(icon: Icons.keyboard_arrow_up, onTap: onMoveUp),
            if (row.canMoveDown)
              _IconButton(icon: Icons.keyboard_arrow_down, onTap: onMoveDown),
            if (row.active)
              const Icon(Icons.check, size: 16, color: Color(0xFF7BC67B)),
          ],
        ),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Icon(icon, size: 20, color: Colors.white70),
      ),
    );
  }
}
