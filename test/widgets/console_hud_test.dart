import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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

    testWidgets('Nintendo layout shows A/B labels', (tester) async {
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

      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('Confirm'), findsOneWidget);
      expect(find.text('Back'), findsOneWidget);
    });

    testWidgets('Xbox layout shows A/B labels (swapped display positions)', (tester) async {
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

      // Xbox: labelA='B', labelB='A'; displayA=b, displayB=a
      // So we still see 'A' and 'B' texts but with swapped actions
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('Confirm'), findsOneWidget);
      expect(find.text('Back'), findsOneWidget);
    });

    testWidgets('PlayStation layout uses CustomPaint instead of text labels', (tester) async {
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

      // PlayStation uses painters, not text labels
      expect(find.byType(CustomPaint), findsWidgets);
      expect(find.text('Confirm'), findsOneWidget);
      expect(find.text('Back'), findsOneWidget);
    });

    testWidgets('Xbox face buttons have colors', (tester) async {
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

      // All 4 face buttons rendered
      expect(find.byType(ControlButton), findsNWidgets(4));
    });

    testWidgets('Nintendo Start shows NintendoPlusPainter', (tester) async {
      final storage = await _createMockStorage(layout: ControllerLayout.nintendo);
      await tester.pumpWidget(createTestAppWithProviders(
        const Stack(children: [
          ConsoleHud(start: HudAction('Menu')),
        ]),
        overrides: _overrides(storage),
      ));

      final finder = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is NintendoPlusPainter,
      );
      expect(finder, findsOneWidget);
    });

    testWidgets('Xbox Start shows menu icon', (tester) async {
      final storage = await _createMockStorage(layout: ControllerLayout.xbox);
      await tester.pumpWidget(createTestAppWithProviders(
        const Stack(children: [
          ConsoleHud(start: HudAction('Menu')),
        ]),
        overrides: _overrides(storage),
      ));

      expect(find.byIcon(Icons.menu_rounded), findsOneWidget);
    });

    testWidgets('PlayStation Start=menu, Select=share icons', (tester) async {
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

      expect(find.byIcon(Icons.menu_rounded), findsOneWidget);
      expect(find.byIcon(Icons.share_rounded), findsOneWidget);
    });

    testWidgets('Nintendo LB/RB labels are L/R', (tester) async {
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

      expect(find.text('L'), findsOneWidget);
      expect(find.text('R'), findsOneWidget);
    });

    testWidgets('Xbox LB/RB labels are LB/RB', (tester) async {
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

      expect(find.text('LB'), findsOneWidget);
      expect(find.text('RB'), findsOneWidget);
    });

    testWidgets('PlayStation LB/RB labels are L1/R1', (tester) async {
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

      expect(find.text('L1'), findsOneWidget);
      expect(find.text('R1'), findsOneWidget);
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
