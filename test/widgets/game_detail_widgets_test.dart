import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:retro_eshop/features/game_detail/widgets/game_info_card.dart';
import 'package:retro_eshop/features/game_detail/widgets/version_card.dart';
import 'package:retro_eshop/models/game_item.dart';
import 'package:retro_eshop/models/game_metadata_info.dart';
import 'package:retro_eshop/models/system_model.dart';
import '../helpers/pump_helpers.dart';

// ─── Test Fixtures ───────────────────────────────────────

GameMetadataInfo _makeMetadata({
  String? summary,
  String? genres,
  String? developer,
  String? publisher,
  int? releaseYear,
  String? releaseDate,
  double? rating,
  String? gameModes,
  String? franchises,
  String? themes,
  String? playerPerspectives,
  String? ageRating,
}) {
  return GameMetadataInfo(
    filename: 'test.nes',
    systemSlug: 'nes',
    summary: summary,
    genres: genres,
    developer: developer,
    publisher: publisher,
    releaseYear: releaseYear,
    releaseDate: releaseDate,
    rating: rating,
    gameModes: gameModes,
    franchises: franchises,
    themes: themes,
    playerPerspectives: playerPerspectives,
    ageRating: ageRating,
    lastUpdated: 0,
  );
}

final _testSystem = SystemModel.supportedSystems.first;

// ─── GameMetadataInfo Model Tests ────────────────────────

