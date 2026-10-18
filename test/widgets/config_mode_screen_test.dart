import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retro_eshop/features/onboarding/onboarding_controller.dart';
import 'package:retro_eshop/features/settings/config_mode_screen.dart';
import 'package:retro_eshop/l10n/app_localizations.dart';
import 'package:retro_eshop/models/config/app_config.dart';
import 'package:retro_eshop/models/config/source.dart';
import 'package:retro_eshop/models/config/system_config.dart';
import 'package:retro_eshop/providers/app_providers.dart';
import 'package:retro_eshop/services/audio_manager.dart';
import 'package:retro_eshop/services/config_storage_service.dart';
import 'package:retro_eshop/services/feedback_service.dart';
import 'package:retro_eshop/services/haptic_service.dart';
import 'package:retro_eshop/services/storage_service.dart';

class _Storage extends StorageService {
  @override
  ControllerLayout getControllerLayout() => ControllerLayout.nintendo;
}

class _Feedback extends FeedbackService {
  _Feedback() : super(AudioManager(), HapticService());
  @override
  void tick() {}
  @override
  void error() {}
}

class _ConfigStorage extends ConfigStorageService {
  _ConfigStorage(this.config);
  AppConfig config;
  bool failSave = false;

  @override
  Future<File> saveConfig(String content) async {
    if (failSave) throw const FileSystemException('Save failed');
    config = AppConfig.fromJson(jsonDecode(content) as Map<String, dynamic>);
    return File('unused.json');
  }

  @override
  Future<AppConfig?> loadConfig() async => config;

  @override
  Future<({AppConfig? config, bool wasRecovered})>
      loadConfigWithRecoveryInfo() async =>
          (config: config, wasRecovered: false);
}

void main() {
  for (final systemBack in [true, false]) {
    testWidgets('${systemBack ? 'Android' : 'HUD'} Back persists console edits',
        (tester) async {
      const config = AppConfig(systems: [
        SystemConfig(
          id: 'nes',
          name: 'Nintendo Entertainment System',
          targetFolder: '/roms/nes',
          providers: [],
          autoExtract: true,
          enabledSourceIds: ['manual'],
          manualMappings: [
            SystemSourceMapping(sourceId: 'manual', remotePath: '/nes')
          ],
        )
      ]);
      final storage = _ConfigStorage(config);
      final container = ProviderContainer(overrides: [
        configStorageServiceProvider.overrideWithValue(storage),
        storageServiceProvider.overrideWithValue(_Storage()),
        feedbackServiceProvider.overrideWithValue(_Feedback()),
      ]);
      addTearDown(container.dispose);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          navigatorKey: navigator,
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
          home: const Scaffold(body: Text('Home')),
        ),
      ));
      navigator.currentState!.push(
          MaterialPageRoute<void>(builder: (_) => const ConfigModeScreen()));
      await tester.pumpAndSettle();
      final controller = container.read(onboardingControllerProvider.notifier)
        ..selectConsole('nes')
        ..setAutoExtract(false)
        ..setAutoSync(false)
        ..setTargetFolder('/new/nes');
      await tester.pumpAndSettle();

      Future<void> back() async {
        if (systemBack) {
          await navigator.currentState!.maybePop();
        } else {
          await tester.tap(find.text('Back'));
        }
        await tester.pumpAndSettle();
      }

      await back();
      expect(controller.state.selectedConsoleId, isNull);
      expect(find.byType(ConfigModeScreen), findsOneWidget);
      controller.selectConsole('nes');
      expect(controller.state.consoleSubState!.autoExtract, isFalse);
      expect(controller.state.consoleSubState!.targetFolder, '/new/nes');
      await tester.pumpAndSettle();
      await back();

      // A failed write must keep the screen and draft available for retry.
      storage.failSave = true;
      await back();
      expect(find.byType(ConfigModeScreen), findsOneWidget);
      expect(find.textContaining('Failed to save'), findsOneWidget);
      storage.failSave = false;
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      await back();
      expect(find.byType(ConfigModeScreen), findsNothing);
      final saved = (await storage.loadConfig())!.systems.single;
      expect(saved.autoExtract, isFalse);
      expect(saved.autoSync, isFalse);
      expect(saved.targetFolder, '/new/nes');
      expect(saved.enabledSourceIds, ['manual']);
      expect(saved.manualMappings.single.remotePath, '/nes');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }
}
