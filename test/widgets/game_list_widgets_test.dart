import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:retro_eshop/features/game_list/widgets/game_grid.dart';
import 'package:retro_eshop/features/game_list/widgets/game_list_header.dart';
import 'package:retro_eshop/models/system_model.dart';
import 'package:retro_eshop/services/disk_space_service.dart';
import '../helpers/pump_helpers.dart';

// ─── Test Fixtures ───────────────────────────────────────

final _snes = SystemModel.supportedSystems.firstWhere((s) => s.id == 'snes');

// ─── Tests ───────────────────────────────────────────────

void main() {
  group('GameListHeader', () {
    testWidgets('shows system name in uppercase', (tester) async {
      await tester.pumpWidget(createTestAppWithProviders(
        Stack(children: [
          GameListHeader(system: _snes, gameCount: 42),
        ]),
      ));

      expect(find.text(_snes.name.toUpperCase()), findsOneWidget);
    });

    testWidgets('shows manufacturer and release year', (tester) async {
      await tester.pumpWidget(createTestAppWithProviders(
        Stack(children: [
          GameListHeader(system: _snes, gameCount: 10),
        ]),
      ));

      expect(
          find.text('${_snes.manufacturer} · ${_snes.releaseYear}'),
          findsOneWidget);
    });

    testWidgets('shows game count badge', (tester) async {
      await tester.pumpWidget(createTestAppWithProviders(
        Stack(children: [
          GameListHeader(system: _snes, gameCount: 123),
        ]),
      ));

      expect(find.text('123 Games'), findsOneWidget);
    });

    testWidgets('shows filter icon when hasActiveFilters', (tester) async {
      await tester.pumpWidget(createTestAppWithProviders(
        Stack(children: [
          GameListHeader(
            system: _snes,
            gameCount: 10,
            hasActiveFilters: true,
          ),
        ]),
      ));

      expect(find.byIcon(Icons.filter_list), findsOneWidget);
    });

    testWidgets('no filter icon when no active filters', (tester) async {
      await tester.pumpWidget(createTestAppWithProviders(
        Stack(children: [
          GameListHeader(
            system: _snes,
            gameCount: 10,
            hasActiveFilters: false,
          ),
        ]),
      ));

      expect(find.byIcon(Icons.filter_list), findsNothing);
    });

    testWidgets('shows local-only banner when isLocalOnly', (tester) async {
      await tester.pumpWidget(createTestAppWithProviders(
        Stack(children: [
          GameListHeader(
            system: _snes,
            gameCount: 5,
            isLocalOnly: true,
          ),
        ]),
      ));

      expect(
        find.textContaining('Local files only'),
        findsOneWidget,
      );
    });

    testWidgets('no local-only banner when not local', (tester) async {
      await tester.pumpWidget(createTestAppWithProviders(
        Stack(children: [
          GameListHeader(system: _snes, gameCount: 5),
        ]),
      ));

      expect(find.textContaining('Local files only'), findsNothing);
    });

    testWidgets('shows folder path when targetFolder set', (tester) async {
      await tester.pumpWidget(createTestAppWithProviders(
        Stack(children: [
          GameListHeader(
            system: _snes,
            gameCount: 10,
            targetFolder: '/storage/emulated/0/Roms/SNES',
          ),
        ]),
      ));

      // Path is shortened: removes /storage/emulated/0/ prefix
      expect(find.text('Roms/SNES'), findsOneWidget);
      expect(find.byIcon(Icons.folder_outlined), findsOneWidget);
    });

    testWidgets('no folder icon when targetFolder empty', (tester) async {
      await tester.pumpWidget(createTestAppWithProviders(
        Stack(children: [
          GameListHeader(system: _snes, gameCount: 10),
        ]),
      ));

      expect(find.byIcon(Icons.folder_outlined), findsNothing);
    });

    testWidgets('games icon is present', (tester) async {
      await tester.pumpWidget(createTestAppWithProviders(
        Stack(children: [
          GameListHeader(system: _snes, gameCount: 1),
        ]),
      ));

      expect(find.byIcon(Icons.games), findsOneWidget);
    });
  });

  group('StorageInfo model', () {
    test('freeGB converts bytes to gigabytes', () {
      const info = StorageInfo(
        freeBytes: 10 * 1024 * 1024 * 1024,
        totalBytes: 64 * 1024 * 1024 * 1024,
      );
      expect(info.freeGB, 10.0);
    });

    test('isLow when less than 1GB free', () {
      const info = StorageInfo(
        freeBytes: 500 * 1024 * 1024, // 500MB
        totalBytes: 64 * 1024 * 1024 * 1024,
      );
      expect(info.isLow, true);
      expect(info.isWarning, false);
      expect(info.isHealthy, false);
    });

    test('isWarning when between 1GB and 5GB free', () {
      const info = StorageInfo(
        freeBytes: 3 * 1024 * 1024 * 1024, // 3GB
        totalBytes: 64 * 1024 * 1024 * 1024,
      );
      expect(info.isLow, false);
      expect(info.isWarning, true);
      expect(info.isHealthy, false);
    });

    test('isHealthy when more than 5GB free', () {
      const info = StorageInfo(
        freeBytes: 10 * 1024 * 1024 * 1024, // 10GB
        totalBytes: 64 * 1024 * 1024 * 1024,
      );
      expect(info.isLow, false);
      expect(info.isWarning, false);
      expect(info.isHealthy, true);
    });

    test('freeSpaceText shows GB when >= 1 GB', () {
      const info = StorageInfo(
        freeBytes: 3 * 1024 * 1024 * 1024,
        totalBytes: 64 * 1024 * 1024 * 1024,
      );
      expect(info.freeSpaceText, '3.0 GB free');
    });

    test('freeSpaceText shows MB when < 1 GB', () {
      const info = StorageInfo(
        freeBytes: 512 * 1024 * 1024, // 512MB
        totalBytes: 64 * 1024 * 1024 * 1024,
      );
      expect(info.freeSpaceText, '512 MB free');
    });

    test('usagePercent calculates correctly', () {
      const info = StorageInfo(
        freeBytes: 16 * 1024 * 1024 * 1024,
        totalBytes: 64 * 1024 * 1024 * 1024,
      );
      expect(info.usagePercent, closeTo(0.75, 0.01));
    });

    test('usagePercent handles zero totalBytes', () {
      const info = StorageInfo(freeBytes: 0, totalBytes: 0);
      expect(info.usagePercent, 0);
    });
  });

  // ─── GameGridError ──────────────────────────────────────

  group('GameGridError', () {
    testWidgets('shows error outline icon', (tester) async {
      await tester.pumpWidget(createTestApp(
        GameGridError(
          error: 'Network failed',
          accentColor: Colors.red,
          onRetry: () {},
        ),
      ));

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('shows error loading games title', (tester) async {
      await tester.pumpWidget(createTestApp(
        GameGridError(
          error: 'Network failed',
          accentColor: Colors.red,
          onRetry: () {},
        ),
      ));

      expect(find.text('Error loading games'), findsOneWidget);
    });

    testWidgets('shows error detail text', (tester) async {
      await tester.pumpWidget(createTestApp(
        GameGridError(
          error: 'Connection timed out after 30s',
          accentColor: Colors.red,
          onRetry: () {},
        ),
      ));

      expect(find.text('Connection timed out after 30s'), findsOneWidget);
    });

    testWidgets('shows retry button', (tester) async {
      await tester.pumpWidget(createTestApp(
        GameGridError(
          error: 'err',
          accentColor: Colors.red,
          onRetry: () {},
        ),
      ));

      expect(find.text('Retry'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('fires onRetry callback on tap', (tester) async {
      bool retried = false;
      await tester.pumpWidget(createTestApp(
        GameGridError(
          error: 'err',
          accentColor: Colors.blue,
          onRetry: () => retried = true,
        ),
      ));

      await tester.tap(find.text('Retry'));
      expect(retried, true);
    });
  });

  // ─── GameGridLoading ────────────────────────────────────

  group('GameGridLoading', () {
    testWidgets('contains GridView with NeverScrollableScrollPhysics',
        (tester) async {
      await tester.pumpWidget(createTestApp(
        const GameGridLoading(
          accentColor: Colors.purple,
          crossAxisCount: 3,
        ),
      ));
      await tester.pump();

      expect(find.byType(GridView), findsOneWidget);
    });

    testWidgets('renders shimmer cells with placeholder bars',
        (tester) async {
      await tester.pumpWidget(createTestApp(
        const GameGridLoading(
          accentColor: Colors.purple,
          crossAxisCount: 2,
        ),
      ));
      await tester.pump();

      // Each visible cell has FractionallySizedBox placeholders
      expect(find.byType(FractionallySizedBox), findsWidgets);
    });

    testWidgets('has ClipRRect for rounded corners', (tester) async {
      await tester.pumpWidget(createTestApp(
        const GameGridLoading(
          accentColor: Colors.purple,
          crossAxisCount: 2,
        ),
      ));
      await tester.pump();

      expect(find.byType(ClipRRect), findsWidgets);
    });
  });

  // ─── GameGrid empty states ──────────────────────────────

  group('GameGrid empty states', () {
    Widget buildEmptyGrid({
      String searchQuery = '',
      bool hasActiveFilters = false,
      bool isLocalOnly = false,
      String targetFolder = '',
    }) {
      return createTestApp(
        GameGrid(
          system: _snes,
          filteredGroups: const [],
          groupedGames: const {},
          installedCache: const {},
          itemKeys: const {},
          focusNodes: const {},
          selectedIndexNotifier: ValueNotifier(0),
          crossAxisCount: 3,
          scrollController: ScrollController(),
          onScrollNotification: (_) => false,
          onOpenGame: (_, __) {},
          onSelectionChanged: (_) {},
          onCoverFound: (_, __) {},
          onThumbnailNeeded: (_, __) {},
          searchQuery: searchQuery,
          hasActiveFilters: hasActiveFilters,
          isLocalOnly: isLocalOnly,
          targetFolder: targetFolder,
        ),
      );
    }

    testWidgets('shows search empty state when query set', (tester) async {
      await tester.pumpWidget(buildEmptyGrid(searchQuery: 'zelda'));

      expect(find.textContaining("No games match 'zelda'"), findsOneWidget);
      expect(find.byIcon(Icons.search_off), findsOneWidget);
    });

    testWidgets('shows filter empty state when hasActiveFilters',
        (tester) async {
      await tester.pumpWidget(buildEmptyGrid(hasActiveFilters: true));

      expect(
          find.text('No games match current filters'), findsOneWidget);
      expect(find.byIcon(Icons.filter_list_off), findsOneWidget);
    });

    testWidgets('shows local empty state when isLocalOnly', (tester) async {
      await tester
          .pumpWidget(buildEmptyGrid(isLocalOnly: true, targetFolder: '/ROMs/SNES'));

      expect(find.text('No ROMs found in /ROMs/SNES'), findsOneWidget);
      expect(find.byIcon(Icons.folder_open), findsOneWidget);
    });

    testWidgets('shows connection error when nothing set', (tester) async {
      await tester.pumpWidget(buildEmptyGrid());

      expect(find.text('Could not load games'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
    });
  });
}
