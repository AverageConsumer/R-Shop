import 'package:flutter/widgets.dart';

enum GridDirection { up, down, left, right }

class BackIntent extends Intent {
  const BackIntent();
}

class ConfirmIntent extends Intent {
  const ConfirmIntent();
}

class SearchIntent extends Intent {
  const SearchIntent();
}

class ToggleOverlayIntent extends Intent {
  const ToggleOverlayIntent();
}

class NavigateIntent extends Intent {
  final GridDirection direction;
  const NavigateIntent(this.direction);
}

class AdjustColumnsIntent extends Intent {
  final bool increase;
  const AdjustColumnsIntent({required this.increase});
}

class MenuIntent extends Intent {
  const MenuIntent();
}

class TabLeftIntent extends Intent {
  const TabLeftIntent();
}

class TabRightIntent extends Intent {
  const TabRightIntent();
}

class FavoriteIntent extends Intent {
  const FavoriteIntent();
}

