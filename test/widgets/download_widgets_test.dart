import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:retro_eshop/models/download_item.dart';
import 'package:retro_eshop/models/game_item.dart';
import 'package:retro_eshop/models/system_model.dart';
import 'package:retro_eshop/widgets/download/action_button.dart';
import 'package:retro_eshop/widgets/download/progress_bar.dart';
import 'package:retro_eshop/widgets/download/pulsing_dot.dart';
import 'package:retro_eshop/widgets/download/status_label.dart';
import '../helpers/pump_helpers.dart';

// ─── Test Fixtures ───────────────────────────────────────

const _testGame = GameItem(
  filename: 'Mario.nes',
  displayName: 'Super Mario Bros',
  url: 'http://example.com/Mario.nes',
);

final _testSystem = SystemModel.supportedSystems.first;

DownloadItem _makeItem({
  DownloadStatus status = DownloadStatus.queued,
  double progress = 0.0,
  double? downloadSpeed,
  String? error,
  int? totalBytes,
  int receivedBytes = 0,
}) {
  return DownloadItem(
    id: 'test-1',
    game: _testGame,
    system: _testSystem,
    targetFolder: '/roms/nes',
    status: status,
    progress: progress,
    downloadSpeed: downloadSpeed,
    error: error,
    totalBytes: totalBytes,
    receivedBytes: receivedBytes,
  );
}

// ─── StatusLabel Tests ───────────────────────────────────

