import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:retro_eshop/features/onboarding/widgets/connection_test_indicator.dart';
import '../helpers/pump_helpers.dart';

void main() {
  group('ConnectionTestIndicator', () {
    testWidgets('shows spinner and text when testing', (tester) async {
      await tester.pumpWidget(createTestApp(
        const ConnectionTestIndicator(
          isTesting: true,
          isSuccess: false,
        ),
      ));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Testing connection...'), findsOneWidget);
    });

    testWidgets('shows green check and success text when successful',
        (tester) async {
      await tester.pumpWidget(createTestApp(
        const ConnectionTestIndicator(
          isTesting: false,
          isSuccess: true,
        ),
      ));

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.text('Connection successful!'), findsOneWidget);
    });

    testWidgets('shows error icon and error text', (tester) async {
      await tester.pumpWidget(createTestApp(
        const ConnectionTestIndicator(
          isTesting: false,
          isSuccess: false,
          error: 'Connection refused',
        ),
      ));

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Connection refused'), findsOneWidget);
    });

    testWidgets('shows nothing when idle (no testing, no success, no error)',
        (tester) async {
      await tester.pumpWidget(createTestApp(
        const ConnectionTestIndicator(
          isTesting: false,
          isSuccess: false,
        ),
      ));

      expect(find.byType(SizedBox), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byIcon(Icons.check_circle), findsNothing);
      expect(find.byIcon(Icons.error_outline), findsNothing);
    });

    testWidgets('isTesting takes priority over isSuccess', (tester) async {
      await tester.pumpWidget(createTestApp(
        const ConnectionTestIndicator(
          isTesting: true,
          isSuccess: true,
        ),
      ));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Testing connection...'), findsOneWidget);
      expect(find.text('Connection successful!'), findsNothing);
    });

    testWidgets('isSuccess takes priority over error', (tester) async {
      await tester.pumpWidget(createTestApp(
        const ConnectionTestIndicator(
          isTesting: false,
          isSuccess: true,
          error: 'Some error',
        ),
      ));

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.text('Connection successful!'), findsOneWidget);
      expect(find.text('Some error'), findsNothing);
    });

    testWidgets('long error text is displayed in full', (tester) async {
      const longError =
          'Failed to connect: server returned HTTP 503 Service Unavailable';
      await tester.pumpWidget(createTestApp(
        const ConnectionTestIndicator(
          isTesting: false,
          isSuccess: false,
          error: longError,
        ),
      ));

      expect(find.text(longError), findsOneWidget);
    });
  });
}
