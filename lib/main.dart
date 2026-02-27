import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/input/input.dart';
import 'core/theme/app_theme.dart';
import 'models/system_model.dart';
import 'providers/app_providers.dart';
import 'providers/download_providers.dart';
import 'providers/game_providers.dart';
import 'providers/rom_status_providers.dart';
import 'features/home/home_view.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'services/crash_log_service.dart';
import 'services/device_info_service.dart';
import 'services/image_cache_service.dart';
import 'services/storage_service.dart';
import 'services/haptic_service.dart';
import 'services/audio_manager.dart';
import 'services/database_service.dart';
import 'services/download_foreground_service.dart';
import 'services/download_service.dart';
import 'services/native_smb_service.dart';
import 'services/provider_factory.dart';
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

void main() {
  final crashLogService = CrashLogService();

  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    installGamepadKeyFix();

    // Initialize crash log service early
    await crashLogService.init();

    // Global error handlers
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugPrint('FlutterError: ${details.exceptionAsString()}');
      crashLogService.logError(details.exceptionAsString(), details.stack);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint('PlatformDispatcher error: $error\n$stack');
      crashLogService.logError(error, stack);
      return true;
    };

    final storageService = StorageService();
    await storageService.init();

    final hapticService = HapticService();
    hapticService.setEnabled(storageService.getHapticEnabled());

    final audioManager = AudioManager();
    await audioManager.init();
    audioManager.updateSettings(storageService.getSoundSettings());

    DownloadForegroundService.init();

    await ThumbnailService.init();

    // Clean orphaned temp files from interrupted downloads (fire-and-forget)
    DownloadService.cleanOrphanedTempFiles();

    // Initialize native SMB service and wire into ProviderFactory
    final nativeSmbService = NativeSmbService();
    ProviderFactory.init(smbService: nativeSmbService);

    // Configure image cache based on device RAM
    final deviceMemory = await DeviceInfoService.getDeviceMemory();
    RateLimitedFileService.configure(
      maxConcurrent: deviceMemory.coverCacheMaxConcurrent,
      requestDelay: Duration(milliseconds: deviceMemory.coverCacheRequestDelayMs),
    );
    GameCoverCacheManager.init(maxObjects: deviceMemory.coverDiskCacheMaxObjects);
    PaintingBinding.instance.imageCache.maximumSize =
        deviceMemory.imageCacheMaxImages;
    PaintingBinding.instance.imageCache.maximumSizeBytes =
        deviceMemory.imageCacheMaxBytes;
    debugPrint(
        'ImageCache configured: tier=${deviceMemory.tier.name}, '
        'maxImages=${deviceMemory.imageCacheMaxImages}, '
        'maxBytes=${deviceMemory.imageCacheMaxBytes ~/ (1024 * 1024)}MB, '
        'maxConcurrent=${deviceMemory.coverCacheMaxConcurrent}, '
        'delay=${deviceMemory.coverCacheRequestDelayMs}ms, '
        'diskCache=${deviceMemory.coverDiskCacheMaxObjects}, '
        'totalRAM=${deviceMemory.totalGB.toStringAsFixed(1)}GB');

    runApp(
      ProviderScope(
        overrides: [
          crashLogServiceProvider.overrideWithValue(crashLogService),
          storageServiceProvider.overrideWithValue(storageService),
          hapticServiceProvider.overrideWithValue(hapticService),
          audioManagerProvider.overrideWithValue(audioManager),
          deviceMemoryProvider.overrideWithValue(deviceMemory),
          nativeSmbServiceProvider.overrideWithValue(nativeSmbService),
        ],
        child: RShopApp(audioManager: audioManager),
      ),
    );
  }, (error, stack) {
    debugPrint('Uncaught error: $error\n$stack');
    crashLogService.logError(error, stack);
  });
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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final configAsync = await ref.read(bootstrappedConfigProvider.future);
      ref
          .read(downloadQueueManagerProvider)
          .restoreQueue(SystemModel.supportedSystems, appConfig: configAsync);

      // Show recovery notification if config was restored from backup
      if (mounted && ref.read(configRecoveredProvider)) {
        final messenger = ScaffoldMessenger.maybeOf(context);
        messenger?.showSnackBar(
          const SnackBar(
            content: Text('Config recovered from backup'),
            duration: Duration(seconds: 4),
          ),
        );
      }

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
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            final currentFocus = FocusManager.instance.primaryFocus;
            if (currentFocus != null && currentFocus.canRequestFocus) {
              currentFocus.requestFocus();
            } else {
              restoreMainFocus(ref);
            }
          }
        });
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
