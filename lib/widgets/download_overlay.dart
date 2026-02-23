import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/input/overlay_scope.dart';
import '../core/responsive/responsive.dart';
import '../models/download_item.dart';
import '../providers/app_providers.dart';
import '../providers/download_providers.dart';
import '../widgets/smart_cover_image.dart';
import '../services/input_debouncer.dart';
import '../utils/image_helper.dart';
import '../widgets/console_hud.dart';

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
  @override
  Widget build(BuildContext context) {
    final isExpanded = ref.watch(downloadOverlayExpandedProvider);
    final queueState = ref.watch(downloadQueueManagerProvider).state;

    // Auto-close modal when queue becomes empty while expanded
    if (queueState.isEmpty && isExpanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(downloadOverlayExpandedProvider.notifier).state = false;
        final priority = ref.read(overlayPriorityProvider);
        if (priority == OverlayPriority.downloadModal) {
          ref.read(overlayPriorityProvider.notifier)
              .releaseByPriority(OverlayPriority.downloadModal);
        }
        restoreMainFocus(ref);
      });
      return const SizedBox.shrink();
    }

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
                          _LowSpaceWarning(items: items),
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
          _PulsingDot(isActive: widget.activeDownloads.isNotEmpty),
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
        child: _DownloadItemCard(
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

// ──────────────────────────────────────────────────────────────────────────────
//  DOWNLOAD ITEM CARD – horizontal card with cover art
// ──────────────────────────────────────────────────────────────────────────────

class _DownloadItemCard extends StatelessWidget {
  final DownloadItem item;
  final int index;
  final VoidCallback onTap;
  final ValueChanged<bool> onHover;
  final bool isFocused;
  final bool isHovered;

  const _DownloadItemCard({
    required this.item,
    required this.index,
    required this.onTap,
    required this.onHover,
    this.isFocused = false,
    this.isHovered = false,
  });

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final accentColor = item.system.accentColor;
    final isHighlighted = isFocused || isHovered;

    final coverUrls =
        ImageHelper.getCoverUrlsForSingle(item.system, item.game.filename);
    final coverSize = rs.isSmall ? 56.0 : 72.0;

    return MouseRegion(
      onEnter: (_) => onHover(true),
      onExit: (_) => onHover(false),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          margin: EdgeInsets.only(bottom: rs.spacing.sm),
          padding: EdgeInsets.all(rs.isSmall ? 10 : 14),
          transform: isHighlighted
              ? Matrix4.diagonal3Values(1.015, 1.015, 1.0)
              : Matrix4.identity(),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            color: _getBackgroundColor(isHighlighted),
            borderRadius: BorderRadius.circular(rs.isSmall ? 14 : 18),
            border: Border.all(
              color: _getBorderColor(isHighlighted),
              width: isHighlighted ? 1.5 : 1,
            ),
            boxShadow: isHighlighted
                ? [
                    BoxShadow(
                      color: _getGlowColor().withValues(alpha: 0.2),
                      blurRadius: 20,
                      spreadRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  // Cover art thumbnail
                  _CoverThumbnail(
                    coverUrls: coverUrls,
                    cachedUrl: item.game.cachedCoverUrl,
                    accentColor: accentColor,
                    size: coverSize,
                    isComplete: item.isComplete,
                    isFailed: item.isFailed,
                    isCancelled: item.isCancelled,
                  ),
                  SizedBox(width: rs.isSmall ? 10 : 14),
                  // Info section
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Game title
                        Text(
                          item.game.displayName,
                          style: TextStyle(
                            color: item.isCancelled
                                ? Colors.white38
                                : Colors.white,
                            fontSize: rs.isSmall ? 14 : 16,
                            fontWeight: FontWeight.w700,
                            decoration: item.isCancelled
                                ? TextDecoration.lineThrough
                                : null,
                            decorationColor: Colors.white38,
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        // System + status row
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                item.system.name,
                                style: TextStyle(
                                  color: accentColor.withValues(alpha: 0.9),
                                  fontSize: rs.isSmall ? 9 : 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _StatusLabel(item: item),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: rs.spacing.sm),
                  // Action button
                  _ActionButton(
                    item: item,
                    isHighlighted: isHighlighted,
                    onTap: onTap,
                  ),
                ],
              ),
              // Progress bar under everything
              if (item.isActive || item.status == DownloadItemStatus.queued)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: _ProgressBar(item: item),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getGlowColor() {
    if (item.isComplete) return Colors.green;
    if (item.isCancelled) return Colors.grey;
    if (item.isFailed) return Colors.red;
    return Colors.white;
  }

  Color _getBackgroundColor(bool isHighlighted) {
    if (item.isComplete) {
      return Colors.green.withValues(alpha: isHighlighted ? 0.12 : 0.06);
    } else if (item.isCancelled) {
      return Colors.grey.withValues(alpha: isHighlighted ? 0.12 : 0.05);
    } else if (item.isFailed) {
      return Colors.red.withValues(alpha: isHighlighted ? 0.12 : 0.06);
    } else if (isHighlighted) {
      return Colors.white.withValues(alpha: 0.08);
    }
    return Colors.white.withValues(alpha: 0.03);
  }

  Color _getBorderColor(bool isHighlighted) {
    if (item.isComplete) {
      return Colors.green.withValues(alpha: isHighlighted ? 0.5 : 0.15);
    } else if (item.isCancelled) {
      return Colors.grey.withValues(alpha: isHighlighted ? 0.4 : 0.1);
    } else if (item.isFailed) {
      return Colors.red.withValues(alpha: isHighlighted ? 0.5 : 0.15);
    } else if (isHighlighted) {
      return Colors.white.withValues(alpha: 0.25);
    }
    return Colors.white.withValues(alpha: 0.06);
  }
}

// ──────────────────────────────────────────────────────────────────────────────
//  SUB-COMPONENTS
// ──────────────────────────────────────────────────────────────────────────────

/// Game cover art thumbnail with status overlay
class _CoverThumbnail extends StatelessWidget {
  final List<String> coverUrls;
  final String? cachedUrl;
  final Color accentColor;
  final double size;
  final bool isComplete;
  final bool isFailed;
  final bool isCancelled;

  const _CoverThumbnail({
    required this.coverUrls,
    this.cachedUrl,
    required this.accentColor,
    required this.size,
    this.isComplete = false,
    this.isFailed = false,
    this.isCancelled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _borderColor.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Cover image or fallback
            _buildImage(),
            // Status overlay
            if (isComplete || isFailed || isCancelled) _buildStatusOverlay(),
          ],
        ),
      ),
    );
  }

  Color get _borderColor {
    if (isComplete) return Colors.green;
    if (isFailed) return Colors.red;
    if (isCancelled) return Colors.grey;
    return accentColor;
  }

  Widget _buildImage() {
    if (coverUrls.isEmpty && cachedUrl == null) {
      return _buildFallback();
    }

    return SmartCoverImage(
      urls: coverUrls,
      cachedUrl: cachedUrl,
      fit: BoxFit.cover,
      placeholder: _buildFallback(),
      errorWidget: _buildFallback(),
    );
  }

  Widget _buildFallback() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor.withValues(alpha: 0.3),
            accentColor.withValues(alpha: 0.1),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.videogame_asset_rounded,
          color: accentColor.withValues(alpha: 0.6),
          size: size * 0.45,
        ),
      ),
    );
  }

  Widget _buildStatusOverlay() {
    final (overlayColor, icon) = isComplete
        ? (Colors.green, Icons.check_rounded)
        : isFailed
            ? (Colors.red, Icons.error_outline_rounded)
            : (Colors.grey, Icons.block_rounded);

    return Container(
      decoration: BoxDecoration(
        color: overlayColor.withValues(alpha: 0.7),
      ),
      child: Center(
        child: Icon(
          icon,
          color: Colors.white,
          size: size * 0.4,
        ),
      ),
    );
  }
}

