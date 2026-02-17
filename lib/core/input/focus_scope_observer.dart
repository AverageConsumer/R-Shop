import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'input_providers.dart';

class FocusScopeObserver extends NavigatorObserver {
  final FocusStateManager focusStateManager;

  FocusScopeObserver(this.focusStateManager);

  @override
  void didPush(Route route, Route? previousRoute) {
    super.didPush(route, previousRoute);

    final previousRouteId = _getRouteId(previousRoute);
    if (previousRouteId != null) {
      final currentFocus = FocusManager.instance.primaryFocus;
      focusStateManager.saveFocusState(
        previousRouteId,
        savedFocusNode: currentFocus,
      );
    }
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    super.didPop(route, previousRoute);

    final previousRouteId = _getRouteId(previousRoute);
    if (previousRouteId != null) {
      final savedState = focusStateManager.getFocusState(previousRouteId);
      if (savedState?.savedFocusNode != null &&
          savedState!.savedFocusNode!.canRequestFocus) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // Re-check canRequestFocus after the frame, as the node may have been disposed
          if (savedState.savedFocusNode!.canRequestFocus) {
            savedState.savedFocusNode!.requestFocus();
          }
        });
      }
    }

    final routeId = _getRouteId(route);
    if (routeId != null) {
      focusStateManager.clearFocusState(routeId);
    }
  }

  @override
  void didRemove(Route route, Route? previousRoute) {
    super.didRemove(route, previousRoute);

    final routeId = _getRouteId(route);
    if (routeId != null) {
      focusStateManager.clearFocusState(routeId);
    }
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);

    final oldRouteId = _getRouteId(oldRoute);
    if (oldRouteId != null) {
      focusStateManager.clearFocusState(oldRouteId);
    }
  }

  String? _getRouteId(Route? route) {
    if (route == null) return null;

    if (route is PageRoute) {
      return route.settings.name;
    }

    return route.runtimeType.toString();
  }
}

final focusScopeObserverProvider = Provider<FocusScopeObserver>((ref) {
  return FocusScopeObserver(ref.read(focusStateManagerProvider.notifier));
});
