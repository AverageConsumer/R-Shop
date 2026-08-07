import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retro_eshop/features/settings/sources_screen.dart';
import 'package:retro_eshop/widgets/console_hud.dart';
import 'package:retro_eshop/models/config/source.dart';
import 'package:retro_eshop/providers/app_providers.dart';
import 'package:retro_eshop/services/config_storage_service.dart';
import 'package:retro_eshop/services/sources_notifier.dart';
import 'package:retro_eshop/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/pump_helpers.dart';

class _StubSourcesNotifier extends SourcesNotifier {
  _StubSourcesNotifier(List<Source> seed)
      : super(ConfigStorageService(
          directoryProvider: () async =>
              Directory.systemTemp.createTempSync('rshop_sources_screen_'),
        )) {
    state = SourcesState(
      sources: List<Source>.unmodifiable(seed),
      loading: false,
    );
  }
}

Future<StorageService> _initMockStorage() async {
  SharedPreferences.setMockInitialValues({});
  FlutterSecureStorage.setMockInitialValues({});
  final storage = StorageService();
  await storage.init();
  return storage;
}

Widget _wrap(StorageService storage, Widget child,
    {List<Source> seed = const []}) {
  return createTestAppWithProviders(
    child,
    overrides: [
      storageServiceProvider.overrideWithValue(storage),
      sourcesProvider.overrideWith((ref) => _StubSourcesNotifier(seed)),
    ],
  );
}

