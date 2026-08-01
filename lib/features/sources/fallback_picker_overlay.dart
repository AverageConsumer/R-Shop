import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/input/input.dart';
import '../../l10n/app_localizations.dart';
import '../../models/config/source.dart';
import '../../providers/app_providers.dart';

/// Picks which source stands in for [source] when it does not answer.
///
/// The usual pair is an internal-network server and its external address, so
/// the list is simply every other source; there is no notion of "compatible"
/// to enforce, and inventing one would only get in the way.
///
/// A fallback is a temporary stand-in, not a change of preference: whichever
/// source the user selected stays selected, so the preferred one resumes on
/// its own once it is reachable again.
class FallbackPickerOverlay extends ConsumerStatefulWidget {
  const FallbackPickerOverlay({
    super.key,
    required this.source,
    required this.onClose,
  });

  final Source source;
  final VoidCallback onClose;

  @override
  ConsumerState<FallbackPickerOverlay> createState() =>
      _FallbackPickerOverlayState();
}

class _FallbackPickerOverlayState
    extends ConsumerState<FallbackPickerOverlay> {
  final FocusNode _scopeFocus = FocusNode(debugLabel: 'fallback_picker');
  int _selectedIndex = 0;

  /// Every source except this one — a source cannot stand in for itself.
  List<Source> get _candidates => ref
      .read(sourcesProvider)
      .sources
      .where((s) => s.id != widget.source.id)
      .toList();

  @override
  void initState() {
    super.initState();
    // Start on what is already set, so [A] without navigating is a no-op.
    final current = widget.source.fallbackSourceId;
    if (current != null) {
      final i = _candidates.indexWhere((s) => s.id == current);
      if (i >= 0) _selectedIndex = i + 1; // row 0 is "none"
    }
  }

  @override
  void dispose() {
    _scopeFocus.dispose();
    super.dispose();
  }

  /// Row 0 clears the fallback; rows 1..n are the candidates; last cancels.
  int get _rowCount => _candidates.length + 2;
  int get _cancelIndex => _rowCount - 1;

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowUp) {
      setState(() =>
          _selectedIndex = (_selectedIndex - 1 + _rowCount) % _rowCount);
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
    return KeyEventResult.ignored;
  }

  Future<void> _activate() async {
    if (_selectedIndex == _cancelIndex) {
      ref.read(feedbackServiceProvider).cancel();
      widget.onClose();
      return;
    }
    ref.read(feedbackServiceProvider).confirm();
    final picked =
        _selectedIndex == 0 ? null : _candidates[_selectedIndex - 1].id;
    try {
      await ref
          .read(sourcesProvider.notifier)
          .setFallbackSource(widget.source.id, picked);
    } catch (e) {
      debugPrint('FallbackPicker: setFallbackSource failed: $e');
    }
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final candidates = _candidates;
    final current = widget.source.fallbackSourceId;

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
                        l.sources_setFallback,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.source.name,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _Row(
                        icon: Icons.block,
                        title: l.sources_fallbackNone,
                        selected: _selectedIndex == 0,
                        active: current == null,
                      ),
                      for (int i = 0; i < candidates.length; i++) ...[
                        const SizedBox(height: 8),
                        _Row(
                          icon: Icons.dns_outlined,
                          title: candidates[i].name,
                          subtitle: candidates[i].hostLabel,
                          selected: _selectedIndex == i + 1,
                          active: candidates[i].id == current,
                        ),
                      ],
                      const SizedBox(height: 8),
                      _Row(
                        icon: Icons.close,
                        title: l.common_cancel,
                        selected: _selectedIndex == _cancelIndex,
                        subdued: true,
                      ),
                      const SizedBox(height: 12),
                      const Center(
                        child: Text(
                          '↑↓ navigate · [A] select · [B] back',
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

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.selected,
    this.subtitle,
    this.active = false,
    this.subdued = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool selected;
  final bool active;
  final bool subdued;

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
          if (active)
            const Icon(Icons.check, size: 16, color: Color(0xFF7BC67B)),
        ],
      ),
    );
  }
}