void main() {
  group('StatusLabel', () {
    testWidgets('shows "Downloading..." for downloading status', (tester) async {
      await tester.pumpWidget(createTestApp(
        StatusLabel(item: _makeItem(status: DownloadStatus.downloading)),
      ));

      expect(find.text('Downloading...'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_downward_rounded), findsOneWidget);
    });

    testWidgets('shows "Extracting..." for extracting status', (tester) async {
      await tester.pumpWidget(createTestApp(
        StatusLabel(item: _makeItem(status: DownloadStatus.extracting)),
      ));

      expect(find.text('Extracting...'), findsOneWidget);
      expect(find.byIcon(Icons.unarchive_rounded), findsOneWidget);
    });

    testWidgets('shows "Installing..." for moving status', (tester) async {
      await tester.pumpWidget(createTestApp(
        StatusLabel(item: _makeItem(status: DownloadStatus.moving)),
      ));

      expect(find.text('Installing...'), findsOneWidget);
      expect(find.byIcon(Icons.drive_file_move_rounded), findsOneWidget);
    });

    testWidgets('shows "Waiting..." for queued status', (tester) async {
      await tester.pumpWidget(createTestApp(
        StatusLabel(item: _makeItem(status: DownloadStatus.queued)),
      ));

      expect(find.text('Waiting...'), findsOneWidget);
      expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
    });

    testWidgets('shows "Complete" for completed status', (tester) async {
      await tester.pumpWidget(createTestApp(
        StatusLabel(item: _makeItem(status: DownloadStatus.completed)),
      ));

      expect(find.text('Complete'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    testWidgets('shows "Cancelled" for cancelled status', (tester) async {
      await tester.pumpWidget(createTestApp(
        StatusLabel(item: _makeItem(status: DownloadStatus.cancelled)),
      ));

      expect(find.text('Cancelled'), findsOneWidget);
      expect(find.byIcon(Icons.cancel_rounded), findsOneWidget);
    });

    testWidgets('shows "Failed" for error status', (tester) async {
      await tester.pumpWidget(createTestApp(
        StatusLabel(item: _makeItem(status: DownloadStatus.error)),
      ));

      expect(find.text('Failed'), findsOneWidget);
      expect(find.byIcon(Icons.error_rounded), findsOneWidget);
    });

    testWidgets('shows speed text when downloading with speed', (tester) async {
      final item = _makeItem(
        status: DownloadStatus.downloading,
        downloadSpeed: 2048, // 2 MB/s
      );
      await tester.pumpWidget(createTestApp(StatusLabel(item: item)));

      expect(find.text('2.0 MB/s'), findsOneWidget);
    });

    testWidgets('no speed text for queued items', (tester) async {
      await tester.pumpWidget(createTestApp(
        StatusLabel(item: _makeItem(status: DownloadStatus.queued)),
      ));

      // Speed divider should not appear
      expect(find.text('KB/s'), findsNothing);
      expect(find.text('MB/s'), findsNothing);
    });
  });

  // ─── DownloadProgressBar Tests ─────────────────────────

  group('DownloadProgressBar', () {
    testWidgets('renders LinearProgressIndicator for queued', (tester) async {
      await tester.pumpWidget(createTestApp(
        DownloadProgressBar(item: _makeItem(status: DownloadStatus.queued)),
      ));

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('renders indeterminate indicator for extracting', (tester) async {
      await tester.pumpWidget(createTestApp(
        DownloadProgressBar(
            item: _makeItem(status: DownloadStatus.extracting)),
      ));

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('renders indeterminate indicator for moving', (tester) async {
      await tester.pumpWidget(createTestApp(
        DownloadProgressBar(
            item: _makeItem(status: DownloadStatus.moving)),
      ));

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('renders animated progress bar for downloading', (tester) async {
      final item = _makeItem(
        status: DownloadStatus.downloading,
        progress: 0.5,
        totalBytes: 1024 * 1024,
      );
      await tester.pumpWidget(createTestApp(DownloadProgressBar(item: item)));
      await tester.pumpAndSettle();

      // Should show percentage text and FractionallySizedBox
      expect(find.byType(FractionallySizedBox), findsOneWidget);
    });

    testWidgets('shows percentage text when progress > 1%', (tester) async {
      final item = _makeItem(
        status: DownloadStatus.downloading,
        progress: 0.42,
        totalBytes: 100,
      );
      await tester.pumpWidget(createTestApp(DownloadProgressBar(item: item)));
      await tester.pumpAndSettle();

      expect(find.text('42%'), findsOneWidget);
    });

    testWidgets('hides percentage text when progress <= 1%', (tester) async {
      final item = _makeItem(
        status: DownloadStatus.downloading,
        progress: 0.005,
      );
      await tester.pumpWidget(createTestApp(DownloadProgressBar(item: item)));
      await tester.pump();

      expect(find.text('1%'), findsNothing);
      expect(find.text('0%'), findsNothing);
    });
  });

  // ─── PulsingDot Tests ──────────────────────────────────

  group('PulsingDot', () {
    testWidgets('active dot is green', (tester) async {
      await tester.pumpWidget(
          createTestApp(const PulsingDot(isActive: true)));
      await tester.pump();

      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, Colors.green);
    });

    testWidgets('inactive dot is grey', (tester) async {
      await tester.pumpWidget(
          createTestApp(const PulsingDot(isActive: false)));

      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, Colors.grey.shade700);
    });

    testWidgets('active dot has box shadow', (tester) async {
      await tester.pumpWidget(
          createTestApp(const PulsingDot(isActive: true)));
      await tester.pump();

      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.boxShadow, isNotNull);
      expect(decoration.boxShadow!.length, 1);
    });

    testWidgets('inactive dot has no shadow', (tester) async {
      await tester.pumpWidget(
          createTestApp(const PulsingDot(isActive: false)));

      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.boxShadow, isNull);
    });

    testWidgets('dot is 14x14 pixels', (tester) async {
      await tester.pumpWidget(
          createTestApp(const PulsingDot(isActive: false)));

      final container = tester.widget<Container>(find.byType(Container));
      expect(container.constraints?.maxWidth, 14);
      expect(container.constraints?.maxHeight, 14);
    });

    testWidgets('switching from inactive to active starts animation', (tester) async {
      await tester.pumpWidget(
          createTestApp(const PulsingDot(isActive: false)));

      // Switch to active
      await tester.pumpWidget(
          createTestApp(const PulsingDot(isActive: true)));
      await tester.pump(const Duration(milliseconds: 750));

      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, Colors.green);
    });
  });

  // ─── DownloadActionButton Tests ────────────────────────

  group('DownloadActionButton', () {
    testWidgets('completed shows green check icon', (tester) async {
      await tester.pumpWidget(createTestApp(
        DownloadActionButton(
          item: _makeItem(status: DownloadStatus.completed),
          isHighlighted: false,
          onTap: () {},
        ),
      ));

      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });

    testWidgets('cancelled shows grey close icon', (tester) async {
      await tester.pumpWidget(createTestApp(
        DownloadActionButton(
          item: _makeItem(status: DownloadStatus.cancelled),
          isHighlighted: false,
          onTap: () {},
        ),
      ));

      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });

    testWidgets('error shows red refresh icon', (tester) async {
      await tester.pumpWidget(createTestApp(
        DownloadActionButton(
          item: _makeItem(status: DownloadStatus.error),
          isHighlighted: false,
          onTap: () {},
        ),
      ));

      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
    });

    testWidgets('downloading shows red stop icon', (tester) async {
      await tester.pumpWidget(createTestApp(
        DownloadActionButton(
          item: _makeItem(status: DownloadStatus.downloading),
          isHighlighted: false,
          onTap: () {},
        ),
      ));

      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
    });

    testWidgets('queued shows white close icon', (tester) async {
      await tester.pumpWidget(createTestApp(
        DownloadActionButton(
          item: _makeItem(status: DownloadStatus.queued),
          isHighlighted: false,
          onTap: () {},
        ),
      ));

      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });

    testWidgets('onTap fires callback', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(createTestApp(
        DownloadActionButton(
          item: _makeItem(status: DownloadStatus.queued),
          isHighlighted: false,
          onTap: () => tapped = true,
        ),
      ));

      await tester.tap(find.byType(DownloadActionButton));
      expect(tapped, true);
    });

    testWidgets('highlighted increases background opacity', (tester) async {
      await tester.pumpWidget(createTestApp(
        DownloadActionButton(
          item: _makeItem(status: DownloadStatus.completed),
          isHighlighted: true,
          onTap: () {},
        ),
      ));

      final container = tester.widget<AnimatedContainer>(
          find.byType(AnimatedContainer));
      final decoration = container.decoration as BoxDecoration;
      // Highlighted: color.withValues(alpha: 0.25)
      expect(decoration.color!.a, greaterThan(0.2));
    });

    testWidgets('non-highlighted has lower background opacity', (tester) async {
      await tester.pumpWidget(createTestApp(
        DownloadActionButton(
          item: _makeItem(status: DownloadStatus.completed),
          isHighlighted: false,
          onTap: () {},
        ),
      ));

      final container = tester.widget<AnimatedContainer>(
          find.byType(AnimatedContainer));
      final decoration = container.decoration as BoxDecoration;
      // Non-highlighted: color.withValues(alpha: 0.1)
      expect(decoration.color!.a, lessThan(0.15));
    });

    testWidgets('button has circular shape', (tester) async {
      await tester.pumpWidget(createTestApp(
        DownloadActionButton(
          item: _makeItem(status: DownloadStatus.queued),
          isHighlighted: false,
          onTap: () {},
        ),
      ));

      final container = tester.widget<AnimatedContainer>(
          find.byType(AnimatedContainer));
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.shape, BoxShape.circle);
    });
  });
}
