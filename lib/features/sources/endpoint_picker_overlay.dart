import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/input/input.dart';
import '../../l10n/app_localizations.dart';
import '../../models/config/source.dart';
import '../../providers/app_providers.dart';
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
/// Picking a route pins it — an explicit choice must not be moved by the next
/// probe. The automatic row hands the choice back ([clearEndpointOverride]),
/// which drops the pin *and* immediately moves to the fastest live route.
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

class _EndpointPickerOverlayState
    extends ConsumerState<EndpointPickerOverlay> {
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

  /// Start on whatever is in effect, so [A] with no navigation is a no-op
  /// rather than a surprise switch.
  int _initialIndex() {
    if (widget.source.endpointSelection == EndpointSelection.auto) return 0;
    final liveId = widget.source.liveEndpoint?.id;
    final i = widget.source.endpoints.indexWhere((e) => e.id == liveId);
    return i < 0 ? 0 : i + 1;
  }

  Future<void> _probe() async {
    final result = await _probeService.probeFor(widget.source);
    if (!mounted) return;
    setState(() => _results = result);
  }

  @override
  void dispose() {
    _scopeFocus.dispose();
    super.dispose();
  }

  /// Row 0 is "Automatic"; rows 1..n are the routes; then "add"; then cancel.
  int get _rowCount => widget.source.endpoints.length + 3;
  int get _addIndex => widget.source.endpoints.length + 1;
  int get _cancelIndex => _rowCount - 1;

  /// The cursor, clamped to the rows that exist *now*. Removing a route
  /// shortens the list under the cursor, and an index left dangling past the
  /// end would make [A] hit nothing at all.
  int get _sel => _selectedIndex.clamp(0, _rowCount - 1);

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _selectedIndex = (_sel - 1 + _rowCount) % _rowCount;
      });
      ref.read(feedbackServiceProvider).tick();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      setState(() => _selectedIndex = (_sel + 1) % _rowCount);
      ref.read(feedbackServiceProvider).tick();
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
    // [X] removes and [Y] edits the highlighted route. Kept off [A] so that
    // switching — the thing you do constantly — stays a single press. Both go
    // through the same methods the per-row icons call, so the two inputs can
    // never drift apart.
    if (key == LogicalKeyboardKey.gameButtonX) {
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
    final i = _sel - 1;
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
  Future<void> _editHighlighted() => _edit(_highlightedEndpoint);

  Future<void> _remove(SourceEndpoint? ep) async {
    if (ep == null) return;
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

    if (_sel == 0) {
      // Hand the choice back *and* act on it in one press: dropping the pin
      // alone would leave the source sitting on the route the user just
      // stopped asking for, which reads as the button having done nothing.
      // The probe behind this hits the cache filled when the overlay opened.
      await notifier.clearEndpointOverride(id, probe: _probeService);
    } else {
      final ep = widget.source.endpoints[_sel - 1];
      await notifier.switchEndpoint(id, ep.id, pin: true);
    }
    if (!mounted) return;
    widget.onClose();
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
                          a: HudAction(l.common_select, onTap: _activate),
                          b: HudAction(l.common_back, onTap: _close),
                          x: onRoute
                              ? HudAction(l.sources_removeRoute,
                                  onTap: _removeHighlighted)
                              : null,
                          y: onRoute
                              ? HudAction(l.sources_editRoute,
                                  onTap: _editHighlighted)
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
      for (int i = 0; i < src.endpoints.length; i++) ...[
        const SizedBox(height: 8),
        _RouteRow(
          icon: Icons.lan_outlined,
          title: _nameOf(src.endpoints[i]),
          subtitle: src.endpoints[i].addressLabel,
          monoSubtitle: true,
          status: _statusFor(src.endpoints[i], l),
          statusOk: _results?.contains(src.endpoints[i].id),
          badges: _badgesFor(src.endpoints[i], l),
          selected: _sel == i + 1,
          onTap: () => _tapRow(i + 1),
          // Touch counterparts of [Y] and [X]. Without them the only way to
          // edit or remove a route is the gamepad, because a tap on the row
          // itself switches to it and closes the overlay.
          onEdit: () {
            setState(() => _selectedIndex = i + 1);
            _edit(src.endpoints[i]);
          },
          onRemove: () {
            setState(() => _selectedIndex = i + 1);
            _remove(src.endpoints[i]);
          },
          editLabel: l.sources_editRoute,
          removeLabel: l.sources_removeRoute,
          active: src.liveEndpoint?.id == src.endpoints[i].id,
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
        icon: Icons.add,
        title: l.sources_addRoute,
        selected: _sel == _addIndex,
        onTap: () => _tapRow(_addIndex),
      ),
      const SizedBox(height: 8),
      _RouteRow(
        icon: Icons.close,
        title: l.common_cancel,
        selected: _sel == _cancelIndex,
        onTap: () => _tapRow(_cancelIndex),
        subdued: true,
      ),
    ];
  }
}

class _RouteRow extends StatelessWidget {
  const _RouteRow({
    required this.icon,
    required this.title,
    required this.selected,
    this.subtitle,
    this.monoSubtitle = false,
    this.notes = const [],
    this.status,
    this.statusOk,
    this.active = false,
    this.subdued = false,
    this.badges = const [],
    this.onTap,
    this.onEdit,
    this.onRemove,
    this.editLabel,
    this.removeLabel,
  });

  /// The overlay is gamepad-driven, but the device has a touchscreen and the
  /// list behind it answers to taps — an overlay that ignores them reads as
  /// frozen rather than as "use the buttons".
  final VoidCallback? onTap;

  /// Per-row touch equivalents of the buttons in the HUD. They sit inside the
  /// row's own [GestureDetector]; the inner detector wins the tap, so hitting
  /// the pencil does not also switch to the route.
  final VoidCallback? onEdit;
  final VoidCallback? onRemove;
  final String? editLabel;
  final String? removeLabel;

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool monoSubtitle;

  /// Extra explanatory lines, e.g. which route automatic selection would take.
  final List<String> notes;

  final String? status;
  final bool? statusOk;
  final bool selected;
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
        color: selected
            ? const Color(0xFF8B0000).withValues(alpha: 0.35)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        // Pure white border on the focused row — project-wide convention.
        border: Border.all(
          color: selected ? Colors.white : Colors.transparent,
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
          if (onEdit != null)
            _RowAction(
              icon: Icons.edit_outlined,
              tooltip: editLabel,
              onTap: onEdit!,
            ),
          if (onRemove != null)
            _RowAction(
              icon: Icons.delete_outline,
              tooltip: removeLabel,
              onTap: onRemove!,
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
  const _RowAction({required this.icon, required this.onTap, this.tooltip});

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Icon(icon, size: 18, color: Colors.white54),
        ),
      ),
    );
  }
}
