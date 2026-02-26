import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/input/overlay_scope.dart';
import '../core/responsive/responsive.dart';
import '../models/download_item.dart';
import '../providers/app_providers.dart';
import '../providers/download_providers.dart';
import '../services/download_queue_manager.dart';
import '../services/input_debouncer.dart';
import '../widgets/console_hud.dart';
import 'download/download_item_card.dart';
import 'download/low_space_warning.dart';
import 'download/pulsing_dot.dart';

final downloadOverlayExpandedProvider = StateProvider<bool>((ref) => false);

void toggleDownloadOverlay(WidgetRef ref) {
  final current = ref.read(downloadOverlayExpandedProvider);
  ref.read(downloadOverlayExpandedProvider.notifier).state = !current;
}

class DownloadOverlay extends ConsumerStatefulWidget {
  const DownloadOverlay({super.key});

  @override
  ConsumerState<DownloadOverlay> createState() => _DownloadOverlayState();
}

class _DownloadOverlayState extends ConsumerState<DownloadOverlay> {
  ProviderSubscription<DownloadQueueManager>? _queueSubscription;

  @override
  void initState() {
    super.initState();
    // Auto-close modal when queue becomes empty while expanded
    _queueSubscription = ref.listenManual(downloadQueueManagerProvider, (prev, next) {
      if (!mounted) return;
      final isExpanded = ref.read(downloadOverlayExpandedProvider);
      if (next.state.isEmpty && isExpanded) {
        ref.read(downloadOverlayExpandedProvider.notifier).state = false;
        final priority = ref.read(overlayPriorityProvider);
        if (priority == OverlayPriority.downloadModal) {
          ref.read(overlayPriorityProvider.notifier)
              .releaseByPriority(OverlayPriority.downloadModal);
        }
        restoreMainFocus(ref);
      }
    });
  }

