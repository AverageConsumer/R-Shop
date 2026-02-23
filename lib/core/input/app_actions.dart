import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_intents.dart';
import '../../providers/app_providers.dart';

bool _noOverlayActive(WidgetRef ref) =>
    ref.read(overlayPriorityProvider) == OverlayPriority.none;

/// Generic guarded action that checks overlay priority before invoking.
/// Use [isEnabledOverride] for screens that need custom guard logic (e.g.
/// allowing actions when a dialog is open).
class OverlayGuardedAction<T extends Intent> extends Action<T> {
  final WidgetRef ref;
  final Object? Function(T intent) onInvoke;
  final bool Function(T intent)? isEnabledOverride;

  OverlayGuardedAction(this.ref, {required this.onInvoke, this.isEnabledOverride});

  @override
  bool isEnabled(T intent) =>
      isEnabledOverride?.call(intent) ??
      ref.read(overlayPriorityProvider) == OverlayPriority.none;

  @override
  Object? invoke(T intent) => onInvoke(intent);
}

class BackAction extends Action<BackIntent> {
  final BuildContext context;
  final WidgetRef ref;

  BackAction(this.context, this.ref);

  @override
  bool isEnabled(BackIntent intent) => _noOverlayActive(ref);

  @override
  Object? invoke(BackIntent intent) {
    if (!ref.read(inputDebouncerProvider).canPerformAction()) return null;

    ref.read(feedbackServiceProvider).cancel();

    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
    return null;
  }
}

class ConfirmAction extends Action<ConfirmIntent> {
  final WidgetRef ref;
  final VoidCallback? onConfirm;

  ConfirmAction(this.ref, {this.onConfirm});

  @override
  bool isEnabled(ConfirmIntent intent) => _noOverlayActive(ref);

  @override
  Object? invoke(ConfirmIntent intent) {
    if (!ref.read(inputDebouncerProvider).canPerformAction()) return null;
    if (onConfirm != null) {
      onConfirm!();
      return null;
    }

    final confirmRequest = ref.read(confirmRequestedProvider.notifier);
    confirmRequest.state = DateTime.now();
    return null;
  }
}

class SearchAction extends Action<SearchIntent> {
  final WidgetRef ref;
  final VoidCallback? onSearch;

  SearchAction(this.ref, {this.onSearch});

  @override
  bool isEnabled(SearchIntent intent) => _noOverlayActive(ref);

  @override
  Object? invoke(SearchIntent intent) {
    if (!ref.read(inputDebouncerProvider).canPerformAction()) return null;

    if (onSearch != null) {
      onSearch!();
    } else {
      final searchRequest = ref.read(searchRequestedProvider.notifier);
      searchRequest.state = DateTime.now();
    }
    return null;
  }
}

class ToggleOverlayAction extends Action<ToggleOverlayIntent> {
  final WidgetRef ref;
  final VoidCallback? onToggle;

  ToggleOverlayAction(this.ref, {this.onToggle});

  // Always enabled — Start button must be able to close overlays
  @override
  bool isEnabled(ToggleOverlayIntent intent) => true;

  @override
  Object? invoke(ToggleOverlayIntent intent) {
    if (!ref.read(inputDebouncerProvider).canPerformAction()) return null;
    onToggle?.call();
    return null;
  }
}

class NavigateAction extends Action<NavigateIntent> {
  final WidgetRef ref;
  final bool Function(NavigateIntent intent)? onNavigate;

  NavigateAction(this.ref, {this.onNavigate});

  @override
  bool isEnabled(NavigateIntent intent) => _noOverlayActive(ref);

  @override
  Object? invoke(NavigateIntent intent) {
    if (onNavigate != null) {
      final handled = onNavigate!(intent);
      if (handled) {
        // Screen handles its own feedback
        return null;
      }
    }

    // Fallback to standard traversal
    final direction = _getTraversalDirection(intent.direction);
    final focusNode = primaryFocus;
    if (focusNode != null) {
      final didMove = focusNode.focusInDirection(direction);
      if (didMove) {
        ref.read(feedbackServiceProvider).tick();
      }
    }
    return null;
  }

  TraversalDirection _getTraversalDirection(GridDirection direction) {
    switch (direction) {
      case GridDirection.up:
        return TraversalDirection.up;
      case GridDirection.down:
        return TraversalDirection.down;
      case GridDirection.left:
        return TraversalDirection.left;
      case GridDirection.right:
        return TraversalDirection.right;
    }
  }
}

class AdjustColumnsAction extends Action<AdjustColumnsIntent> {
  final WidgetRef ref;
  final void Function(bool increase)? onAdjust;

  AdjustColumnsAction(this.ref, {this.onAdjust});

  @override
  bool isEnabled(AdjustColumnsIntent intent) => _noOverlayActive(ref);

  @override
  Object? invoke(AdjustColumnsIntent intent) {
    if (!ref.read(inputDebouncerProvider).canPerformAction()) return null;

    onAdjust?.call(intent.increase);
    return null;
  }
}

class InfoAction extends Action<InfoIntent> {
  final WidgetRef ref;
  final VoidCallback? onInfo;

  InfoAction(this.ref, {this.onInfo});

  @override
  bool isEnabled(InfoIntent intent) => _noOverlayActive(ref);

  @override
  Object? invoke(InfoIntent intent) {
    if (!ref.read(inputDebouncerProvider).canPerformAction()) return null;

    onInfo?.call();
    return null;
  }
}

