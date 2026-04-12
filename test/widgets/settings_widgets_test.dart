import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:retro_eshop/features/settings/widgets/about_tab.dart';
import 'package:retro_eshop/features/settings/widgets/device_info_card.dart';
import 'package:retro_eshop/features/settings/widgets/general_tab.dart';
import 'package:retro_eshop/features/settings/widgets/settings_switch.dart';
import 'package:retro_eshop/features/settings/widgets/settings_tabs.dart';
import 'package:retro_eshop/models/sound_settings.dart';
import 'package:retro_eshop/providers/app_providers.dart';
import 'package:retro_eshop/services/audio_manager.dart';
import 'package:retro_eshop/services/device_info_service.dart';
import 'package:retro_eshop/services/feedback_service.dart';
import 'package:retro_eshop/services/haptic_service.dart';
import 'package:retro_eshop/services/storage_service.dart';
import '../helpers/pump_helpers.dart';

// ─── Fakes ───────────────────────────────────────────────

class _FakeAudioManager extends AudioManager {
  @override
  void playNavigation() {}
  @override
  void playConfirm() {}
}

class _FakeHapticService extends HapticService {
  @override
  void tick() {}
  @override
  void select() {}
  @override
  void action() {}
  @override
  void success() {}
}

class _FakeStorageService extends StorageService {
  _FakeStorageService() : super();

  @override
  Future<void> init() async {}

  @override
  bool getHapticEnabled() => true;
  @override
  Future<void> setHapticEnabled(bool enabled) async {}
  @override
  bool getHideEmptyConsoles() => false;
  @override
  Future<void> setHideEmptyConsoles(bool value) async {}
  @override
  bool getAllowNonLanHttp() => false;
  @override
  Future<void> setAllowNonLanHttp(bool allowed) async {}
  @override
  ControllerLayout getControllerLayout() => ControllerLayout.nintendo;
  @override
  Future<void> setControllerLayout(ControllerLayout layout) async {}
  @override
  bool getHomeLayoutIsGrid() => false;
  @override
  Future<void> setHomeLayoutIsGrid(bool value) async {}
  @override
  String? getLocaleOverride() => null;
  @override
  Future<void> setLocaleOverride(String? code) async {}
  @override
  int getSyncTimeoutSeconds() => 60;
  @override
  Future<void> setSyncTimeoutSeconds(int value) async {}
  @override
  int getSyncCooldownMinutes() => 60;
  @override
  Future<void> setSyncCooldownMinutes(int value) async {}
  @override
  int getMaxConcurrentDownloads() => 2;
  @override
  Future<void> setMaxConcurrentDownloads(int value) async {}
  @override
  SoundSettings getSoundSettings() =>
      const SoundSettings(enabled: true, bgmVolume: 0.5, sfxVolume: 0.5);
  @override
  Future<void> setSoundSettings(SoundSettings settings) async {}
  @override
  List<String> getFavorites() => [];
  @override
  Future<void> setFavorites(List<String> favorites) async {}
  @override
  bool isRaConfigured = false;
}

// ─── Tests ───────────────────────────────────────────────

