import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:retro_eshop/widgets/glass_overlay.dart';
import '../helpers/pump_helpers.dart';

void main() {
  group('GlassOverlay', () {
    testWidgets('renders child widget', (tester) async {
      await tester.pumpWidget(createTestApp(
        const GlassOverlay(child: Text('Hello')),
      ));

      expect(find.text('Hello'), findsOneWidget);
    });

    testWidgets('contains BackdropFilter', (tester) async {
      await tester.pumpWidget(createTestApp(
        const GlassOverlay(child: SizedBox()),
      ));

      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('has Container with default tint color (black)', (tester) async {
      await tester.pumpWidget(createTestApp(
        const GlassOverlay(child: SizedBox()),
      ));

      final container = tester.widget<Container>(find.byType(Container).last);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, Colors.black.withValues(alpha: 0.2));
    });

    testWidgets('applies custom tint and opacity', (tester) async {
      await tester.pumpWidget(createTestApp(
        const GlassOverlay(
          tint: Colors.red,
          opacity: 0.5,
          child: SizedBox(),
        ),
      ));

      final container = tester.widget<Container>(find.byType(Container).last);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, Colors.red.withValues(alpha: 0.5));
    });

    testWidgets('contains ClipRRect wrapper', (tester) async {
      await tester.pumpWidget(createTestApp(
        const GlassOverlay(child: SizedBox()),
      ));

      expect(find.byType(ClipRRect), findsOneWidget);
    });
  });
}
