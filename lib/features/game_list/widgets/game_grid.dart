import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/responsive/responsive.dart';
import '../../../core/util/source_color.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/config/source.dart';
import '../../../models/game_item.dart';
import '../../../models/ra_models.dart';
import '../../../models/system_model.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/download_providers.dart';
import '../../../utils/image_helper.dart';
import '../../../widgets/base_game_card.dart';
import '../../../widgets/selection_aware_item.dart';

class GameGrid extends ConsumerStatefulWidget {
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
  ConsumerState<GameGrid> createState() => _GameGridState();
}

class _GameGridState extends ConsumerState<GameGrid> {
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
    final l = L.of(context);
    if (widget.searchQuery.isNotEmpty) {
      return (Icons.search_off, l.gameList_noGamesMatchSearch(widget.searchQuery), l.gameList_tryShorterSearch);
    }
    if (widget.hasActiveFilters) {
      return (Icons.filter_list_off, l.gameList_noGamesMatchFilters, l.gameList_changeFilters);
    }
    if (widget.isLocalOnly) {
      return (Icons.folder_open, l.gameList_noRomsFound(widget.targetFolder), l.gameList_addRomFiles);
    }
    return (Icons.cloud_off, l.gameList_couldNotLoadGames, l.gameList_checkConnection);
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

    // Source dot — look up the contributing Source by its id (set by
    // SourceResolver when it synthesised this provider). Falls back to
    // null for legacy/unmanaged providers, in which case BaseGameCard
    // simply renders no dot.
    final sourcesState = ref.watch(sourcesProvider);
    final sourceId = first.providerConfig?.sourceId;
    Source? source;
    if (sourceId != null) {
      for (final s in sourcesState.sources) {
        if (s.id == sourceId) {
          source = s;
          break;
        }
      }
    }
    final dotColor = source == null ? null : sourceDotColorFor(source);
    final dotBorrowed = source?.borrowed ?? false;

    // Extras: every alternativeSource that resolves to a known Source.
    // Variants are different filenames so they don't count as "this same
    // game has multiple sources" — only `first.alternativeSources` does.
    final List<SourceDotData> extraDots = [];
    for (final alt in first.alternativeSources) {
      final altId = alt.providerConfig.sourceId;
      if (altId == null) continue;
      Source? altSource;
      for (final s in sourcesState.sources) {
        if (s.id == altId) {
          altSource = s;
          break;
        }
      }
      if (altSource == null) continue;
      extraDots.add(SourceDotData(
        color: sourceDotColorFor(altSource),
        borrowed: altSource.borrowed,
      ));
    }

    // Download status for first variant
    final gameId = '${widget.system.name}_${first.filename}';
    final dlStatus = ref.watch(
      downloadStatusForGameProvider((gameId: gameId)),
    );

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
          sourceDotColor: dotColor,
          sourceDotBorrowed: dotBorrowed,
          extraSourceDots: extraDots,
          downloadStatus: dlStatus?.status,
          downloadProgress: dlStatus?.progress ?? 0.0,
          onTap: () => widget.onOpenGame(displayName, variants),
          onTapSelect: () => widget.onSelectionChanged(index),
          onCoverFound: (url) => widget.onCoverFound(url, variants),
          onThumbnailNeeded: (url) => widget.onThumbnailNeeded(url, variants),
        ),
      ),
    );
  }

}

class GameGridLoading extends StatelessWidget {
  final Color accentColor;
  final int crossAxisCount;

  const GameGridLoading({
    super.key,
    required this.accentColor,
    required this.crossAxisCount,
  });

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final spacing = rs.isSmall ? 10.0 : 16.0;
    final borderRadius = BorderRadius.circular(rs.isSmall ? 8.0 : 10.0);

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.only(
        left: rs.spacing.lg,
        right: rs.spacing.lg,
        top: rs.spacing.md,
        bottom: rs.isPortrait ? 80 : 100,
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: spacing,
        crossAxisSpacing: spacing,
        childAspectRatio: 1.0,
      ),
      itemCount: crossAxisCount * 3,
      itemBuilder: (context, index) {
        return Stack(
          fit: StackFit.expand,
          children: [
            SkeletonBox(borderRadius: borderRadius),
            // Bottom title placeholder — preserves the visual rhythm so the
            // skeleton hints "title goes here" before real cards arrive.
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
            L.of(context).gameList_errorLoadingGames,
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
            child: Text(L.of(context).common_retry),
          ),
        ],
      ),
    );
  }
}

class GameGridSyncing extends StatefulWidget {
  final Color accentColor;

  const GameGridSyncing({
    super.key,
    required this.accentColor,
  });

  @override
  State<GameGridSyncing> createState() => _GameGridSyncingState();
}

class _GameGridSyncingState extends State<GameGridSyncing>
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
    final rs = context.rs;
    final titleFontSize = rs.isSmall ? 14.0 : 18.0;
    final subtitleFontSize = rs.isSmall ? 10.0 : 12.0;
    final iconSize = rs.isSmall ? 36.0 : 48.0;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          RotationTransition(
            turns: _controller,
            child: Icon(
              Icons.sync,
              size: iconSize,
              color: Colors.cyanAccent,
            ),
          ),
          SizedBox(height: rs.spacing.md),
          Text(
            L.of(context).gameList_syncingLibrary,
            style: TextStyle(
              color: Colors.white,
              fontSize: titleFontSize,
            ),
          ),
          SizedBox(height: rs.spacing.sm),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: rs.spacing.xl),
            child: Text(
              L.of(context).gameList_gamesAppearShortly,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: subtitleFontSize,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
