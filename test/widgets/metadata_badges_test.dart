import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:retro_eshop/features/game_detail/widgets/metadata_badges.dart';
import 'package:retro_eshop/utils/game_metadata.dart';
import '../helpers/pump_helpers.dart';

void main() {
  // --- RegionBadge ---
  group('RegionBadge', () {
    const testRegion = RegionInfo(name: 'USA', flag: '\u{1F1FA}\u{1F1F8}');

    testWidgets('shows flag emoji and region name', (tester) async {
      await tester.pumpWidget(createTestApp(
        const RegionBadge(region: testRegion),
      ));

      expect(find.text('\u{1F1FA}\u{1F1F8}'), findsOneWidget);
      expect(find.text('USA'), findsOneWidget);
    });

    testWidgets('applies custom fontSize to flag', (tester) async {
      await tester.pumpWidget(createTestApp(
        const RegionBadge(region: testRegion, fontSize: 20),
      ));

      final flagText = tester.widget<Text>(find.text('\u{1F1FA}\u{1F1F8}'));
      expect(flagText.style!.fontSize, 20);
    });

    testWidgets('container has border', (tester) async {
      await tester.pumpWidget(createTestApp(
        const RegionBadge(region: testRegion),
      ));

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(RegionBadge),
          matching: find.byType(Container),
        ),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.border, isNotNull);
    });
  });

  // --- LanguageBadges ---
  group('LanguageBadges', () {
    const en = LanguageInfo(code: 'En', name: 'English', flag: '\u{1F1EC}\u{1F1E7}');
    const fr = LanguageInfo(code: 'Fr', name: 'French', flag: '\u{1F1EB}\u{1F1F7}');
    const de = LanguageInfo(code: 'De', name: 'German', flag: '\u{1F1E9}\u{1F1EA}');
    const es = LanguageInfo(code: 'Es', name: 'Spanish', flag: '\u{1F1EA}\u{1F1F8}');

    testWidgets('shows language flags', (tester) async {
      await tester.pumpWidget(createTestApp(
        const LanguageBadges(languages: [en, fr]),
      ));

      expect(find.text('\u{1F1EC}\u{1F1E7}'), findsOneWidget);
      expect(find.text('\u{1F1EB}\u{1F1F7}'), findsOneWidget);
    });

    testWidgets('maxVisible limits display', (tester) async {
      await tester.pumpWidget(createTestApp(
        const LanguageBadges(languages: [en, fr, de, es], maxVisible: 2),
      ));

      expect(find.text('\u{1F1EC}\u{1F1E7}'), findsOneWidget);
      expect(find.text('\u{1F1EB}\u{1F1F7}'), findsOneWidget);
      // German and Spanish should be hidden
      expect(find.text('\u{1F1E9}\u{1F1EA}'), findsNothing);
      expect(find.text('\u{1F1EA}\u{1F1F8}'), findsNothing);
    });

    testWidgets('+N badge on overflow', (tester) async {
      await tester.pumpWidget(createTestApp(
        const LanguageBadges(languages: [en, fr, de, es], maxVisible: 2),
      ));

      expect(find.text('+2'), findsOneWidget);
    });

    testWidgets('empty list renders empty Row', (tester) async {
      await tester.pumpWidget(createTestApp(
        const LanguageBadges(languages: []),
      ));

      expect(find.byType(Tooltip), findsNothing);
      expect(find.byType(Row), findsWidgets);
    });
  });

  // --- TagBadges ---
  group('TagBadges', () {
    const versionTag = TagInfo(raw: '(Rev A)', content: 'Rev A', type: TagType.version);
    const buildTag = TagInfo(raw: '(Beta)', content: 'Beta', type: TagType.build);
    const discTag = TagInfo(raw: '(Disc 1)', content: 'Disc 1', type: TagType.disc);
    const otherTag = TagInfo(raw: '(Special)', content: 'Special', type: TagType.other);

    testWidgets('empty tags shows "Standard" text (italic)', (tester) async {
      await tester.pumpWidget(createTestApp(
        const TagBadges(tags: []),
      ));

      final text = tester.widget<Text>(find.text('Standard'));
      expect(text.style!.fontStyle, FontStyle.italic);
    });

    testWidgets('single tag renders correctly', (tester) async {
      await tester.pumpWidget(createTestApp(
        const TagBadges(tags: [versionTag]),
      ));

      expect(find.text('(Rev A)'), findsOneWidget);
    });

    testWidgets('tag has correct color for version type', (tester) async {
      await tester.pumpWidget(createTestApp(
        const TagBadges(tags: [versionTag]),
      ));

      final text = tester.widget<Text>(find.text('(Rev A)'));
      // Version type color is Colors.blue with alpha 0.9
      expect(text.style!.color, Colors.blue.withValues(alpha: 0.9));
    });

    testWidgets('maxVisible + overflow badge', (tester) async {
      await tester.pumpWidget(createTestApp(
        const TagBadges(tags: [versionTag, buildTag, discTag, otherTag], maxVisible: 2),
      ));

      expect(find.text('(Rev A)'), findsOneWidget);
      expect(find.text('(Beta)'), findsOneWidget);
      expect(find.text('(Disc 1)'), findsNothing);
      expect(find.text('+2'), findsOneWidget);
    });

    testWidgets('compact=true uses smaller fonts', (tester) async {
      await tester.pumpWidget(createTestApp(
        const TagBadges(tags: [versionTag], compact: true),
      ));

      final text = tester.widget<Text>(find.text('(Rev A)'));
      expect(text.style!.fontSize, 9);
    });

    testWidgets('compact=false uses normal fonts', (tester) async {
      await tester.pumpWidget(createTestApp(
        const TagBadges(tags: [versionTag], compact: false),
      ));

      final text = tester.widget<Text>(find.text('(Rev A)'));
      expect(text.style!.fontSize, 10);
    });
  });

  // --- FileTypeBadge ---
  group('FileTypeBadge', () {
    testWidgets('text is uppercase', (tester) async {
      await tester.pumpWidget(createTestApp(
        const FileTypeBadge(fileType: 'zip'),
      ));

      expect(find.text('ZIP'), findsOneWidget);
    });

    testWidgets('container has border', (tester) async {
      await tester.pumpWidget(createTestApp(
        const FileTypeBadge(fileType: 'iso'),
      ));

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(FileTypeBadge),
          matching: find.byType(Container),
        ),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.border, isNotNull);
    });

    testWidgets('renders correct fileType', (tester) async {
      await tester.pumpWidget(createTestApp(
        const FileTypeBadge(fileType: 'chd'),
      ));

      expect(find.text('CHD'), findsOneWidget);
    });
  });

  // --- InstalledBadge (metadata version) ---
  group('InstalledBadge (metadata)', () {
    testWidgets('isInstalled=false returns SizedBox.shrink', (tester) async {
      await tester.pumpWidget(createTestApp(
        const InstalledBadge(isInstalled: false),
      ));

      expect(find.byType(SizedBox), findsWidgets);
      expect(find.byIcon(Icons.check), findsNothing);
    });

    testWidgets('isInstalled=true shows check icon', (tester) async {
      await tester.pumpWidget(createTestApp(
        const InstalledBadge(isInstalled: true),
      ));

      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('custom size is applied', (tester) async {
      await tester.pumpWidget(createTestApp(
        const InstalledBadge(isInstalled: true, size: 24),
      ));

      final icon = tester.widget<Icon>(find.byIcon(Icons.check));
      expect(icon.size, 24 - 6); // size - 6
    });
  });
}
