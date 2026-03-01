import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';
import 'app_intents.dart';
import 'global_input_wrapper.dart';

mixin ConsoleScreenMixin<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  late final FocusNode screenFocusNode;
  late final FocusStateManager _focusStateManager;

  @protected
  FocusStateManager get focusStateManager => _focusStateManager;

  String get routeId;

  Map<Type, Action<Intent>> get screenActions => {};

  Map<ShortcutActivator, Intent>? get additionalShortcuts => null;

  @override
  void initState() {
    super.initState();
    screenFocusNode = FocusNode(debugLabel: 'Screen_$routeId');
    _focusStateManager = ref.read(focusStateManagerProvider.notifier);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(mainFocusRequestProvider.notifier).state = screenFocusNode;
      _restoreFocus();
    });
  }

  void _restoreFocus() {
    try {
      final savedState = ref.read(focusStateManagerProvider)[routeId];
      if (savedState?.savedFocusNode?.canRequestFocus == true) {
        savedState!.savedFocusNode!.requestFocus();
      } else {
        screenFocusNode.requestFocus();
      }
    } catch (e) {
      debugPrint('ConsoleScreenMixin: focus restore failed for $routeId: $e');
      if (screenFocusNode.canRequestFocus) {
        screenFocusNode.requestFocus();
      }
    }
  }

  void requestScreenFocus() {
    if (screenFocusNode.canRequestFocus) {
      screenFocusNode.requestFocus();
    }
  }

  // --- Quick Menu ---

  bool _showQuickMenu = false;
  bool get showQuickMenu => _showQuickMenu;

  void toggleQuickMenu() {
    if (_showQuickMenu) return;
    if (ref.read(overlayPriorityProvider) != OverlayPriority.none) return;
    ref.read(feedbackServiceProvider).tick();
    setState(() => _showQuickMenu = true);
  }

  void closeQuickMenu() {
    setState(() => _showQuickMenu = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) requestScreenFocus();
    });
  }

  @override
  void dispose() {
    // Capture focus state synchronously before FocusNode is disposed
    final currentFocus = FocusManager.instance.primaryFocus;
    if (currentFocus != null && currentFocus != screenFocusNode) {
      final id = routeId;
      // Defer state modification — dispose runs during widget tree
      // finalization where Riverpod prohibits provider mutations
      Future.microtask(() {
        // Only save if the node is still usable (may have been disposed
        // along with its owning widget by the time this microtask runs)
        if (currentFocus.canRequestFocus) {
          _focusStateManager.saveFocusState(id, savedFocusNode: currentFocus);
        }
      });
    }
    screenFocusNode.dispose();
    super.dispose();
  }

  void saveFocusState({
    int? selectedIndex,
    String? focusedElementId,
    Map<String, dynamic>? metadata,
  }) {
    _focusStateManager.saveFocusState(
          routeId,
          selectedIndex: selectedIndex,
          focusedElementId: focusedElementId,
          metadata: metadata ?? const {},
        );
  }

  FocusStateEntry? getSavedFocusState() {
    return _focusStateManager.getFocusState(routeId);
  }

  int? get savedSelectedIndex => getSavedFocusState()?.selectedIndex;

  Widget buildWithActions(Widget child,
      {KeyEventResult Function(FocusNode, KeyEvent)? onKeyEvent}) {
    return ScreenActionsWrapper(
      screenActions: screenActions,
      additionalShortcuts: additionalShortcuts,
      child: Focus(
        focusNode: screenFocusNode,
        onKeyEvent: onKeyEvent,
        autofocus: true,
        child: child,
      ),
    );
  }
}

/// Adjusts column count within [minColumns]..[maxColumns] and persists via
/// [gridColumnsProvider]. Returns the new column count, or [current] if the
/// adjustment would go out of bounds.
int adjustColumnCount({
  required int current,
  required bool increase,
  int minColumns = 3,
  int maxColumns = 8,
  required String providerKey,
  required WidgetRef ref,
}) {
  final next = increase ? current + 1 : current - 1;
  if (next < minColumns || next > maxColumns) return current;
  ref.read(gridColumnsProvider(providerKey).notifier).setColumns(next);
  return next;
}

mixin ConsoleGridScreenMixin<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  late final FocusNode screenFocusNode;
  late final FocusStateManager _focusStateManager;

  String get routeId;

  int get currentSelectedIndex;
  set currentSelectedIndex(int value);

  void onNavigate(GridDirection direction);
  void onConfirm();

  Map<Type, Action<Intent>> get screenActions => {};

  @override
  void initState() {
    super.initState();
    screenFocusNode = FocusNode(debugLabel: 'GridScreen_$routeId');
    _focusStateManager = ref.read(focusStateManagerProvider.notifier);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreFocus();
    });
  }

  void _restoreFocus() {
    final savedState = ref.read(focusStateManagerProvider)[routeId];
    if (savedState?.selectedIndex != null) {
      currentSelectedIndex = savedState!.selectedIndex!;
    }

    if (screenFocusNode.canRequestFocus) {
      screenFocusNode.requestFocus();
    }
  }

  void requestScreenFocus() {
    if (screenFocusNode.canRequestFocus) {
      screenFocusNode.requestFocus();
    }
  }

  @override
  void dispose() {
    final index = currentSelectedIndex;
    final id = routeId;
    // Defer state modification — dispose runs during widget tree
    // finalization where Riverpod prohibits provider mutations
    Future.microtask(() {
      _focusStateManager.saveFocusState(id, selectedIndex: index);
    });
    screenFocusNode.dispose();
    super.dispose();
  }

  Map<Type, Action<Intent>> get gridActions => {
        NavigateIntent: _GridNavigateAction(this, ref),
        ConfirmIntent: CallbackAction<ConfirmIntent>(
          onInvoke: (_) {
            onConfirm();
            return null;
          },
        ),
        ...screenActions,
      };

  Widget buildWithGridActions(Widget child) {
    return ScreenActionsWrapper(
      screenActions: gridActions,
      child: Focus(
        focusNode: screenFocusNode,
        autofocus: true,
        child: child,
      ),
    );
  }
}

class _GridNavigateAction extends Action<NavigateIntent> {
  final ConsoleGridScreenMixin<dynamic> screen;
  final WidgetRef ref;

  _GridNavigateAction(this.screen, this.ref);

  @override
  bool isEnabled(NavigateIntent intent) =>
      ref.read(overlayPriorityProvider) == OverlayPriority.none;

  @override
  Object? invoke(NavigateIntent intent) {
    screen.onNavigate(intent.direction);
    return null;
  }
}
