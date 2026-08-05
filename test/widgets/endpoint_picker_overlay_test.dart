import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retro_eshop/features/sources/endpoint_picker_overlay.dart';
import 'package:retro_eshop/models/config/source.dart';
import 'package:retro_eshop/providers/app_providers.dart';
import 'package:retro_eshop/services/config_storage_service.dart';
import 'package:retro_eshop/services/endpoint_probe_service.dart';
import 'package:retro_eshop/services/sources_notifier.dart';
import 'package:retro_eshop/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/pump_helpers.dart';

class _StubSourcesNotifier extends SourcesNotifier {
  _StubSourcesNotifier(List<Source> seed)
      : super(ConfigStorageService(
          directoryProvider: () async =>
              Directory.systemTemp.createTempSync('rshop_picker_'),
        )) {
    state = SourcesState(
      sources: List<Source>.unmodifiable(seed),
      loading: false,
    );
  }
}

const _lan = SourceEndpoint(
  id: 'lan',
  label: 'LAN',
  url: 'http://192.168.1.50:8090',
);
const _remote = SourceEndpoint(
  id: 'remote',
  label: 'Remote',
  url: 'https://roms.example.org',
);

const _source = Source(
  id: 'src',
  name: 'My RomM',
  type: SourceType.romm,
  url: 'http://192.168.1.50:8090',
  endpoints: [_lan, _remote],
);

const _pinnedSource = Source(
  id: 'src',
  name: 'My RomM',
  type: SourceType.romm,
  url: 'https://roms.example.org',
  endpoints: [_lan, _remote],
  endpointSelection: EndpointSelection.pinned,
  pinnedEndpointId: 'remote',
);

EndpointProbeService _probe() => EndpointProbeService(
      connect: (host, port, timeout) async {
        if (host == 'roms.example.org') throw const SocketException('down');
      },
    );

Future<StorageService> _storage() async {
  SharedPreferences.setMockInitialValues({});
  FlutterSecureStorage.setMockInitialValues({});
  final s = StorageService();
  await s.init();
  return s;
}

Future<List<Override>> _overrides(List<Source> seed) async => [
      storageServiceProvider.overrideWithValue(await _storage()),
      sourcesProvider.overrideWith((ref) => _StubSourcesNotifier(seed)),
    ];

/// Swaps the overlay out while keeping the ProviderScope alive: the scope
/// releases its priority claim from a microtask in `dispose`, which explodes
/// if the manager went with it.
Future<void> _teardown(WidgetTester tester, List<Override> overrides) async {
  await tester.pumpWidget(createTestAppWithProviders(
    const SizedBox.shrink(),
    size: const Size(640, 480),
    overrides: overrides,
  ));
  await tester.pump(const Duration(milliseconds: 50));
}

/// Config writes are real file I/O, which never completes inside the fake
/// async zone `pump` runs in.
Future<void> _tapForReal(WidgetTester tester, Finder target) async {
  await tester.runAsync(() async {
    await tester.tap(target);
    await tester.pump();
    await Future<void>.delayed(const Duration(milliseconds: 300));
  });
  await tester.pump();
}

void main() {
  testWidgets('shows per-route latency, no-answer and what auto would pick',
      (tester) async {
    final overrides = await _overrides(const [_source]);
    var closed = 0;
    await tester.pumpWidget(createTestAppWithProviders(
      EndpointPickerOverlay(
        source: _source,
        onClose: () => closed++,
        probeService: _probe(),
      ),
      size: const Size(640, 480),
      overrides: overrides,
    ));
    await tester.pumpAndSettle();

    expect(find.text('No answer'), findsOneWidget);
    expect(find.textContaining('Would use LAN'), findsOneWidget);
    expect(find.textContaining('ms'), findsWidgets);
    expect(find.text('Fastest'), findsOneWidget);
    // Touch counterparts of [Y] and [X], one pair per route.
    expect(find.byIcon(Icons.edit_outlined), findsNWidgets(2));
    expect(find.byIcon(Icons.delete_outline), findsNWidgets(2));
    expect(closed, 0);
    expect(tester.takeException(), isNull);

    await _teardown(tester, overrides);
  });

  testWidgets('a pinned source says so and offers to hand the choice back',
      (tester) async {
    final overrides = await _overrides(const [_pinnedSource]);
    await tester.pumpWidget(createTestAppWithProviders(
      EndpointPickerOverlay(
        source: _pinnedSource,
        onClose: () {},
        probeService: _probe(),
      ),
      size: const Size(640, 480),
      overrides: overrides,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Locked'), findsOneWidget);
    expect(find.textContaining('Drops the lock'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _teardown(tester, overrides);
  });

  testWidgets('tapping a row runs the same path the [A] button does',
      (tester) async {
    final overrides = await _overrides(const [_source]);
    var closed = 0;
    await tester.pumpWidget(createTestAppWithProviders(
      EndpointPickerOverlay(
        source: _source,
        onClose: () => closed++,
        probeService: _probe(),
      ),
      size: const Size(640, 480),
      overrides: overrides,
    ));
    await tester.pumpAndSettle();

    await _tapForReal(tester, find.text('Remote'));

    // The switch completed and the overlay closed itself — the row is not a
    // decoration that only the gamepad can operate.
    expect(closed, 1);
    expect(tester.takeException(), isNull);

    await _teardown(tester, overrides);
  });

  testWidgets('tapping automatic runs to completion too', (tester) async {
    final overrides = await _overrides(const [_pinnedSource]);
    var closed = 0;
    await tester.pumpWidget(createTestAppWithProviders(
      EndpointPickerOverlay(
        source: _pinnedSource,
        onClose: () => closed++,
        probeService: _probe(),
      ),
      size: const Size(640, 480),
      overrides: overrides,
    ));
    await tester.pumpAndSettle();

    await _tapForReal(tester, find.text('Automatic'));

    expect(closed, 1);
    expect(tester.takeException(), isNull);

    await _teardown(tester, overrides);
  });

  testWidgets('the order row is offered next to automatic, and is tappable',
      (tester) async {
    // Tapping a route means "pin this one" — an override. Following the list
    // is the opposite of that, so it needs a row of its own rather than being
    // hidden behind the same gesture.
    final overrides = await _overrides([_source]);

    await tester.pumpWidget(createTestAppWithProviders(
      EndpointPickerOverlay(
        source: _source,
        onClose: () {},
        probeService: _probe(),
      ),
      size: const Size(640, 480),
      overrides: overrides,
    ));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('My order'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('My order'),
        matching: find.byType(GestureDetector),
      ),
      findsAtLeastNWidgets(1),
    );
    // Reordering by finger, so the order is not a gamepad-only setting.
    expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_up), findsOneWidget);

    await _teardown(tester, overrides);
  });
}
