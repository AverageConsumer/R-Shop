import 'package:flutter/material.dart';

import '../../../core/responsive/responsive.dart';
import '../../../models/game_item.dart';
import '../../../models/ra_models.dart';
import '../../../models/system_model.dart';
import '../../../utils/image_helper.dart';
import '../../../widgets/base_game_card.dart';
import '../../../widgets/selection_aware_item.dart';

class GameGrid extends StatefulWidget {
  final SystemModel system;
  final List<String> filteredGroups;
  final Map<String, List<GameItem>> groupedGames;
  final Map<String, bool> installedCache;
  final Set<String> favorites;
  final Map<int, GlobalKey> itemKeys;
  final Map<int, FocusNode> focusNodes;
  final ValueNotifier<int> selectedIndexNotifier;
  final int crossAxisCount;
  final ScrollController scrollController;
  final bool Function(ScrollNotification) onScrollNotification;
  final void Function(String displayName, List<GameItem> variants) onOpenGame;
  final void Function(int index) onSelectionChanged;
  final void Function(String url, List<GameItem> variants) onCoverFound;
  final void Function(String url, List<GameItem> variants) onThumbnailNeeded;
  final String searchQuery;
  final bool hasActiveFilters;
  final bool isLocalOnly;
  final String targetFolder;
  final Map<String, RaMatchResult> raMatches;
  final ValueNotifier<bool>? scrollSuppression;
  final int memCacheWidthMax;
  final double gridCacheExtent;

  const GameGrid({
    super.key,
    required this.system,
    required this.filteredGroups,
    required this.groupedGames,
    required this.installedCache,
    this.favorites = const {},
    required this.itemKeys,
    required this.focusNodes,
    required this.selectedIndexNotifier,
    required this.crossAxisCount,
    required this.scrollController,
    required this.onScrollNotification,
    required this.onOpenGame,
    required this.onSelectionChanged,
    required this.onCoverFound,
    required this.onThumbnailNeeded,
    this.searchQuery = '',
    this.hasActiveFilters = false,
    this.isLocalOnly = false,
    this.targetFolder = '',
    this.raMatches = const {},
    this.scrollSuppression,
    this.memCacheWidthMax = 500,
    this.gridCacheExtent = 400,
  });

  @override
  State<GameGrid> createState() => _GameGridState();
}

class _GameGridState extends State<GameGrid> {
  int _optimalCacheWidth = 500;
  Map<String, List<String>> _coverUrlCache = {};

  @override
  void initState() {
    super.initState();
    _rebuildCoverUrlCache();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _optimalCacheWidth = _computeOptimalCacheWidth(context);
  }

  @override
  void didUpdateWidget(GameGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.filteredGroups, widget.filteredGroups)) {
      _rebuildCoverUrlCache();
    }
    if (oldWidget.crossAxisCount != widget.crossAxisCount) {
      _optimalCacheWidth = _computeOptimalCacheWidth(context);
    }
  }

  void _rebuildCoverUrlCache() {
    _coverUrlCache = {
      for (final name in widget.filteredGroups)
        if (widget.groupedGames[name] case final variants?)
          name: ImageHelper.getCoverUrls(
            widget.system,
            variants.map((v) => v.filename).toList(),
          ),
    };
  }

  int _computeOptimalCacheWidth(BuildContext context) {
    final rs = context.rs;
    final gridPadding = rs.spacing.lg * 2;
    final spacing = rs.isSmall ? 10.0 : 16.0;
    final gridWidth = MediaQuery.of(context).size.width - gridPadding;
    final itemWidth = (gridWidth - (widget.crossAxisCount - 1) * spacing) / widget.crossAxisCount;
    final dpr = MediaQuery.of(context).devicePixelRatio;
    return (itemWidth * dpr).round().clamp(150, widget.memCacheWidthMax);
  }

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;

    if (widget.filteredGroups.isEmpty) {
      final (icon, message, hint) = _emptyStateContent();
      return Center(
        child: Container(
          padding: EdgeInsets.all(rs.spacing.xl),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(rs.radius.lg),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: rs.isSmall ? 48 : 64,
                color: Colors.white.withValues(alpha: 0.15),
              ),
              SizedBox(height: rs.spacing.md),
              Text(
                message,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontSize: rs.isSmall ? 14 : 18,
                ),
                textAlign: TextAlign.center,
              ),
              if (hint != null) ...[
                SizedBox(height: rs.spacing.sm),
                Text(
                  hint,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.2),
                    fontSize: rs.isSmall ? 11 : 13,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      );
    }

    return FocusTraversalGroup(
      policy: WidgetOrderTraversalPolicy(),
      descendantsAreFocusable: false,
      child: NotificationListener<ScrollNotification>(
        onNotification: widget.onScrollNotification,
        child: RepaintBoundary(
          child: GridView.builder(
            cacheExtent: widget.gridCacheExtent,
            controller: widget.scrollController,
            padding: EdgeInsets.only(
              left: rs.spacing.lg,
              right: rs.spacing.lg,
              top: rs.spacing.md,
              bottom: rs.isPortrait ? 80 : 100,
            ),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: widget.crossAxisCount,
              mainAxisSpacing: rs.isSmall ? 10 : 16,
              crossAxisSpacing: rs.isSmall ? 10 : 16,
              childAspectRatio: 1.0,
            ),
            itemCount: widget.filteredGroups.length,
            itemBuilder: _buildItem,
          ),
        ),
      ),
    );
  }

  (IconData, String, String?) _emptyStateContent() {
    if (widget.searchQuery.isNotEmpty) {
      return (Icons.search_off, "No games match '${widget.searchQuery}'", 'Try a shorter search term');
    }
    if (widget.hasActiveFilters) {
      return (Icons.filter_list_off, 'No games match current filters', 'Change or reset filters in the menu');
    }
    if (widget.isLocalOnly) {
      return (Icons.folder_open, 'No ROMs found in ${widget.targetFolder}', 'Add ROM files to this folder and refresh');
    }
    return (Icons.cloud_off, 'Could not load games', 'Check your connection and try again');
  }

  Widget _buildItem(BuildContext context, int index) {
    final displayName = widget.filteredGroups[index];
    final variants = widget.groupedGames[displayName]!;
    final coverUrls = _coverUrlCache[displayName] ?? const [];
    final first = variants.first;
    final cachedUrl = first.cachedCoverUrl;
    final isInstalled = widget.installedCache[displayName] ?? false;
    final isFavorite = widget.favorites.contains(displayName);
    final providerLabel = first.providerConfig?.shortLabel;
    final raMatch = widget.raMatches[first.filename];

    return RepaintBoundary(
      key: widget.itemKeys[index],
      child: SelectionAwareItem(
        selectedIndexNotifier: widget.selectedIndexNotifier,
        index: index,
        builder: (isSelected) => BaseGameCard(
          displayName: displayName,
          coverUrls: coverUrls,
          cachedUrl: cachedUrl,
          variantCount: variants.length,
          isInstalled: isInstalled,
          isSelected: isSelected,
          isFavorite: isFavorite,
          accentColor: widget.system.accentColor,
          providerLabel: providerLabel,
          raAchievementCount: raMatch?.achievementCount,
          raMatchType: raMatch?.type ?? RaMatchType.none,
          isMastered: raMatch?.isMastered ?? false,
          hasThumbnail: first.hasThumbnail,
          memCacheWidth: _optimalCacheWidth,
          scrollSuppression: widget.scrollSuppression,
          focusNode: widget.focusNodes[index],
          onTap: () => widget.onOpenGame(displayName, variants),
          onTapSelect: () => widget.onSelectionChanged(index),
          onCoverFound: (url) => widget.onCoverFound(url, variants),
          onThumbnailNeeded: (url) => widget.onThumbnailNeeded(url, variants),
        ),
      ),
    );
  }
}

