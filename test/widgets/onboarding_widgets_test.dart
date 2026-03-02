import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:retro_eshop/features/onboarding/onboarding_state.dart';
import 'package:retro_eshop/features/onboarding/widgets/connection_test_indicator.dart';
import 'package:retro_eshop/features/onboarding/widgets/provider_list_item.dart';
import 'package:retro_eshop/features/onboarding/widgets/romm_action_button.dart';
import 'package:retro_eshop/features/onboarding/widgets/romm_folder_view.dart';
import 'package:retro_eshop/models/config/provider_config.dart';
import 'package:retro_eshop/models/system_model.dart';
import '../helpers/pump_helpers.dart';

// ─── Helpers ────────────────────────────────────────────

const _snesId = 'snes';

ScannedFolder _makeFolder({
  String name = 'SNES',
  int fileCount = 42,
  String? autoMatchedSystemId,
  bool isLocalOnly = false,
}) =>
    ScannedFolder(
      name: name,
      fileCount: fileCount,
      autoMatchedSystemId: autoMatchedSystemId,
      isLocalOnly: isLocalOnly,
    );

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

  // ─── ProviderListItem ───────────────────────────────────

  group('ProviderListItem', () {
    Widget buildItem(
      ProviderConfig provider, {
      VoidCallback? onMoveUp,
      VoidCallback? onMoveDown,
    }) {
      return createTestAppWithProviders(
        ProviderListItem(
          provider: provider,
          index: 0,
          onEdit: () {},
          onDelete: () {},
          onMoveUp: onMoveUp,
          onMoveDown: onMoveDown,
        ),
      );
    }

    testWidgets('renders WEB type with language icon and URL', (tester) async {
      await tester.pumpWidget(buildItem(
        const ProviderConfig(
          type: ProviderType.web,
          priority: 0,
          url: 'https://example.com/roms',
        ),
      ));

      expect(find.byIcon(Icons.language), findsOneWidget);
      expect(find.text('https://example.com/roms'), findsOneWidget);
      expect(find.text('WEB'), findsOneWidget);
    });

    testWidgets('renders FTP type with dns icon and host:port/path',
        (tester) async {
      await tester.pumpWidget(buildItem(
        const ProviderConfig(
          type: ProviderType.ftp,
          priority: 0,
          host: '192.168.1.10',
          port: 2121,
          path: '/roms',
        ),
      ));

      expect(find.byIcon(Icons.dns), findsOneWidget);
      expect(find.text('192.168.1.10:2121/roms'), findsOneWidget);
      expect(find.text('FTP'), findsOneWidget);
    });

    testWidgets('renders SMB type with folder_shared icon and host/share/path',
        (tester) async {
      await tester.pumpWidget(buildItem(
        const ProviderConfig(
          type: ProviderType.smb,
          priority: 0,
          host: 'nas',
          share: 'games',
          path: '/retro',
        ),
      ));

      expect(find.byIcon(Icons.folder_shared), findsOneWidget);
      expect(find.text('nas/games/retro'), findsOneWidget);
      expect(find.text('SMB'), findsOneWidget);
    });

    testWidgets('renders RomM type with storage icon and URL',
        (tester) async {
      await tester.pumpWidget(buildItem(
        const ProviderConfig(
          type: ProviderType.romm,
          priority: 0,
          url: 'https://romm.local',
        ),
      ));

      expect(find.byIcon(Icons.storage), findsOneWidget);
      expect(find.text('https://romm.local'), findsOneWidget);
      expect(find.text('ROMM'), findsOneWidget);
    });

    testWidgets('shows warning icon when needsAuth is true', (tester) async {
      await tester.pumpWidget(buildItem(
        const ProviderConfig(
          type: ProviderType.web,
          priority: 0,
          url: 'https://example.com',
          // No auth → needsAuth = true
        ),
      ));

      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('hides warning icon when auth is complete', (tester) async {
      await tester.pumpWidget(buildItem(
        const ProviderConfig(
          type: ProviderType.ftp,
          priority: 0,
          host: '192.168.1.1',
          port: 21,
          auth: AuthConfig(user: 'admin', pass: 'secret'),
        ),
      ));

      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    });

    testWidgets('shows move buttons only when callbacks provided',
        (tester) async {
      // Without move callbacks
      await tester.pumpWidget(buildItem(
        const ProviderConfig(type: ProviderType.web, priority: 0, url: 'x'),
      ));
      expect(find.byIcon(Icons.arrow_upward), findsNothing);
      expect(find.byIcon(Icons.arrow_downward), findsNothing);

      // With move callbacks
      await tester.pumpWidget(buildItem(
        const ProviderConfig(type: ProviderType.web, priority: 0, url: 'x'),
        onMoveUp: () {},
        onMoveDown: () {},
      ));
      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
      expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
    });
  });

  // ─── RommActionButton ───────────────────────────────────

  group('RommActionButton', () {
    testWidgets('renders label and icon', (tester) async {
      await tester.pumpWidget(createTestAppWithProviders(
        RommActionButton(
          label: 'Scan folder',
          icon: Icons.search_rounded,
          color: Colors.blue,
          onTap: () {},
        ),
      ));

      expect(find.text('Scan folder'), findsOneWidget);
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);
    });

    testWidgets('applies color to icon', (tester) async {
      await tester.pumpWidget(createTestAppWithProviders(
        RommActionButton(
          label: 'Test',
          icon: Icons.folder_open_rounded,
          color: Colors.green,
          onTap: () {},
        ),
      ));

      final icon = tester.widget<Icon>(find.byIcon(Icons.folder_open_rounded));
      expect(icon.color, Colors.green.withValues(alpha: 0.8));
    });

    testWidgets('has minimum height constraint', (tester) async {
      await tester.pumpWidget(createTestAppWithProviders(
        RommActionButton(
          label: 'X',
          icon: Icons.add,
          color: Colors.red,
          onTap: () {},
        ),
      ));

      final containers = tester.widgetList<Container>(
        find.descendant(
          of: find.byType(RommActionButton),
          matching: find.byType(Container),
        ),
      );
      final withConstraint = containers.where(
        (c) => c.constraints?.minHeight == 56,
      );
      expect(withConstraint, isNotEmpty);
    });
  });

  // ─── FolderRow ──────────────────────────────────────────

  group('FolderRow', () {
    testWidgets('matched status shows green check icon', (tester) async {
      await tester.pumpWidget(createTestAppWithProviders(
        FolderRow(
          folder: _makeFolder(),
          status: FolderStatus.matched,
          assignedSystemId: _snesId,
        ),
      ));

      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    testWidgets('ignoredNoFiles shows cancel icon and ignored text',
        (tester) async {
      await tester.pumpWidget(createTestAppWithProviders(
        FolderRow(
          folder: _makeFolder(fileCount: 0),
          status: FolderStatus.ignoredNoFiles,
        ),
      ));

      expect(find.byIcon(Icons.cancel_rounded), findsOneWidget);
      expect(find.text('ignored'), findsOneWidget);
    });

    testWidgets('ignoredNotSelected shows cancel icon and not selected text',
        (tester) async {
      await tester.pumpWidget(createTestAppWithProviders(
        FolderRow(
          folder: _makeFolder(),
          status: FolderStatus.ignoredNotSelected,
        ),
      ));

      expect(find.byIcon(Icons.cancel_rounded), findsOneWidget);
      expect(find.text('not selected'), findsOneWidget);
    });

    testWidgets('shows system name for matched folder', (tester) async {
      final snesName = SystemModel.supportedSystems
          .firstWhere((s) => s.id == _snesId)
          .name;

      await tester.pumpWidget(createTestAppWithProviders(
        FolderRow(
          folder: _makeFolder(),
          status: FolderStatus.matched,
          assignedSystemId: _snesId,
        ),
      ));

      expect(find.text(snesName), findsOneWidget);
    });

    testWidgets('shows file count', (tester) async {
      await tester.pumpWidget(createTestAppWithProviders(
        FolderRow(
          folder: _makeFolder(fileCount: 42),
          status: FolderStatus.matched,
        ),
      ));

      expect(find.text('42 files'), findsOneWidget);
    });

    testWidgets('shows unassign button when manually assigned',
        (tester) async {
      await tester.pumpWidget(createTestAppWithProviders(
        FolderRow(
          folder: _makeFolder(),
          status: FolderStatus.matched,
          isManuallyAssigned: true,
          onUnassign: () {},
        ),
      ));

      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });
  });

  // ─── LocalFoundFolderRow ────────────────────────────────

  group('LocalFoundFolderRow', () {
    testWidgets('renders system name from autoMatchedSystemId',
        (tester) async {
      final snesName = SystemModel.supportedSystems
          .firstWhere((s) => s.id == _snesId)
          .name;

      await tester.pumpWidget(createTestAppWithProviders(
        LocalFoundFolderRow(
          folder: _makeFolder(autoMatchedSystemId: _snesId),
          isEnabled: true,
          onToggle: () {},
        ),
      ));

      expect(find.text(snesName), findsOneWidget);
    });

    testWidgets('shows local badge', (tester) async {
      await tester.pumpWidget(createTestAppWithProviders(
        LocalFoundFolderRow(
          folder: _makeFolder(autoMatchedSystemId: _snesId),
          isEnabled: true,
          onToggle: () {},
        ),
      ));

      expect(find.text('local'), findsOneWidget);
    });

    testWidgets('shows folder path and file count', (tester) async {
      await tester.pumpWidget(createTestAppWithProviders(
        LocalFoundFolderRow(
          folder: _makeFolder(name: 'MyROMs', fileCount: 15, autoMatchedSystemId: _snesId),
          isEnabled: false,
          onToggle: () {},
        ),
      ));

      expect(find.textContaining('MyROMs/'), findsOneWidget);
      expect(find.textContaining('15 files'), findsOneWidget);
    });

    testWidgets('shows check icon when enabled', (tester) async {
      await tester.pumpWidget(createTestAppWithProviders(
        LocalFoundFolderRow(
          folder: _makeFolder(autoMatchedSystemId: _snesId),
          isEnabled: true,
          onToggle: () {},
        ),
      ));

      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('no check icon when disabled', (tester) async {
      await tester.pumpWidget(createTestAppWithProviders(
        LocalFoundFolderRow(
          folder: _makeFolder(autoMatchedSystemId: _snesId),
          isEnabled: false,
          onToggle: () {},
        ),
      ));

      expect(find.byIcon(Icons.check), findsNothing);
    });
  });

  // ─── UnmatchedFolderRow ─────────────────────────────────

  group('UnmatchedFolderRow', () {
    testWidgets('shows help outline icon', (tester) async {
      await tester.pumpWidget(createTestAppWithProviders(
        UnmatchedFolderRow(
          folder: _makeFolder(name: 'unknown_roms'),
          availableSystemIds: const [_snesId],
          onAssign: (_) {},
        ),
      ));

      expect(find.byIcon(Icons.help_outline_rounded), findsOneWidget);
    });

    testWidgets('renders folder name with trailing slash', (tester) async {
      await tester.pumpWidget(createTestAppWithProviders(
        UnmatchedFolderRow(
          folder: _makeFolder(name: 'myFolder'),
          availableSystemIds: const [_snesId],
          onAssign: (_) {},
        ),
      ));

      expect(find.text('myFolder/'), findsOneWidget);
    });

    testWidgets('shows file count', (tester) async {
      await tester.pumpWidget(createTestAppWithProviders(
        UnmatchedFolderRow(
          folder: _makeFolder(fileCount: 99),
          availableSystemIds: const [_snesId],
          onAssign: (_) {},
        ),
      ));

      expect(find.text('99 files'), findsOneWidget);
    });

    testWidgets('contains SystemDropdown', (tester) async {
      await tester.pumpWidget(createTestAppWithProviders(
        UnmatchedFolderRow(
          folder: _makeFolder(),
          availableSystemIds: const [_snesId],
          onAssign: (_) {},
        ),
      ));

      expect(find.byType(SystemDropdown), findsOneWidget);
    });
  });

  // ─── SystemDropdown ─────────────────────────────────────

  group('SystemDropdown', () {
    testWidgets('shows skip hint text', (tester) async {
      await tester.pumpWidget(createTestApp(
        SystemDropdown(
          availableSystemIds: const [_snesId],
          onChanged: (_) {},
        ),
      ));

      expect(find.text('-- Skip --'), findsWidgets);
    });

    testWidgets('renders system name for known ID in items', (tester) async {
      final snesName = SystemModel.supportedSystems
          .firstWhere((s) => s.id == _snesId)
          .name;

      await tester.pumpWidget(createTestApp(
        SystemDropdown(
          availableSystemIds: const [_snesId],
          onChanged: (_) {},
        ),
      ));

      // Items exist in the dropdown (offstage)
      expect(find.text(snesName, skipOffstage: false), findsOneWidget);
    });

    testWidgets('renders multiple system names', (tester) async {
      const ids = ['snes', 'nes', 'gb'];
      await tester.pumpWidget(createTestApp(
        SystemDropdown(
          availableSystemIds: ids,
          onChanged: (_) {},
        ),
      ));

      for (final id in ids) {
        final name = SystemModel.supportedSystems
            .where((s) => s.id == id)
            .firstOrNull
            ?.name;
        if (name != null) {
          expect(find.text(name, skipOffstage: false), findsOneWidget);
        }
      }
    });
  });
}
