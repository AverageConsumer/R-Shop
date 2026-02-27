import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:retro_eshop/providers/app_providers.dart';
import 'package:retro_eshop/services/storage_service.dart';
import 'package:retro_eshop/widgets/console_hud.dart';
import 'package:retro_eshop/widgets/control_button.dart';
import '../helpers/pump_helpers.dart';

Future<StorageService> _createMockStorage({
  ControllerLayout layout = ControllerLayout.nintendo,
}) async {
  SharedPreferences.setMockInitialValues({
    'controller_layout': layout.name,
  });
  FlutterSecureStorage.setMockInitialValues({});
  final storage = StorageService();
  await storage.init();
  return storage;
}

List<Override> _overrides(StorageService storage) => [
      storageServiceProvider.overrideWithValue(storage),
    ];

void main() {
  group('ConsoleHud', () {
    testWidgets('no buttons returns SizedBox.shrink', (tester) async {
      final storage = await _createMockStorage();
      await tester.pumpWidget(createTestAppWithProviders(
        const Stack(children: [ConsoleHud()]),
        overrides: _overrides(storage),
      ));

      expect(find.byType(SizedBox), findsWidgets);
      expect(find.byType(ControlButton), findsNothing);
    });

    testWidgets('Nintendo layout renders SVG buttons for A/B', (tester) async {
      final storage = await _createMockStorage(layout: ControllerLayout.nintendo);
      await tester.pumpWidget(createTestAppWithProviders(
        const Stack(children: [
          ConsoleHud(
            a: HudAction('Confirm'),
            b: HudAction('Back'),
          ),
        ]),
        overrides: _overrides(storage),
      ));

      // Both A and B should render as SVG icons
      expect(find.byType(SvgPicture), findsNWidgets(2));
      expect(find.text('Confirm'), findsOneWidget);
      expect(find.text('Back'), findsOneWidget);
    });

    testWidgets('Xbox layout renders SVG buttons (swapped display positions)', (tester) async {
      final storage = await _createMockStorage(layout: ControllerLayout.xbox);
      await tester.pumpWidget(createTestAppWithProviders(
        const Stack(children: [
          ConsoleHud(
            a: HudAction('Confirm'),
            b: HudAction('Back'),
          ),
        ]),
        overrides: _overrides(storage),
      ));

      expect(find.byType(SvgPicture), findsNWidgets(2));
      expect(find.text('Confirm'), findsOneWidget);
      expect(find.text('Back'), findsOneWidget);
    });

    testWidgets('PlayStation layout renders SVG icons', (tester) async {
      final storage = await _createMockStorage(layout: ControllerLayout.playstation);
      await tester.pumpWidget(createTestAppWithProviders(
        const Stack(children: [
          ConsoleHud(
            a: HudAction('Confirm'),
            b: HudAction('Back'),
          ),
        ]),
        overrides: _overrides(storage),
      ));

      expect(find.byType(SvgPicture), findsNWidgets(2));
      expect(find.text('Confirm'), findsOneWidget);
      expect(find.text('Back'), findsOneWidget);
    });

    testWidgets('Xbox face buttons all render SVGs', (tester) async {
      final storage = await _createMockStorage(layout: ControllerLayout.xbox);
      await tester.pumpWidget(createTestAppWithProviders(
        const Stack(children: [
          ConsoleHud(
            a: HudAction('Go'),
            b: HudAction('Stop'),
            x: HudAction('Special'),
            y: HudAction('Alt'),
          ),
        ]),
        overrides: _overrides(storage),
      ));

      expect(find.byType(ControlButton), findsNWidgets(4));
      expect(find.byType(SvgPicture), findsNWidgets(4));
    });

    testWidgets('Nintendo Start renders SVG (plus button)', (tester) async {
      final storage = await _createMockStorage(layout: ControllerLayout.nintendo);
      await tester.pumpWidget(createTestAppWithProviders(
        const Stack(children: [
          ConsoleHud(start: HudAction('Menu')),
        ]),
        overrides: _overrides(storage),
      ));

      expect(find.byType(SvgPicture), findsOneWidget);
    });

    testWidgets('Xbox Start renders SVG (menu button)', (tester) async {
      final storage = await _createMockStorage(layout: ControllerLayout.xbox);
      await tester.pumpWidget(createTestAppWithProviders(
        const Stack(children: [
          ConsoleHud(start: HudAction('Menu')),
        ]),
        overrides: _overrides(storage),
      ));

      expect(find.byType(SvgPicture), findsOneWidget);
    });

    testWidgets('PlayStation Start/Select render SVGs', (tester) async {
      final storage = await _createMockStorage(layout: ControllerLayout.playstation);
      await tester.pumpWidget(createTestAppWithProviders(
        const Stack(children: [
          ConsoleHud(
            start: HudAction('Options'),
            select: HudAction('Share'),
          ),
        ]),
        overrides: _overrides(storage),
      ));

      expect(find.byType(SvgPicture), findsNWidgets(2));
    });

    testWidgets('Nintendo LB/RB render SVGs', (tester) async {
      final storage = await _createMockStorage(layout: ControllerLayout.nintendo);
      await tester.pumpWidget(createTestAppWithProviders(
        const Stack(children: [
          ConsoleHud(
            lb: HudAction('Prev'),
            rb: HudAction('Next'),
          ),
        ]),
        overrides: _overrides(storage),
      ));

      expect(find.byType(SvgPicture), findsNWidgets(2));
    });

    testWidgets('Xbox LB/RB render SVGs', (tester) async {
      final storage = await _createMockStorage(layout: ControllerLayout.xbox);
      await tester.pumpWidget(createTestAppWithProviders(
        const Stack(children: [
          ConsoleHud(
            lb: HudAction('Prev'),
            rb: HudAction('Next'),
          ),
        ]),
        overrides: _overrides(storage),
      ));

      expect(find.byType(SvgPicture), findsNWidgets(2));
    });

    testWidgets('PlayStation LB/RB render SVGs', (tester) async {
      final storage = await _createMockStorage(layout: ControllerLayout.playstation);
      await tester.pumpWidget(createTestAppWithProviders(
        const Stack(children: [
          ConsoleHud(
            lb: HudAction('Prev'),
            rb: HudAction('Next'),
          ),
        ]),
        overrides: _overrides(storage),
      ));

      expect(find.byType(SvgPicture), findsNWidgets(2));
    });

    testWidgets('embedded=true has no Positioned wrapper', (tester) async {
      final storage = await _createMockStorage();
      await tester.pumpWidget(createTestAppWithProviders(
        const ConsoleHud(
          a: HudAction('Confirm'),
          embedded: true,
        ),
        overrides: _overrides(storage),
      ));

      expect(find.byType(Positioned), findsNothing);
      expect(find.byType(Padding), findsWidgets);
    });

    testWidgets('embedded=false has Positioned wrapper', (tester) async {
      final storage = await _createMockStorage();
      await tester.pumpWidget(createTestAppWithProviders(
        const Stack(children: [
          ConsoleHud(
            a: HudAction('Confirm'),
            embedded: false,
          ),
        ]),
        overrides: _overrides(storage),
      ));

      expect(find.byType(Positioned), findsOneWidget);
    });

    testWidgets('only set buttons are rendered', (tester) async {
      final storage = await _createMockStorage();
      await tester.pumpWidget(createTestAppWithProviders(
        const Stack(children: [
          ConsoleHud(
            a: HudAction('Confirm'),
          ),
        ]),
        overrides: _overrides(storage),
      ));

      expect(find.byType(ControlButton), findsOneWidget);
    });

    testWidgets('HudAction.highlight passes highlight=true to ControlButton', (tester) async {
      final storage = await _createMockStorage();
      await tester.pumpWidget(createTestAppWithProviders(
        const Stack(children: [
          ConsoleHud(
            a: HudAction('Delete', highlight: true),
          ),
        ]),
        overrides: _overrides(storage),
      ));

      // highlight=true → action text has redAccent color
      final actionText = tester.widget<Text>(find.text('Delete'));
      expect(
        actionText.style!.color,
        Colors.redAccent.withValues(alpha: 0.7),
      );
    });
  });
}
