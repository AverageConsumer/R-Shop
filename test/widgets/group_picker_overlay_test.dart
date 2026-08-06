import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retro_eshop/features/sources/group_picker_overlay.dart';
import 'package:retro_eshop/models/config/app_config.dart';
import 'package:retro_eshop/models/config/source.dart';
import 'package:retro_eshop/providers/app_providers.dart';
import 'package:retro_eshop/services/config_storage_service.dart';
import 'package:retro_eshop/services/sources_notifier.dart';
import 'package:retro_eshop/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/pump_helpers.dart';

/// The group editor, checked the way this project has learned to check
/// overlays: **every row has to answer to a finger.** Four overlays in this
/// feature shipped gamepad-only at some point, and they all looked fine.
class _StubSourcesNotifier extends SourcesNotifier {
  _StubSourcesNotifier(List<Source> seed, List<SourceGroup> groups)
      : super(ConfigStorageService(
          directoryProvider: () async =>
              Directory.systemTemp.createTempSync('rshop_groups_'),
        )) {
    state = SourcesState(
      sources: List<Source>.unmodifiable(seed),
      loading: false,
      groups: List<SourceGroup>.unmodifiable(groups),
    );
  }
}

Source _src(String id, String name, {SourceType type = SourceType.romm}) =>
    Source(
      id: id,
      name: name,
      type: type,
      url: 'http://$id.local:8090',
    );

Future<StorageService> _storage() async {
  SharedPreferences.setMockInitialValues({});
  FlutterSecureStorage.setMockInitialValues({});
  final s = StorageService();
  await s.init();
  return s;
}

Future<List<Override>> _overrides(
  List<Source> seed,
  List<SourceGroup> groups,
) async =>
    [
      storageServiceProvider.overrideWithValue(await _storage()),
      sourcesProvider
          .overrideWith((ref) => _StubSourcesNotifier(seed, groups)),
    ];

Future<void> _teardown(WidgetTester tester, List<Override> overrides) async {
  await tester.pumpWidget(createTestAppWithProviders(
    const SizedBox.shrink(),
    size: const Size(640, 480),
    overrides: overrides,
  ));
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('an ungrouped source is offered the sources it could join with',
      (tester) async {
    final sources = [
      _src('lan', 'LAN RomM'),
      _src('wan', 'WAN RomM'),
      _src('nas', 'NAS', type: SourceType.smb),
    ];
    final overrides = await _overrides(sources, const []);

    await tester.pumpWidget(createTestAppWithProviders(
      GroupPickerOverlay(source: sources.first, onClose: () {}),
      size: const Size(640, 480),
      overrides: overrides,
    ));
    await tester.pump();

    expect(find.text('WAN RomM'), findsOneWidget);
    // Different protocol: it cannot be the same server, so it is not offered.
    expect(find.text('NAS'), findsNothing);

    await _teardown(tester, overrides);
  });

  testWidgets('a grouped source gets the mode rows and its members',
      (tester) async {
    final sources = [_src('lan', 'LAN RomM'), _src('wan', 'WAN RomM')];
    final overrides = await _overrides(sources, const [
      SourceGroup(
        id: 'grp-lan',
        name: 'Home',
        memberIds: ['lan', 'wan'],
        cacheOwnerId: 'lan',
      ),
    ]);

    await tester.pumpWidget(createTestAppWithProviders(
      GroupPickerOverlay(source: sources.first, onClose: () {}),
      size: const Size(640, 480),
      overrides: overrides,
    ));
    await tester.pump();

    // One tickbox, not a pair of rows: a group starts on `ordered`, so it is
    // unticked and the members below are the order.
    expect(find.text('Automatic'), findsOneWidget);
    expect(find.byIcon(Icons.check_box_outline_blank), findsOneWidget);
    expect(find.byIcon(Icons.check_box), findsNothing);
    expect(find.text('My order'), findsNothing);
    expect(find.text('LAN RomM'), findsOneWidget);
    expect(find.text('WAN RomM'), findsOneWidget);
    // The group's own label and size, so it is clear what is being edited.
    expect(find.textContaining('Home'), findsOneWidget);

    await _teardown(tester, overrides);
  });

  testWidgets('every row is inside a tappable gesture detector',
      (tester) async {
    // The failure this guards against is a row that looks identical and does
    // nothing under a finger, which reads as the app having frozen.
    final sources = [_src('lan', 'LAN RomM'), _src('wan', 'WAN RomM')];
    final overrides = await _overrides(sources, const [
      SourceGroup(
        id: 'grp-lan',
        name: 'Home',
        memberIds: ['lan', 'wan'],
        cacheOwnerId: 'lan',
      ),
    ]);

    await tester.pumpWidget(createTestAppWithProviders(
      GroupPickerOverlay(source: sources.first, onClose: () {}),
      size: const Size(640, 480),
      overrides: overrides,
    ));
    await tester.pump();

    for (final label in const [
      'Automatic',
      'LAN RomM',
      'WAN RomM',
      'Dissolve the group',
      'Cancel',
    ]) {
      final row = find.ancestor(
        of: find.text(label),
        matching: find.byType(GestureDetector),
      );
      expect(row, findsAtLeastNWidgets(1), reason: '$label must be tappable');
    }

    await _teardown(tester, overrides);
  });

  testWidgets('a member row carries its own actions as icons',
      (tester) async {
    // Not a submenu: the user asked for the icons to stay on the row and for
    // ▶ to walk the cursor onto them — "不是開視窗，是那邊會有小圖示，我焦點
    // 移到小圖示上面". Leaving is one of them, which is what he expected the
    // arrows to be.
    final sources = [_src('lan', 'LAN RomM'), _src('wan', 'WAN RomM')];
    final overrides = await _overrides(sources, const [
      SourceGroup(
        id: 'grp-lan',
        name: 'Home',
        memberIds: ['lan', 'wan'],
        cacheOwnerId: 'lan',
      ),
    ]);

    await tester.pumpWidget(createTestAppWithProviders(
      GroupPickerOverlay(source: sources.first, onClose: () {}),
      size: const Size(640, 480),
      overrides: overrides,
    ));
    await tester.pump();

    // A handle to start moving it and a way out, one of each per member. The
    // arrows appear on the row being moved, not on every row at once.
    expect(find.byIcon(Icons.drag_handle), findsNWidgets(2));
    expect(find.byIcon(Icons.logout), findsNWidgets(2));
    expect(find.byIcon(Icons.keyboard_arrow_up), findsNothing);

    await _teardown(tester, overrides);
  });

  testWidgets('every row icon is its own tap target', (tester) async {
    final sources = [_src('lan', 'LAN RomM'), _src('wan', 'WAN RomM')];
    final overrides = await _overrides(sources, const [
      SourceGroup(
        id: 'grp-lan',
        name: 'Home',
        memberIds: ['lan', 'wan'],
        cacheOwnerId: 'lan',
      ),
    ]);

    await tester.pumpWidget(createTestAppWithProviders(
      GroupPickerOverlay(source: sources.first, onClose: () {}),
      size: const Size(640, 480),
      overrides: overrides,
    ));
    await tester.pump();

    // The pad reaches them with ▶; a finger must not have to.
    for (final icon in const [Icons.logout, Icons.drag_handle]) {
      expect(
        find.ancestor(
          of: find.byIcon(icon).first,
          matching: find.byType(GestureDetector),
        ),
        findsAtLeastNWidgets(1),
        reason: '$icon must be tappable on its own',
      );
    }

    await _teardown(tester, overrides);
  });
}
