import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:retro_eshop/features/settings/widgets/settings_item.dart';
import '../helpers/pump_helpers.dart';

void main() {
  group('SettingsItem', () {
    testWidgets('title is rendered in UPPERCASE', (tester) async {
      await tester.pumpWidget(createTestAppWithProviders(
        const SettingsItem(title: 'Sound', subtitle: 'Audio settings'),
      ));

      expect(find.text('SOUND'), findsOneWidget);
    });

    testWidgets('subtitle is rendered', (tester) async {
      await tester.pumpWidget(createTestAppWithProviders(
        const SettingsItem(title: 'Sound', subtitle: 'Audio settings'),
      ));

      expect(find.text('Audio settings'), findsOneWidget);
    });

    testWidgets('isDestructive shows red title text', (tester) async {
      await tester.pumpWidget(createTestAppWithProviders(
        const SettingsItem(
          title: 'Delete',
          subtitle: 'Remove all data',
          isDestructive: true,
        ),
      ));

      final titleText = tester.widget<Text>(find.text('DELETE'));
      expect(titleText.style!.color, Colors.redAccent);
    });

    testWidgets('trailing widget is rendered', (tester) async {
      await tester.pumpWidget(createTestAppWithProviders(
        const SettingsItem(
          title: 'Sound',
          subtitle: 'Toggle',
          trailing: Icon(Icons.check),
        ),
      ));

      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('trailingBuilder receives isFocused value', (tester) async {
      bool? receivedFocused;
      final focusNode = FocusNode();

      await tester.pumpWidget(createTestAppWithProviders(
        SettingsItem(
          title: 'Test',
          subtitle: 'Sub',
          focusNode: focusNode,
          trailingBuilder: (isFocused) {
            receivedFocused = isFocused;
            return Text(isFocused ? 'Focused' : 'Not focused');
          },
        ),
      ));

      expect(receivedFocused, false);
      expect(find.text('Not focused'), findsOneWidget);

      focusNode.requestFocus();
      await tester.pumpAndSettle();

      expect(receivedFocused, true);
      expect(find.text('Focused'), findsOneWidget);

      focusNode.dispose();
    });

    testWidgets('focus changes title color to white', (tester) async {
      final focusNode = FocusNode();

      await tester.pumpWidget(createTestAppWithProviders(
        SettingsItem(
          title: 'Sound',
          subtitle: 'Settings',
          focusNode: focusNode,
        ),
      ));

      // Before focus: color is white70
      var titleText = tester.widget<Text>(find.text('SOUND'));
      expect(titleText.style!.color, Colors.white70);

      focusNode.requestFocus();
      await tester.pumpAndSettle();

      // After focus: color is white
      titleText = tester.widget<Text>(find.text('SOUND'));
      expect(titleText.style!.color, Colors.white);

      focusNode.dispose();
    });

    testWidgets('onTap is triggered on tap', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(createTestAppWithProviders(
        SettingsItem(
          title: 'Action',
          subtitle: 'Do something',
          onTap: () => tapped = true,
        ),
      ));

      await tester.tap(find.byType(SettingsItem));
      await tester.pumpAndSettle();
      expect(tapped, true);
    });

    testWidgets('external FocusNode is used and not disposed', (tester) async {
      final focusNode = FocusNode();

      await tester.pumpWidget(createTestAppWithProviders(
        SettingsItem(
          title: 'Test',
          subtitle: 'Sub',
          focusNode: focusNode,
        ),
      ));

      // Replace widget to trigger dispose
      await tester.pumpWidget(createTestAppWithProviders(
        const SizedBox(),
      ));
      await tester.pumpAndSettle();

      // External FocusNode should still be usable
      expect(focusNode.canRequestFocus, true);
      focusNode.dispose();
    });

    testWidgets('internal FocusNode is disposed when widget removed', (tester) async {
      await tester.pumpWidget(createTestAppWithProviders(
        const SettingsItem(title: 'Test', subtitle: 'Sub'),
      ));

      // Replace widget to trigger dispose — should not throw
      await tester.pumpWidget(createTestAppWithProviders(
        const SizedBox(),
      ));
      await tester.pumpAndSettle();
    });

    test('asserts when both trailing and trailingBuilder provided', () {
      expect(
        () => SettingsItem(
          title: 'Test',
          subtitle: 'Sub',
          trailing: const Icon(Icons.check),
          trailingBuilder: (focused) => const Icon(Icons.star),
        ),
        throwsAssertionError,
      );
    });
  });
}