void main() {
  group('SourcesScreen — empty state', () {
    testWidgets('shows empty hint and add button when no sources', (tester) async {
      final storage = await _initMockStorage();
      await tester.pumpWidget(_wrap(storage, const SourcesScreen()));
      await tester.pumpAndSettle();

      expect(find.text('No sources yet'), findsOneWidget);
      expect(find.text('Add source'), findsWidgets);
      expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
      expect(find.text('No sources configured'), findsOneWidget);
    });
  });

  group('SourcesScreen — populated', () {
    testWidgets('renders one card per source with name + host', (tester) async {
      final storage = await _initMockStorage();
      await tester.pumpWidget(_wrap(
        storage,
        const SourcesScreen(),
        seed: const [
          Source(
            id: 'mine',
            name: 'Mein RomM',
            type: SourceType.romm,
            url: 'http://192.168.1.50:8090',
            autoMap: true,
            knownPlatforms: {'snes': 4, 'nds': 8, 'gba': 5},
          ),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Mein RomM'), findsOneWidget);
      expect(find.textContaining('192.168.1.50'), findsOneWidget);
      expect(find.text('3 platforms'), findsOneWidget);
      // The count line is localised now, and the key name lives in the HUD
      // where it follows the configured controller layout.
      expect(find.text('1 source'), findsOneWidget);
    });

    testWidgets('shows BORROWED badge for borrowed sources', (tester) async {
      final storage = await _initMockStorage();
      await tester.pumpWidget(_wrap(
        storage,
        const SourcesScreen(),
        seed: const [
          Source(
            id: 'tims',
            name: 'Tims RomM',
            type: SourceType.romm,
            url: 'http://tim.duckdns.org',
            autoMap: true,
            borrowed: true,
            knownPlatforms: {'snes': 4},
          ),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('BORROWED'), findsOneWidget);
      expect(find.byIcon(Icons.share), findsOneWidget);
    });

    testWidgets('shows OFF badge for disabled sources', (tester) async {
      final storage = await _initMockStorage();
      await tester.pumpWidget(_wrap(
        storage,
        const SourcesScreen(),
        seed: const [
          Source(
            id: 'off',
            name: 'Inactive',
            type: SourceType.romm,
            url: 'http://x',
            autoMap: true,
            enabled: false,
            knownPlatforms: {'snes': 4},
          ),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('OFF'), findsOneWidget);
    });

    testWidgets('shows expiry warning for tokens expiring within 7 days',
        (tester) async {
      final storage = await _initMockStorage();
      // Use 5d so the inDays-rounding-down can land on 4 or 5 without
      // the test going flaky depending on millisecond clock drift.
      final soon = DateTime.now().add(const Duration(days: 5));
      await tester.pumpWidget(_wrap(
        storage,
        SourcesScreen(),
        seed: [
          Source(
            id: 'soon',
            name: 'Expiring',
            type: SourceType.romm,
            url: 'http://x',
            autoMap: true,
            tokenExpiresAt: soon,
            knownPlatforms: const {'snes': 4},
          ),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining(RegExp(r'Expires in [45]d')), findsOneWidget);
    });

    testWidgets('two sources render two cards', (tester) async {
      final storage = await _initMockStorage();
      await tester.pumpWidget(_wrap(
        storage,
        const SourcesScreen(),
        seed: const [
          Source(
            id: 'a',
            name: 'A',
            type: SourceType.romm,
            url: 'http://a',
            autoMap: true,
            knownPlatforms: {'snes': 4},
          ),
          Source(
            id: 'b',
            name: 'B',
            type: SourceType.smb,
            host: 'nas',
            share: 'roms',
          ),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('2 sources'), findsOneWidget);
    });
  });

  group('SourcesScreen — list shortcuts', () {
    // The hints are the point of the test: a shortcut nobody can see is a
    // shortcut nobody uses, and each hint is also the tappable half of the
    // same action. If these disappear the feature is half gone even though
    // the key handler still works.
    testWidgets('the focused card puts its three actions in the HUD',
        (tester) async {
      final storage = await _initMockStorage();
      await tester.pumpWidget(_wrap(
        storage,
        const SourcesScreen(),
        seed: const [
          Source(
            id: 'mine',
            name: 'Mein RomM',
            type: SourceType.romm,
            url: 'http://192.168.1.50:8090',
            autoMap: true,
          ),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Use this'), findsOneWidget);
      expect(find.text('Disable'), findsOneWidget);
      expect(find.text('Remove'), findsOneWidget);
      // On by default, so the eye is filled; not in use, so the tick is an
      // empty ring. Two marks, two different decisions.
      expect(find.byIcon(Icons.visibility), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
    });

    testWidgets('the disable hint reads Enable on a source already off',
        (tester) async {
      final storage = await _initMockStorage();
      await tester.pumpWidget(_wrap(
        storage,
        const SourcesScreen(),
        seed: const [
          Source(
            id: 'mine',
            name: 'Mein RomM',
            type: SourceType.romm,
            url: 'http://192.168.1.50:8090',
            autoMap: true,
            enabled: false,
          ),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Enable'), findsOneWidget);
      expect(find.text('Disable'), findsNothing);
    });

    testWidgets('the actions menu ends in real buttons, not a typed-out line',
        (tester) async {
      // It used to end in a hardcoded Chinese string naming [A]/[X]/[B]:
      // untranslated in six languages, wrong on two of the three controller
      // layouts, and doing nothing under a finger.
      final storage = await _initMockStorage();
      await tester.pumpWidget(_wrap(
        storage,
        const SourcesScreen(),
        seed: const [
          Source(
            id: 'mine',
            name: 'Mein RomM',
            type: SourceType.romm,
            url: 'http://192.168.1.50:8090',
            autoMap: true,
          ),
        ],
      ));
      await tester.pumpAndSettle();

      // All of it outside the fake async zone: opening the menu plays a
      // navigation sound, and the audio plugin's timers never complete inside
      // that zone — the test then fails on teardown rather than on an
      // expectation.
      await tester.runAsync(() async {
        await tester.tap(find.text('Mein RomM'));
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 400));
        await tester.pump();

        expect(find.text('Remove'), findsWidgets);
        expect(find.textContaining('[A]'), findsNothing);
        // The screen's own HUD plus the menu's.
        expect(find.byType(ConsoleHud), findsNWidgets(2));
        expect(find.text('Select'), findsOneWidget);
      });

      // Swap the screen out while the scope is still alive: the overlay
      // releases its dialog-priority claim from a zero-duration timer in
      // dispose, and a test that ends on top of it fails the teardown rather
      // than any expectation.
      await tester.pumpWidget(_wrap(storage, const SizedBox.shrink()));
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('no card focused means no per-source hints', (tester) async {
      final storage = await _initMockStorage();
      await tester.pumpWidget(_wrap(storage, const SourcesScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Use this'), findsNothing);
      expect(find.text('Disable'), findsNothing);
      expect(find.text('Remove'), findsNothing);
    });
  });
}
