import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_intents.dart';
import '../../providers/app_providers.dart';
import '../../widgets/download_overlay.dart';

class BackAction extends Action<BackIntent> {
  final BuildContext context;
  final WidgetRef ref;

  BackAction(this.context, this.ref);

  @override
  Object? invoke(BackIntent intent) {
    if (!ref.read(inputDebouncerProvider).canPerformAction()) return null;
    final overlayPriority = ref.read(overlayPriorityProvider);
    if (overlayPriority != OverlayPriority.none) {
      return null;
    }

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
  Object? invoke(ConfirmIntent intent) {
    if (!ref.read(inputDebouncerProvider).canPerformAction()) return null;
    if (onConfirm != null) {
      ref.read(feedbackServiceProvider).confirm();
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
  Object? invoke(SearchIntent intent) {
    if (!ref.read(inputDebouncerProvider).canPerformAction()) return null;
    // Search might be allowed even if overlay is open in some cases,
    // but for now let's respect priority
    final overlayPriority = ref.read(overlayPriorityProvider);
    if (overlayPriority != OverlayPriority.none && overlayPriority != OverlayPriority.search) {
      return null;
    }

    ref.read(feedbackServiceProvider).tick();

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

  ToggleOverlayAction(this.ref);

  @override
  Object? invoke(ToggleOverlayIntent intent) {
    if (!ref.read(inputDebouncerProvider).canPerformAction()) return null;
    ref.read(feedbackServiceProvider).tick();
    toggleDownloadOverlay(ref);
    return null;
  }
}

class NavigateAction extends Action<NavigateIntent> {
  final WidgetRef ref;
  final bool Function(NavigateIntent intent)? onNavigate;

  NavigateAction(this.ref, {this.onNavigate});

  @override
  Object? invoke(NavigateIntent intent) {
    final overlayPriority = ref.read(overlayPriorityProvider);
    if (overlayPriority != OverlayPriority.none) {
      return null;
    }

    if (onNavigate != null) {
      final handled = onNavigate!(intent);
      if (handled) {
        ref.read(feedbackServiceProvider).tick();
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
  Object? invoke(AdjustColumnsIntent intent) {
    if (!ref.read(inputDebouncerProvider).canPerformAction()) return null;
    final overlayPriority = ref.read(overlayPriorityProvider);
    if (overlayPriority != OverlayPriority.none) {
      return null;
    }

    ref.read(feedbackServiceProvider).tick();
    onAdjust?.call(intent.increase);
    return null;
  }
}

class InfoAction extends Action<InfoIntent> {
  final WidgetRef ref;
  final VoidCallback? onInfo;

  InfoAction(this.ref, {this.onInfo});

  @override
  Object? invoke(InfoIntent intent) {
    if (!ref.read(inputDebouncerProvider).canPerformAction()) return null;
    final overlayPriority = ref.read(overlayPriorityProvider);
    if (overlayPriority != OverlayPriority.none) {
      return null;
    }

    ref.read(feedbackServiceProvider).tick();
    onInfo?.call();
    return null;
  }
}

class MenuAction extends Action<MenuIntent> {
  final WidgetRef ref;
  final VoidCallback? onMenu;

  MenuAction(this.ref, {this.onMenu});

  @override
  Object? invoke(MenuIntent intent) {
    if (!ref.read(inputDebouncerProvider).canPerformAction()) return null;
    final overlayPriority = ref.read(overlayPriorityProvider);
    if (overlayPriority != OverlayPriority.none) {
      return null;
    }

    ref.read(feedbackServiceProvider).tick();
    onMenu?.call();
    return null;
  }
}

class TabLeftAction extends Action<TabLeftIntent> {
  final WidgetRef ref;
  final VoidCallback? onTabLeft;

  TabLeftAction(this.ref, {this.onTabLeft});

  @override
  Object? invoke(TabLeftIntent intent) {
    if (!ref.read(inputDebouncerProvider).canPerformAction()) return null;
    final overlayPriority = ref.read(overlayPriorityProvider);
    if (overlayPriority != OverlayPriority.none) {
      return null;
    }

    if (onTabLeft != null) {
      ref.read(feedbackServiceProvider).tick();
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
  Object? invoke(TabRightIntent intent) {
    if (!ref.read(inputDebouncerProvider).canPerformAction()) return null;
    final overlayPriority = ref.read(overlayPriorityProvider);
    if (overlayPriority != OverlayPriority.none) {
      return null;
    }

    if (onTabRight != null) {
      ref.read(feedbackServiceProvider).tick();
      onTabRight!();
    }
    return null;
  }
}

class AppShortcuts {
  static Map<ShortcutActivator, Intent> get defaultShortcuts => {
    // Back
    const SingleActivator(LogicalKeyboardKey.gameButtonB): const BackIntent(),
    const SingleActivator(LogicalKeyboardKey.escape): const BackIntent(),
    const SingleActivator(LogicalKeyboardKey.backspace): const BackIntent(),
    const SingleActivator(LogicalKeyboardKey.goBack): const BackIntent(),

    // Confirm
    const SingleActivator(LogicalKeyboardKey.gameButtonA): const ConfirmIntent(),
    const SingleActivator(LogicalKeyboardKey.enter): const ConfirmIntent(),
    const SingleActivator(LogicalKeyboardKey.numpadEnter): const ConfirmIntent(),
    const SingleActivator(LogicalKeyboardKey.space): const ConfirmIntent(),
    const SingleActivator(LogicalKeyboardKey.select): const ConfirmIntent(),

    // Search
    const SingleActivator(LogicalKeyboardKey.gameButtonY): const SearchIntent(),
    const SingleActivator(LogicalKeyboardKey.keyI): const SearchIntent(),

    // Overlay
    const SingleActivator(LogicalKeyboardKey.gameButtonStart): const ToggleOverlayIntent(),

    // Navigation
    const SingleActivator(LogicalKeyboardKey.arrowUp): const NavigateIntent(GridDirection.up),
    const SingleActivator(LogicalKeyboardKey.arrowDown): const NavigateIntent(GridDirection.down),
    const SingleActivator(LogicalKeyboardKey.arrowLeft): const NavigateIntent(GridDirection.left),
    const SingleActivator(LogicalKeyboardKey.arrowRight): const NavigateIntent(GridDirection.right),
    
    // Tabs / L1 R1
    const SingleActivator(LogicalKeyboardKey.gameButtonLeft1): const TabLeftIntent(),
    const SingleActivator(LogicalKeyboardKey.gameButtonRight1): const TabRightIntent(),
    const SingleActivator(LogicalKeyboardKey.pageUp): const TabLeftIntent(),
    const SingleActivator(LogicalKeyboardKey.pageDown): const TabRightIntent(),
    const SingleActivator(LogicalKeyboardKey.bracketLeft): const TabLeftIntent(),
    const SingleActivator(LogicalKeyboardKey.bracketRight): const TabRightIntent(),

    // Info
    const SingleActivator(LogicalKeyboardKey.gameButtonX): const InfoIntent(),
  };
}
