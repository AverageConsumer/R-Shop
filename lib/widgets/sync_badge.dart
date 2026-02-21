import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/responsive/responsive.dart';
import '../providers/library_providers.dart';
import '../services/library_sync_service.dart';

class SyncBadge extends ConsumerStatefulWidget {
  const SyncBadge({super.key});

  @override
  ConsumerState<SyncBadge> createState() => _SyncBadgeState();
}

class _SyncBadgeState extends ConsumerState<SyncBadge> {
  bool _showOffline = false;
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
      // Sync started → cancel any pending offline toast
      if (next.isSyncing) {
        _dismissTimer?.cancel();
        if (_showOffline) setState(() => _showOffline = false);
        return;
      }

      // Transition: syncing → done with failures
      if (prev != null && prev.isSyncing && !next.isSyncing && next.hadFailures) {
        setState(() => _showOffline = true);
        _dismissTimer?.cancel();
        _dismissTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) setState(() => _showOffline = false);
        });
      }
    });

    final showSyncing = state.isSyncing;

    if (!showSyncing && !_showOffline) return const SizedBox.shrink();

    final rs = context.rs;
    final fontSize = rs.isSmall ? 10.0 : 12.0;
    final iconSize = rs.isSmall ? 14.0 : 16.0;

    final Color accentColor;
    final Widget leadingIcon;
    final String label;

    if (showSyncing) {
      accentColor = Colors.cyanAccent;
      leadingIcon = _SpinningSyncIcon(size: iconSize);
      label = 'Syncing ${state.completedSystems}/${state.totalSystems}';
    } else {
      accentColor = Colors.amber;
      leadingIcon = Icon(Icons.cloud_off, size: iconSize, color: Colors.amber);
      label = 'Offline — cached data';
    }

    return Positioned(
      top: rs.safeAreaTop + (rs.isSmall ? 8 : 12),
      left: rs.isSmall ? 12 : 16,
      child: AnimatedOpacity(
        opacity: 1.0,
        duration: const Duration(milliseconds: 300),
        child: Container(
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
              Text(
                label,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                  color: accentColor,
                ),
              ),
              if (showSyncing && state.currentSystem != null) ...[
                const SizedBox(width: 4),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: rs.isSmall ? 100 : 150),
                  child: Text(
                    state.currentSystem!,
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
        ),
      ),
    );
  }
}

class _SpinningSyncIcon extends StatefulWidget {
  final double size;

  const _SpinningSyncIcon({required this.size});

  @override
  State<_SpinningSyncIcon> createState() => _SpinningSyncIconState();
}

class _SpinningSyncIconState extends State<_SpinningSyncIcon>
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
        Icons.sync,
        size: widget.size,
        color: Colors.cyanAccent,
      ),
    );
  }
}
