import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/responsive/responsive.dart';
import '../providers/library_providers.dart';

class SyncBadge extends ConsumerWidget {
  const SyncBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(librarySyncServiceProvider);

    if (!state.isSyncing) return const SizedBox.shrink();

    final rs = context.rs;
    final fontSize = rs.isSmall ? 10.0 : 12.0;
    final iconSize = rs.isSmall ? 14.0 : 16.0;

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
              color: Colors.cyanAccent.withValues(alpha: 0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.cyanAccent.withValues(alpha: 0.1),
                blurRadius: 8,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SpinningSyncIcon(size: iconSize),
              const SizedBox(width: 6),
              Text(
                'Syncing ${state.completedSystems}/${state.totalSystems}',
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                  color: Colors.cyanAccent,
                ),
              ),
              if (state.currentSystem != null) ...[
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