class MenuAction extends Action<MenuIntent> {
  final WidgetRef ref;
  final VoidCallback? onMenu;

  MenuAction(this.ref, {this.onMenu});

  @override
  bool isEnabled(MenuIntent intent) => _noOverlayActive(ref);

  @override
  Object? invoke(MenuIntent intent) {
    if (!ref.read(inputDebouncerProvider).canPerformAction()) return null;

    onMenu?.call();
    return null;
  }
}

class TabLeftAction extends Action<TabLeftIntent> {
  final WidgetRef ref;
  final VoidCallback? onTabLeft;

  TabLeftAction(this.ref, {this.onTabLeft});

  @override
  bool isEnabled(TabLeftIntent intent) => _noOverlayActive(ref);

  @override
  Object? invoke(TabLeftIntent intent) {
    if (!ref.read(inputDebouncerProvider).canPerformAction()) return null;

    if (onTabLeft != null) {
      onTabLeft!();
    }
    return null;
  }
}

class TabRightAction extends Action<TabRightIntent> {
  final WidgetRef ref;
  final VoidCallback? onTabRight;

  TabRightAction(this.ref, {this.onTabRight});

  @override
  bool isEnabled(TabRightIntent intent) => _noOverlayActive(ref);

  @override
  Object? invoke(TabRightIntent intent) {
    if (!ref.read(inputDebouncerProvider).canPerformAction()) return null;

    if (onTabRight != null) {
      onTabRight!();
    }
    return null;
  }
}

class FavoriteAction extends Action<FavoriteIntent> {
  final WidgetRef ref;
  final VoidCallback? onFavorite;

  FavoriteAction(this.ref, {this.onFavorite});

  @override
  bool isEnabled(FavoriteIntent intent) => _noOverlayActive(ref);

  @override
  Object? invoke(FavoriteIntent intent) {
    if (!ref.read(inputDebouncerProvider).canPerformAction()) return null;

    if (onFavorite != null) {
      onFavorite!();
    }
    return null;
  }
}

class AppShortcuts {
  static Map<ShortcutActivator, Intent> get defaultShortcuts => {
    // Back (no repeat)
    const SingleActivator(LogicalKeyboardKey.gameButtonB, includeRepeats: false): const BackIntent(),
    const SingleActivator(LogicalKeyboardKey.escape, includeRepeats: false): const BackIntent(),
    const SingleActivator(LogicalKeyboardKey.backspace, includeRepeats: false): const BackIntent(),
    const SingleActivator(LogicalKeyboardKey.goBack, includeRepeats: false): const BackIntent(),

    // Confirm (no repeat)
    const SingleActivator(LogicalKeyboardKey.gameButtonA, includeRepeats: false): const ConfirmIntent(),
    const SingleActivator(LogicalKeyboardKey.enter, includeRepeats: false): const ConfirmIntent(),
    const SingleActivator(LogicalKeyboardKey.numpadEnter, includeRepeats: false): const ConfirmIntent(),
    const SingleActivator(LogicalKeyboardKey.space, includeRepeats: false): const ConfirmIntent(),
    const SingleActivator(LogicalKeyboardKey.gameButtonSelect, includeRepeats: false): const FavoriteIntent(),

    // Search (no repeat)
    const SingleActivator(LogicalKeyboardKey.gameButtonY, includeRepeats: false): const SearchIntent(),
    const SingleActivator(LogicalKeyboardKey.keyI, includeRepeats: false): const SearchIntent(),

    // Overlay (no repeat)
    const SingleActivator(LogicalKeyboardKey.gameButtonStart, includeRepeats: false): const ToggleOverlayIntent(),

    // Navigation (d-pad keeps repeat for scrolling)
    const SingleActivator(LogicalKeyboardKey.arrowUp): const NavigateIntent(GridDirection.up),
    const SingleActivator(LogicalKeyboardKey.arrowDown): const NavigateIntent(GridDirection.down),
    const SingleActivator(LogicalKeyboardKey.arrowLeft): const NavigateIntent(GridDirection.left),
    const SingleActivator(LogicalKeyboardKey.arrowRight): const NavigateIntent(GridDirection.right),

    // Tabs / L1 R1 (no repeat)
    const SingleActivator(LogicalKeyboardKey.gameButtonLeft1, includeRepeats: false): const TabLeftIntent(),
    const SingleActivator(LogicalKeyboardKey.gameButtonRight1, includeRepeats: false): const TabRightIntent(),
    const SingleActivator(LogicalKeyboardKey.pageUp, includeRepeats: false): const TabLeftIntent(),
    const SingleActivator(LogicalKeyboardKey.pageDown, includeRepeats: false): const TabRightIntent(),
    const SingleActivator(LogicalKeyboardKey.bracketLeft, includeRepeats: false): const TabLeftIntent(),
    const SingleActivator(LogicalKeyboardKey.bracketRight, includeRepeats: false): const TabRightIntent(),

    // Info (no repeat)
    const SingleActivator(LogicalKeyboardKey.gameButtonX, includeRepeats: false): const InfoIntent(),

    // Favorite (no repeat)
    const SingleActivator(LogicalKeyboardKey.gameButtonRight2, includeRepeats: false): const FavoriteIntent(),
    const SingleActivator(LogicalKeyboardKey.keyF, includeRepeats: false): const FavoriteIntent(),
  };
}
