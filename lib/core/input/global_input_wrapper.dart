import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_actions.dart';
import 'app_intents.dart';

class GlobalInputWrapper extends ConsumerWidget {
  final Widget child;

  const GlobalInputWrapper({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Shortcuts(
      shortcuts: AppShortcuts.defaultShortcuts,
      child: Actions(
        actions: _buildActions(context, ref),
        child: child,
      ),
    );
  }

  Map<Type, Action<Intent>> _buildActions(BuildContext context, WidgetRef ref) {
    return {
      BackIntent: BackAction(context, ref),
      ConfirmIntent: ConfirmAction(ref),
      SearchIntent: SearchAction(ref),
      ToggleOverlayIntent: ToggleOverlayAction(ref),
      NavigateIntent: NavigateAction(ref),
      AdjustColumnsIntent: AdjustColumnsAction(ref),
      InfoIntent: InfoAction(ref),
      MenuIntent: MenuAction(ref),
    };
  }
}

class ScreenActionsWrapper extends ConsumerWidget {
  final Widget child;
  final Map<Type, Action<Intent>> screenActions;
  final Map<ShortcutActivator, Intent>? additionalShortcuts;

  const ScreenActionsWrapper({
    super.key,
    required this.child,
    this.screenActions = const {},
    this.additionalShortcuts,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final combinedShortcuts = <ShortcutActivator, Intent>{
      ...AppShortcuts.defaultShortcuts,
      if (additionalShortcuts != null) ...additionalShortcuts!,
    };

    return Shortcuts(
      shortcuts: combinedShortcuts,
      child: Actions(
        actions: screenActions,
        child: child,
      ),
    );
  }
}
