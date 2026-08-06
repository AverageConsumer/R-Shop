import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/input/input.dart';
import '../../l10n/app_localizations.dart';
import '../../models/config/source.dart';
import '../../providers/app_providers.dart';
import '../../widgets/console_dialog.dart';
import '../../services/endpoint_probe_service.dart';
import '../../widgets/console_hud.dart';
import 'endpoint_edit_screen.dart';

/// Lets the user pick which way to reach a source — the same RomM server over
/// the LAN or over the internet, an SMB share direct or via VPN.
///
/// Every route is probed on its own and the result is shown as a **latency**,
/// not as a yes/no: when two routes both answer, "both reachable" is not an
/// answer to the question the user is actually asking, which is which one to
/// take. The row the machine would take on its own is named on the automatic
/// row, so leaving the choice to it is an informed decision rather than a
/// leap.
///
/// Which route goes live is decided by the two rows at the top — automatic, or
/// the order the user put the routes in — and by the lock on [X], which is the
/// one setting a probe may not move. The route rows themselves are edited, not
/// chosen: [A] on one starts moving it, the same gesture the group editor uses
/// on its members. The automatic row hands the choice back
/// ([clearEndpointOverride]), which drops the lock *and* immediately moves to
/// the fastest live route.
/// **Switching never touches cached games** — see [SourcesNotifier].
///
/// Reachability is probed fresh every time this opens rather than read from
/// cache: the user is here precisely because they want to know what works
/// *now*.
class EndpointPickerOverlay extends ConsumerStatefulWidget {
  const EndpointPickerOverlay({
    super.key,
    required this.source,
    required this.onClose,
    this.probeService,
  });

  final Source source;
  final VoidCallback onClose;

  /// Injected by tests; production builds a fresh one so results are never
  /// stale.
  final EndpointProbeService? probeService;

  @override
  ConsumerState<EndpointPickerOverlay> createState() =>
      _EndpointPickerOverlayState();
}

