import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/input/input.dart';
import 'core/theme/app_theme.dart';
import 'providers/app_providers.dart';
import 'features/home/home_view.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'services/storage_service.dart';
import 'services/haptic_service.dart';
import 'services/audio_manager.dart';
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
  final storageService = StorageService();
  await storageService.init();

  final hapticService = HapticService();
  hapticService.setEnabled(storageService.getHapticEnabled());

  final audioManager = AudioManager();
  await audioManager.init();
  audioManager.updateSettings(storageService.getSoundSettings());

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

class RShopApp extends StatefulWidget {
  final AudioManager audioManager;

  const RShopApp({super.key, required this.audioManager});

  @override
  State<RShopApp> createState() => _RShopAppState();
}

class _RShopAppState extends State<RShopApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    return Consumer(
      builder: (context, ref, child) {
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
      },
    );
  }
}
