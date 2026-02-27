import '../services/storage_service.dart';

/// Maps logical button IDs (Nintendo convention) to SVG asset paths
/// for each [ControllerLayout].
///
/// Button IDs: a, b, x, y, l, r, zl, zr, plus, minus, dpad
class GamepadIcons {
  GamepadIcons._();

  static String assetPath(String buttonId, ControllerLayout layout) {
    return switch (layout) {
      ControllerLayout.nintendo => _nintendo(buttonId),
      ControllerLayout.xbox => _xbox(buttonId),
      ControllerLayout.playstation => _playstation(buttonId),
    };
  }

  static String _nintendo(String id) {
    const base = 'assets/gamepad/nintendo';
    return switch (id) {
      'a' => '$base/switch_button_a.svg',
      'b' => '$base/switch_button_b.svg',
      'x' => '$base/switch_button_x.svg',
      'y' => '$base/switch_button_y.svg',
      'l' => '$base/switch_button_l.svg',
      'r' => '$base/switch_button_r.svg',
      'zl' => '$base/switch_button_zl.svg',
      'zr' => '$base/switch_button_zr.svg',
      'plus' => '$base/switch_button_plus.svg',
      'minus' => '$base/switch_button_minus.svg',
      'dpad' => '$base/switch_dpad_horizontal.svg',
      _ => '$base/switch_button_a.svg',
    };
  }

  static String _xbox(String id) {
    const base = 'assets/gamepad/xbox';
    return switch (id) {
      'a' => '$base/xbox_button_color_a.svg',
      'b' => '$base/xbox_button_color_b.svg',
      'x' => '$base/xbox_button_color_x.svg',
      'y' => '$base/xbox_button_color_y.svg',
      'l' => '$base/xbox_lb.svg',
      'r' => '$base/xbox_rb.svg',
      'zl' => '$base/xbox_lt.svg',
      'zr' => '$base/xbox_rt.svg',
      'plus' => '$base/xbox_button_menu.svg',
      'minus' => '$base/xbox_button_view.svg',
      'dpad' => '$base/xbox_dpad_horizontal.svg',
      _ => '$base/xbox_button_color_a.svg',
    };
  }

  static String _playstation(String id) {
    const base = 'assets/gamepad/playstation';
    return switch (id) {
      'a' => '$base/playstation_button_color_cross.svg',
      'b' => '$base/playstation_button_color_circle.svg',
      'x' => '$base/playstation_button_color_square.svg',
      'y' => '$base/playstation_button_color_triangle.svg',
      'l' => '$base/playstation_trigger_l1.svg',
      'r' => '$base/playstation_trigger_r1.svg',
      'zl' => '$base/playstation_trigger_l2.svg',
      'zr' => '$base/playstation_trigger_r2.svg',
      'plus' => '$base/playstation5_button_options.svg',
      'minus' => '$base/playstation5_button_create.svg',
      'dpad' => '$base/playstation_dpad_horizontal.svg',
      _ => '$base/playstation_button_color_cross.svg',
    };
  }
}
