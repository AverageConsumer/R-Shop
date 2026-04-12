import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retro_eshop/features/settings/sources_screen.dart';
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
      expect(find.text('1 source · [Y] add new'), findsOneWidget);
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
      expect(find.text('2 sources · [Y] add new'), findsOneWidget);
    });
  });
}
