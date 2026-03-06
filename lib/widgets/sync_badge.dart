import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/responsive/responsive.dart';
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
      left: rs.isSmall ? 12 : 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _LibrarySyncPill(),
          _RaSyncPill(),
        ],
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
  Timer? _dismissTimer;

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(librarySyncServiceProvider);

    ref.listen<LibrarySyncState>(librarySyncServiceProvider, (prev, next) {
      if (next.isSyncing) {
        _dismissTimer?.cancel();
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
        _dismissTimer?.cancel();
        _dismissTimer = Timer(const Duration(seconds: 6), () {
          if (mounted) setState(() => _failedSystems = const {});
        });
      }
    });

    final showSyncing = state.isSyncing;
    if (!showSyncing && _failedSystems.isEmpty) return const SizedBox.shrink();

    final rs = context.rs;
    final iconSize = rs.isSmall ? 14.0 : 16.0;

    if (showSyncing) {
      return _SyncPillContent(
        key: const ValueKey('library-syncing'),
        accentColor: Colors.cyanAccent,
        leadingIcon: _SpinningIcon(
          size: iconSize,
          icon: Icons.sync,
          color: Colors.cyanAccent,
        ),
        label: 'Syncing ${state.completedSystems}/${state.totalSystems}',
        systemName: state.currentSystem,
      );
    }

    final label = _failedSystems.length == 1
        ? '${_failedSystems.keys.first} unavailable'
        : '${_failedSystems.length} sources unavailable';

    return _SyncPillContent(
      key: const ValueKey('library-warning'),
      accentColor: Colors.amber,
      leadingIcon:
          Icon(Icons.warning_amber_rounded, size: iconSize, color: Colors.amber),
      label: label,
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
            'Achievements ${state.completedSystems}/${state.totalSystems}',
        systemName: state.currentSystem,
      );
    } else {
      pill = _SyncPillContent(
        key: const ValueKey('ra-error'),
        accentColor: Colors.redAccent,
        leadingIcon:
            Icon(Icons.error_outline, size: iconSize, color: Colors.redAccent),
        label: _lastError ?? 'RA sync failed',
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
    final fontSize = rs.isSmall ? 10.0 : 12.0;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: rs.isSmall ? 10 : 12,
        vertical: rs.isSmall ? 5 : 6,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.1),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          leadingIcon,
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints:
                BoxConstraints(maxWidth: rs.isSmall ? 200 : 300),
            child: Text(
              label,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: accentColor,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (systemName != null) ...[
            const SizedBox(width: 4),
            ConstrainedBox(
              constraints:
                  BoxConstraints(maxWidth: rs.isSmall ? 100 : 150),
              child: Text(
                systemName!,
                style: TextStyle(
                  fontSize: fontSize - 1,
                  color: Colors.grey[400],
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
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
