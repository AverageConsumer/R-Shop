import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/input/input.dart';
import 'core/theme/app_theme.dart';
import 'models/system_model.dart';
import 'providers/app_providers.dart';
import 'providers/download_providers.dart';
import 'providers/rom_status_providers.dart';
import 'features/home/home_view.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'services/storage_service.dart';
import 'services/haptic_service.dart';
import 'services/audio_manager.dart';
import 'services/database_service.dart';
import 'services/download_foreground_service.dart';
import 'services/thumbnail_migration_service.dart';
import 'services/thumbnail_service.dart';
import 'widgets/download_overlay.dart';

class NoGlowScrollBehavior extends ScrollBehavior {
  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  installGamepadKeyFix();
  final storageService = StorageService();
  await storageService.init();

  final hapticService = HapticService();
  hapticService.setEnabled(storageService.getHapticEnabled());

  final audioManager = AudioManager();
  await audioManager.init();
  audioManager.updateSettings(storageService.getSoundSettings());

  DownloadForegroundService.init();

  await ThumbnailService.init();

  runApp(
    ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(storageService),
        hapticServiceProvider.overrideWithValue(hapticService),
        audioManagerProvider.overrideWithValue(audioManager),
      ],
      child: RShopApp(audioManager: audioManager),
    ),
  );
}

class RShopApp extends ConsumerStatefulWidget {
  final AudioManager audioManager;

  const RShopApp({super.key, required this.audioManager});

  @override
  ConsumerState<RShopApp> createState() => _RShopAppState();
}

class _RShopAppState extends ConsumerState<RShopApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(downloadQueueManagerProvider)
          .restoreQueue(SystemModel.supportedSystems);
      // Defer thumbnail migration to avoid DB contention at startup
      Future.delayed(const Duration(seconds: 3), () {
        ThumbnailMigrationService.migrateIfNeeded(DatabaseService());
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.audioManager.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        widget.audioManager.pause();
        break;
      case AppLifecycleState.resumed:
        widget.audioManager.resume();
        restoreMainFocus(ref);
        break;
      case AppLifecycleState.detached:
        widget.audioManager.dispose();
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(romWatcherProvider);
    final storage = ref.read(storageServiceProvider);
    final onboardingCompleted = storage.getOnboardingCompleted();

    return GlobalInputWrapper(
      child: MaterialApp(
        title: 'R-Shop',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        builder: (context, child) {
          return ScrollConfiguration(
            behavior: NoGlowScrollBehavior(),
            child: Stack(
              children: [
                child!,
                Builder(
                  builder: (context) => const DownloadOverlay(),
                ),
              ],
            ),
          );
        },
        routes: {
          '/home': (context) => const HomeView(),
        },
        home: onboardingCompleted
            ? const HomeView()
            : const OnboardingScreen(),
      ),
    );
  }
}
