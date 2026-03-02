import 'dart:io';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:retro_eshop/features/settings/widgets/about_tab.dart';
import 'package:retro_eshop/features/settings/widgets/device_info_card.dart';
import 'package:retro_eshop/features/settings/widgets/preferences_tab.dart';
import 'package:retro_eshop/features/settings/widgets/settings_tabs.dart';
import 'package:retro_eshop/features/settings/widgets/system_tab.dart';
import 'package:retro_eshop/providers/app_providers.dart';
import 'package:retro_eshop/services/audio_manager.dart';
import 'package:retro_eshop/services/cover_preload_service.dart';
import 'package:retro_eshop/services/crash_log_service.dart';
import 'package:retro_eshop/services/device_info_service.dart';
import 'package:retro_eshop/services/feedback_service.dart';
import 'package:retro_eshop/services/haptic_service.dart';
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

class _FakeCrashLogService extends CrashLogService {
  final File? _file;
  _FakeCrashLogService({File? logFile}) : _file = logFile;

  @override
  File? getLogFile() => _file;
}

// ─── Tests ───────────────────────────────────────────────

void main() {
  // ─── SettingsTabs ────────────────────────────────────────

  group('SettingsTabs', () {
    const tabs = ['Preferences', 'Systems', 'About'];

    testWidgets('renders all tab labels in uppercase', (tester) async {
      await tester.pumpWidget(createTestApp(
        const SettingsTabs(selectedTab: 0, tabs: tabs),
      ));

      expect(find.text('PREFERENCES'), findsOneWidget);
      expect(find.text('SYSTEMS'), findsOneWidget);
      expect(find.text('ABOUT'), findsOneWidget);
    });

    testWidgets('active tab has bold text', (tester) async {
      await tester.pumpWidget(createTestApp(
        const SettingsTabs(selectedTab: 1, tabs: tabs),
      ));

      final systemsText = tester.widget<Text>(find.text('SYSTEMS'));
      expect(systemsText.style!.fontWeight, FontWeight.w700);
    });

    testWidgets('inactive tab has normal weight text', (tester) async {
      await tester.pumpWidget(createTestApp(
        const SettingsTabs(selectedTab: 1, tabs: tabs),
      ));

      final prefsText = tester.widget<Text>(find.text('PREFERENCES'));
      expect(prefsText.style!.fontWeight, FontWeight.w500);
    });

    testWidgets('active tab text uses accent color', (tester) async {
      await tester.pumpWidget(createTestApp(
        const SettingsTabs(
          selectedTab: 0,
          tabs: tabs,
          accentColor: Colors.cyanAccent,
        ),
      ));

      final prefsText = tester.widget<Text>(find.text('PREFERENCES'));
      expect(prefsText.style!.color, Colors.cyanAccent);
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

      await tester.tap(find.text('SYSTEMS'));
      expect(tappedIndex, 1);
    });

    testWidgets('tapping third tab fires index 2', (tester) async {
      int? tappedIndex;
      await tester.pumpWidget(createTestApp(
        SettingsTabs(
          selectedTab: 0,
          tabs: tabs,
          onTap: (i) => tappedIndex = i,
        ),
      ));

      await tester.tap(find.text('ABOUT'));
      expect(tappedIndex, 2);
    });

    testWidgets('custom accentColor is used for active tab', (tester) async {
      await tester.pumpWidget(createTestApp(
        const SettingsTabs(
          selectedTab: 0,
          tabs: tabs,
          accentColor: Colors.redAccent,
        ),
      ));

      final prefsText = tester.widget<Text>(find.text('PREFERENCES'));
      expect(prefsText.style!.color, Colors.redAccent);
    });
  });

  // ─── SettingsPreferencesTab ─────────────────────────────

  group('SettingsPreferencesTab', () {
    late FocusNode homeNode, layoutNode, hapticNode, hideEmptyNode;
    late FeedbackService fakeFeedback;

    setUp(() {
      homeNode = FocusNode();
      layoutNode = FocusNode();
      hapticNode = FocusNode();
      hideEmptyNode = FocusNode();
      fakeFeedback = FeedbackService(
        _FakeAudioManager(),
        _FakeHapticService(),
      );
    });

    tearDown(() {
      homeNode.dispose();
      layoutNode.dispose();
      hapticNode.dispose();
      hideEmptyNode.dispose();
    });

    Widget buildTab({
      ControllerLayout layout = ControllerLayout.nintendo,
      bool isHomeGrid = false,
      bool hapticEnabled = true,
      bool soundEnabled = true,
      bool hideEmptyConsoles = false,
      double bgmVolume = 0.5,
      double sfxVolume = 0.5,
      VoidCallback? onToggleHomeLayout,
      VoidCallback? onCycleLayout,
      VoidCallback? onToggleHaptic,
      VoidCallback? onToggleSound,
      VoidCallback? onToggleHideEmpty,
    }) {
      return createTestAppWithProviders(
        SettingsPreferencesTab(
          controllerLayout: layout,
          isHomeGrid: isHomeGrid,
          hapticEnabled: hapticEnabled,
          soundEnabled: soundEnabled,
          hideEmptyConsoles: hideEmptyConsoles,
          bgmVolume: bgmVolume,
          sfxVolume: sfxVolume,
          homeLayoutFocusNode: homeNode,
          layoutFocusNode: layoutNode,
          hapticFocusNode: hapticNode,
          hideEmptyFocusNode: hideEmptyNode,
          onToggleHomeLayout: onToggleHomeLayout ?? () {},
          onCycleLayout: onCycleLayout ?? () {},
          onToggleHaptic: onToggleHaptic ?? () {},
          onToggleSound: onToggleSound ?? () {},
          onToggleHideEmpty: onToggleHideEmpty ?? () {},
          onAdjustBgmVolume: (_) {},
          onAdjustSfxVolume: (_) {},
          onSetBgmVolume: (_) {},
          onSetSfxVolume: (_) {},
        ),
        overrides: [
          feedbackServiceProvider.overrideWithValue(fakeFeedback),
        ],
      );
    }

    testWidgets('renders all setting titles', (tester) async {
      await tester.pumpWidget(buildTab());

      expect(find.text('HOME SCREEN LAYOUT'), findsOneWidget);
      expect(find.text('HIDE EMPTY CONSOLES'), findsOneWidget);
      expect(find.text('CONTROLLER LAYOUT'), findsOneWidget);
      expect(find.text('HAPTIC FEEDBACK'), findsOneWidget);
      expect(find.text('SOUND EFFECTS'), findsOneWidget);
      expect(find.text('BACKGROUND MUSIC'), findsOneWidget);
      expect(find.text('SFX VOLUME'), findsOneWidget);
    });

    testWidgets('shows carousel subtitle when not grid', (tester) async {
      await tester.pumpWidget(buildTab(isHomeGrid: false));
      expect(find.text('Horizontal Carousel'), findsOneWidget);
    });

    testWidgets('shows grid view subtitle when grid', (tester) async {
      await tester.pumpWidget(buildTab(isHomeGrid: true));
      expect(find.text('Grid View'), findsOneWidget);
    });

    testWidgets('shows Nintendo layout label', (tester) async {
      await tester.pumpWidget(
          buildTab(layout: ControllerLayout.nintendo));
      expect(find.text('NIN'), findsOneWidget);
      expect(find.text('Nintendo (default)'), findsOneWidget);
    });

    testWidgets('shows Xbox layout label', (tester) async {
      await tester.pumpWidget(buildTab(layout: ControllerLayout.xbox));
      expect(find.text('XBOX'), findsOneWidget);
    });

    testWidgets('shows PlayStation layout label', (tester) async {
      await tester.pumpWidget(
          buildTab(layout: ControllerLayout.playstation));
      expect(find.text('PS'), findsOneWidget);
    });

    testWidgets('onToggleHomeLayout fires on tap', (tester) async {
      bool toggled = false;
      await tester.pumpWidget(
          buildTab(onToggleHomeLayout: () => toggled = true));

      // Find the SettingsItem for Home Screen Layout and tap it
      await tester.tap(find.text('HOME SCREEN LAYOUT'));
      await tester.pumpAndSettle();
      expect(toggled, true);
    });

    testWidgets('onToggleHaptic fires on tap', (tester) async {
      bool toggled = false;
      await tester.pumpWidget(
          buildTab(onToggleHaptic: () => toggled = true));

      await tester.tap(find.text('HAPTIC FEEDBACK'));
      await tester.pumpAndSettle();
      expect(toggled, true);
    });

    testWidgets('renders volume sliders', (tester) async {
      await tester.pumpWidget(buildTab(bgmVolume: 0.8, sfxVolume: 0.3));

      // Volume settings should be present (titles are uppercased by SettingsItem)
      expect(find.text('BACKGROUND MUSIC'), findsOneWidget);
      expect(find.text('SFX VOLUME'), findsOneWidget);
      expect(find.text('Ambient background music volume'), findsOneWidget);
      expect(find.text('Interface sound effects volume'), findsOneWidget);
    });
  });

  // ─── SettingsSystemTab ──────────────────────────────────

  group('SettingsSystemTab', () {
    late FocusNode firstNode;
    late FeedbackService fakeFeedback;

    setUp(() {
      firstNode = FocusNode();
      fakeFeedback = FeedbackService(
        _FakeAudioManager(),
        _FakeHapticService(),
      );
    });

    tearDown(() => firstNode.dispose());

    Widget buildSystemTab({
      int maxDownloads = 2,
      bool allowNonLanHttp = false,
      String coverSubtitle = 'Download covers for all games',
      File? logFile,
    }) {
      return createTestAppWithProviders(
        SettingsSystemTab(
          firstSystemTabNode: firstNode,
          maxDownloads: maxDownloads,
          allowNonLanHttp: allowNonLanHttp,
          coverSubtitle: coverSubtitle,
          onOpenRommConfig: () {},
          onOpenRaConfig: () {},
          onOpenConfigMode: () {},
          onOpenLibraryScan: () {},
          onStartCoverPreload: () {},
          onExportErrorLog: () {},
          onAdjustMaxDownloads: (_) {},
          onToggleAllowNonLanHttp: () {},
        ),
        overrides: [
          feedbackServiceProvider.overrideWithValue(fakeFeedback),
          crashLogServiceProvider
              .overrideWithValue(_FakeCrashLogService(logFile: logFile)),
          coverPreloadServiceProvider.overrideWith(
            (ref) => CoverPreloadService(),
          ),
        ],
      );
    }

    testWidgets('renders RomM Server item', (tester) async {
      await tester.pumpWidget(buildSystemTab());
      // SettingsItem uppercases titles
      expect(find.text('ROMM SERVER'), findsOneWidget);
      expect(find.text('Global RomM connection settings'), findsOneWidget);
    });

    testWidgets('renders RetroAchievements item', (tester) async {
      await tester.pumpWidget(buildSystemTab());
      expect(find.text('RETROACHIEVEMENTS'), findsOneWidget);
    });

    testWidgets('renders Max Concurrent Downloads with counter',
        (tester) async {
      await tester.pumpWidget(buildSystemTab(maxDownloads: 3));
      expect(find.text('MAX CONCURRENT DOWNLOADS'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('renders Allow HTTP toggle', (tester) async {
      await tester.pumpWidget(buildSystemTab());
      expect(find.text('ALLOW HTTP FOR EXTERNAL SERVERS'), findsOneWidget);
    });

    testWidgets('renders Edit Consoles item', (tester) async {
      await tester.pumpWidget(buildSystemTab());
      expect(find.text('EDIT CONSOLES'), findsOneWidget);
    });

    testWidgets('renders Scan Library item', (tester) async {
      await tester.pumpWidget(buildSystemTab());
      // Scan Library may be offscreen in the ListView
      expect(find.text('SCAN LIBRARY', skipOffstage: false), findsOneWidget);
    });

    testWidgets('renders Fetch All Covers when idle', (tester) async {
      await tester.pumpWidget(buildSystemTab(
        coverSubtitle: 'Pre-load box art for all configured systems',
      ));
      expect(find.text('FETCH ALL COVERS', skipOffstage: false), findsOneWidget);
    });

    testWidgets('shows Export Error Log when log file exists',
        (tester) async {
      final tempDir = Directory.systemTemp.createTempSync('rshop_test_');
      final logFile = File('${tempDir.path}/test.log')
        ..writeAsStringSync('error log');
      try {
        await tester.pumpWidget(buildSystemTab(logFile: logFile));
        expect(find.text('EXPORT ERROR LOG', skipOffstage: false), findsOneWidget);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    testWidgets('hides Export Error Log when no log file', (tester) async {
      await tester.pumpWidget(buildSystemTab());
      expect(find.text('EXPORT ERROR LOG', skipOffstage: false), findsNothing);
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
      // SettingsItem uppercases titles
      expect(find.text('GITHUB'), findsOneWidget);
      expect(find.text('View source code on GitHub'), findsOneWidget);
    });

    testWidgets('renders Issues link', (tester) async {
      await tester.pumpWidget(buildAboutTab());
      expect(find.text('ISSUES'), findsOneWidget);
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
}
