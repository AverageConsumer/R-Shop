import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:retro_eshop/features/settings/widgets/volume_slider.dart';
import '../helpers/pump_helpers.dart';

void main() {
  group('VolumeSlider', () {
    testWidgets('has exactly 20 AnimatedContainer bars', (tester) async {
      await tester.pumpWidget(createTestApp(
        const VolumeSlider(volume: 0.5),
      ));

      final containers = tester.widgetList<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      expect(containers.length, 20);
    });

    testWidgets('volume 0.0 has 0 bars with boxShadow (isSelected=true)', (tester) async {
      await tester.pumpWidget(createTestApp(
        const VolumeSlider(volume: 0.0, isSelected: true),
      ));

      final containers = tester.widgetList<AnimatedContainer>(
        find.byType(AnimatedContainer),
      ).toList();
      final withShadow = containers.where((c) {
        final dec = c.decoration as BoxDecoration;
        return dec.boxShadow != null && dec.boxShadow!.isNotEmpty;
      }).length;
      expect(withShadow, 0);
    });

    testWidgets('volume 1.0 has 20 bars with boxShadow (isSelected=true)', (tester) async {
      await tester.pumpWidget(createTestApp(
        const VolumeSlider(volume: 1.0, isSelected: true),
      ));

      final containers = tester.widgetList<AnimatedContainer>(
        find.byType(AnimatedContainer),
      ).toList();
      final withShadow = containers.where((c) {
        final dec = c.decoration as BoxDecoration;
        return dec.boxShadow != null && dec.boxShadow!.isNotEmpty;
      }).length;
      expect(withShadow, 20);
    });

    testWidgets('volume 0.5 has 10 bars with boxShadow (isSelected=true)', (tester) async {
      await tester.pumpWidget(createTestApp(
        const VolumeSlider(volume: 0.5, isSelected: true),
      ));

      final containers = tester.widgetList<AnimatedContainer>(
        find.byType(AnimatedContainer),
      ).toList();
      final withShadow = containers.where((c) {
        final dec = c.decoration as BoxDecoration;
        return dec.boxShadow != null && dec.boxShadow!.isNotEmpty;
      }).length;
      expect(withShadow, 10);
    });

    testWidgets('isSelected=false has no bars with boxShadow', (tester) async {
      await tester.pumpWidget(createTestApp(
        const VolumeSlider(volume: 1.0, isSelected: false),
      ));

      final containers = tester.widgetList<AnimatedContainer>(
        find.byType(AnimatedContainer),
      ).toList();
      final withShadow = containers.where((c) {
        final dec = c.decoration as BoxDecoration;
        return dec.boxShadow != null && dec.boxShadow!.isNotEmpty;
      }).length;
      expect(withShadow, 0);
    });

    testWidgets('onChanged callback triggered on tap', (tester) async {
      double? receivedVolume;
      await tester.pumpWidget(createTestApp(
        VolumeSlider(
          volume: 0.0,
          onChanged: (v) => receivedVolume = v,
        ),
      ));

      await tester.tap(find.byType(VolumeSlider));
      expect(receivedVolume, isNotNull);
      expect(receivedVolume, greaterThanOrEqualTo(0.0));
      expect(receivedVolume, lessThanOrEqualTo(1.0));
    });

    testWidgets('onChanged callback triggered on horizontal drag', (tester) async {
      double? receivedVolume;
      await tester.pumpWidget(createTestApp(
        VolumeSlider(
          volume: 0.0,
          onChanged: (v) => receivedVolume = v,
        ),
      ));

      await tester.drag(find.byType(VolumeSlider), const Offset(50, 0));
      expect(receivedVolume, isNotNull);
    });

    testWidgets('onChanged null means no GestureDetector', (tester) async {
      await tester.pumpWidget(createTestApp(
        const VolumeSlider(volume: 0.5),
      ));

      expect(find.byType(GestureDetector), findsNothing);
    });

    testWidgets('onChanged non-null wraps in GestureDetector', (tester) async {
      await tester.pumpWidget(createTestApp(
        VolumeSlider(volume: 0.5, onChanged: (_) {}),
      ));

      expect(find.byType(GestureDetector), findsOneWidget);
    });

    testWidgets('tap value is clamped between 0.0 and 1.0', (tester) async {
      final receivedVolumes = <double>[];
      await tester.pumpWidget(createTestApp(
        VolumeSlider(
          volume: 0.5,
          onChanged: (v) => receivedVolumes.add(v),
        ),
      ));

      // Tap at left edge
      final topLeft = tester.getTopLeft(find.byType(GestureDetector));
      await tester.tapAt(topLeft);
      // Tap at right edge
      final topRight = tester.getTopRight(find.byType(GestureDetector));
      await tester.tapAt(topRight);

      for (final v in receivedVolumes) {
        expect(v, greaterThanOrEqualTo(0.0));
        expect(v, lessThanOrEqualTo(1.0));
      }
    });
  });
}
