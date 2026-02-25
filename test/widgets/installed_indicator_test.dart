import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:retro_eshop/widgets/installed_indicator.dart';
import '../helpers/pump_helpers.dart';

void main() {
  group('InstalledBadge', () {
    testWidgets('renders "INSTALLED" text', (tester) async {
      await tester.pumpWidget(createTestApp(const InstalledBadge()));

      expect(find.text('INSTALLED'), findsOneWidget);
    });

    testWidgets('renders check_circle icon', (tester) async {
      await tester.pumpWidget(createTestApp(const InstalledBadge()));

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('compact=true has smaller font (7.0)', (tester) async {
      await tester.pumpWidget(createTestApp(const InstalledBadge(compact: true)));

      final text = tester.widget<Text>(find.text('INSTALLED'));
      expect(text.style!.fontSize, 7.0);
    });

    testWidgets('compact=false has normal font (10.0)', (tester) async {
      await tester.pumpWidget(createTestApp(const InstalledBadge(compact: false)));

      final text = tester.widget<Text>(find.text('INSTALLED'));
      expect(text.style!.fontSize, 10.0);
    });

    testWidgets('compact=true has smaller icon (10.0)', (tester) async {
      await tester.pumpWidget(createTestApp(const InstalledBadge(compact: true)));

      final icon = tester.widget<Icon>(find.byIcon(Icons.check_circle));
      expect(icon.size, 10.0);
    });

    testWidgets('compact=false has normal icon (14.0)', (tester) async {
      await tester.pumpWidget(createTestApp(const InstalledBadge(compact: false)));

      final icon = tester.widget<Icon>(find.byIcon(Icons.check_circle));
      expect(icon.size, 14.0);
    });
  });

  group('InstalledLedStrip', () {
    testWidgets('renders Container with gradient', (tester) async {
      await tester.pumpWidget(createTestApp(const InstalledLedStrip()));

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(InstalledLedStrip),
          matching: find.byType(Container),
        ),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.gradient, isA<LinearGradient>());
    });

    testWidgets('gradient contains greenAccent color', (tester) async {
      await tester.pumpWidget(createTestApp(const InstalledLedStrip()));

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(InstalledLedStrip),
          matching: find.byType(Container),
        ),
      );
      final decoration = container.decoration as BoxDecoration;
      final gradient = decoration.gradient as LinearGradient;
      expect(gradient.colors, contains(Colors.greenAccent));
    });

    testWidgets('borderRadius is applied', (tester) async {
      const radius = BorderRadius.all(Radius.circular(8));
      await tester.pumpWidget(
        createTestApp(const InstalledLedStrip(borderRadius: radius)),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(InstalledLedStrip),
          matching: find.byType(Container),
        ),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.borderRadius, radius);
    });

    testWidgets('height is 3.5 on medium screen (default 800x600)', (tester) async {
      await tester.pumpWidget(createTestApp(const InstalledLedStrip()));

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(InstalledLedStrip),
          matching: find.byType(Container),
        ),
      );
      expect(container.constraints?.maxHeight, 3.5);
    });

    testWidgets('height is 2.5 on small screen', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          const InstalledLedStrip(),
          size: const Size(500, 400),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(InstalledLedStrip),
          matching: find.byType(Container),
        ),
      );
      expect(container.constraints?.maxHeight, 2.5);
    });
  });
}
