import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:retro_eshop/widgets/control_button.dart';
import '../helpers/pump_helpers.dart';

void main() {
  group('ControlButton', () {
    testWidgets('renders label text', (tester) async {
      await tester.pumpWidget(createTestApp(
        const ControlButton(label: 'A', action: 'Confirm'),
      ));

      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('renders action text', (tester) async {
      await tester.pumpWidget(createTestApp(
        const ControlButton(label: 'A', action: 'Confirm'),
      ));

      expect(find.text('Confirm'), findsOneWidget);
    });

    testWidgets('face button "A" gets circle shape (borderRadius = buttonSize)', (tester) async {
      await tester.pumpWidget(createTestApp(
        const ControlButton(label: 'A', action: 'Confirm'),
      ));

      // Find the button container (first Container descendant of ControlButton)
      final containers = tester.widgetList<Container>(
        find.descendant(
          of: find.byType(ControlButton),
          matching: find.byType(Container),
        ),
      ).toList();
      // The first container is the button shape
      final decoration = containers.first.decoration as BoxDecoration;
      // For face buttons, borderRadius = buttonSize (circle), not pill
      // Default medium: buttonSize = 28.0
      expect(decoration.borderRadius, BorderRadius.circular(28.0));
    });

    testWidgets('shoulder button "LB" gets pill shape', (tester) async {
      await tester.pumpWidget(createTestApp(
        const ControlButton(label: 'LB', action: 'Prev'),
      ));

      final containers = tester.widgetList<Container>(
        find.descendant(
          of: find.byType(ControlButton),
          matching: find.byType(Container),
        ),
      ).toList();
      final decoration = containers.first.decoration as BoxDecoration;
      // For pill: borderRadius = buttonSize * 0.35
      // Default medium: buttonSize = 28.0, pillRadius = 28 * 0.35 = 9.8
      expect(decoration.borderRadius, BorderRadius.circular(28.0 * 0.35));
    });

    testWidgets('highlight=true uses redAccent label color', (tester) async {
      await tester.pumpWidget(createTestApp(
        const ControlButton(label: 'B', action: 'Back', highlight: true),
      ));

      final actionText = tester.widget<Text>(find.text('Back'));
      expect(
        actionText.style!.color,
        Colors.redAccent.withValues(alpha: 0.7),
      );
    });

    testWidgets('custom buttonColor is applied (no highlight)', (tester) async {
      await tester.pumpWidget(createTestApp(
        const ControlButton(
          label: 'A',
          action: 'OK',
          buttonColor: Colors.green,
        ),
      ));

      final containers = tester.widgetList<Container>(
        find.descendant(
          of: find.byType(ControlButton),
          matching: find.byType(Container),
        ),
      ).toList();
      final decoration = containers.first.decoration as BoxDecoration;
      expect(decoration.color, Colors.green.withValues(alpha: 0.25));
    });

    testWidgets('onTap callback triggered', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(createTestApp(
        ControlButton(label: 'A', action: 'OK', onTap: () => tapped = true),
      ));

      await tester.tap(find.byType(ControlButton));
      expect(tapped, true);
    });

    testWidgets('onTap null means no Material/InkWell wrapper', (tester) async {
      await tester.pumpWidget(createTestApp(
        const ControlButton(label: 'A', action: 'OK'),
      ));

      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('onTap non-null wraps in Material + InkWell', (tester) async {
      await tester.pumpWidget(createTestApp(
        ControlButton(label: 'A', action: 'OK', onTap: () {}),
      ));

      expect(find.byType(InkWell), findsOneWidget);
    });

    testWidgets('icon is shown instead of label text when set', (tester) async {
      await tester.pumpWidget(createTestApp(
        const ControlButton(
          label: 'X',
          action: 'Menu',
          icon: Icons.menu,
        ),
      ));

      expect(find.byIcon(Icons.menu), findsOneWidget);
      // Label text should not be rendered (icon takes priority)
      expect(find.text('X'), findsNothing);
    });

    testWidgets('shapePainter renders CustomPaint', (tester) async {
      await tester.pumpWidget(createTestApp(
        const ControlButton(
          label: '',
          action: 'Start',
          shapePainter: NintendoPlusPainter(),
        ),
      ));

      final finder = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is NintendoPlusPainter,
      );
      expect(finder, findsOneWidget);
    });

    testWidgets('highlight recolors NintendoPlusPainter to redAccent', (tester) async {
      await tester.pumpWidget(createTestApp(
        const ControlButton(
          label: '',
          action: 'Start',
          shapePainter: NintendoPlusPainter(),
          highlight: true,
        ),
      ));

      final finder = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is NintendoPlusPainter,
      );
      final customPaint = tester.widget<CustomPaint>(finder);
      final painter = customPaint.painter as NintendoPlusPainter;
      expect(painter.color, Colors.redAccent);
    });

    testWidgets('labelColor is applied to label text', (tester) async {
      await tester.pumpWidget(createTestApp(
        const ControlButton(
          label: 'A',
          action: 'OK',
          labelColor: Colors.blue,
        ),
      ));

      final labelText = tester.widget<Text>(find.text('A'));
      expect(labelText.style!.color, Colors.blue);
    });
  });
}