void main() {
  group('GameMetadataInfo', () {
    test('hasContent true when summary set', () {
      expect(_makeMetadata(summary: 'A great game').hasContent, true);
    });

    test('hasContent true when genres set', () {
      expect(_makeMetadata(genres: 'Action').hasContent, true);
    });

    test('hasContent true when developer set', () {
      expect(_makeMetadata(developer: 'Nintendo').hasContent, true);
    });

    test('hasContent true when releaseYear set', () {
      expect(_makeMetadata(releaseYear: 1985).hasContent, true);
    });

    test('hasContent true when franchises set', () {
      expect(_makeMetadata(franchises: 'Zelda').hasContent, true);
    });

    test('hasContent true when themes set', () {
      expect(_makeMetadata(themes: 'Fantasy').hasContent, true);
    });

    test('hasContent false when all null', () {
      expect(_makeMetadata().hasContent, false);
    });

    test('hasCardContent true when summary set', () {
      expect(_makeMetadata(summary: 'A game').hasCardContent, true);
    });

    test('hasCardContent true when genres set', () {
      expect(_makeMetadata(genres: 'Action').hasCardContent, true);
    });

    test('hasCardContent false when all null', () {
      expect(_makeMetadata().hasCardContent, false);
    });

    test('creditsLine shows developer / publisher', () {
      expect(
        _makeMetadata(developer: 'Rare', publisher: 'Nintendo').creditsLine,
        'Rare / Nintendo',
      );
    });

    test('creditsLine shows only developer when no publisher', () {
      expect(_makeMetadata(developer: 'Rare').creditsLine, 'Rare');
    });

    test('creditsLine shows only publisher when no developer', () {
      expect(_makeMetadata(publisher: 'Nintendo').creditsLine, 'Nintendo');
    });

    test('creditsLine null when neither set', () {
      expect(_makeMetadata().creditsLine, isNull);
    });

    test('franchiseList splits CSV', () {
      final meta = _makeMetadata(franchises: 'Mario, Zelda');
      expect(meta.franchiseList, ['Mario', 'Zelda']);
    });

    test('themeList splits CSV', () {
      final meta = _makeMetadata(themes: 'Fantasy, Sci-fi');
      expect(meta.themeList, ['Fantasy', 'Sci-fi']);
    });

    test('playerPerspectiveList splits CSV', () {
      final meta = _makeMetadata(playerPerspectives: 'Third person, Top-down');
      expect(meta.playerPerspectiveList, ['Third person', 'Top-down']);
    });

    test('genreList splits comma-separated genres', () {
      final meta = _makeMetadata(genres: 'Action, Platformer, RPG');
      expect(meta.genreList, ['Action', 'Platformer', 'RPG']);
    });

    test('genreList returns empty for null genres', () {
      expect(_makeMetadata().genreList, isEmpty);
    });

    test('genreList filters empty entries', () {
      final meta = _makeMetadata(genres: 'Action,, ,RPG');
      expect(meta.genreList, ['Action', 'RPG']);
    });

    test('gameModeList splits comma-separated modes', () {
      final meta = _makeMetadata(gameModes: 'Single Player, Multiplayer');
      expect(meta.gameModeList, ['Single Player', 'Multiplayer']);
    });

    test('gameModeList returns empty for null modes', () {
      expect(_makeMetadata().gameModeList, isEmpty);
    });

    test('toDbRow includes all fields', () {
      final meta = _makeMetadata(
        summary: 'desc',
        genres: 'RPG',
        developer: 'Dev',
        publisher: 'Pub',
        releaseYear: 2000,
        releaseDate: '2000-03-21',
        rating: 80.0,
        gameModes: 'Single',
        franchises: 'Final Fantasy',
        themes: 'Fantasy',
        playerPerspectives: 'Top-down',
        ageRating: 'ESRB: E',
      );
      final row = meta.toDbRow();
      expect(row['filename'], 'test.nes');
      expect(row['system_slug'], 'nes');
      expect(row['summary'], 'desc');
      expect(row['genres'], 'RPG');
      expect(row['developer'], 'Dev');
      expect(row['publisher'], 'Pub');
      expect(row['release_year'], 2000);
      expect(row['release_date'], '2000-03-21');
      expect(row['rating'], 80.0);
      expect(row['game_modes'], 'Single');
      expect(row['franchises'], 'Final Fantasy');
      expect(row['themes'], 'Fantasy');
      expect(row['player_perspectives'], 'Top-down');
      expect(row['age_rating'], 'ESRB: E');
    });

    test('fromDbRow parses all fields', () {
      final meta = GameMetadataInfo.fromDbRow({
        'filename': 'game.sfc',
        'system_slug': 'snes',
        'summary': 'A game',
        'genres': 'Action',
        'developer': 'Dev',
        'publisher': 'Pub',
        'release_year': 1995,
        'release_date': '1995-06-15',
        'game_modes': 'Co-op',
        'rating': 75.0,
        'franchises': 'Zelda',
        'themes': 'Adventure',
        'player_perspectives': 'Third person',
        'age_rating': 'PEGI: 7',
        'last_updated': 12345,
      });
      expect(meta.filename, 'game.sfc');
      expect(meta.systemSlug, 'snes');
      expect(meta.summary, 'A game');
      expect(meta.developer, 'Dev');
      expect(meta.publisher, 'Pub');
      expect(meta.releaseYear, 1995);
      expect(meta.releaseDate, '1995-06-15');
      expect(meta.rating, 75.0);
      expect(meta.franchises, 'Zelda');
      expect(meta.themes, 'Adventure');
      expect(meta.playerPerspectives, 'Third person');
      expect(meta.ageRating, 'PEGI: 7');
      expect(meta.lastUpdated, 12345);
    });
  });

  // ─── GameInfoCard Widget Tests ─────────────────────────

  group('GameInfoCard', () {
    testWidgets('shows developer name', (tester) async {
      await tester.pumpWidget(createTestApp(
        GameInfoCard(
          metadata: _makeMetadata(developer: 'Nintendo EAD'),
          accentColor: Colors.redAccent,
        ),
      ));

      expect(find.text('Nintendo EAD'), findsOneWidget);
    });

    testWidgets('shows credits line with developer and publisher', (tester) async {
      await tester.pumpWidget(createTestApp(
        GameInfoCard(
          metadata: _makeMetadata(developer: 'Squaresoft', publisher: 'Nintendo'),
          accentColor: Colors.redAccent,
        ),
      ));

      expect(find.text('Squaresoft / Nintendo'), findsOneWidget);
    });

    testWidgets('shows release year', (tester) async {
      await tester.pumpWidget(createTestApp(
        GameInfoCard(
          metadata: _makeMetadata(releaseYear: 1985),
          accentColor: Colors.redAccent,
        ),
      ));

      expect(find.text('1985'), findsOneWidget);
    });

    testWidgets('shows genre pills', (tester) async {
      await tester.pumpWidget(createTestApp(
        GameInfoCard(
          metadata: _makeMetadata(genres: 'Action, Platformer'),
          accentColor: Colors.redAccent,
        ),
      ));

      expect(find.text('Action'), findsOneWidget);
      expect(find.text('Platformer'), findsOneWidget);
    });

    testWidgets('limits genres to 3', (tester) async {
      await tester.pumpWidget(createTestApp(
        GameInfoCard(
          metadata: _makeMetadata(
              genres: 'Action, Platformer, RPG, Strategy, Puzzle'),
          accentColor: Colors.redAccent,
        ),
      ));

      expect(find.text('Action'), findsOneWidget);
      expect(find.text('Platformer'), findsOneWidget);
      expect(find.text('RPG'), findsOneWidget);
      expect(find.text('Strategy'), findsNothing);
      expect(find.text('Puzzle'), findsNothing);
    });

    testWidgets('shows star rating', (tester) async {
      await tester.pumpWidget(createTestApp(
        GameInfoCard(
          metadata: _makeMetadata(rating: 80.0),
          accentColor: Colors.redAccent,
        ),
      ));

      // 80/20 = 4.0 stars → 4 full stars + 1 outline
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(4));
      expect(find.byIcon(Icons.star_outline_rounded), findsOneWidget);
      expect(find.text('80'), findsOneWidget);
    });

    testWidgets('shows half star for partial rating', (tester) async {
      await tester.pumpWidget(createTestApp(
        GameInfoCard(
          metadata: _makeMetadata(rating: 50.0),
          accentColor: Colors.redAccent,
        ),
      ));

      // 50/20 = 2.5 → 2 full + 1 half + 2 outline
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(2));
      expect(find.byIcon(Icons.star_half_rounded), findsOneWidget);
      expect(find.byIcon(Icons.star_outline_rounded), findsNWidgets(2));
    });

    testWidgets('shows truncated summary', (tester) async {
      await tester.pumpWidget(createTestApp(
        GameInfoCard(
          metadata: _makeMetadata(summary: 'A great adventure game with puzzles.'),
          accentColor: Colors.redAccent,
        ),
      ));

      expect(find.text('A great adventure game with puzzles.'), findsOneWidget);
    });

    testWidgets('no rating icons when rating is null', (tester) async {
      await tester.pumpWidget(createTestApp(
        GameInfoCard(
          metadata: _makeMetadata(developer: 'Some Dev'),
          accentColor: Colors.redAccent,
        ),
      ));

      expect(find.byIcon(Icons.star_rounded), findsNothing);
      expect(find.byIcon(Icons.star_outline_rounded), findsNothing);
    });

    testWidgets('card has border and rounded corners', (tester) async {
      await tester.pumpWidget(createTestApp(
        GameInfoCard(
          metadata: _makeMetadata(developer: 'test'),
          accentColor: Colors.blue,
        ),
      ));

      final containers = tester.widgetList<Container>(
        find.descendant(
          of: find.byType(GameInfoCard),
          matching: find.byType(Container),
        ),
      );
      final mainContainer = containers.first;
      final decoration = mainContainer.decoration as BoxDecoration;
      expect(decoration.border, isNotNull);
      expect(decoration.borderRadius, isNotNull);
    });
  });

  // ─── SingleVersionDisplay Widget Tests ─────────────────

  group('SingleVersionDisplay', () {
    const testVariant = GameItem(
      filename: 'Super Mario Bros (USA) (Rev A).nes',
      displayName: 'Super Mario Bros',
      url: 'http://example.com/mario.nes',
    );

    testWidgets('renders region badge', (tester) async {
      await tester.pumpWidget(createTestApp(
        SingleVersionDisplay(
          variant: testVariant,
          system: _testSystem,
          isInstalled: false,
        ),
      ));

      // Should show USA region flag
      expect(find.text('USA'), findsOneWidget);
    });

    testWidgets('renders file type badge in uppercase', (tester) async {
      await tester.pumpWidget(createTestApp(
        SingleVersionDisplay(
          variant: testVariant,
          system: _testSystem,
          isInstalled: false,
        ),
      ));

      expect(find.text('NES'), findsOneWidget);
    });

    testWidgets('shows tag badges for version tags', (tester) async {
      await tester.pumpWidget(createTestApp(
        SingleVersionDisplay(
          variant: testVariant,
          system: _testSystem,
          isInstalled: false,
        ),
      ));

      expect(find.text('(Rev A)'), findsOneWidget);
    });

    testWidgets('onTap fires callback', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(createTestApp(
        SingleVersionDisplay(
          variant: testVariant,
          system: _testSystem,
          isInstalled: false,
          onTap: () => tapped = true,
        ),
      ));

      await tester.tap(find.byType(SingleVersionDisplay));
      expect(tapped, true);
    });

    testWidgets('installed version shows InstalledBadge', (tester) async {
      await tester.pumpWidget(createTestApp(
        SingleVersionDisplay(
          variant: testVariant,
          system: _testSystem,
          isInstalled: true,
        ),
      ));

      expect(find.text('INSTALLED'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('non-installed version has no InstalledBadge', (tester) async {
      await tester.pumpWidget(createTestApp(
        SingleVersionDisplay(
          variant: testVariant,
          system: _testSystem,
          isInstalled: false,
        ),
      ));

      expect(find.text('INSTALLED'), findsNothing);
    });
  });
}
