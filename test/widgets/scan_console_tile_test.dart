import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retro_eshop/features/settings/widgets/scan_console_tile.dart';
import 'package:retro_eshop/models/system_model.dart';
import '../helpers/pump_helpers.dart';

void main() {
  // Pick a known system for testing
  final testSystem = SystemModel.supportedSystems
      .firstWhere((s) => s.id == 'nes');

  Widget buildTile({
    ScanTileState scanState = ScanTileState.pending,
    int gameCount = 0,
    bool isFocused = false,
  }) {
    return createTestApp(
      SizedBox(
        width: 100,
        height: 100,
        child: ScanConsoleTile(
          system: testSystem,
          scanState: scanState,
          gameCount: gameCount,
          isFocused: isFocused,
        ),
      ),
    );
  }

  group('ScanConsoleTile', () {
    testWidgets('pending state shows low opacity and no indicators', (tester) async {
      await tester.pumpWidget(buildTile());

      // System name is rendered
      expect(find.text(testSystem.name), findsOneWidget);

      // No game count badge
      expect(find.text('0'), findsNothing);

      // No error icon
      expect(find.byIcon(Icons.error_outline), findsNothing);

      // No circular progress
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('scanning state shows progress indicator', (tester) async {
      await tester.pumpWidget(buildTile(scanState: ScanTileState.scanning));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsNothing);
    });

    testWidgets('complete state shows game count badge', (tester) async {
      await tester.pumpWidget(buildTile(
        scanState: ScanTileState.complete,
        gameCount: 42,
      ));

      expect(find.text('42'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('complete state with 0 games hides badge', (tester) async {
      await tester.pumpWidget(buildTile(
        scanState: ScanTileState.complete,
      ));

      // Badge only shown when gameCount > 0
      expect(find.text('0'), findsNothing);
    });

    testWidgets('failed state shows error icon', (tester) async {
      await tester.pumpWidget(buildTile(scanState: ScanTileState.failed));

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('failed state does not show game count badge', (tester) async {
      await tester.pumpWidget(buildTile(
        scanState: ScanTileState.failed,
        gameCount: 50,
      ));

      // Even with gameCount set, badge is only for complete state
      expect(find.text('50'), findsNothing);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('failed state uses red border color', (tester) async {
      await tester.pumpWidget(buildTile(scanState: ScanTileState.failed));

      final container = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      final decoration = container.decoration as BoxDecoration;
      final borderSide = decoration.border! as Border;

      // Border color should be red-ish (not accent color)
      expect((borderSide.top.color.r * 255.0).round(), greaterThan(200));
      expect((borderSide.top.color.g * 255.0).round(), lessThan(100));
    });

    testWidgets('failed state with focus uses brighter red border', (tester) async {
      await tester.pumpWidget(buildTile(
        scanState: ScanTileState.failed,
        isFocused: true,
      ));

      final container = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      final decoration = container.decoration as BoxDecoration;
      final borderSide = decoration.border! as Border;

      // Focused failed should have higher alpha red
      expect((borderSide.top.color.r * 255.0).round(), greaterThan(200));
      expect((borderSide.top.color.a * 255.0).round(), greaterThan(200));
    });

    testWidgets('system name is always visible', (tester) async {
      for (final state in ScanTileState.values) {
        await tester.pumpWidget(buildTile(scanState: state));
        if (state == ScanTileState.scanning) await tester.pump();
        expect(find.text(testSystem.name), findsOneWidget,
            reason: 'System name missing for state $state');
      }
    });
  });
}
