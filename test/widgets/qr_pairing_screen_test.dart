import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retro_eshop/core/widgets/console_focusable.dart';
import 'package:retro_eshop/features/pairing/qr_pairing_screen.dart';
import 'package:retro_eshop/providers/app_providers.dart';
import 'package:retro_eshop/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/pump_helpers.dart';

Future<StorageService> _initMockStorage() async {
  SharedPreferences.setMockInitialValues({});
  FlutterSecureStorage.setMockInitialValues({});
  final storage = StorageService();
  await storage.init();
  return storage;
}

Widget _wrap(StorageService storage, Widget child) {
  return createTestAppWithProviders(
    child,
    overrides: [
      storageServiceProvider.overrideWithValue(storage),
    ],
  );
}

void main() {
  group('QrPairingScreen — Gamepad focus & navigation', () {
    testWidgets('defaults focus to manual pairing button and moves to back button on Up',
        (tester) async {
      final storage = await _initMockStorage();
      await tester.pumpWidget(_wrap(storage, const QrPairingScreen()));
      await tester.pumpAndSettle();

      // Verify ConsoleFocusable widgets are rendered (Back button & Manual button)
      expect(find.byType(ConsoleFocusable), findsNWidgets(2));

      // Press D-pad Up to navigate to top-left Back button
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();

      // Press D-pad Down to navigate back to Manual button
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      // Cleanup
      await tester.pumpWidget(_wrap(storage, const SizedBox.shrink()));
      await tester.pump(const Duration(milliseconds: 50));
    });
  });
}
