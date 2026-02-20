import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/config/app_config.dart';
import '../../models/config/system_config.dart';

import '../../core/input/input.dart';
import '../../core/responsive/responsive.dart';
import '../../models/game_item.dart';
import '../../models/system_model.dart';
import '../../providers/app_providers.dart';
import '../../providers/game_providers.dart';
import '../../services/config_bootstrap.dart';
import '../../services/input_debouncer.dart';
import '../../utils/image_helper.dart';
import '../game_detail/game_detail_screen.dart';
import 'logic/focus_sync_manager.dart';
import 'logic/game_list_controller.dart';
import '../../widgets/console_hud.dart';
import 'widgets/dynamic_background.dart';
import 'widgets/game_grid.dart';
import 'widgets/game_list_header.dart';
import 'widgets/filter_overlay.dart';
import 'widgets/search_overlay.dart';
import 'widgets/tinted_overlay.dart';

class GameListScreen extends ConsumerStatefulWidget {
  final SystemModel system;
  final String targetFolder;

  const GameListScreen({
    super.key,
    required this.system,
    required this.targetFolder,
  });

  @override
  ConsumerState<GameListScreen> createState() => _GameListScreenState();
}

class _GameListScreenState extends ConsumerState<GameListScreen>
    with ConsoleScreenMixin {
  late final GameListController _controller;
  late final FocusSyncManager _focusManager;
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<String?> _backgroundNotifier = ValueNotifier(null);
  final Map<int, GlobalKey> _itemKeys = {};

  bool _isSearching = false;
  bool _isSearchFocused = false;
  bool _isClosingSearch = false;
  bool _isFiltering = false;

  late int _columns;
  double _lastPinchScale = 1.0;
  late InputDebouncer _debouncer;

  @override
  String get routeId => 'game_list_${widget.system.name}';

  @override
  Map<Type, Action<Intent>> get screenActions => {
        NavigateIntent: _GridNavigateAction(this),
        AdjustColumnsIntent: _AdjustColumnsAction(this),
        ConfirmIntent: CallbackAction<ConfirmIntent>(
          onInvoke: (_) {
            _openSelectedGame();
            return null;
          },
        ),
        BackIntent: _BackAction(this),
        SearchIntent: CallbackAction<SearchIntent>(
          onInvoke: (_) {
            if (!_isFiltering) _openSearch();
            return null;
          },
        ),
        InfoIntent: CallbackAction<InfoIntent>(
          onInvoke: (_) {
            _toggleFilter();
            return null;
          },
        ),
      };

  @override
  void initState() {
    super.initState();
    _columns = ref.read(gridColumnsProvider(widget.system.name));
    _debouncer = ref.read(inputDebouncerProvider);

    final appConfig =
        ref.read(bootstrappedConfigProvider).value ?? AppConfig.empty;
    final systemConfig =
        ConfigBootstrap.configForSystem(appConfig, widget.system);

    _controller = GameListController(
      system: widget.system,
      targetFolder: widget.targetFolder,
      systemConfig: systemConfig ?? SystemConfig(id: widget.system.id, name: widget.system.name, targetFolder: widget.targetFolder, providers: []),
      storage: ref.read(storageServiceProvider),
    )..addListener(_onControllerChanged);

    _focusManager = FocusSyncManager(
      scrollController: _scrollController,
      getCrossAxisCount: () => _columns,
      getItemCount: () => _controller.state.filteredGroups.length,
      getGridRatio: () => 1.0,
      onSelectionChanged: (_) => setState(() {}),
      onBackgroundUpdate: _updateBackground,
    );

    _searchFocusNode.addListener(_onSearchFocusChange);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(mainFocusRequestProvider.notifier).state = screenFocusNode;
      _restoreSavedIndex();
    });
  }

  void _restoreSavedIndex() {
    final saved = getSavedFocusState();
    if (saved?.selectedIndex != null && saved!.selectedIndex! > 0) {
      _focusManager.setSelectedIndex(saved.selectedIndex!);
      _updateBackground();
      setState(() {});
    }
  }

  void _onSearchFocusChange() {
    if (!mounted) return;

    final hasFocus = _searchFocusNode.hasFocus;
    setState(() {
      _isSearchFocused = hasFocus;
    });

    // If search lost focus but is still active, redirect focus to screenFocusNode
    if (!hasFocus && _isSearching && !_isClosingSearch) {
      if (!screenFocusNode.hasFocus) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _isSearching && !_isClosingSearch && !_searchFocusNode.hasFocus) {
            requestScreenFocus();
          }
        });
      }
    }
  }

  @override
  void dispose() {
    // Capture before dispose, defer save to avoid provider modification during finalization
    final selectedIndex = _focusManager.selectedIndex;
    Future.delayed(Duration.zero, () {
      focusStateManager.saveFocusState(routeId, selectedIndex: selectedIndex);
    });

    _debouncer.stopHold();
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _focusManager.dispose();
    _scrollController.dispose();
    _backgroundNotifier.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    setState(() {});
    _updateItemKeys();
  }

  void _updateItemKeys() {
    _itemKeys.clear();
    final count = _controller.state.filteredGroups.length;
    for (int i = 0; i < count; i++) {
      _itemKeys[i] = GlobalKey();
    }
    _focusManager.ensureFocusNodes(count);
  }

  void _updateBackground() {
    final state = _controller.state;
    final selectedIndex = _focusManager.selectedIndex;
    if (selectedIndex >= 0 && selectedIndex < state.filteredGroups.length) {
      final displayName = state.filteredGroups[selectedIndex];
      final variants = state.filteredGroupedGames[displayName];
      if (variants == null || variants.isEmpty) return;
      final coverUrls = ImageHelper.getCoverUrls(
        widget.system,
        variants.map((v) => v.filename).toList(),
      );
      final imageUrl = variants.first.cachedCoverUrl ??
          (coverUrls.isNotEmpty ? coverUrls.first : null);
      if (imageUrl != null && imageUrl != _backgroundNotifier.value) {
        _backgroundNotifier.value = imageUrl;
      }
    }
  }

  void _openSearch() {
    if (_isFiltering) setState(() => _isFiltering = false);
    _searchController.clear();
    _controller.resetFilter();
    _focusManager.reset(0);
    _isClosingSearch = false;
    setState(() => _isSearching = true);
    _updateItemKeys();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isSearching) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  void _closeSearch() {
    _isClosingSearch = true;
    FocusManager.instance.primaryFocus?.unfocus();
    FocusScope.of(context).unfocus();

    _searchController.clear();
    _controller.resetFilter();
    _focusManager.reset(0);

    setState(() {
      _isSearching = false;
      _isSearchFocused = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        requestScreenFocus();
      }
      _isClosingSearch = false;
    });
  }

  void _toggleFilter() {
    if (_isFiltering) {
      _closeFilter();
    } else {
      if (_isSearching) _closeSearch();
      _openFilter();
    }
  }

  void _openFilter() {
    setState(() => _isFiltering = true);
  }

  void _closeFilter() {
    setState(() => _isFiltering = false);
    _resetFocusAfterFilterChange();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) requestScreenFocus();
    });
  }

  void _resetFocusAfterFilterChange() {
    final count = _controller.state.filteredGroups.length;
    if (count == 0) {
      _focusManager.reset(0);
    } else if (_focusManager.selectedIndex >= count) {
      _focusManager.reset(count - 1);
    }
    _updateItemKeys();
  }

  void _onSearchChanged(String query) {
    final prevCount = _controller.state.filteredGroups.length;
    _controller.filterGames(query);
    final newCount = _controller.state.filteredGroups.length;

    if (newCount == 0) {
      _focusManager.reset(0);
    } else if (_focusManager.selectedIndex >= newCount) {
      _focusManager.reset(newCount - 1);
    }

    if (newCount != prevCount) {
      _updateItemKeys();
    }

    setState(() {});
  }

  void _onSearchSubmitted() {
    _searchFocusNode.unfocus();
    setState(() {
      _isSearchFocused = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _controller.state.filteredGroups.isNotEmpty) {
        requestScreenFocus();
      }
    });
  }

  void _unfocusSearch() {
    _searchFocusNode.unfocus();
    setState(() {
      _isSearchFocused = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        requestScreenFocus();
      }
    });
  }

  void _adjustColumns(bool increase) {
    if (increase) {
      _moreColumns();
    } else {
      _lessColumns();
    }
  }

  void _lessColumns() {
    if (_columns <= 3) return;
    setState(() {
      _columns--;
      ref
          .read(gridColumnsProvider(widget.system.name).notifier)
          .setColumns(_columns);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusManager.scrollToSelected(_itemKeys[_focusManager.selectedIndex]);
    });
  }

  void _moreColumns() {
    if (_columns >= 8) return;
    setState(() {
      _columns++;
      ref
          .read(gridColumnsProvider(widget.system.name).notifier)
          .setColumns(_columns);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusManager.scrollToSelected(_itemKeys[_focusManager.selectedIndex]);
    });
  }

  void _navigateGrid(GridDirection direction) {
    if (_debouncer.startHold(() {
      if (_focusManager.moveFocus(direction)) {
        setState(() {});
        _focusManager.scrollToSelected(
          _itemKeys[_focusManager.selectedIndex],
          instant: _debouncer.isHolding,
        );
      } else if (direction == GridDirection.up && _isSearching) {
        _searchFocusNode.requestFocus();
      }
    })) {
      ref.read(feedbackServiceProvider).tick();
    }
  }

  void _handleBack() {
    ref.read(feedbackServiceProvider).cancel();
    if (_isFiltering) {
      _closeFilter();
    } else if (_isSearching && !_searchFocusNode.hasFocus) {
      _closeSearch();
    } else {
      Navigator.pop(context);
    }
  }

  void _openSelectedGame() {
    final state = _controller.state;
    final selectedIndex = _focusManager.selectedIndex;
    if (selectedIndex >= 0 && selectedIndex < state.filteredGroups.length) {
      final displayName = state.filteredGroups[selectedIndex];
      final variants = state.filteredGroupedGames[displayName];
      if (variants == null || variants.isEmpty) return;
      _openGameDetail(displayName, variants);
    }
  }

  Future<void> _openGameDetail(
      String displayName, List<GameItem> variants) async {
    _searchFocusNode.unfocus();
    ref.read(feedbackServiceProvider).confirm();
    final isLocalOnly = _controller.state.isLocalOnly;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GameDetailScreen(
          game: variants.first,
          variants: variants,
          system: widget.system,
          targetFolder: widget.targetFolder,
          isLocalOnly: isLocalOnly,
        ),
      ),
    );
    if (isLocalOnly) {
      await _controller.loadGames();
    } else {
      await _controller.updateInstalledStatus(displayName);
    }
    if (_isSearching && mounted) {
      requestScreenFocus();
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    // When search field is focused, stop key events from reaching
    // the Shortcuts widget above, but let them through to text input.
    if (_isSearching && _searchFocusNode.hasFocus) {
      return KeyEventResult.skipRemainingHandlers;
    }

    final isDown = event is KeyDownEvent;
    final isUp = event is KeyUpEvent;

    if (isUp) {
      _debouncer.stopHold();
      return KeyEventResult.ignored;
    }

    if (!isDown) return KeyEventResult.ignored;

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final state = _controller.state;
    final baseTopPadding = rs.safeAreaTop + (rs.isSmall ? 60 : 80);
    final folderExtraPadding = widget.targetFolder.isNotEmpty ? (rs.isSmall ? 14.0 : 16.0) : 0.0;
    final localOnlyExtraPadding = state.isLocalOnly ? (rs.isSmall ? 24.0 : 28.0) : 0.0;
    final searchExtraPadding = rs.isSmall ? 16.0 : 20.0;
    final topPadding =
        baseTopPadding + folderExtraPadding + localOnlyExtraPadding + (_isSearching ? searchExtraPadding : 0.0);

    _focusManager.validateState(_columns);

    return buildWithActions(
      PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            _handleBack();
          }
        },
        child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onScaleStart: (details) {
            _lastPinchScale = 1.0;
          },
          onScaleEnd: (details) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _focusManager
                  .scrollToSelected(_itemKeys[_focusManager.selectedIndex]);
            });
          },
          onScaleUpdate: (details) {
            if (details.scale != 1.0) {
              final pinchDelta = details.scale - _lastPinchScale;
              if (pinchDelta.abs() > 0.15) {
                _lastPinchScale = details.scale;
                if (pinchDelta > 0) {
                  _lessColumns();
                } else {
                  _moreColumns();
                }
              }
            }
          },
          child: Stack(
            children: [
              DynamicBackground(
                backgroundNotifier: _backgroundNotifier,
                accentColor: widget.system.accentColor,
              ),
              TintedOverlay(accentColor: widget.system.accentColor),
              _buildNormalContent(state, topPadding),
              if (_isSearching) _buildSearchContent(state),
              if (_isFiltering) _buildFilterContent(state),
              _isFiltering
                  ? ConsoleHud(
                      a: const HudAction('Toggle'),
                      b: HudAction('Close', onTap: _closeFilter),
                      x: HudAction('Clear', onTap: () {
                        _controller.clearFilters();
                        _resetFocusAfterFilterChange();
                        setState(() {});
                      }),
                      showDownloads: false,
                    )
                  : _isSearching
                      ? ConsoleHud(
                          dpad: !_isSearchFocused ? (label: '\u2191', action: 'Search') : null,
                          a: HudAction('Select', onTap: _openSelectedGame),
                          b: HudAction(
                            _isSearchFocused ? 'Keyboard' : 'Close',
                            highlight: _isSearchFocused,
                            onTap: () => Navigator.pop(context),
                          ),
                          showDownloads: false,
                        )
                      : ConsoleHud(
                          a: HudAction('Select', onTap: _openSelectedGame),
                          b: HudAction('Back', onTap: () => Navigator.pop(context)),
                          x: HudAction(
                            state.activeFilters.isNotEmpty ? 'Filter \u25CF' : 'Filter',
                            onTap: _toggleFilter,
                          ),
                          y: HudAction('Search', onTap: _openSearch),
                        ),
            ],
          ),
        ),
      ),
      ),
      onKeyEvent: _handleKeyEvent,
    );
  }

  Widget _buildNormalContent(GameListState state, double topPadding) {
    return Stack(
      children: [
        Padding(
          padding: EdgeInsets.only(top: topPadding),
          child: _buildGridOrStatus(state),
        ),
        GameListHeader(
          system: widget.system,
          gameCount: state.filteredGroups.length,
          hasActiveFilters: state.activeFilters.isNotEmpty,
          isLocalOnly: state.isLocalOnly,
          targetFolder: widget.targetFolder,
        ),
      ],
    );
  }

  Widget _buildGridOrStatus(GameListState state) {
    if (state.isLoading) {
      return GameGridLoading(accentColor: widget.system.accentColor);
    }
    if (state.error != null) {
      return GameGridError(
        error: state.error!,
        accentColor: widget.system.accentColor,
        onRetry: _controller.loadGames,
      );
    }
    return GameGrid(
      key: ValueKey('grid_$_columns'),
      system: widget.system,
      filteredGroups: state.filteredGroups,
      groupedGames: state.filteredGroupedGames,
      installedCache: state.installedCache,
      itemKeys: _itemKeys,
      focusNodes: _focusManager.focusNodes,
      selectedIndex: _focusManager.selectedIndex,
      crossAxisCount: _columns,
      scrollController: _scrollController,
      onScrollNotification: (n) =>
          _focusManager.handleScrollNotification(n, context),
      onOpenGame: _openGameDetail,
      onSelectionChanged: (index) {
        _focusManager.setSelectedIndex(index);
        setState(() {});
        _updateBackground();
      },
      onCoverFound: (url, variants) async {
        for (final v in variants) {
          await _controller.updateCoverUrl(v.filename, url);
        }
      },
      searchQuery: state.searchQuery,
      hasActiveFilters: state.activeFilters.isNotEmpty,
      isLocalOnly: state.isLocalOnly,
      targetFolder: widget.targetFolder,
    );
  }

  Widget _buildSearchContent(GameListState state) {
    return SearchFocusScope(
      isVisible: _isSearching,
      textFieldFocusNode: _searchFocusNode,
      onClose: _closeSearch,
      child: SearchOverlay(
        system: widget.system,
        searchController: _searchController,
        searchFocusNode: _searchFocusNode,
        isSearching: _isSearching,
        isSearchFocused: _isSearchFocused,
        searchQuery: state.searchQuery,
        onSearchChanged: _onSearchChanged,
        onClose: _closeSearch,
        onUnfocus: _unfocusSearch,
        onSubmitted: _onSearchSubmitted,
      ),
    );
  }

  Widget _buildFilterContent(GameListState state) {
    return DialogFocusScope(
      isVisible: _isFiltering,
      onClose: _closeFilter,
      child: FilterOverlay(
        accentColor: widget.system.accentColor,
        availableRegions: state.availableRegions,
        availableLanguages: state.availableLanguages,
        selectedRegions: state.activeFilters.selectedRegions,
        selectedLanguages: state.activeFilters.selectedLanguages,
        onToggleRegion: (r) {
          _controller.toggleRegionFilter(r);
          _resetFocusAfterFilterChange();
          setState(() {});
        },
        onToggleLanguage: (l) {
          _controller.toggleLanguageFilter(l);
          _resetFocusAfterFilterChange();
          setState(() {});
        },
        onClearAll: () {
          _controller.clearFilters();
          _resetFocusAfterFilterChange();
          setState(() {});
        },
        onClose: _closeFilter,
      ),
    );
  }
}

class _GridNavigateAction extends Action<NavigateIntent> {
  final _GameListScreenState screen;

  _GridNavigateAction(this.screen);

  @override
  Object? invoke(NavigateIntent intent) {
    screen._navigateGrid(intent.direction);
    return null;
  }
}

class _AdjustColumnsAction extends Action<AdjustColumnsIntent> {
  final _GameListScreenState screen;

  _AdjustColumnsAction(this.screen);

  @override
  Object? invoke(AdjustColumnsIntent intent) {
    screen._adjustColumns(intent.increase);
    return null;
  }
}

class _BackAction extends Action<BackIntent> {
  final _GameListScreenState screen;

  _BackAction(this.screen);

  @override
  Object? invoke(BackIntent intent) {
    screen._handleBack();
    return null;
  }
}
