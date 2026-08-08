import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/responsive/responsive.dart';
import '../core/util/color_contrast.dart';
import '../l10n/app_localizations.dart';
import '../providers/app_providers.dart';
import '../providers/library_providers.dart';
import '../providers/ra_providers.dart';
import '../services/library_sync_service.dart';
import '../services/ra_sync_service.dart';

/// Top-left sync status container showing ROM library and RA sync pills.
class SyncBadge extends ConsumerWidget {
  const SyncBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rs = context.rs;

    return Positioned(
      top: rs.safeAreaTop + (rs.isSmall ? 8 : 12),
      right: rs.isSmall ? 12 : 16,
      child: DefaultTextStyle(
        style: const TextStyle(decoration: TextDecoration.none),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: const [
            _LibrarySyncPill(),
            _RaSyncPill(),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Library sync pill (cyan) — existing behavior preserved
// ---------------------------------------------------------------------------

class _LibrarySyncPill extends ConsumerStatefulWidget {
  const _LibrarySyncPill();

  @override
  ConsumerState<_LibrarySyncPill> createState() => _LibrarySyncPillState();
}

class _LibrarySyncPillState extends ConsumerState<_LibrarySyncPill> {
  Map<String, String> _failedSystems = const {};

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(librarySyncServiceProvider);
    final failoverChoice = ref.watch(activeFailoverChoiceProvider);
    final isFailoverActive = failoverChoice != null && failoverChoice.isFallback;

    ref.listen<LibrarySyncState>(librarySyncServiceProvider, (prev, next) {
      if (next.isSyncing) {
        // New sync starting — clear stale failure state
        if (_failedSystems.isNotEmpty) {
          setState(() => _failedSystems = const {});
        }
        return;
      }

      if (prev != null &&
          prev.isSyncing &&
          !next.isSyncing &&
          next.hadFailures) {
        ref.read(feedbackServiceProvider).warning();
        setState(() => _failedSystems = next.failedSystems);
      }
    });

    final showSyncing = state.isSyncing;
    final rs = context.rs;
    final iconSize = rs.isSmall ? 14.0 : 16.0;

    if (showSyncing) {
      final accent = isFailoverActive ? Colors.amberAccent : Colors.cyanAccent;
      final labelText = isFailoverActive
          ? '⚡ 備援同步中 (${state.completedSystems}/${state.totalSystems})'
          : L.of(context).sync_progress(state.completedSystems, state.totalSystems);

      return _SyncPillContent(
        key: const ValueKey('library-syncing'),
        accentColor: accent,
        leadingIcon: _SpinningIcon(
          size: iconSize,
          icon: Icons.sync,
          color: accent,
        ),
        label: labelText,
        systemName: state.currentSystem,
      );
    }

    if (isFailoverActive && _failedSystems.isEmpty) {
      return _PulsingPill(
        key: const ValueKey('library-failover-active'),
        child: _SyncPillContent(
          accentColor: Colors.amberAccent,
          leadingIcon: Icon(Icons.bolt, size: iconSize, color: Colors.amberAccent),
          label: '⚡ 備援連線中',
          systemName: failoverChoice.source?.name,
        ),
      );
    }

    if (_failedSystems.isEmpty) return const SizedBox.shrink();

    final l = L.of(context);
    final label = _failedSystems.length == 1
        ? l.sync_singleSystemFailed(_failedSystems.keys.first)
        : l.sync_multipleSystemsFailed(_failedSystems.length);

    return _PulsingPill(
      key: const ValueKey('library-error'),
      child: _SyncPillContent(
        accentColor: Colors.redAccent,
        leadingIcon:
            Icon(Icons.error_outline, size: iconSize, color: Colors.redAccent),
        label: label,
      ),
    );
  }
}

/// Slow pulse animation to draw attention to error pills.
class _PulsingPill extends StatefulWidget {
  final Widget child;
  const _PulsingPill({super.key, required this.child});

  @override
  State<_PulsingPill> createState() => _PulsingPillState();
}

class _PulsingPillState extends State<_PulsingPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.55, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: widget.child,
    );
  }
}

