import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retro_eshop/features/sources/source_endpoints_screen.dart';
import 'package:retro_eshop/features/settings/sources_screen.dart';
import 'package:retro_eshop/models/config/app_config.dart';
import 'package:retro_eshop/models/config/source.dart';
import 'package:retro_eshop/providers/app_providers.dart';
import 'package:retro_eshop/services/config_storage_service.dart';
import 'package:retro_eshop/services/sources_notifier.dart';
import 'package:retro_eshop/services/storage_service.dart';
import 'package:retro_eshop/services/feedback_service.dart';
import 'package:retro_eshop/services/audio_manager.dart';
import 'package:retro_eshop/services/haptic_service.dart';

import '../helpers/pump_helpers.dart';

const _source = Source(
    id: 'home',
    name: 'My RomM',
    type: SourceType.romm,
    url: 'http://lan.test',
    fallbackUrls: ['https://wan.test']);

class _Storage extends ConfigStorageService {
  @override
  Future<AppConfig?> loadConfig() async =>
      const AppConfig(systems: [], sources: [_source]);
}

class _Sources extends SourcesNotifier {
  _Sources() : super(_Storage());
  List<String>? saved;
  @override
  Future<void> setFallbackUrls(String id, List<String> urls) async {
    expect(id, 'home');
    saved = urls;
  }
}

class _Settings extends StorageService {
  @override
  ControllerLayout getControllerLayout() => ControllerLayout.nintendo;
}

class _Feedback extends FeedbackService {
  _Feedback() : super(AudioManager(), HapticService());
  @override
  void tick() {}
  @override
  void confirm() {}
  @override
  void cancel() {}
}

void main() {
  testWidgets(
      'source action menu fits a small handheld and scrolls with the gamepad',
      (tester) async {
    tester.view.physicalSize = const Size(640, 320);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final notifier = _Sources();
    await notifier.ready;
    await tester.pumpWidget(
        createTestAppWithProviders(const SourcesScreen(), overrides: [
      sourcesProvider.overrideWith((_) => notifier),
      storageServiceProvider.overrideWithValue(_Settings()),
      feedbackServiceProvider.overrideWithValue(_Feedback()),
    ]));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My RomM'));
    await tester.pumpAndSettle();
    expect(find.text('Connection addresses'), findsOneWidget);
    expect(tester.takeException(), isNull);
    for (var i = 0; i < 4; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.gameButtonA);
    await tester.pumpAndSettle();
    expect(find.text('Connection addresses'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('rejects invalid addresses without changing the source',
      (tester) async {
    final notifier = _Sources();
    await tester.pumpWidget(createTestAppWithProviders(
      const SourceEndpointsScreen(source: _source),
      overrides: [sourcesProvider.overrideWith((_) => notifier)],
    ));
    await tester.pumpAndSettle();
    expect(find.text('http://lan.test'), findsOneWidget);
    await tester.enterText(
        find.byType(TextField), 'ftp://not-an-http-endpoint');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(notifier.saved, isNull);
    expect(find.textContaining('Enter valid HTTP(S)'), findsOneWidget);
  });

  testWidgets('gamepad edits, leaves text entry and saves normalized URLs',
      (tester) async {
    final notifier = _Sources();
    await tester.pumpWidget(createTestAppWithProviders(
      const SourceEndpointsScreen(source: _source),
      overrides: [sourcesProvider.overrideWith((_) => notifier)],
    ));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.gameButtonA);
    await tester.pump();
    await tester.enterText(find.byType(TextField),
        'https://wan.test/\nhttps://wan.test\nhttps://tunnel.test/romm');
    await tester.sendKeyEvent(LogicalKeyboardKey.gameButtonB);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.gameButtonA);
    await tester.pumpAndSettle();
    expect(notifier.saved, ['https://wan.test', 'https://tunnel.test/romm']);
  });
}
