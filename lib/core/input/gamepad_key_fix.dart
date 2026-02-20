import 'dart:ui' as ui;

/// Fixes inconsistent logical key mappings from certain gamepad drivers.
///
/// Some devices (e.g. AYN Thor) send mismatched logical keys between
/// key-down and key-up events for the same physical key, causing Flutter's
/// `HardwareKeyboard._assertEventIsRegular` to flood assertion errors.
///
/// This intercepts `onKeyData` at the lowest level (before HardwareKeyboard)
/// and corrects the logical key on up/repeat events to match what was
/// recorded on the corresponding down event.
void installGamepadKeyFix() {
  final originalHandler = ui.PlatformDispatcher.instance.onKeyData;
  if (originalHandler == null) return;

  final Map<int, int> pressedLogicalKeys = {};

  ui.PlatformDispatcher.instance.onKeyData = (ui.KeyData data) {
    var corrected = data;

    switch (data.type) {
      case ui.KeyEventType.down:
        pressedLogicalKeys[data.physical] = data.logical;
      case ui.KeyEventType.up:
        final recorded = pressedLogicalKeys.remove(data.physical);
        if (recorded != null && recorded != data.logical) {
          corrected = ui.KeyData(
            timeStamp: data.timeStamp,
            type: data.type,
            physical: data.physical,
            logical: recorded,
            character: data.character,
            synthesized: data.synthesized,
          );
        }
      case ui.KeyEventType.repeat:
        final recorded = pressedLogicalKeys[data.physical];
        if (recorded != null && recorded != data.logical) {
          corrected = ui.KeyData(
            timeStamp: data.timeStamp,
            type: data.type,
            physical: data.physical,
            logical: recorded,
            character: data.character,
            synthesized: data.synthesized,
          );
        }
    }

    return originalHandler(corrected);
  };
}