/// Pulsing green dot for the header
class _PulsingDot extends StatefulWidget {
  final bool isActive;
  const _PulsingDot({required this.isActive});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    if (widget.isActive) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_PulsingDot old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isActive && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final glowVal = widget.isActive ? _controller.value : 0.0;
        return Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.isActive
                ? Colors.green
                : Colors.grey.shade700,
            boxShadow: widget.isActive
                ? [
                    BoxShadow(
                      color: Colors.green.withValues(alpha: 0.3 + glowVal * 0.5),
                      blurRadius: 8 + glowVal * 8,
                      spreadRadius: glowVal * 3,
                    ),
                  ]
                : null,
          ),
        );
      },
    );
  }
}

/// Low storage warning banner shown in the download modal.
class _LowSpaceWarning extends ConsumerWidget {
  final List<DownloadItem> items;
  const _LowSpaceWarning({required this.items});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Find the target folder from the first active or queued download
    final activeOrQueued = items
        .where((i) => i.isActive || i.status == DownloadItemStatus.queued)
        .toList();
    if (activeOrQueued.isEmpty) return const SizedBox.shrink();

    final targetFolder = activeOrQueued.first.targetFolder;
    final storageAsync = ref.watch(storageInfoProvider(targetFolder));

    return storageAsync.when(
      data: (info) {
        if (info == null || info.isHealthy) return const SizedBox.shrink();

        final rs = context.rs;
        final Color color;
        final String message;
        if (info.isLow) {
          color = Colors.red;
          message = 'Very low storage: ${info.freeSpaceText}';
        } else {
          color = Colors.amber;
          message = 'Storage getting low: ${info.freeSpaceText}';
        }

        return Container(
          width: double.infinity,
          margin: EdgeInsets.symmetric(
            horizontal: rs.spacing.lg,
            vertical: rs.spacing.sm,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: rs.isSmall ? 10 : 14,
            vertical: rs.isSmall ? 6 : 8,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(rs.isSmall ? 6 : 8),
            border: Border.all(
              color: color.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.warning_rounded,
                size: rs.isSmall ? 14 : 16,
                color: color,
              ),
              SizedBox(width: rs.spacing.sm),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: rs.isSmall ? 11.0 : 13.0,
                    color: info.isLow ? Colors.red.shade200 : Colors.amber.shade200,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

/// Status label (Downloading, Queued, etc.)
class _StatusLabel extends StatelessWidget {
  final DownloadItem item;
  const _StatusLabel({required this.item});

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final (label, color, icon) = _getInfo();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: rs.isSmall ? 12 : 14),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: rs.isSmall ? 10 : 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (item.isActive && item.speedText != null) ...[
          const SizedBox(width: 6),
          Container(
            width: 1,
            height: 10,
            color: Colors.white.withValues(alpha: 0.15),
          ),
          const SizedBox(width: 6),
          Text(
            item.speedText!,
            style: TextStyle(
              color: Colors.white70,
              fontSize: rs.isSmall ? 10 : 12,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ],
    );
  }

  (String, Color, IconData) _getInfo() {
    switch (item.status) {
      case DownloadItemStatus.downloading:
        return ('Downloading…', Colors.green, Icons.arrow_downward_rounded);
      case DownloadItemStatus.extracting:
        return ('Extracting…', Colors.amber, Icons.unarchive_rounded);
      case DownloadItemStatus.moving:
        return ('Installing…', Colors.amber, Icons.drive_file_move_rounded);
      case DownloadItemStatus.queued:
        return ('Waiting…', Colors.white38, Icons.schedule_rounded);
      case DownloadItemStatus.completed:
        return ('Complete', Colors.green, Icons.check_circle_rounded);
      case DownloadItemStatus.cancelled:
        return ('Cancelled', Colors.grey, Icons.cancel_rounded);
      case DownloadItemStatus.error:
        return ('Failed', Colors.red, Icons.error_rounded);
    }
  }
}

/// Sleek progress bar with glow
class _ProgressBar extends StatelessWidget {
  final DownloadItem item;
  const _ProgressBar({required this.item});

  @override
  Widget build(BuildContext context) {
    final accentColor = item.system.accentColor;
    final isQueued = item.status == DownloadItemStatus.queued;
    final isIndeterminate = item.status == DownloadItemStatus.extracting ||
        item.status == DownloadItemStatus.moving;

    if (isQueued) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: LinearProgressIndicator(
          value: 0,
          backgroundColor: Colors.white.withValues(alpha: 0.06),
          valueColor: AlwaysStoppedAnimation(Colors.white.withValues(alpha: 0.15)),
          minHeight: 3,
        ),
      );
    }

    if (isIndeterminate) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: LinearProgressIndicator(
          backgroundColor: Colors.white.withValues(alpha: 0.06),
          valueColor: AlwaysStoppedAnimation(Colors.amber.withValues(alpha: 0.7)),
          minHeight: 3,
        ),
      );
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: item.progress),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      builder: (context, value, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Percentage text
            if (item.progress > 0.01)
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    '${(value * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: accentColor.withValues(alpha: 0.8),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            // Track + filled bar
            Stack(
              children: [
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: value.clamp(0.0, 1.0),
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      gradient: LinearGradient(
                        colors: [
                          accentColor.withValues(alpha: 0.7),
                          accentColor,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withValues(alpha: 0.5),
                          blurRadius: 6,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Action button (cancel / retry / dismiss)
class _ActionButton extends StatelessWidget {
  final DownloadItem item;
  final bool isHighlighted;
  final VoidCallback onTap;

  const _ActionButton({
    required this.item,
    required this.isHighlighted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final (color, icon, tooltip) = _getConfig();
    final buttonSize = rs.isSmall ? 34.0 : 40.0;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: buttonSize,
        height: buttonSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isHighlighted
              ? color.withValues(alpha: 0.25)
              : color.withValues(alpha: 0.1),
          border: Border.all(
            color: isHighlighted
                ? color.withValues(alpha: 0.6)
                : color.withValues(alpha: 0.2),
          ),
        ),
        child: Icon(
          icon,
          color: isHighlighted
              ? color
              : color.withValues(alpha: 0.6),
          size: rs.isSmall ? 16 : 20,
        ),
      ),
    );
  }

  (Color, IconData, String) _getConfig() {
    if (item.isComplete) {
      return (Colors.green, Icons.check_rounded, 'Dismiss');
    } else if (item.isCancelled) {
      return (Colors.grey, Icons.close_rounded, 'Dismiss');
    } else if (item.isFailed) {
      return (Colors.red, Icons.refresh_rounded, 'Retry');
    } else if (item.isActive) {
      return (Colors.red.shade300, Icons.stop_rounded, 'Cancel');
    } else {
      return (Colors.white38, Icons.close_rounded, 'Remove');
    }
  }
}
