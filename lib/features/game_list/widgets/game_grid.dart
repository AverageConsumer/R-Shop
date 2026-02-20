import 'package:flutter/material.dart';

import '../../../core/responsive/responsive.dart';
import '../../../models/game_item.dart';
import '../../../models/system_model.dart';
import '../../../utils/image_helper.dart';
import 'game_card.dart';

class GameGrid extends StatefulWidget {
  final SystemModel system;
  final List<String> filteredGroups;
  final Map<String, List<GameItem>> groupedGames;
  final Map<String, bool> installedCache;
  final Map<int, GlobalKey> itemKeys;
  final Map<int, FocusNode> focusNodes;
  final int selectedIndex;
  final int crossAxisCount;
  final ScrollController scrollController;
  final bool Function(ScrollNotification) onScrollNotification;
  final void Function(String displayName, List<GameItem> variants) onOpenGame;
  final void Function(int index) onSelectionChanged;
  final void Function(String url, List<GameItem> variants) onCoverFound;
  final String searchQuery;
  final bool hasActiveFilters;
  final bool isLocalOnly;
  final String targetFolder;

  const GameGrid({
    super.key,
    required this.system,
    required this.filteredGroups,
    required this.groupedGames,
    required this.installedCache,
    required this.itemKeys,
    required this.focusNodes,
    required this.selectedIndex,
    required this.crossAxisCount,
    required this.scrollController,
    required this.onScrollNotification,
    required this.onOpenGame,
    required this.onSelectionChanged,
    required this.onCoverFound,
    this.searchQuery = '',
    this.hasActiveFilters = false,
    this.isLocalOnly = false,
    this.targetFolder = '',
  });

  @override
  State<GameGrid> createState() => _GameGridState();
}

class _GameGridState extends State<GameGrid> {
  @override
  Widget build(BuildContext context) {
    final rs = context.rs;

    if (widget.filteredGroups.isEmpty) {
      final (icon, message) = _emptyStateContent();
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
            cacheExtent: 500,
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

  (IconData, String) _emptyStateContent() {
    if (widget.searchQuery.isNotEmpty) {
      return (Icons.search_off, "No games match '${widget.searchQuery}'");
    }
    if (widget.hasActiveFilters) {
      return (Icons.filter_list_off, 'No games match current filters');
    }
    if (widget.isLocalOnly) {
      return (Icons.folder_open, 'No ROMs found in ${widget.targetFolder}');
    }
    return (Icons.cloud_off, 'Could not load games \u2014 check your connection');
  }

  Widget _buildItem(BuildContext context, int index) {
    final displayName = widget.filteredGroups[index];
    final variants = widget.groupedGames[displayName]!;
    final coverUrls = ImageHelper.getCoverUrls(
      widget.system,
      variants.map((v) => v.filename).toList(),
    );
    final cachedUrl = variants.first.cachedCoverUrl;
    final isInstalled = widget.installedCache[displayName] ?? false;
    final isSelected = index == widget.selectedIndex;

    return RepaintBoundary(
      key: widget.itemKeys[index],
      child: GameCard(
        displayName: displayName,
        coverUrls: coverUrls,
        cachedUrl: cachedUrl,
        variantCount: variants.length,
        isInstalled: isInstalled,
        isSelected: isSelected,
        accentColor: widget.system.accentColor,
        focusNode: widget.focusNodes[index],
        onTap: () => widget.onOpenGame(displayName, variants),
        onTapSelect: () => widget.onSelectionChanged(index),
        onCoverFound: (url) => widget.onCoverFound(url, variants),
      ),
    );
  }
}

class GameGridLoading extends StatelessWidget {
  final Color accentColor;

  const GameGridLoading({super.key, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final fontSize = rs.isSmall ? 12.0 : 14.0;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: accentColor),
          SizedBox(height: rs.spacing.md),
          Text(
            'Loading Games...',
            style: TextStyle(color: Colors.grey[500], fontSize: fontSize),
          ),
        ],
      ),
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