void main() {
  // ─── SettingsTabs ────────────────────────────────────────

  group('SettingsTabs', () {
    const tabs = ['General', 'Audio', 'Advanced', 'About'];

    testWidgets('renders all tab labels in uppercase', (tester) async {
      await tester.pumpWidget(createTestApp(
        const SettingsTabs(selectedTab: 0, tabs: tabs),
      ));

      expect(find.text('GENERAL'), findsOneWidget);
      expect(find.text('AUDIO'), findsOneWidget);
      expect(find.text('ADVANCED'), findsOneWidget);
      expect(find.text('ABOUT'), findsOneWidget);
    });

    testWidgets('active tab has bold text', (tester) async {
      await tester.pumpWidget(createTestApp(
        const SettingsTabs(selectedTab: 1, tabs: tabs),
      ));

      final audioText = tester.widget<Text>(find.text('AUDIO'));
      expect(audioText.style!.fontWeight, FontWeight.w700);
    });

    testWidgets('inactive tab has normal weight text', (tester) async {
      await tester.pumpWidget(createTestApp(
        const SettingsTabs(selectedTab: 1, tabs: tabs),
      ));

      final generalText = tester.widget<Text>(find.text('GENERAL'));
      expect(generalText.style!.fontWeight, FontWeight.w500);
    });

    testWidgets('active tab text uses accent color', (tester) async {
      await tester.pumpWidget(createTestApp(
        const SettingsTabs(
          selectedTab: 0,
          tabs: tabs,
          accentColor: Colors.cyanAccent,
        ),
      ));

      final generalText = tester.widget<Text>(find.text('GENERAL'));
      expect(generalText.style!.color, Colors.cyanAccent);
    });

    testWidgets('inactive tab text is grey', (tester) async {
      await tester.pumpWidget(createTestApp(
        const SettingsTabs(selectedTab: 0, tabs: tabs),
      ));

      final aboutText = tester.widget<Text>(find.text('ABOUT'));
      expect(aboutText.style!.color, Colors.grey[500]);
    });

    testWidgets('onTap fires with correct tab index', (tester) async {
      int? tappedIndex;
      await tester.pumpWidget(createTestApp(
        SettingsTabs(
          selectedTab: 0,
          tabs: tabs,
          onTap: (i) => tappedIndex = i,
        ),
      ));

      await tester.tap(find.text('AUDIO'));
      expect(tappedIndex, 1);
    });

    testWidgets('tapping About tab fires index 3', (tester) async {
      int? tappedIndex;
      await tester.pumpWidget(createTestApp(
        SettingsTabs(
          selectedTab: 0,
          tabs: tabs,
          onTap: (i) => tappedIndex = i,
        ),
      ));

      await tester.tap(find.text('ABOUT'));
      expect(tappedIndex, 3);
    });

    testWidgets('custom accentColor is used for active tab', (tester) async {
      await tester.pumpWidget(createTestApp(
        const SettingsTabs(
          selectedTab: 0,
          tabs: tabs,
          accentColor: Colors.redAccent,
        ),
      ));

      final generalText = tester.widget<Text>(find.text('GENERAL'));
      expect(generalText.style!.color, Colors.redAccent);
    });
  });

  // ─── SettingsGeneralTab ─────────────────────────────────

  group('SettingsGeneralTab', () {
    late FocusNode firstNode;
    late FeedbackService fakeFeedback;
    late _FakeStorageService fakeStorage;

    setUp(() {
      firstNode = FocusNode();
      fakeFeedback = FeedbackService(
        _FakeAudioManager(),
        _FakeHapticService(),
      );
      fakeStorage = _FakeStorageService();
    });

    tearDown(() => firstNode.dispose());

    Widget buildTab() {
      return createTestAppWithProviders(
        SettingsGeneralTab(firstFocusNode: firstNode),
        overrides: [
          storageServiceProvider.overrideWithValue(fakeStorage),
          feedbackServiceProvider.overrideWithValue(fakeFeedback),
          hapticServiceProvider.overrideWithValue(_FakeHapticService()),
          audioManagerProvider.overrideWithValue(_FakeAudioManager()),
        ],
      );
    }

    testWidgets('renders Library section header', (tester) async {
      await tester.pumpWidget(buildTab());
      expect(find.text('LIBRARY'), findsOneWidget);
    });

    testWidgets('renders Display section header', (tester) async {
      await tester.pumpWidget(buildTab());
      expect(find.text('DISPLAY'), findsOneWidget);
    });

    testWidgets('renders My Sources navigation tile', (tester) async {
      await tester.pumpWidget(buildTab());
      expect(find.text('My Sources'), findsOneWidget);
      expect(find.text('Add or manage RomM, SMB, FTP servers'),
          findsOneWidget);
    });

    testWidgets('renders Console Settings navigation tile', (tester) async {
      await tester.pumpWidget(buildTab());
      expect(find.text('Console Settings'), findsOneWidget);
    });

    testWidgets('renders RetroAchievements navigation tile', (tester) async {
      await tester.pumpWidget(buildTab());
      expect(find.text('RetroAchievements'), findsOneWidget);
    });

    testWidgets('renders Home Layout toggle', (tester) async {
      await tester.pumpWidget(buildTab());
      expect(find.text('HOME LAYOUT'), findsOneWidget);
      expect(find.text('Horizontal Carousel'), findsOneWidget);
    });

    testWidgets('renders Hide Empty Consoles toggle', (tester) async {
      await tester.pumpWidget(buildTab());
      expect(find.text('HIDE EMPTY CONSOLES'), findsOneWidget);
    });

    testWidgets('renders Controller Buttons cycle', (tester) async {
      await tester.pumpWidget(buildTab());
      expect(find.text('CONTROLLER BUTTONS'), findsOneWidget);
      expect(find.text('NIN'), findsOneWidget);
    });

    testWidgets('has chevron icons for nav tiles', (tester) async {
      await tester.pumpWidget(buildTab());
      expect(find.byIcon(Icons.chevron_right), findsNWidgets(3));
    });
  });

  // ─── SettingsSwitch ────────────────────────────────────

  group('SettingsSwitch', () {
    testWidgets('renders on state', (tester) async {
      await tester.pumpWidget(
        createTestApp(const SettingsSwitch(value: true)),
      );
      expect(find.byType(AnimatedContainer), findsWidgets);
    });

    testWidgets('renders off state', (tester) async {
      await tester.pumpWidget(
        createTestApp(const SettingsSwitch(value: false)),
      );
      expect(find.byType(AnimatedContainer), findsWidgets);
    });
  });

  // ─── SettingsAboutTab ───────────────────────────────────

  group('SettingsAboutTab', () {
    late FocusNode firstNode;
    late ConfettiController confetti;
    late FeedbackService fakeFeedback;

    setUp(() {
      firstNode = FocusNode();
      confetti = ConfettiController(duration: const Duration(seconds: 1));
      fakeFeedback = FeedbackService(
        _FakeAudioManager(),
        _FakeHapticService(),
      );
    });

    tearDown(() {
      firstNode.dispose();
      confetti.dispose();
    });

    Widget buildAboutTab({String version = '1.3.0'}) {
      return createTestAppWithProviders(
        SettingsAboutTab(
          appVersion: version,
          firstAboutTabNode: firstNode,
          confettiController: confetti,
        ),
        overrides: [
          feedbackServiceProvider.overrideWithValue(fakeFeedback),
          deviceMemoryProvider.overrideWithValue(
            const DeviceMemoryInfo(
              totalBytes: 4 * 1024 * 1024 * 1024,
              tier: MemoryTier.standard,
            ),
          ),
        ],
      );
    }

    testWidgets('renders GitHub link', (tester) async {
      await tester.pumpWidget(buildAboutTab());
      expect(find.text('GitHub'), findsOneWidget);
      expect(find.text('View source code on GitHub'), findsOneWidget);
    });

    testWidgets('renders Issues link', (tester) async {
      await tester.pumpWidget(buildAboutTab());
      expect(find.text('Issues'), findsOneWidget);
      expect(find.text('Report bugs or request features'), findsOneWidget);
    });

    testWidgets('renders tagline', (tester) async {
      await tester.pumpWidget(buildAboutTab());
      expect(find.text('INTENSIV, AGGRESSIV, MUTIG'), findsOneWidget);
    });

    testWidgets('contains DeviceInfoCard', (tester) async {
      await tester.pumpWidget(buildAboutTab());
      expect(find.byType(DeviceInfoCard), findsOneWidget);
    });
  });

  // ─── DeviceInfoCard ─────────────────────────────────────

  group('DeviceInfoCard', () {
    Widget buildCard({
      required int totalBytes,
      required MemoryTier tier,
      String version = '1.3.0',
    }) {
      return createTestAppWithProviders(
        DeviceInfoCard(appVersion: version),
        overrides: [
          deviceMemoryProvider.overrideWithValue(
            DeviceMemoryInfo(totalBytes: totalBytes, tier: tier),
          ),
        ],
      );
    }

    testWidgets('shows LOW label for low tier', (tester) async {
      await tester.pumpWidget(buildCard(
        totalBytes: 2 * 1024 * 1024 * 1024,
        tier: MemoryTier.low,
      ));
      expect(find.text('LOW'), findsOneWidget);
    });

    testWidgets('shows STANDARD label for standard tier', (tester) async {
      await tester.pumpWidget(buildCard(
        totalBytes: 4 * 1024 * 1024 * 1024,
        tier: MemoryTier.standard,
      ));
      expect(find.text('STANDARD'), findsOneWidget);
    });

    testWidgets('shows HIGH label for high tier', (tester) async {
      await tester.pumpWidget(buildCard(
        totalBytes: 8 * 1024 * 1024 * 1024,
        tier: MemoryTier.high,
      ));
      expect(find.text('HIGH'), findsOneWidget);
    });

    testWidgets('shows version text', (tester) async {
      await tester.pumpWidget(buildCard(
        totalBytes: 4 * 1024 * 1024 * 1024,
        tier: MemoryTier.standard,
        version: '1.3.0',
      ));
      expect(find.text('v1.3.0'), findsOneWidget);
    });
  });

  group('formatSyncTimeout', () {
    test('formats known values', () {
      expect(formatSyncTimeout(60), '1 min');
      expect(formatSyncTimeout(120), '2 min');
      expect(formatSyncTimeout(300), '5 min');
      expect(formatSyncTimeout(600), '10 min');
    });

    test('formats unknown values as seconds', () {
      expect(formatSyncTimeout(45), '45s');
      expect(formatSyncTimeout(90), '90s');
    });
  });

  group('syncTimeoutSteps', () {
    test('contains expected values', () {
      expect(syncTimeoutSteps, [60, 120, 300, 600]);
    });
  });
}