class GameGridLoading extends StatefulWidget {
  final Color accentColor;
  final int crossAxisCount;

  const GameGridLoading({
    super.key,
    required this.accentColor,
    required this.crossAxisCount,
  });

  @override
  State<GameGridLoading> createState() => _GameGridLoadingState();
}

class _GameGridLoadingState extends State<GameGridLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final spacing = rs.isSmall ? 10.0 : 16.0;
    final borderRadius = rs.isSmall ? 8.0 : 10.0;

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.only(
        left: rs.spacing.lg,
        right: rs.spacing.lg,
        top: rs.spacing.md,
        bottom: rs.isPortrait ? 80 : 100,
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: widget.crossAxisCount,
        mainAxisSpacing: spacing,
        crossAxisSpacing: spacing,
        childAspectRatio: 1.0,
      ),
      itemCount: widget.crossAxisCount * 3,
      itemBuilder: (context, index) {
        return AnimatedBuilder(
          animation: _shimmerController,
          builder: (context, child) {
            final shimmerValue = _shimmerController.value;
            final begin = Alignment.lerp(
              const Alignment(-1.5, -0.3),
              const Alignment(0.5, -0.1),
              shimmerValue,
            )!;
            final end = Alignment.lerp(
              const Alignment(-0.5, 0.1),
              const Alignment(1.5, 0.3),
              shimmerValue,
            )!;

            return Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(borderRadius - 1),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Shimmer sweep
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: begin,
                          end: end,
                          colors: [
                            Colors.transparent,
                            Colors.white.withValues(alpha: 0.06),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),
                    // Bottom title placeholder
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 40,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black87],
                          ),
                        ),
                        padding: const EdgeInsets.fromLTRB(8, 12, 8, 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            FractionallySizedBox(
                              widthFactor: 0.6,
                              child: Container(
                                height: rs.isSmall ? 8 : 10,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            FractionallySizedBox(
                              widthFactor: 0.35,
                              child: Container(
                                height: rs.isSmall ? 6 : 8,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class GameGridError extends StatelessWidget {
  final String error;
  final Color accentColor;
  final VoidCallback onRetry;

  const GameGridError({
    super.key,
    required this.error,
    required this.accentColor,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final titleFontSize = rs.isSmall ? 14.0 : 18.0;
    final errorFontSize = rs.isSmall ? 10.0 : 12.0;
    final iconSize = rs.isSmall ? 36.0 : 48.0;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: iconSize,
            color: Colors.redAccent,
          ),
          SizedBox(height: rs.spacing.md),
          Text(
            'Error loading games',
            style: TextStyle(
              color: Colors.white,
              fontSize: titleFontSize,
            ),
          ),
          SizedBox(height: rs.spacing.sm),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: rs.spacing.xl),
            child: Text(
              error,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: errorFontSize,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: rs.spacing.md),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
