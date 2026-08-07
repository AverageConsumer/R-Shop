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
import 'providers/ra_providers.dart';
import 'providers/library_providers.dart';
import 'providers/source_health_providers.dart';
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
import 'utils/rom_share_helper.dart';
import 'widgets/add_to_queue_toast.dart';
import 'widgets/download/global_progress_bar.dart';
import 'widgets/download_overlay.dart';
import 'widgets/sync_badge.dart';
import 'l10n/app_localizations.dart';

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
    RomShareHelper.cleanShareTempFiles();

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
          SnackBar(
            content: Text(L.of(context).toast_configRecovered),
            duration: const Duration(seconds: 4),
          ),
        );
      }

      // Proactive RomM health check: validates tokens AND discovers new
      // platforms in a single call per source. Auto-creates SystemConfigs
      // for any newly discovered consoles.
      Future.delayed(const Duration(seconds: 2), () async {
        if (!mounted) return;
        final sourcesState = ref.read(sourcesProvider);
        if (sourcesState.loading || sourcesState.sources.isEmpty) {
          await ref.read(sourcesProvider.notifier).ready;
          if (!mounted) return;
        }
        final sources = ref.read(sourcesProvider).sources;
        final discovered = await ref
            .read(sourceHealthProvider.notifier)
            .checkAll(sources);

        if (discovered.isEmpty || !mounted) return;

        final notifier = ref.read(sourcesProvider.notifier);
        final basePath = ref.read(storageServiceProvider).getRomPath()
            ?? '/storage/emulated/0/ROMs';
        var totalNew = 0;
        final allNewIds = <String>[];
        final allNewNames = <String>[];

        for (final entry in discovered.entries) {
          final sourceId = entry.key;
          final platforms = entry.value;
          final source = sources.firstWhere((s) => s.id == sourceId);

          if (!mapEquals(source.knownPlatforms, platforms)) {
            await notifier.updateKnownPlatforms(sourceId, platforms);
          }

          // Auto-create SystemConfigs for newly discovered consoles.
          final updatedSource = source.copyWith(knownPlatforms: platforms);
          final result = await notifier.ensureSystemsForSource(
            updatedSource,
            basePath: basePath,
          );
          if (result.names.isNotEmpty) {
            totalNew += result.names.length;
            allNewNames.addAll(result.names);
          }
        }

        if (totalNew > 0 && mounted) {
          ref.invalidate(bootstrappedConfigProvider);

          // Queue a sync for the newly created systems so they populate
          // immediately instead of requiring a manual "Sync All".
          final freshConfig =
              await ref.read(bootstrappedConfigProvider.future);
          final syncService =
              ref.read(librarySyncServiceProvider.notifier);
          final timeout = Duration(
              seconds: ref.read(syncTimeoutProvider));
          for (final id in allNewIds) {
            syncService.syncSystem(id, freshConfig, syncTimeout: timeout);
          }
        }
      });


      // Defer thumbnail migration to avoid DB contention at startup
      Future.delayed(const Duration(seconds: 3), () {
        ThumbnailMigrationService.migrateIfNeeded(DatabaseService());
      });

      // Deferred RA sync — only if RA is configured
      Future.delayed(const Duration(seconds: 5), () {
        if (!mounted) return;
        triggerRaSync(
          ref.read(raSyncServiceProvider.notifier),
          ref.read(storageServiceProvider),
        );
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
            // Re-check RomM token health if stale (> 5min since last check).
            final health = ref.read(sourceHealthProvider);
            if (health.isStale) {
              final sources = ref.read(sourcesProvider).sources;
              // Fire-and-forget — platform discovery on resume is
              // best-effort, the startup check already covered it.
              ref.read(sourceHealthProvider.notifier).checkAll(sources);
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

    // Reactive: when sync finishes with auth errors, re-check RomM tokens.
    ref.listen(librarySyncServiceProvider, (prev, next) {
      if (prev == null || prev.isSyncing || !next.hadFailures) return;
      if (next.isSyncing) return;
      final authKeywords = ['authentication', 'credentials', 'access denied'];
      final hasAuthFailure = next.failedSystems.values.any(
        (msg) => authKeywords.any(
            (kw) => msg.toLowerCase().contains(kw)),
      );
      if (hasAuthFailure) {
        final sources = ref.read(sourcesProvider).sources;
        ref.read(sourceHealthProvider.notifier).checkAll(sources);
      }
    });

    final storage = ref.read(storageServiceProvider);
    final onboardingCompleted = storage.getOnboardingCompleted();

    final localeOverride = ref.watch(localeProvider);

    return GlobalInputWrapper(
      child: MaterialApp(
        title: 'R-Shop',
        debugShowCheckedModeBanner: false,
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        locale: localeOverride,
        theme: AppTheme.darkTheme,
        builder: (context, child) {
          return ScrollConfiguration(
            behavior: NoGlowScrollBehavior(),
            child: Stack(
              children: [
                child!,
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: GlobalDownloadProgressBar(),
                ),
                Builder(
                  builder: (context) => const DownloadOverlay(),
                ),
                const AddToQueueToast(),
                const SyncBadge(),
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