// ---------------------------------------------------------------------------
// RetroAchievements sync pill (golden)
// ---------------------------------------------------------------------------

const _raColor = Color(0xFFFFD54F);

class _RaSyncPill extends ConsumerStatefulWidget {
  const _RaSyncPill();

  @override
  ConsumerState<_RaSyncPill> createState() => _RaSyncPillState();
}

class _RaSyncPillState extends ConsumerState<_RaSyncPill> {
  bool _showError = false;
  String? _lastError;
  Timer? _dismissTimer;

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final raEnabled = ref.watch(raEnabledProvider);
    if (!raEnabled) return const SizedBox.shrink();

    final state = ref.watch(raSyncServiceProvider);

    ref.listen<RaSyncState>(raSyncServiceProvider, (prev, next) {
      if (next.isSyncing) {
        _dismissTimer?.cancel();
        if (_showError) setState(() => _showError = false);
        return;
      }

      if (prev != null &&
          prev.isSyncing &&
          !next.isSyncing &&
          next.error != null) {
        ref.read(feedbackServiceProvider).warning();
        setState(() {
          _showError = true;
          _lastError = next.error;
        });
        _dismissTimer?.cancel();
        _dismissTimer = Timer(const Duration(seconds: 6), () {
          if (mounted) setState(() => _showError = false);
        });
      }
    });

    final showSyncing = state.isSyncing;
    if (!showSyncing && !_showError) return const SizedBox.shrink();

    final rs = context.rs;
    final iconSize = rs.isSmall ? 14.0 : 16.0;

    final Widget pill;
    if (showSyncing) {
      pill = _SyncPillContent(
        key: const ValueKey('ra-syncing'),
        accentColor: _raColor,
        leadingIcon: _SpinningIcon(
          size: iconSize,
          icon: Icons.emoji_events,
          color: _raColor,
        ),
        label:
            L.of(context).sync_raProgress(state.completedSystems, state.totalSystems),
        systemName: state.currentSystem,
      );
    } else {
      pill = _SyncPillContent(
        key: const ValueKey('ra-error'),
        accentColor: Colors.redAccent,
        leadingIcon:
            Icon(Icons.error_outline, size: iconSize, color: Colors.redAccent),
        label: _lastError ?? L.of(context).sync_raFailed,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: pill,
    );
  }
}

// ---------------------------------------------------------------------------
// Shared pill decoration
// ---------------------------------------------------------------------------

class _SyncPillContent extends StatelessWidget {
  final Color accentColor;
  final Widget leadingIcon;
  final String label;
  final String? systemName;

  const _SyncPillContent({
    super.key,
    required this.accentColor,
    required this.leadingIcon,
    required this.label,
    this.systemName,
  });

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final fontSize = rs.isSmall ? 11.0 : 12.5;
    final fullText = (systemName != null && systemName!.isNotEmpty)
        ? '$label · $systemName'
        : label;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: rs.isSmall ? 12 : 14,
        vertical: rs.isSmall ? 5 : 7,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.6),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.2),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          leadingIcon,
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: rs.isSmall ? 360 : 480),
            child: Text(
              fullText,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                color: accentColor.forText,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Spinning icon (generalized)
// ---------------------------------------------------------------------------

class _SpinningIcon extends StatefulWidget {
  final double size;
  final IconData icon;
  final Color color;

  const _SpinningIcon({
    required this.size,
    required this.icon,
    required this.color,
  });

  @override
  State<_SpinningIcon> createState() => _SpinningIconState();
}

class _SpinningIconState extends State<_SpinningIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: Icon(
        widget.icon,
        size: widget.size,
        color: widget.color,
      ),
    );
  }
}
