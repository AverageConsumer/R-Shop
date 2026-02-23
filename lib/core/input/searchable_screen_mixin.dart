import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';
import '../../widgets/console_hud.dart';
import '../../widgets/search_overlay.dart';
import 'console_screen_mixin.dart';
import 'overlay_scope.dart';

/// Extracts the common search-field logic shared by LibraryScreen and
/// GameListScreen. Screens mix this in **after** [ConsoleScreenMixin]:
///
/// ```dart
/// class _MyScreenState extends ConsumerState<MyScreen>
///     with ConsoleScreenMixin, SearchableScreenMixin {
/// ```
///
/// The mixin owns the search text-field state (focus node, controller,
/// opening/closing flags) and fixes the B-button bug where
/// `_handleKeyEvent`'s `skipRemainingHandlers` prevented
/// `CallbackShortcuts` in SearchOverlay from seeing the B press.
mixin SearchableScreenMixin<T extends ConsumerStatefulWidget>
    on ConsoleScreenMixin<T> {
  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  bool _isSearching = false;
  bool _isSearchFocused = false;
  bool _isClosingSearch = false;
  int _searchOverlaySuspendCount = 0;

  final FocusNode searchFieldNode = FocusNode();
  final TextEditingController searchTextController = TextEditingController();

  // ---------------------------------------------------------------------------
  // Public getters
  // ---------------------------------------------------------------------------

  bool get isSearchActive => _isSearching;
  bool get isSearchFieldFocused => _isSearchFocused;

  // ---------------------------------------------------------------------------
  // Abstract — screens implement
  // ---------------------------------------------------------------------------

  Color get searchAccentColor;
  String get searchHintText;

  /// Called when the user types in the search field.
  void onSearchQueryChanged(String query);

  /// Called when search is closed — reset query + filters to default.
  void onSearchReset();

  /// Called when selection should jump to 0 (e.g. after opening search).
  void onSearchSelectionReset();

  // ---------------------------------------------------------------------------
  // Optional hook
  // ---------------------------------------------------------------------------

  /// Override to run logic right before the search field opens
  /// (e.g. close an active filter overlay).
  void onBeforeSearchOpen() {}

  // ---------------------------------------------------------------------------
  // Lifecycle — screens call from initState / dispose
  // ---------------------------------------------------------------------------

  void initSearch() {
    searchFieldNode.addListener(_onSearchFocusChange);
  }

  void disposeSearch() {
    searchFieldNode.removeListener(_onSearchFocusChange);
    searchTextController.dispose();
    searchFieldNode.dispose();
  }

  // ---------------------------------------------------------------------------
  // Core methods
  // ---------------------------------------------------------------------------

  void openSearch() {
    ref.read(feedbackServiceProvider).tick();
    onBeforeSearchOpen();
    searchTextController.clear();
    onSearchReset();
    onSearchSelectionReset();
    _isClosingSearch = false;
    setState(() => _isSearching = true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isSearching) {
        searchFieldNode.requestFocus();
      }
    });
  }

  void closeSearch() {
    _isClosingSearch = true;
    _searchOverlaySuspendCount = 0;
    FocusManager.instance.primaryFocus?.unfocus();
    FocusScope.of(context).unfocus();

    searchTextController.clear();
    onSearchReset();

    setState(() {
      _isSearching = false;
      _isSearchFocused = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) requestScreenFocus();
      _isClosingSearch = false;
    });
  }

  void toggleSearch() {
    if (_isSearching) {
      closeSearch();
    } else {
      openSearch();
    }
  }

  void unfocusSearch() {
    searchFieldNode.unfocus();
    setState(() => _isSearchFocused = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) requestScreenFocus();
    });
  }

  /// Two-step back: if the text field is focused → unfocus only;
  /// otherwise → close search entirely.
  void handleSearchBack() {
    if (searchFieldNode.hasFocus) {
      unfocusSearch();
    } else {
      closeSearch();
    }
  }

  void refocusSearchField() {
    searchFieldNode.requestFocus();
  }

  // ---------------------------------------------------------------------------
  // Overlay suspend/resume — call around Navigator.push from search
  // ---------------------------------------------------------------------------

  /// Temporarily resets overlay priority to `none` so the pushed screen's
  /// actions are not blocked by the lingering search priority.
  /// Uses a counter so nested suspend/resume pairs are balanced.
  void suspendSearchOverlay() {
    if (_isSearching) {
      _searchOverlaySuspendCount++;
      if (_searchOverlaySuspendCount == 1) {
        ref.read(overlayPriorityProvider.notifier).releaseByPriority(OverlayPriority.search);
      }
    }
  }

  /// Restores `search` priority after returning from a pushed route.
  void resumeSearchOverlay() {
    if (_isSearching && _searchOverlaySuspendCount > 0) {
      _searchOverlaySuspendCount--;
      if (_searchOverlaySuspendCount == 0) {
        ref.read(overlayPriorityProvider.notifier).claim(OverlayPriority.search);
      }
    }
  }

  /// Exception-safe wrapper: suspends search overlay, runs [action], then
  /// resumes — even if [action] throws.
  Future<R> withSuspendedSearch<R>(Future<R> Function() action) async {
    suspendSearchOverlay();
    try {
      return await action();
    } finally {
      resumeSearchOverlay();
    }
  }

  // ---------------------------------------------------------------------------
  // Helper for screenActions' isEnabledOverride
  // ---------------------------------------------------------------------------

  /// Returns `true` when the overlay priority is `none` **or** `search`,
  /// i.e. grid navigation should still work while searching.
  bool searchOrNone(dynamic _) {
    final p = ref.read(overlayPriorityProvider);
    return p == OverlayPriority.none || p == OverlayPriority.search;
  }

  // ---------------------------------------------------------------------------
  // Bug-fix: handleSearchKeyEvent
  // ---------------------------------------------------------------------------

  /// Call this as the **first** thing inside the screen's `onKeyEvent`.
  ///
  /// When the search text-field is focused we intercept B / Escape / GoBack
  /// **before** the blanket `skipRemainingHandlers` can swallow them. All
  /// other keys still get `skipRemainingHandlers` so the Shortcuts widget
  /// above doesn't interfere with text input.
  KeyEventResult? handleSearchKeyEvent(KeyEvent event) {
    if (!_isSearching || !searchFieldNode.hasFocus) return null;

    if (event is KeyDownEvent) {
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.gameButtonB ||
          key == LogicalKeyboardKey.escape ||
          key == LogicalKeyboardKey.goBack) {
        unfocusSearch();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.skipRemainingHandlers;
  }

  // ---------------------------------------------------------------------------
  // Build helpers
  // ---------------------------------------------------------------------------

  /// Returns the `SearchFocusScope` + `SearchOverlay` pill widget.
  /// The caller wraps it in their own `Positioned` for screen-specific offset.
  Widget buildSearchWidget({required String searchQuery}) {
    return SearchFocusScope(
      isVisible: _isSearching,
      textFieldFocusNode: searchFieldNode,
      onClose: closeSearch,
      child: SearchOverlay(
        accentColor: searchAccentColor,
        hintText: searchHintText,
        searchController: searchTextController,
        searchFocusNode: searchFieldNode,
        isSearching: _isSearching,
        isSearchFocused: _isSearchFocused,
        searchQuery: searchQuery,
        onSearchChanged: onSearchQueryChanged,
        onClose: closeSearch,
        onUnfocus: unfocusSearch,
        onSubmitted: unfocusSearch,
        showBackdrop: false,
      ),
    );
  }

  /// Returns the HUD shown while search is active.
  Widget buildSearchHud({required HudAction aAction}) {
    return ConsoleHud(
      a: aAction,
      b: HudAction(
        _isSearchFocused ? 'Keyboard' : 'Close',
        highlight: _isSearchFocused,
        onTap: handleSearchBack,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  void _onSearchFocusChange() {
    if (!mounted) return;
    final hasFocus = searchFieldNode.hasFocus;
    setState(() => _isSearchFocused = hasFocus);

    if (!hasFocus && _isSearching && !_isClosingSearch) {
      if (!screenFocusNode.hasFocus) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _isSearching && !_isClosingSearch &&
              !searchFieldNode.hasFocus) {
            requestScreenFocus();
          }
        });
      }
    }
  }
}
