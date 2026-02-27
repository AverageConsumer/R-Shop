import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:retro_eshop/widgets/control_button.dart';
import '../helpers/pump_helpers.dart';

void main() {
  group('ControlButton', () {
    testWidgets('renders label text (legacy mode)', (tester) async {
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

    testWidgets('face button "A" gets circle shape (legacy mode)', (tester) async {
      await tester.pumpWidget(createTestApp(
        const ControlButton(label: 'A', action: 'Confirm'),
      ));

      final containers = tester.widgetList<Container>(
        find.descendant(
          of: find.byType(ControlButton),
          matching: find.byType(Container),
        ),
      ).toList();
      final decoration = containers.first.decoration as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(28.0));
    });

    testWidgets('shoulder button "LB" gets pill shape (legacy mode)', (tester) async {
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
      expect(decoration.borderRadius, BorderRadius.circular(28.0 * 0.35));
    });

    testWidgets('highlight=true uses redAccent action color', (tester) async {
      await tester.pumpWidget(createTestApp(
        const ControlButton(label: 'B', action: 'Back', highlight: true),
      ));

      final actionText = tester.widget<Text>(find.text('Back'));
      expect(
        actionText.style!.color,
        Colors.redAccent.withValues(alpha: 0.7),
      );
    });

    testWidgets('custom buttonColor is applied (legacy mode)', (tester) async {
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

    testWidgets('onTap null means no InkWell wrapper', (tester) async {
      await tester.pumpWidget(createTestApp(
        const ControlButton(label: 'A', action: 'OK'),
      ));

      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('onTap non-null wraps in InkWell', (tester) async {
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
      expect(find.text('X'), findsNothing);
    });

    testWidgets('svgAsset renders SvgPicture instead of label', (tester) async {
      await tester.pumpWidget(createTestApp(
        const ControlButton(
          label: '',
          action: 'Confirm',
          svgAsset: 'assets/gamepad/nintendo/switch_button_a.svg',
        ),
      ));

      expect(find.byType(SvgPicture), findsOneWidget);
      expect(find.text('Confirm'), findsOneWidget);
    });

    testWidgets('svgAsset with highlight shows red glow border', (tester) async {
      await tester.pumpWidget(createTestApp(
        const ControlButton(
          label: '',
          action: 'Save',
          svgAsset: 'assets/gamepad/nintendo/switch_button_a.svg',
          highlight: true,
        ),
      ));

      expect(find.byType(SvgPicture), findsOneWidget);
      // Highlight wraps SVG in a Container with circle border
      final containers = tester.widgetList<Container>(
        find.descendant(
          of: find.byType(ControlButton),
          matching: find.byType(Container),
        ),
      ).toList();
      final highlighted = containers.where((c) {
        final decoration = c.decoration;
        if (decoration is BoxDecoration && decoration.border != null) {
          return decoration.shape == BoxShape.circle;
        }
        return false;
      });
      expect(highlighted, isNotEmpty);
    });

    testWidgets('svgAsset with onTap wraps in InkWell', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(createTestApp(
        ControlButton(
          label: '',
          action: 'OK',
          svgAsset: 'assets/gamepad/nintendo/switch_button_a.svg',
          onTap: () => tapped = true,
        ),
      ));

      expect(find.byType(InkWell), findsOneWidget);
      await tester.tap(find.byType(ControlButton));
      expect(tapped, true);
    });

    testWidgets('labelColor is applied to label text (legacy mode)', (tester) async {
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
