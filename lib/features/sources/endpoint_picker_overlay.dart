import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/input/input.dart';
import '../../l10n/app_localizations.dart';
import '../../models/config/source.dart';
import '../../providers/app_providers.dart';
import '../../services/endpoint_probe_service.dart';
import 'endpoint_edit_screen.dart';

/// Lets the user pick which way to reach a source — the same RomM server over
/// the LAN or over the internet, an SMB share direct or via VPN.
///
/// Picking a route pins it: an explicit choice should not be moved by the next
/// probe. "Automatic" releases the pin and lets reachability decide again.
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

  /// null while the probe is in flight, so the UI can say "checking" rather
  /// than claiming every route is dead.
  Set<String>? _reachable;

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
    final svc = widget.probeService ?? EndpointProbeService();
    final result = await svc.reachableFor(widget.source);
    if (!mounted) return;
    setState(() => _reachable = result);
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

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _selectedIndex = (_selectedIndex - 1 + _rowCount) % _rowCount;
      });
      ref.read(feedbackServiceProvider).tick();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      setState(() => _selectedIndex = (_selectedIndex + 1) % _rowCount);
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
      ref.read(feedbackServiceProvider).cancel();
      widget.onClose();
      return KeyEventResult.handled;
    }
    // [X] removes and [Y] edits the highlighted route. Kept off [A] so that
    // switching — the thing you do constantly — stays a single press.
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
    final i = _selectedIndex - 1;
    if (i < 0 || i >= widget.source.endpoints.length) return null;
    return widget.source.endpoints[i];
  }

  Future<void> _removeHighlighted() async {
    final ep = _highlightedEndpoint;
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

  Future<void> _editHighlighted() async {
    final ep = _highlightedEndpoint;
    if (ep == null) return;
    ref.read(feedbackServiceProvider).confirm();
    widget.onClose();
    final edited = await Navigator.of(context).push<SourceEndpoint?>(
      MaterialPageRoute(
        builder: (_) => EndpointEditScreen(
          sourceType: widget.source.type,
          existingEndpoints: widget.source.endpoints,
          initial: ep,
        ),
      ),
    );
    if (edited != null) {
      await ref
          .read(sourcesProvider.notifier)
          .updateEndpoint(widget.source.id, edited);
    }
  }

  Future<void> _activate() async {
    final notifier = ref.read(sourcesProvider.notifier);
    final id = widget.source.id;

    if (_selectedIndex == _cancelIndex) {
      ref.read(feedbackServiceProvider).cancel();
      widget.onClose();
      return;
    }
    ref.read(feedbackServiceProvider).confirm();

    if (_selectedIndex == _addIndex) {
      // Close first: the editor is a route (Navigator) and leaving a
      // dialog-priority overlay mounted underneath it would keep swallowing
      // the gamepad keys the editor needs.
      widget.onClose();
      final created = await Navigator.of(context).push<SourceEndpoint?>(
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

    if (_selectedIndex == 0) {
      await notifier.setEndpointSelection(id, EndpointSelection.auto);
    } else {
      final ep = widget.source.endpoints[_selectedIndex - 1];
      await notifier.switchEndpoint(id, ep.id, pin: true);
    }
    widget.onClose();
  }

  String? _statusFor(SourceEndpoint ep, L l) {
    final reachable = _reachable;
    if (reachable == null) return l.sources_routeChecking;
    return reachable.contains(ep.id)
        ? l.sources_routeReachable
        : l.sources_routeNoAnswer;
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final src = widget.source;
    final isAuto = src.endpointSelection == EndpointSelection.auto;
    final liveId = src.liveEndpoint?.id;

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
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Routes share the source's credentials, so they only
                      // work for addresses of the *same* server. Pointing one
                      // at a different server sends the wrong token and fails
                      // with a 401 that looks like an outage. Say so here —
                      // the alternative (a second source with its own login,
                      // paired as a fallback) is not obvious otherwise.
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline,
                              size: 12, color: Colors.white38),
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
                        selected: _selectedIndex == 0,
                        active: isAuto,
                      ),
                      for (int i = 0; i < src.endpoints.length; i++) ...[
                        const SizedBox(height: 8),
                        _RouteRow(
                          icon: Icons.lan_outlined,
                          title: src.endpoints[i].label.isEmpty
                              ? src.endpoints[i].addressLabel
                              : src.endpoints[i].label,
                          subtitle: src.endpoints[i].addressLabel,
                          status: _statusFor(src.endpoints[i], l),
                          statusOk: _reachable?.contains(src.endpoints[i].id),
                          selected: _selectedIndex == i + 1,
                          active: src.endpoints[i].id == liveId,
                          badge: !isAuto && src.pinnedEndpointId == src.endpoints[i].id
                              ? l.sources_routePinned
                              : (src.endpoints[i].id == liveId
                                  ? l.sources_routeInUse
                                  : null),
                        ),
                      ],
                      if (src.endpoints.length <= 1) ...[
                        const SizedBox(height: 10),
                        Text(
                          l.sources_routeOnlyOne,
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      _RouteRow(
                        icon: Icons.add,
                        title: l.sources_addRoute,
                        selected: _selectedIndex == _addIndex,
                      ),
                      const SizedBox(height: 8),
                      _RouteRow(
                        icon: Icons.close,
                        title: l.common_cancel,
                        selected: _selectedIndex == _cancelIndex,
                        subdued: true,
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
                      const SizedBox(height: 12),
                      const Center(
                        child: Text(
                          '↑↓ navigate · [A] select · [Y] edit · [X] remove · [B] back',
                          style: TextStyle(
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
}

class _RouteRow extends StatelessWidget {
  const _RouteRow({
    required this.icon,
    required this.title,
    required this.selected,
    this.subtitle,
    this.status,
    this.statusOk,
    this.active = false,
    this.subdued = false,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? status;
  final bool? statusOk;
  final bool selected;
  final bool active;
  final bool subdued;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final fg = subdued ? Colors.white54 : Colors.white;
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
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected ? Colors.white : fg,
                          fontSize: 14,
                          fontWeight:
                              active ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          badge!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                      fontFamily: 'monospace',
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
              ),
            ),
          ],
        ],
      ),
    );
  }
}