class _EndpointPickerOverlayState extends ConsumerState<EndpointPickerOverlay>
    with SingleTickerProviderStateMixin {
  final FocusNode _scopeFocus = FocusNode(debugLabel: 'endpoint_picker');
  int _selectedIndex = 0;

  /// One service for the whole overlay, and the same one handed to the
  /// notifier: it caches, so the automatic row does not pay for a second probe
  /// of the routes we measured a moment ago while the user watched.
  late final EndpointProbeService _probeService =
      widget.probeService ?? EndpointProbeService();

  /// null while the probe is in flight, so the UI can say "checking" rather
  /// than claiming every route is dead.
  ProbeResults? _results;

  /// Shown when an action was refused, e.g. removing the only route.
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedIndex = _initialIndex();
    _probe();
  }

  /// Start on whatever is in effect, so the first press lands on the thing the
  /// user is already using rather than on a neighbour.
  ///
  /// The route rows are offset by [_firstRouteIndex], **not by one**: the "my
  /// order" row sits between them and automatic. Counting from one put the
  /// cursor a row too high, so opening the overlay on a locked route and
  /// pressing [A] straight away switched the whole source to `ordered`.
  int _initialIndex() {
    final src = widget.source;
    if (src.endpointSelection == EndpointSelection.auto) return 0;
    if (src.endpointSelection == EndpointSelection.ordered) return _orderedIndex;
    final liveId = src.liveEndpoint?.id;
    final i = src.endpoints.indexWhere((e) => e.id == liveId);
    return i < 0 ? 0 : i + _firstRouteIndex;
  }

  Future<void> _probe() async {
    final result = await _probeService.probeFor(widget.source);
    if (!mounted) return;
    setState(() => _results = result);
  }

  @override
  void dispose() {
    _slide.dispose();
    _scopeFocus.dispose();
    super.dispose();
  }

  /// The icons on the route at [index], in the order they are drawn. One
  /// list, read by both the key handler and the row widget, so ▶ and a finger
  /// can never land on different things.
  List<_RowActionSpec> _actionsForRoute(int index) {
    final src = widget.source;
    if (index < 0 || index >= src.endpoints.length) return const [];
    final ep = src.endpoints[index];
    final l = L.of(context);
    if (_sorting && _sel - _firstRouteIndex == index) {
      // While the d-pad is moving this row the icons are the finger's version
      // of the same thing.
      return [
        if (index > 0)
          _RowActionSpec(
            icon: Icons.keyboard_arrow_up,
            label: l.sources_moveUp,
            run: () => _moveRoute(ep, -1),
          ),
        if (index < src.endpoints.length - 1)
          _RowActionSpec(
            icon: Icons.keyboard_arrow_down,
            label: l.sources_moveDown,
            run: () => _moveRoute(ep, 1),
          ),
        _RowActionSpec(
          icon: Icons.check,
          label: l.common_done,
          run: () => setState(() => _sorting = false),
        ),
      ];
    }
    return [
      _RowActionSpec(
        icon: Icons.drag_handle,
        label: l.sources_moveUp,
        run: _toggleSorting,
      ),
      _RowActionSpec(
        icon: Icons.edit_outlined,
        label: l.sources_editRoute,
        run: () => _edit(ep),
      ),
      _RowActionSpec(
        icon: Icons.delete_outline,
        label: l.sources_removeRoute,
        run: () => _remove(ep),
      ),
    ];
  }

  /// The icons on the row the cursor is on, or empty for a non-route row.
  List<_RowActionSpec> get _currentActions =>
      _actionsForRoute(_sel - _firstRouteIndex);

  Future<void> _moveRoute(SourceEndpoint ep, int delta) async {
    final from = widget.source.endpoints.indexWhere((e) => e.id == ep.id);
    final to = from + delta;
    if (from < 0 || to < 0 || to >= widget.source.endpoints.length) return;
    ref.read(feedbackServiceProvider).tick();
    final fromY = _yOf(_sel);
    await ref
        .read(sourcesProvider.notifier)
        .moveEndpointTo(widget.source.id, ep.id, to, probe: _probeService);
    if (!mounted) return;
    // Follow the row that moved, so a second press moves the same route.
    setState(() => _selectedIndex = _sel + delta);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final toY = _yOf(_sel);
      if (fromY == null || toY == null || (fromY - toY).abs() < 0.5) return;
      setState(() {
        _slidingId = ep.id;
        _slideFrom = fromY - toY;
      });
      _slide.forward(from: 0);
    });
  }

  /// Row 0 is "Automatic", row 1 is "my order"; rows 2..n+1 are the routes;
  /// then "add"; then cancel.
  ///
  /// `ordered` needs a row of its own because a route row is where the order is
  /// *edited* — putting "follow this order" on the same press as "move this
  /// route" would mean the user could not rearrange the list without also
  /// changing what the list is for.
  int get _rowCount => widget.source.endpoints.length + 4;
  int get _orderedIndex => 1;
  int get _firstRouteIndex => 2;
  int get _addIndex => widget.source.endpoints.length + 2;
  int get _cancelIndex => _rowCount - 1;

  /// Which control on the selected row has the cursor: 0 is the row itself,
  /// 1..n are the small icons at its right end (reorder, edit, remove).
  ///
  /// ▶ walks onto them, ◀ walks back. The icons were already there for a
  /// finger; this gives the pad the same target instead of a submenu.
  int _actionIndex = 0;

  /// Slides the row that just moved from where it was to where it is now —
  /// a reorder is otherwise a single frame in which two rows swap, and the
  /// list looks unchanged. Measured rather than assumed: rows carry latencies,
  /// badges and a hint line, so they are not all the same height.
  late final AnimationController _slide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );
  String? _slidingId;
  double _slideFrom = 0;

  double? _yOf(int index) {
    final ctx = _rowKeys[index]?.currentContext;
    final box = ctx?.findRenderObject() as RenderBox?;
    return box?.localToGlobal(Offset.zero).dy;
  }

  /// True while ↑↓ moves the selected route instead of the cursor.
  /// See [_toggleSorting] for who turns it on.
  bool _sorting = false;

  /// One key per row so the cursor can be scrolled into view: with four
  /// routes the list is taller than the panel, and a selection below the fold
  /// looks like the pad has stopped working.
  final Map<int, GlobalKey> _rowKeys = {};

  GlobalKey _keyFor(int index) =>
      _rowKeys.putIfAbsent(index, () => GlobalKey());

  void _scrollToSelected() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _rowKeys[_sel]?.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.5,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
      );
    });
  }

  /// The cursor, clamped to the rows that exist *now*. Removing a route
  /// shortens the list under the cursor, and an index left dangling past the
  /// end would make [A] hit nothing at all.
  int get _sel => _selectedIndex.clamp(0, _rowCount - 1);

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final sortingRoute = _sorting ? _highlightedEndpoint : null;
    if (sortingRoute != null) {
      if (key == LogicalKeyboardKey.arrowUp) {
        _moveRoute(sortingRoute, -1);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowDown) {
        _moveRoute(sortingRoute, 1);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.gameButtonA ||
          key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.select ||
          key == LogicalKeyboardKey.gameButtonB ||
          key == LogicalKeyboardKey.escape ||
          key == LogicalKeyboardKey.goBack) {
        ref.read(feedbackServiceProvider).confirm();
        setState(() => _sorting = false);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _selectedIndex = (_sel - 1 + _rowCount) % _rowCount;
        _actionIndex = 0;
        _sorting = false;
      });
      _scrollToSelected();
      ref.read(feedbackServiceProvider).tick();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _selectedIndex = (_sel + 1) % _rowCount;
        _actionIndex = 0;
        _sorting = false;
      });
      ref.read(feedbackServiceProvider).tick();
      _scrollToSelected();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.gameButtonA ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.select) {
      _activate();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.gameButtonB ||
        key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack) {
      _close();
      return KeyEventResult.handled;
    }
    // [X] locks and [Y] edits the highlighted route. Both go through the same
    // methods the per-row icons call, so the two inputs can never drift apart.
    // ▶ ◀ walk the cursor along the icons at the end of the row. Same gesture
    // as the group editor, so one habit covers both.
    final actions = _currentActions;
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
    if (key == LogicalKeyboardKey.gameButtonX) {
      _toggleLockHighlighted();
      return KeyEventResult.handled;
    }
    // Removing sits on a shoulder button, away from the two presses that get
    // used constantly, and it asks before it acts.
    if (key == LogicalKeyboardKey.gameButtonLeft1 ||
        key == LogicalKeyboardKey.gameButtonRight1) {
      _removeHighlighted();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.gameButtonY) {
      _editHighlighted();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// The route under the cursor, or null when the cursor is on a non-route row.
  SourceEndpoint? get _highlightedEndpoint {
    final i = _sel - _firstRouteIndex;
    if (i < 0 || i >= widget.source.endpoints.length) return null;
    return widget.source.endpoints[i];
  }

  void _close() {
    ref.read(feedbackServiceProvider).cancel();
    widget.onClose();
  }

  /// Touch entry point for every row: move the cursor there first, so a tap
  /// leaves the overlay in the state a gamepad user would have put it in, then
  /// run the identical activation path.
  void _tapRow(int index) {
    setState(() => _selectedIndex = index);
    _activate();
  }

  Future<void> _removeHighlighted() => _remove(_highlightedEndpoint);

  /// Locks the highlighted route, or releases the lock if it already has one.
  ///
  /// A lock is the one mode with no failover, so it is worth a press of its
  /// own rather than riding along with "use this".
  Future<void> _toggleLockHighlighted() async {
    final ep = _highlightedEndpoint;
    if (ep == null) return;
    final src = widget.source;
    final notifier = ref.read(sourcesProvider.notifier);
    ref.read(feedbackServiceProvider).confirm();
    if (src.endpointSelection == EndpointSelection.pinned &&
        src.pinnedEndpointId == ep.id) {
      await notifier.clearEndpointOverride(src.id, probe: _probeService);
    } else {
      await notifier.switchEndpoint(src.id, ep.id, pin: true);
    }
    if (mounted) setState(() {});
  }

  Future<void> _editHighlighted() => _edit(_highlightedEndpoint);


  Future<void> _remove(SourceEndpoint? ep) async {
    if (ep == null) return;
    final l = L.of(context);
    ref.read(feedbackServiceProvider).tick();
    final ok = await showConsoleDialog(
      context,
      title: l.sources_removeRoute,
      message: l.sources_removeRouteConfirm(_nameOf(ep)),
      primaryLabel: l.common_remove,
      isDestructive: true,
    );
    if (ok != true || !mounted) return;
    final removed = await ref
        .read(sourcesProvider.notifier)
        .removeEndpoint(widget.source.id, ep.id);
    if (!mounted) return;
    if (!removed) {
      // Refused: this is the last route, and a source with no address is
      // unusable. Say so rather than appearing to ignore the press.
      ref.read(feedbackServiceProvider).cancel();
      setState(() => _error = L.of(context).sources_routeCannotRemoveLast);
      return;
    }
    ref.read(feedbackServiceProvider).confirm();
    setState(() {
      _error = null;
      if (_selectedIndex >= _rowCount - 1) _selectedIndex = 0;
    });
  }

  Future<void> _edit(SourceEndpoint? ep) async {
    if (ep == null) return;
    ref.read(feedbackServiceProvider).confirm();
    final notifier = ref.read(sourcesProvider.notifier);
    final navigator = Navigator.of(context);
    widget.onClose();
    final edited = await navigator.push<SourceEndpoint?>(
      MaterialPageRoute(
        builder: (_) => EndpointEditScreen(
          sourceType: widget.source.type,
          existingEndpoints: widget.source.endpoints,
          initial: ep,
        ),
      ),
    );
    if (edited != null) {
      await notifier.updateEndpoint(widget.source.id, edited);
    }
  }

  Future<void> _activate() async {
    // The cursor may be on one of the row's icons rather than on the row.
    final actions = _currentActions;
    if (_actionIndex > 0 && _actionIndex <= actions.length) {
      ref.read(feedbackServiceProvider).confirm();
      actions[_actionIndex - 1].run();
      return;
    }

    final notifier = ref.read(sourcesProvider.notifier);
    final id = widget.source.id;

    if (_sel == _cancelIndex) {
      _close();
      return;
    }
    ref.read(feedbackServiceProvider).confirm();

    if (_sel == _addIndex) {
      // Close first: the editor is a route (Navigator) and leaving a
      // dialog-priority overlay mounted underneath it would keep swallowing
      // the gamepad keys the editor needs.
      final navigator = Navigator.of(context);
      widget.onClose();
      final created = await navigator.push<SourceEndpoint?>(
        MaterialPageRoute(
          builder: (_) => EndpointEditScreen(
            sourceType: widget.source.type,
            existingEndpoints: widget.source.endpoints,
          ),
        ),
      );
      if (created != null) {
        await notifier.addEndpoint(id, created);
      }
      return;
    }

    // The two mode rows **stay open**. They are a setting, not a destination:
    // closing on the press hides the very thing the press was for — which
    // route went live, and which badge moved onto it. Picking a route is the
    // opposite: it is an override, the question is answered, so it closes.
    if (_sel == 0) {
      // Hand the choice back *and* act on it in one press: dropping the pin
      // alone would leave the source sitting on the route the user just
      // stopped asking for, which reads as the button having done nothing.
      // The probe behind this hits the cache filled when the overlay opened.
      await notifier.clearEndpointOverride(id, probe: _probeService);
      if (mounted) setState(() {});
      return;
    }
    if (_sel == _orderedIndex) {
      await notifier.useOrderedSelection(id, probe: _probeService);
      if (mounted) setState(() {});
      return;
    }
    // [A] on a route starts moving it, exactly as it does on a group member:
    // one habit edits both lists. It is deliberately **not** "use this one".
    // Switching without a lock never stuck — the next probe was free to move
    // off it again, and the user read that as the press having been undone.
    // The three things a route can be put through are: the order (here),
    // the lock ([X]), and edit/remove on the icons at its end.
    _toggleSorting();
  }

  /// Enters the mode where ↑↓ move the highlighted route, and leaves it again.
  ///
  /// Reordering is repetitive, so it gets the whole d-pad rather than a press
  /// per step. Shared by [A] and by the ≡ handle, so the pad and a finger can
  /// never end up in different states.
  void _toggleSorting() {
    setState(() {
      _sorting = !_sorting;
      // The icons swap to arrows, so the cursor must not stay in whichever
      // slot it happened to be in.
      _actionIndex = 0;
    });
  }

  /// What one route's probe said: a latency, an explicit "no answer", or
  /// "checking" while the probe is still out.
  String _statusFor(SourceEndpoint ep, L l) {
    final results = _results;
    if (results == null) return l.sources_routeChecking;
    final latency = results.latencyOf(ep.id);
    if (latency == null) return l.sources_routeNoAnswer;
    return l.sources_routeLatencyMs(latency.inMilliseconds);
  }

  /// Which route automatic selection would take, named rather than implied.
  String _autoOutcome(L l) {
    final results = _results;
    if (results == null) return l.sources_routeChecking;
    final fastest = results.fastestId;
    if (fastest == null) return l.sources_routeAutoNoneReachable;
    final ep = widget.source.endpointById(fastest);
    return l.sources_routeAutoPicks(ep == null ? fastest : _nameOf(ep));
  }

  String _nameOf(SourceEndpoint ep) =>
      ep.label.isEmpty ? ep.addressLabel : ep.label;

  List<String> _badgesFor(SourceEndpoint ep, L l) {
    final src = widget.source;
    final isAuto = src.endpointSelection == EndpointSelection.auto;
    return [
      if (!isAuto && src.pinnedEndpointId == ep.id) l.sources_routePinned,
      if (src.liveEndpoint?.id == ep.id) l.sources_routeInUse,
      if (_results?.fastestId == ep.id) l.sources_routeFastest,
      // A route with its own credentials is worth calling out: it is the one
      // that will keep working when the source's login is rotated, and the one
      // to look at when only this address returns 401.
      if (ep.hasOwnAuth) l.sources_routeOwnLogin,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final src = widget.source;
    final isAuto = src.endpointSelection == EndpointSelection.auto;
    final onRoute = _highlightedEndpoint != null;

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
                constraints: const BoxConstraints(maxWidth: 420),
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
                      // Scrollable so latencies, badges and a fourth route can
                      // be added without painting the yellow overflow stripe
                      // on a 3.92" screen. The hints below stay pinned.
                      Flexible(
                        child: SingleChildScrollView(
                          // The hint row below is pinned, so the last list row
                          // sat underneath it. Padding, not a shorter list:
                          // the row has to be reachable *and* readable.
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: _rows(l, src, isAuto),
                          ),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          _error!,
                          style: const TextStyle(
                            color: Color(0xFFE57373),
                            fontSize: 11,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      // D-pad arrows are the same glyphs on every layout, so
                      // they can be written out; the face buttons cannot, and
                      // [ConsoleHud] draws those as the icons of whichever
                      // layout is configured. A bare letter would name the
                      // wrong physical button on two of the three.
                      Text(
                        '↑↓  ${l.common_navigate}',
                        style: const TextStyle(
                          color: Colors.white30,
                          fontSize: 10,
                          letterSpacing: 0.5,
                        ),
                      ),
                      // Scaled down rather than allowed to overflow: four
                      // hints with localised labels are wider than the panel
                      // on a 3.92" screen, and an overflowing HUD paints the
                      // yellow stripe over the row above it.
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: ConsoleHud(
                          embedded: true,
                          a: HudAction(
                            _sorting ? l.common_done : l.common_select,
                            onTap: _activate,
                          ),
                          b: HudAction(l.common_back, onTap: _close),
                          x: onRoute
                              ? HudAction(
                                  widget.source.endpointSelection ==
                                              EndpointSelection.pinned &&
                                          widget.source.pinnedEndpointId ==
                                              _highlightedEndpoint?.id
                                      ? l.sources_routeUnlock
                                      : l.sources_routeLock,
                                  onTap: _toggleLockHighlighted)
                              : null,
                          y: onRoute
                              ? HudAction(l.sources_editRoute,
                                  onTap: _editHighlighted)
                              : null,
                          rb: onRoute
                              ? HudAction(l.sources_removeRoute,
                                  onTap: _removeHighlighted)
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

  List<Widget> _rows(L l, Source src, bool isAuto) {
    return [
      Text(
        l.sources_connectionRoute,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        src.name,
        style: const TextStyle(color: Colors.white54, fontSize: 12),
      ),
      const SizedBox(height: 8),
      // Routes are addresses of one server, and each may want its own login —
      // which is why a route that asks you to sign in again is no longer a
      // reason to split the source in two.
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 12, color: Colors.white38),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              l.sources_routeSameServerHint,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 10,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      _RouteRow(
        key: _keyFor(0),
        icon: Icons.auto_mode,
        title: l.sources_routeAuto,
        subtitle: l.sources_routeAutoHint,
        notes: [
          _autoOutcome(l),
          if (!isAuto) l.sources_routeReleasePin,
        ],
        badges: [if (isAuto) l.sources_routeInUse],
        selected: _sel == 0,
        onTap: () => _tapRow(0),
        active: isAuto,
      ),
      const SizedBox(height: 8),
      _RouteRow(
        key: _keyFor(_orderedIndex),
        icon: Icons.format_list_numbered,
        title: l.sources_routeOrdered,
        subtitle: l.sources_routeOrderedHint,
        badges: [
          if (src.endpointSelection == EndpointSelection.ordered)
            l.sources_routeInUse
        ],
        selected: _sel == _orderedIndex,
        onTap: () => _tapRow(_orderedIndex),
        active: src.endpointSelection == EndpointSelection.ordered,
      ),
      for (int i = 0; i < src.endpoints.length; i++) ...[
        const SizedBox(height: 8),
        _SlideIn(
          controller: _slide,
          from: src.endpoints[i].id == _slidingId ? _slideFrom : 0,
          child: _RouteRow(
          key: _keyFor(i + _firstRouteIndex),
          icon: Icons.lan_outlined,
          title: _nameOf(src.endpoints[i]),
          subtitle: src.endpoints[i].addressLabel,
          monoSubtitle: true,
          notes: [
            _sorting && _sel == i + _firstRouteIndex
                ? l.sources_reorderHint
                : l.sources_routeRowHint,
          ],
          status: _statusFor(src.endpoints[i], l),
          statusOk: _results?.contains(src.endpoints[i].id),
          badges: _badgesFor(src.endpoints[i], l),
          selected: _sel == i + _firstRouteIndex,
          sorting: _sorting && _sel == i + _firstRouteIndex,
          onTap: () => _tapRow(i + _firstRouteIndex),
          actions: _actionsForRoute(i),
          focusedAction:
              _sel == i + _firstRouteIndex ? _actionIndex : 0,
          onAction: (a) {
            setState(() {
              _selectedIndex = i + _firstRouteIndex;
              _actionIndex = 0;
                    });
            a.run();
          },
          // Touch counterpart of ◀ ▶.
          active: src.liveEndpoint?.id == src.endpoints[i].id,
        ),
        ),
      ],
      if (src.endpoints.length <= 1) ...[
        const SizedBox(height: 10),
        Text(
          l.sources_routeOnlyOne,
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
      ],
      const SizedBox(height: 8),
      _RouteRow(
        key: _keyFor(_addIndex),
        icon: Icons.add,
        title: l.sources_addRoute,
        selected: _sel == _addIndex,
        onTap: () => _tapRow(_addIndex),
      ),
      const SizedBox(height: 8),
      _RouteRow(
        // Keyed like every other row: without it, wrapping from the top row
        // to this one scrolled nowhere and the cursor simply vanished below
        // the fold.
        key: _keyFor(_cancelIndex),
        icon: Icons.close,
        title: l.common_cancel,
        selected: _sel == _cancelIndex,
        onTap: () => _tapRow(_cancelIndex),
        subdued: true,
      ),
    ];
  }
}

/// One icon at the right end of a route row: a target the cursor can land on
/// with ▶ and a finger can hit directly.
class _RowActionSpec {
  const _RowActionSpec({
    required this.icon,
    required this.label,
    required this.run,
  });

  final IconData icon;
  final String label;
  final VoidCallback run;
}

class _RouteRow extends StatelessWidget {
  const _RouteRow({
    super.key,
    required this.icon,
    required this.title,
    required this.selected,
    this.sorting = false,
    this.subtitle,
    this.monoSubtitle = false,
    this.notes = const [],
    this.status,
    this.statusOk,
    this.active = false,
    this.subdued = false,
    this.badges = const [],
    this.onTap,
    this.actions = const [],
    this.focusedAction = 0,
    this.onAction,
  });

  /// The overlay is gamepad-driven, but the device has a touchscreen and the
  /// list behind it answers to taps — an overlay that ignores them reads as
  /// frozen rather than as "use the buttons".
  final VoidCallback? onTap;

  /// Icons at the right end: reorder, edit, remove. 0 means the cursor is on
  /// the row body; 1..n put it on one of these. The pad walks them with ▶ ◀
  /// and a finger hits them directly, so both inputs reach the same set.
  final List<_RowActionSpec> actions;
  final int focusedAction;
  final void Function(_RowActionSpec action)? onAction;

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool monoSubtitle;

  /// Extra explanatory lines, e.g. which route automatic selection would take.
  final List<String> notes;

  final String? status;
  final bool? statusOk;
  final bool selected;

  /// True while the d-pad is moving this row rather than the cursor. Its own
  /// colour, because "where I am" and "what I am dragging" are two states.
  final bool sorting;
  final bool active;
  final bool subdued;

  /// Badges wrap onto their own line rather than sharing the title's row:
  /// three of them beside a long label is exactly how a RenderFlex overflow
  /// gets onto a 3.92" screen.
  final List<String> badges;

  @override
  Widget build(BuildContext context) {
    final fg = subdued ? Colors.white54 : Colors.white;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: _body(fg),
    );
  }

  Widget _body(Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: sorting
            ? const Color(0xFFB8860B).withValues(alpha: 0.35)
            : selected
                ? const Color(0xFF8B0000).withValues(alpha: 0.35)
                : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        // Pure white border on the focused row — project-wide convention.
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
          Icon(icon, size: 18, color: selected ? Colors.white : fg),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? Colors.white : fg,
                    fontSize: 14,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
                if (badges.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [for (final b in badges) _Badge(b)],
                    ),
                  ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                      fontFamily: monoSubtitle ? 'monospace' : null,
                    ),
                  ),
                for (final note in notes)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      note,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                        height: 1.3,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (status != null) ...[
            const SizedBox(width: 8),
            Text(
              status!,
              style: TextStyle(
                color: statusOk == null
                    ? Colors.white38
                    : (statusOk! ? const Color(0xFF7BC67B) : Colors.white38),
                fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
          ],
          for (var i = 0; i < actions.length; i++)
            _RowAction(
              icon: actions[i].icon,
              tooltip: actions[i].label,
              focused: focusedAction == i + 1,
              onTap: () => onAction?.call(actions[i]),
            ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// A tap target inside a row. Sized well past the icon so a thumb on a 3.92"
/// screen can hit it without hitting the row.
class _RowAction extends StatelessWidget {
  const _RowAction({
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.focused = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  /// True when ▶ has walked the cursor onto this icon. It gets the same white
  /// ring the rows use, so "where am I" has one answer everywhere.
  final bool focused;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(left: 2),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
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
            icon,
            size: 18,
            color: focused ? Colors.white : Colors.white54,
          ),
        ),
      ),
    );
  }
}

/// Slides [child] in from [from] pixels away from its final position. Twin of
/// the one in `group_picker_overlay.dart`; both exist because only the row
/// that moved is animated and neither list is long enough to justify a
/// reorderable list widget.
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
        offset:
            Offset(0, from * (1 - Curves.easeOut.transform(controller.value))),
        child: inner,
      ),
      child: child,
    );
  }
}
