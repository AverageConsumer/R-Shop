import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/input/input.dart';
import '../../../core/responsive/responsive.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/game_item.dart';
import '../../../models/system_model.dart';
import '../../../utils/game_metadata.dart';
import '../../../providers/game_providers.dart';
import '../../../services/config_bootstrap.dart';
import '../../../services/database_service.dart';
import '../../../widgets/console_hud.dart';
import '../../../widgets/smart_cover_image.dart';
import '../../../utils/image_helper.dart';
import '../../game_detail/game_detail_screen.dart';

class GlobalSearchOverlay extends ConsumerStatefulWidget {
  final VoidCallback onClose;

  const GlobalSearchOverlay({super.key, required this.onClose});

  @override
  ConsumerState<GlobalSearchOverlay> createState() =>
      _GlobalSearchOverlayState();
}

class _GlobalSearchOverlayState extends ConsumerState<GlobalSearchOverlay> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode(debugLabel: 'globalSearch');
  final _listFocusNode = FocusNode(debugLabel: 'globalSearchList');
  final _databaseService = DatabaseService();
  List<GameSearchResult> _results = [];
  int _focusedIndex = 0;
  Timer? _debounce;
  bool _isSearchFocused = true;

  // Grouped results for display
  List<_GroupedResult> _grouped = [];
  final Map<int, GlobalKey> _resultKeys = {};

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(_onSearchFocusChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.removeListener(_onSearchFocusChange);
    _searchFocusNode.dispose();
    _listFocusNode.dispose();
    super.dispose();
  }

  void _onSearchFocusChange() {
    setState(() => _isSearchFocused = _searchFocusNode.hasFocus);
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 2) {
      setState(() {
        _results = [];
        _grouped = [];
        _focusedIndex = 0;
        _resultKeys.clear();
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 200), () async {
      final results = await _databaseService.searchGames(query.trim());
      if (!mounted) return;
      setState(() {
        _results = results;
        _grouped = _groupResults(results);
        _focusedIndex = 0;
        _resultKeys.clear();
      });
    });
  }

  void _scrollToFocused() {
    final key = _resultKeys[_focusedIndex];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        alignment: 0.3,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
      );
    }
  }

  List<_GroupedResult> _groupResults(List<GameSearchResult> results) {
    final systemMap = <String, SystemModel>{};
    for (final s in SystemModel.supportedSystems) {
      systemMap[s.id] = s;
    }

    final groups = <String, List<GameSearchResult>>{};
    for (final r in results) {
      groups.putIfAbsent(r.systemSlug, () => []).add(r);
    }

    return groups.entries.map((e) {
      final system = systemMap[e.key];
      return _GroupedResult(
        systemSlug: e.key,
        systemName: system?.name ?? e.key,
        system: system,
        results: e.value,
      );
    }).toList()
      ..sort((a, b) => a.systemName.compareTo(b.systemName));
  }

  List<GameSearchResult> get _flatResults {
    final flat = <GameSearchResult>[];
    for (final group in _grouped) {
      flat.addAll(group.results);
    }
    return flat;
  }

  void _navigateToResult(GameSearchResult result) {
    final systemMap = <String, SystemModel>{};
    for (final s in SystemModel.supportedSystems) {
      systemMap[s.id] = s;
    }
    final system = systemMap[result.systemSlug];
    if (system == null) return;

    final appConfig = ref.read(bootstrappedConfigProvider).value;
    final systemConfig = appConfig != null
        ? ConfigBootstrap.configForSystem(appConfig, system)
        : null;
    final targetFolder = systemConfig?.targetFolder ?? '';

    final game = GameItem(
      filename: result.filename,
      displayName: result.displayName,
      url: result.url,
      cachedCoverUrl: result.coverUrl,
      providerConfig: result.providerConfig,
    );

    widget.onClose();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GameDetailScreen(
          game: game,
          variants: [game],
          system: system,
          targetFolder: targetFolder,
        ),
      ),
    );
  }

  KeyEventResult _handleListKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;
    final flat = _flatResults;

    if (key == LogicalKeyboardKey.arrowDown) {
      if (_focusedIndex < flat.length - 1) {
        setState(() => _focusedIndex++);
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToFocused());
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      if (_focusedIndex > 0) {
        setState(() => _focusedIndex--);
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToFocused());
      } else {
        _searchFocusNode.requestFocus();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.gameButtonA ||
        key == LogicalKeyboardKey.enter) {
      if (_focusedIndex < flat.length) {
        _navigateToResult(flat[_focusedIndex]);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.gameButtonB ||
        key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.backspace) {
      widget.onClose();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;

    return OverlayFocusScope(
      priority: OverlayPriority.dialog,
      isVisible: true,
      onClose: widget.onClose,
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: widget.onClose,
          child: Container(
            color: Colors.black.withValues(alpha: 0.92),
            child: SafeArea(
              child: GestureDetector(
                onTap: () {}, // block tap-through
                child: Column(
                  children: [
                    SizedBox(height: rs.spacing.lg),
                    _buildSearchField(rs),
                    SizedBox(height: rs.spacing.md),
                    Expanded(child: _buildResults(rs)),
                    _buildHud(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField(Responsive rs) {
    final textFieldFontSize = rs.isSmall ? 15.0 : 18.0;
    final borderRadius = rs.isSmall ? 22.0 : 30.0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: rs.spacing.lg),
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape, includeRepeats: false): () {
            if (_searchFocusNode.hasFocus) {
              if (_flatResults.isNotEmpty) {
                _listFocusNode.requestFocus();
              } else {
                widget.onClose();
              }
            } else {
              widget.onClose();
            }
          },
          const SingleActivator(LogicalKeyboardKey.gameButtonB, includeRepeats: false): () {
            if (_searchFocusNode.hasFocus) {
              if (_flatResults.isNotEmpty) {
                _listFocusNode.requestFocus();
              } else {
                widget.onClose();
              }
            } else {
              widget.onClose();
            }
          },
          const SingleActivator(LogicalKeyboardKey.arrowDown, includeRepeats: false): () {
            if (_flatResults.isNotEmpty) {
              _listFocusNode.requestFocus();
            }
          },
        },
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF252525),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: _isSearchFocused
                  ? AppTheme.primaryColor
                  : AppTheme.primaryColor.withValues(alpha: 0.4),
              width: 2,
            ),
            boxShadow: _isSearchFocused
                ? [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            autofocus: true,
            autocorrect: false,
            textInputAction: TextInputAction.search,
            style: TextStyle(
              color: Colors.white,
              fontSize: textFieldFontSize,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: 'Search all games...',
              hintStyle: TextStyle(
                color: Colors.grey[500],
                fontSize: textFieldFontSize,
              ),
              prefixIcon: Icon(
                Icons.search,
                color: AppTheme.primaryColor,
                size: rs.isSmall ? 20 : 24,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: () {
                        _searchController.clear();
                        _onQueryChanged('');
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: rs.isSmall ? 12 : 16,
                vertical: rs.isSmall ? 12 : 16,
              ),
            ),
            onChanged: _onQueryChanged,
            onSubmitted: (_) {
              if (_flatResults.isNotEmpty) {
                _listFocusNode.requestFocus();
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildResults(Responsive rs) {
    if (_searchController.text.trim().length < 2) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 64,
                color: Colors.white.withValues(alpha: 0.1)),
            SizedBox(height: rs.spacing.md),
            Text(
              'Search across all cached systems',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: rs.isSmall ? 14 : 16,
              ),
            ),
            SizedBox(height: rs.spacing.sm),
            Text(
              'Visit system game lists to populate search',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.2),
                fontSize: rs.isSmall ? 11 : 13,
              ),
            ),
          ],
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 48,
                color: Colors.white.withValues(alpha: 0.15)),
            SizedBox(height: rs.spacing.md),
            Text(
              'No results found',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: rs.isSmall ? 14 : 16,
              ),
            ),
          ],
        ),
      );
    }

    int flatIndex = 0;
    return Focus(
      focusNode: _listFocusNode,
      onKeyEvent: _handleListKeyEvent,
      child: ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: rs.spacing.lg),
        itemCount: _grouped.length,
        itemBuilder: (context, groupIndex) {
          final group = _grouped[groupIndex];
          final startIndex = flatIndex;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // System header
              Padding(
                padding: EdgeInsets.only(
                  top: groupIndex > 0 ? rs.spacing.md : 0,
                  bottom: rs.spacing.xs,
                  left: rs.spacing.xs,
                ),
                child: Text(
                  group.systemName.toUpperCase(),
                  style: TextStyle(
                    color: group.system?.accentColor ?? AppTheme.primaryColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              // Results
              ...List.generate(group.results.length, (i) {
                final itemFlatIndex = startIndex + i;
                // Advance flatIndex tracker (this is read after the loop)
                if (i == group.results.length - 1) {
                  flatIndex = startIndex + group.results.length;
                }
                final result = group.results[i];
                final isFocused = itemFlatIndex == _focusedIndex &&
                    _listFocusNode.hasFocus;

                _resultKeys.putIfAbsent(itemFlatIndex, () => GlobalKey());
                return _SearchResultTile(
                  key: _resultKeys[itemFlatIndex],
                  result: result,
                  system: group.system,
                  isFocused: isFocused,
                  onTap: () => _navigateToResult(result),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHud() {
    return ConsoleHud(
      a: _flatResults.isNotEmpty
          ? HudAction('Select', onTap: () {
              final flat = _flatResults;
              if (_focusedIndex < flat.length) {
                _navigateToResult(flat[_focusedIndex]);
              }
            })
          : null,
      b: HudAction('Close', onTap: widget.onClose),
      showDownloads: false,
      embedded: true,
    );
  }
}

class _GroupedResult {
  final String systemSlug;
  final String systemName;
  final SystemModel? system;
  final List<GameSearchResult> results;

  const _GroupedResult({
    required this.systemSlug,
    required this.systemName,
    this.system,
    required this.results,
  });
}

class _SearchResultTile extends StatelessWidget {
  final GameSearchResult result;
  final SystemModel? system;
  final bool isFocused;
  final VoidCallback onTap;

  const _SearchResultTile({
    super.key,
    required this.result,
    this.system,
    this.isFocused = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final accentColor = system?.accentColor ?? AppTheme.primaryColor;
    final coverSize = rs.isSmall ? 40.0 : 48.0;

    List<String> coverUrls = [];
    if (system != null) {
      coverUrls = ImageHelper.getCoverUrlsForSingle(system!, result.filename);
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: EdgeInsets.only(bottom: rs.spacing.xs),
        padding: EdgeInsets.symmetric(
          horizontal: rs.spacing.md,
          vertical: rs.spacing.sm,
        ),
        decoration: BoxDecoration(
          color: isFocused
              ? accentColor.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isFocused
                ? accentColor.withValues(alpha: 0.5)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            // Cover thumbnail
            Container(
              width: coverSize,
              height: coverSize,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: accentColor.withValues(alpha: 0.1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: coverUrls.isNotEmpty
                    ? SmartCoverImage(
                        urls: coverUrls,
                        cachedUrl: result.coverUrl,
                        fit: BoxFit.cover,
                        placeholder: _buildFallback(accentColor, coverSize),
                        errorWidget: _buildFallback(accentColor, coverSize),
                      )
                    : _buildFallback(accentColor, coverSize),
              ),
            ),
            SizedBox(width: rs.spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    result.displayName,
                    style: TextStyle(
                      color: isFocused ? Colors.white : Colors.white70,
                      fontSize: rs.isSmall ? 13 : 15,
                      fontWeight: isFocused ? FontWeight.w600 : FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  _buildTags(rs),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTags(Responsive rs) {
    final region = GameMetadata.extractRegion(result.filename);
    final tags = GameMetadata.extractAllTags(result.filename)
        .where((t) => t.type != TagType.hidden)
        .toList();

    if (tags.isEmpty && region.name == 'Unknown') {
      return const SizedBox.shrink();
    }

    const maxTags = 3;
    final visibleTags = tags.take(maxTags).toList();
    final remaining = tags.length - maxTags;

    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          if (region.name != 'Unknown')
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Text(region.flag, style: const TextStyle(fontSize: 12)),
            ),
          Expanded(
            child: Wrap(
              spacing: 4,
              runSpacing: 2,
              children: [
                ...visibleTags.map((tag) {
                  final color = tag.getColor();
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(
                        color: color.withValues(alpha: 0.35),
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      tag.raw,
                      style: TextStyle(
                        color: color.withValues(alpha: 0.9),
                        fontSize: rs.isSmall ? 8 : 9,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }),
                if (remaining > 0)
                  Text(
                    '+$remaining',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: rs.isSmall ? 8 : 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallback(Color color, double size) {
    return Container(
      color: color.withValues(alpha: 0.15),
      child: Center(
        child: Icon(
          Icons.videogame_asset_rounded,
          color: color.withValues(alpha: 0.4),
          size: size * 0.5,
        ),
      ),
    );
  }
}