  @override
  void dispose() {
    _queueSubscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isExpanded = ref.watch(downloadOverlayExpandedProvider);
    final queueState = ref.watch(downloadQueueManagerProvider).state;

    if (queueState.isEmpty) {
      return const SizedBox.shrink();
    }

    final activeDownloads = queueState.activeDownloads;
    final queuedItems = queueState.queuedItems;

    if (isExpanded) {
      return _DownloadModal(
        activeDownloads: activeDownloads,
        queuedItems: queuedItems,
        recentItems: queueState.recentItems,
      );
    }

    return _DownloadBadge(
      activeDownloads: activeDownloads,
      queuedItems: queuedItems,
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
//  BADGE – pulsing mini-badge with animated progress ring
// ──────────────────────────────────────────────────────────────────────────────

class _DownloadBadge extends ConsumerStatefulWidget {
  final List<DownloadItem> activeDownloads;
  final List<DownloadItem> queuedItems;

  const _DownloadBadge({
    required this.activeDownloads,
    required this.queuedItems,
  });

  @override
  ConsumerState<_DownloadBadge> createState() => _DownloadBadgeState();
}

class _DownloadBadgeState extends ConsumerState<_DownloadBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.activeDownloads.isNotEmpty) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_DownloadBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeDownloads.isNotEmpty && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (widget.activeDownloads.isEmpty && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.value = 0.0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final hasActive = widget.activeDownloads.isNotEmpty;
    final totalActive = widget.activeDownloads.length + widget.queuedItems.length;
    final avgProgress = widget.activeDownloads.isEmpty
        ? 0.0
        : widget.activeDownloads.map((d) => d.progress).reduce((a, b) => a + b) /
            widget.activeDownloads.length;

    final badgeSize = rs.isSmall ? 52.0 : 60.0;

    return Positioned(
      left: rs.spacing.lg,
      top: rs.safeAreaTop + rs.spacing.md,
      child: GestureDetector(
        onTap: () => toggleDownloadOverlay(ref),
        child: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            final glowAlpha = hasActive ? _pulseAnimation.value * 0.5 : 0.0;
            return Container(
              width: badgeSize,
              height: badgeSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0D0D0D),
                border: Border.all(
                  color: hasActive
                      ? Colors.green.withValues(alpha: 0.5 + _pulseAnimation.value * 0.3)
                      : Colors.white.withValues(alpha: 0.15),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.7),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                  if (hasActive)
                    BoxShadow(
                      color: Colors.green.withValues(alpha: glowAlpha),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (hasActive)
                    SizedBox(
                      width: badgeSize - 8,
                      height: badgeSize - 8,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: avgProgress),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeInOut,
                        builder: (context, value, _) => CircularProgressIndicator(
                          value: value,
                          strokeWidth: 2.5,
                          backgroundColor: Colors.white.withValues(alpha: 0.08),
                          valueColor: AlwaysStoppedAnimation(
                            Colors.green.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    ),
                  Material(
                    type: MaterialType.transparency,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          hasActive ? Icons.downloading_rounded : Icons.download_done_rounded,
                          size: rs.isSmall ? 18 : 22,
                          color: hasActive ? Colors.green : Colors.white54,
                        ),
                        Text(
                          '$totalActive',
                          style: TextStyle(
                            color: hasActive ? Colors.green : Colors.white70,
                            fontSize: rs.isSmall ? 10 : 12,
                            fontWeight: FontWeight.w700,
                            height: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
//  MODAL – fullscreen console-style download panel
// ──────────────────────────────────────────────────────────────────────────────

class _DownloadModal extends ConsumerStatefulWidget {
  final List<DownloadItem> activeDownloads;
  final List<DownloadItem> queuedItems;
  final List<DownloadItem> recentItems;

  const _DownloadModal({
    required this.activeDownloads,
    required this.queuedItems,
    required this.recentItems,
  });

  @override
  ConsumerState<_DownloadModal> createState() => _DownloadModalState();
}

class _DownloadModalState extends ConsumerState<_DownloadModal>
    with TickerProviderStateMixin {
  late AnimationController _panelController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late InputDebouncer _debouncer;
  String? _focusedItemId;
  String? _hoveredItemId;

  // HUD fade when focused item overlaps the button bar
  final GlobalKey _hudKey = GlobalKey();
  bool _hudFaded = false;

  // Stagger animation
  late AnimationController _staggerController;

  // GlobalKeys for auto-scroll (keyed by item ID)
  final Map<String, GlobalKey> _itemKeys = {};

  final FocusNode _modalFocusNode = FocusNode(debugLabel: 'DownloadModal');

  /// Flat list of all focusable items: active → queued → finished
  List<DownloadItem> get _allItems {
    final finished = widget.recentItems.where((i) => i.isFinished).toList();
    return [...widget.activeDownloads, ...widget.queuedItems, ...finished];
  }

  /// Returns the index of [id] in [items], or -1 if not found.
  int _indexOfId(String? id, List<DownloadItem> items) {
    if (id == null) return -1;
    return items.indexWhere((item) => item.id == id);
  }

  /// Returns the effective focused index, resetting to first item if the
  /// tracked ID is no longer in the list.
  int _effectiveFocusedIndex(List<DownloadItem> items) {
    if (items.isEmpty) return 0;
    final idx = _indexOfId(_focusedItemId, items);
    if (idx >= 0) return idx;
    // ID gone (item removed/moved) → reset to first item
    _focusedItemId = items.first.id;
    return 0;
  }

  @override
  void initState() {
    super.initState();
    _debouncer = InputDebouncer();

    // Panel enter animation
    _panelController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _panelController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _panelController,
      curve: Curves.easeOutCubic,
    ));

    // Stagger controller for list items
    _staggerController = AnimationController(
      duration: Duration(
        milliseconds: 300 + (widget.recentItems.length * 60).clamp(0, 600),
      ),
      vsync: this,
    );

    // Initialize focused ID to first item
    final items = _allItems;
    if (items.isNotEmpty) {
      _focusedItemId = items.first.id;
    }

    _panelController.forward();
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _staggerController.forward();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _modalFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _modalFocusNode.dispose();
    _panelController.dispose();
    _staggerController.dispose();
    _debouncer.dispose();
    super.dispose();
  }

  void _close() {
    if (!mounted) return;
    _staggerController.reverse();
    _panelController.reverse().then((_) {
      if (!mounted) return;
      ref.read(downloadOverlayExpandedProvider.notifier).state = false;
      restoreMainFocus(ref);
    });
  }

  @override
  void didUpdateWidget(_DownloadModal oldWidget) {
    super.didUpdateWidget(oldWidget);
    final items = _allItems;
    // If focused item was removed, _effectiveFocusedIndex resets it
    _effectiveFocusedIndex(items);
    // Clear hovered item if it no longer exists
    if (_hoveredItemId != null && _indexOfId(_hoveredItemId, items) < 0) {
      _hoveredItemId = null;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkHudOverlap();
    });
  }

  void _checkHudOverlap() {
    final hudBox = _hudKey.currentContext?.findRenderObject() as RenderBox?;
    final targetId = _hoveredItemId ?? _focusedItemId;
    final itemKey = _itemKeys[targetId];
    final itemBox = itemKey?.currentContext?.findRenderObject() as RenderBox?;
    if (hudBox == null || itemBox == null) {
      if (_hudFaded) setState(() => _hudFaded = false);
      return;
    }
    final hudRect = hudBox.localToGlobal(Offset.zero) & hudBox.size;
    final itemRect = itemBox.localToGlobal(Offset.zero) & itemBox.size;
    final overlaps = hudRect.overlaps(itemRect);
    if (overlaps != _hudFaded) setState(() => _hudFaded = overlaps);
  }

  void _scrollToFocused() {
    final key = _itemKeys[_focusedItemId];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        alignment: 0.3,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkHudOverlap();
    });
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.gameButtonB ||
        key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.backspace) {
      if (!_debouncer.canPerformAction()) return KeyEventResult.handled;
      _close();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.gameButtonA ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.space) {
      if (!_debouncer.canPerformAction()) return KeyEventResult.handled;
      final items = _allItems;
      final targetId = _hoveredItemId ?? _focusedItemId;
      final targetIdx = _indexOfId(targetId, items);
      if (targetIdx >= 0) {
        _performAction(items[targetIdx]);
      }
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.gameButtonY) {
      if (!_debouncer.canPerformAction()) return KeyEventResult.handled;
      ref.read(downloadQueueManagerProvider).clearCompleted();
      return KeyEventResult.handled;
    }

    final items = _allItems;
    final focusedIdx = _effectiveFocusedIndex(items);
    if (key == LogicalKeyboardKey.arrowDown) {
      if (focusedIdx < items.length - 1) {
        setState(() => _focusedItemId = items[focusedIdx + 1].id);
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToFocused());
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      if (focusedIdx > 0) {
        setState(() => _focusedItemId = items[focusedIdx - 1].id);
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToFocused());
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final items = _allItems;

    return OverlayFocusScope(
      priority: OverlayPriority.downloadModal,
      isVisible: true,
      onClose: _close,
      child: Stack(
        children: [
          Focus(
        focusNode: _modalFocusNode,
        onKeyEvent: _handleKeyEvent,
        autofocus: true,
        child: GestureDetector(
          onTap: _close,
          child: Material(
            color: Colors.transparent,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF0A0A0A),
                      Color(0xFF111111),
                      Color(0xFF0D0D0D),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: GestureDetector(
                      onTap: () {}, // block tap-through
                      child: Column(
                        children: [
                          _buildHeader(rs),
                          LowSpaceWarning(items: items),
                          Expanded(child: _buildSectionedList(rs, items)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      _buildControls(items),
    ]));
  }

  Widget _buildControls(List<DownloadItem> items) {
    final targetId = _hoveredItemId ?? _focusedItemId;
    final targetIdx = _indexOfId(targetId, items);
    final targetItem = targetIdx >= 0 ? items[targetIdx] : null;
    final hasFinished = items.any((i) => i.isFinished);

    final HudAction? aAction;
    if (targetItem != null) {
      final label = targetItem.isActive
          ? 'Cancel'
          : targetItem.isFailed
              ? 'Retry'
              : targetItem.status == DownloadItemStatus.queued
                  ? 'Remove'
                  : 'Clear';
      aAction = HudAction(label, onTap: () => _performAction(targetItem));
    } else {
      aAction = null;
    }

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        child: AnimatedOpacity(
          opacity: _hudFaded ? 0.15 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: ConsoleHud(
            key: _hudKey,
            a: aAction,
            b: HudAction('Close', onTap: _close),
            y: hasFinished
                ? HudAction('Clear Done', onTap: () {
                    ref.read(downloadQueueManagerProvider).clearCompleted();
                  })
                : null,
            embedded: true,
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Responsive rs) {
    final activeCount =
        widget.activeDownloads.length + widget.queuedItems.length;

    return Container(
      padding: EdgeInsets.fromLTRB(
        rs.spacing.xl,
        rs.spacing.lg,
        rs.spacing.xl,
        rs.spacing.md,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: Row(
        children: [
          // Animated status dot
          PulsingDot(isActive: widget.activeDownloads.isNotEmpty),
          SizedBox(width: rs.spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Downloads',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: rs.isSmall ? 22 : 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                if (activeCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '$activeCount active',
                      style: TextStyle(
                        color: Colors.green.withValues(alpha: 0.8),
                        fontSize: rs.isSmall ? 12 : 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _close,
            child: Container(
              width: rs.isSmall ? 36 : 42,
              height: rs.isSmall ? 36 : 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: Icon(
                Icons.close_rounded,
                color: Colors.white54,
                size: rs.isSmall ? 18 : 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionedList(Responsive rs, List<DownloadItem> allItems) {
    if (allItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_done_rounded,
              color: Colors.white.withValues(alpha: 0.15),
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'No downloads',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: rs.isSmall ? 16 : 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    // Build flat widget list with section headers
    final widgets = <Widget>[];
    final seenIds = <String>{};
    int itemIndex = 0;

    // Section: DOWNLOADING
    if (widget.activeDownloads.isNotEmpty) {
      widgets.add(_buildSectionHeader('Downloading', rs));
      for (final item in widget.activeDownloads) {
        _itemKeys.putIfAbsent(item.id, () => GlobalKey());
        seenIds.add(item.id);
        widgets.add(_buildCard(item, itemIndex, rs));
        itemIndex++;
      }
    }

    // Section: QUEUED
    if (widget.queuedItems.isNotEmpty) {
      widgets.add(_buildSectionHeader('Queued', rs));
      for (final item in widget.queuedItems) {
        _itemKeys.putIfAbsent(item.id, () => GlobalKey());
        seenIds.add(item.id);
        widgets.add(_buildCard(item, itemIndex, rs));
        itemIndex++;
      }
    }

    // Section: COMPLETE (includes completed, failed, cancelled)
    final finishedItems = widget.recentItems.where((i) => i.isFinished).toList();
    if (finishedItems.isNotEmpty) {
      widgets.add(_buildSectionHeader('Complete', rs));
      for (final item in finishedItems) {
        _itemKeys.putIfAbsent(item.id, () => GlobalKey());
        seenIds.add(item.id);
        widgets.add(_buildCard(item, itemIndex, rs));
        itemIndex++;
      }
    }

    // Remove stale keys for items that no longer exist
    _itemKeys.removeWhere((key, _) => !seenIds.contains(key));

    return ListView(
      padding: EdgeInsets.fromLTRB(
        rs.spacing.lg,
        rs.spacing.sm,
        rs.spacing.lg,
        rs.spacing.xxl,
      ),
      children: widgets,
    );
  }

  Widget _buildSectionHeader(String label, Responsive rs) {
    return Padding(
      padding: EdgeInsets.only(
        top: rs.spacing.lg,
        bottom: rs.spacing.sm,
        left: rs.spacing.xs,
      ),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: rs.isSmall ? 10 : 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
          SizedBox(width: rs.spacing.md),
          Expanded(
            child: Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.06),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(DownloadItem item, int index, Responsive rs) {
    final totalItems = _allItems.length;
    final itemDelay = (index / max(totalItems, 1)).clamp(0.0, 1.0);
    final itemEnd = ((index + 1) / max(totalItems, 1)).clamp(0.0, 1.0);

    final itemAnimation = CurvedAnimation(
      parent: _staggerController,
      curve: Interval(
        itemDelay * 0.6,
        0.4 + itemEnd * 0.6,
        curve: Curves.easeOutCubic,
      ),
    );

    return FadeTransition(
      key: _itemKeys[item.id],
      opacity: itemAnimation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.15),
          end: Offset.zero,
        ).animate(itemAnimation),
        child: DownloadItemCard(
          item: item,
          index: index,
          isFocused: item.id == _focusedItemId,
          isHovered: item.id == _hoveredItemId,
          onTap: () => _performAction(item),
          onHover: (isHovering) {
            setState(() => _hoveredItemId = isHovering ? item.id : null);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _checkHudOverlap();
            });
          },
        ),
      ),
    );
  }

  void _performAction(DownloadItem item) {
    if (item.isActive) {
      ref.read(downloadQueueManagerProvider).cancelDownload(item.id);
    } else if (item.isFailed) {
      ref.read(downloadQueueManagerProvider).retryDownload(item.id);
    } else if (item.status == DownloadItemStatus.queued) {
      ref.read(downloadQueueManagerProvider).removeDownload(item.id);
    } else if (item.isFinished) {
      ref.read(downloadQueueManagerProvider).removeDownload(item.id);
    }
  }
}
