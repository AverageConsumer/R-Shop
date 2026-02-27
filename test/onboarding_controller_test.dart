import 'package:flutter_test/flutter_test.dart';
import 'package:retro_eshop/features/onboarding/onboarding_controller.dart';
import 'package:retro_eshop/models/config/app_config.dart';
import 'package:retro_eshop/models/config/provider_config.dart';
import 'package:retro_eshop/models/config/system_config.dart';
import 'package:retro_eshop/models/system_model.dart';
import 'package:retro_eshop/services/config_storage_service.dart';
import 'package:retro_eshop/services/romm_api_service.dart';

/// Fake ConfigStorageService that records exportConfig calls without I/O.
class FakeConfigStorageService extends ConfigStorageService {
  AppConfig? lastExportedConfig;

  FakeConfigStorageService() : super(directoryProvider: _throwDir);

  static Future<Never> _throwDir() =>
      throw UnimplementedError('No directory in tests');

  @override
  Future<void> exportConfig(AppConfig config) async {
    lastExportedConfig = config;
  }
}

/// Helper to create a controller with a fake config storage.
OnboardingController _createController([FakeConfigStorageService? storage]) {
  return OnboardingController(storage ?? FakeConfigStorageService());
}

/// Helper to build a SystemConfig for a known system ID.
SystemConfig _systemConfig(
  String id, {
  String? targetFolder,
  List<ProviderConfig> providers = const [],
  bool autoExtract = false,
  bool mergeMode = false,
}) {
  final system = SystemModel.supportedSystems.firstWhere((s) => s.id == id);
  return SystemConfig(
    id: id,
    name: system.name,
    targetFolder: targetFolder ?? '/roms/$id',
    providers: providers,
    autoExtract: autoExtract,
    mergeMode: mergeMode,
  );
}

const _testPlatformNes = RommPlatform(
  id: 10,
  slug: 'nes',
  fsSlug: 'nes',
  name: 'Nintendo Entertainment System',
  romCount: 50,
);

const _testPlatformSnes = RommPlatform(
  id: 20,
  slug: 'snes',
  fsSlug: 'snes',
  name: 'Super Nintendo',
  romCount: 30,
);

void main() {
  // =========================================================================
  // 1. Initial State
  // =========================================================================
  group('Initial state', () {
    test('defaults to welcome step with empty config', () {
      final c = _createController();
      expect(c.state.currentStep, OnboardingStep.welcome);
      expect(c.state.configuredSystems, isEmpty);
      expect(c.state.canProceed, false);
      expect(c.state.selectedConsoleId, isNull);
      expect(c.state.consoleSubState, isNull);
      expect(c.state.providerForm, isNull);
      expect(c.state.rommSetupState, isNull);
      expect(c.state.localSetupState, isNull);
    });

    test('onMessageComplete sets canProceed to true', () {
      final c = _createController();
      expect(c.state.canProceed, false);
      c.onMessageComplete();
      expect(c.state.canProceed, true);
    });

    test('loadFromConfig jumps to consoleSetup with systems', () {
      final c = _createController();
      final config = AppConfig(systems: [
        _systemConfig('nes'),
        _systemConfig('snes'),
      ]);
      c.loadFromConfig(config);
      expect(c.state.currentStep, OnboardingStep.consoleSetup);
      expect(c.state.configuredSystems.length, 2);
      expect(c.state.configuredSystems.containsKey('nes'), true);
      expect(c.state.configuredSystems.containsKey('snes'), true);
      expect(c.state.canProceed, true);
    });
  });

  // =========================================================================
  // 2. nextStep()
  // =========================================================================
  group('nextStep()', () {
    test('welcome → legalNotice', () {
      final c = _createController();
      c.onMessageComplete();
      c.nextStep();
      expect(c.state.currentStep, OnboardingStep.legalNotice);
      expect(c.state.canProceed, false);
    });

    test('legalNotice → rommSetup (initializes RommSetupState)', () {
      final c = _createController();
      c.onMessageComplete();
      c.nextStep(); // → legalNotice
      c.onMessageComplete();
      c.nextStep(); // → rommSetup
      expect(c.state.currentStep, OnboardingStep.rommSetup);
      expect(c.state.rommSetupState, isNotNull);
      expect(c.state.rommSetupState!.subStep, RommSetupSubStep.ask);
      expect(c.state.canProceed, true);
    });

    test('rommSetup/select → rommSetup/folder sub-step', () {
      final c = _createController();
      // Manually set up rommSetup at select sub-step
      c.onMessageComplete();
      c.nextStep(); // → legalNotice
      c.onMessageComplete();
      c.nextStep(); // → rommSetup

      // Simulate arriving at select sub-step
      final rs = c.state.rommSetupState!.copyWith(
        subStep: RommSetupSubStep.select,
        selectedSystemIds: {'nes'},
        systemMatches: {'nes': _testPlatformNes},
        url: 'https://romm.example.com',
      );
      // Directly update state to simulate sub-step
      c.state = c.state.copyWith(rommSetupState: rs);

      c.nextStep(); // select → folder
      expect(c.state.currentStep, OnboardingStep.rommSetup);
      expect(c.state.rommSetupState!.subStep, RommSetupSubStep.folder);
      expect(c.state.rommSetupState!.isAutoDetecting, true);
      expect(c.state.canProceed, true);
    });

    test('rommSetup/folder → consoleSetup (auto-configures systems)', () {
      final c = _createController();
      c.onMessageComplete();
      c.nextStep(); // → legalNotice
      c.onMessageComplete();
      c.nextStep(); // → rommSetup

      // Set up at folder sub-step with selections
      final rs = c.state.rommSetupState!.copyWith(
        subStep: RommSetupSubStep.folder,
        selectedSystemIds: {'nes'},
        systemMatches: {'nes': _testPlatformNes},
        url: 'https://romm.example.com',
      );
      c.state = c.state.copyWith(rommSetupState: rs);

      c.nextStep(); // folder → consoleSetup
      expect(c.state.currentStep, OnboardingStep.consoleSetup);
      expect(c.state.configuredSystems.containsKey('nes'), true);
      expect(c.state.canProceed, true);
    });

    test('localSetup → consoleSetup (auto-configures local systems)', () {
      final c = _createController();
      // Set up at localSetup step with enabled systems
      c.state = c.state.copyWith(
        currentStep: OnboardingStep.localSetup,
        localSetupState: const LocalSetupState(
          romBasePath: '/roms',
          enabledSystemIds: {'snes'},
          scannedFolders: [
            ScannedFolder(
              name: 'SNES',
              fileCount: 10,
              autoMatchedSystemId: 'snes',
            ),
          ],
        ),
      );

      c.nextStep(); // localSetup → consoleSetup
      expect(c.state.currentStep, OnboardingStep.consoleSetup);
      expect(c.state.configuredSystems.containsKey('snes'), true);
      expect(c.state.configuredSystems['snes']!.targetFolder, '/roms/SNES');
    });

    test('consoleSetup → complete', () {
      final c = _createController();
      c.state = c.state.copyWith(
        currentStep: OnboardingStep.consoleSetup,
        configuredSystems: {'nes': _systemConfig('nes')},
      );
      c.nextStep();
      expect(c.state.currentStep, OnboardingStep.complete);
    });

    test('canProceed resets to false for message steps', () {
      final c = _createController();
      c.onMessageComplete();
      expect(c.state.canProceed, true);
      c.nextStep(); // → legalNotice
      expect(c.state.canProceed, false);
    });

    test('preserves existing rommSetupState when entering rommSetup', () {
      final c = _createController();
      final existingRs = const RommSetupState(
        url: 'https://existing.com',
        apiKey: 'key123',
      );
      c.state = c.state.copyWith(
        currentStep: OnboardingStep.legalNotice,
        rommSetupState: existingRs,
      );
      c.onMessageComplete();
      c.nextStep(); // → rommSetup
      expect(c.state.rommSetupState!.url, 'https://existing.com');
      expect(c.state.rommSetupState!.apiKey, 'key123');
    });

    test('does nothing at last step', () {
      final c = _createController();
      c.state = c.state.copyWith(currentStep: OnboardingStep.complete);
      c.nextStep();
      expect(c.state.currentStep, OnboardingStep.complete);
    });
  });

  // =========================================================================
  // 3. previousStep()
  // =========================================================================
  group('previousStep()', () {
    test('legalNotice → welcome', () {
      final c = _createController();
      c.state = c.state.copyWith(currentStep: OnboardingStep.legalNotice);
      c.previousStep();
      expect(c.state.currentStep, OnboardingStep.welcome);
    });

    test('rommSetup → legalNotice', () {
      final c = _createController();
      c.state = c.state.copyWith(
        currentStep: OnboardingStep.rommSetup,
        rommSetupState: const RommSetupState(),
      );
      c.previousStep();
      expect(c.state.currentStep, OnboardingStep.legalNotice);
    });

    test('consoleSetup → rommSetup when rommSetupState exists', () {
      final c = _createController();
      c.state = c.state.copyWith(
        currentStep: OnboardingStep.consoleSetup,
        rommSetupState: const RommSetupState(url: 'https://romm.com'),
      );
      c.previousStep();
      expect(c.state.currentStep, OnboardingStep.rommSetup);
      expect(c.state.rommSetupState!.url, 'https://romm.com');
      expect(c.state.canProceed, true);
    });

    test('consoleSetup → localSetup when no rommSetupState', () {
      final c = _createController();
      c.state = c.state.copyWith(
        currentStep: OnboardingStep.consoleSetup,
      );
      c.previousStep();
      expect(c.state.currentStep, OnboardingStep.localSetup);
      expect(c.state.localSetupState, isNotNull);
      expect(c.state.canProceed, true);
    });

    test('localSetup → rommSetup', () {
      final c = _createController();
      c.state = c.state.copyWith(
        currentStep: OnboardingStep.localSetup,
        localSetupState: const LocalSetupState(),
      );
      c.previousStep();
      expect(c.state.currentStep, OnboardingStep.rommSetup);
      expect(c.state.rommSetupState, isNotNull);
      expect(c.state.canProceed, true);
    });

    test('preserves localSetupState when going back from consoleSetup', () {
      final c = _createController();
      final ls = const LocalSetupState(
        romBasePath: '/roms',
        enabledSystemIds: {'nes'},
      );
      c.state = c.state.copyWith(
        currentStep: OnboardingStep.consoleSetup,
        localSetupState: ls,
      );
      c.previousStep();
      expect(c.state.localSetupState!.romBasePath, '/roms');
      expect(c.state.localSetupState!.enabledSystemIds, contains('nes'));
    });

    test('does nothing at welcome step', () {
      final c = _createController();
      c.previousStep();
      expect(c.state.currentStep, OnboardingStep.welcome);
    });
  });

  // =========================================================================
  // 4. RomM Setup Sub-Steps
  // =========================================================================
  group('RomM setup sub-steps', () {
    test('rommSetupAnswer(true) → connect sub-step', () {
      final c = _createController();
      c.state = c.state.copyWith(
        currentStep: OnboardingStep.rommSetup,
        rommSetupState: const RommSetupState(),
      );
      c.rommSetupAnswer(true);
      expect(c.state.rommSetupState!.subStep, RommSetupSubStep.connect);
    });

    test('rommSetupAnswer(false) → clears state, advances to localSetup', () {
      final c = _createController();
      c.state = c.state.copyWith(
        currentStep: OnboardingStep.rommSetup,
        rommSetupState: const RommSetupState(url: 'https://romm.com'),
      );
      c.rommSetupAnswer(false);
      // Should have cleared rommSetupState and advanced
      expect(c.state.rommSetupState, isNull);
      expect(c.state.currentStep, OnboardingStep.localSetup);
    });

    test('rommSetupBack from connect → ask', () {
      final c = _createController();
      c.state = c.state.copyWith(
        currentStep: OnboardingStep.rommSetup,
        rommSetupState: const RommSetupState(
          subStep: RommSetupSubStep.connect,
        ),
      );
      c.rommSetupBack();
      expect(c.state.rommSetupState!.subStep, RommSetupSubStep.ask);
    });

    test('rommSetupBack from select → connect', () {
      final c = _createController();
      c.state = c.state.copyWith(
        currentStep: OnboardingStep.rommSetup,
        rommSetupState: const RommSetupState(
          subStep: RommSetupSubStep.select,
        ),
      );
      c.rommSetupBack();
      expect(c.state.rommSetupState!.subStep, RommSetupSubStep.connect);
    });

    test('rommSetupBack from folder → select (clears scan state)', () {
      final c = _createController();
      c.state = c.state.copyWith(
        currentStep: OnboardingStep.rommSetup,
        rommSetupState: const RommSetupState(
          subStep: RommSetupSubStep.folder,
          detectedPath: '/roms',
          scannedFolders: [ScannedFolder(name: 'NES', fileCount: 5)],
        ),
      );
      c.rommSetupBack();
      expect(c.state.rommSetupState!.subStep, RommSetupSubStep.select);
      expect(c.state.rommSetupState!.detectedPath, isNull);
      expect(c.state.rommSetupState!.scannedFolders, isNull);
      expect(c.state.rommSetupState!.isAutoDetecting, false);
    });

    test('rommSetupBack from ask → previousStep', () {
      final c = _createController();
      c.state = c.state.copyWith(
        currentStep: OnboardingStep.rommSetup,
        rommSetupState: const RommSetupState(subStep: RommSetupSubStep.ask),
      );
      c.rommSetupBack();
      expect(c.state.currentStep, OnboardingStep.legalNotice);
    });

    test('updateRommSetupField url', () {
      final c = _createController();
      c.state = c.state.copyWith(
        currentStep: OnboardingStep.rommSetup,
        rommSetupState: const RommSetupState(),
      );
      c.updateRommSetupField('url', 'https://romm.new.com');
      expect(c.state.rommSetupState!.url, 'https://romm.new.com');
    });

    test('updateRommSetupField apiKey/user/pass', () {
      final c = _createController();
      c.state = c.state.copyWith(
        currentStep: OnboardingStep.rommSetup,
        rommSetupState: const RommSetupState(),
      );
      c.updateRommSetupField('apiKey', 'key123');
      expect(c.state.rommSetupState!.apiKey, 'key123');
      c.updateRommSetupField('user', 'admin');
      expect(c.state.rommSetupState!.user, 'admin');
      c.updateRommSetupField('pass', 'secret');
      expect(c.state.rommSetupState!.pass, 'secret');
    });

    test('updateRommSetupField clears connection state', () {
      final c = _createController();
      c.state = c.state.copyWith(
        currentStep: OnboardingStep.rommSetup,
        rommSetupState: const RommSetupState(),
        connectionTestSuccess: true,
        connectionTestError: 'old error',
      );
      c.updateRommSetupField('url', 'https://new.com');
      expect(c.state.connectionTestSuccess, false);
      expect(c.state.connectionTestError, isNull);
    });

    test('updateRommSetupField ignores unknown key', () {
      final c = _createController();
      c.state = c.state.copyWith(
        currentStep: OnboardingStep.rommSetup,
        rommSetupState: const RommSetupState(url: 'original'),
      );
      c.updateRommSetupField('unknown', 'value');
      expect(c.state.rommSetupState!.url, 'original');
    });

    test('toggleRommSystem adds and removes', () {
      final c = _createController();
      c.state = c.state.copyWith(
        rommSetupState: const RommSetupState(selectedSystemIds: {'nes'}),
      );
      c.toggleRommSystem('snes');
      expect(c.state.rommSetupState!.selectedSystemIds, {'nes', 'snes'});
      c.toggleRommSystem('nes');
      expect(c.state.rommSetupState!.selectedSystemIds, {'snes'});
    });

    test('toggleAllRommSystems select all / deselect all', () {
      final c = _createController();
      c.state = c.state.copyWith(
        rommSetupState: const RommSetupState(
          systemMatches: {
            'nes': _testPlatformNes,
            'snes': _testPlatformSnes,
          },
          selectedSystemIds: {'nes'},
        ),
      );
      c.toggleAllRommSystems(true);
      expect(c.state.rommSetupState!.selectedSystemIds, {'nes', 'snes'});
      c.toggleAllRommSystems(false);
      expect(c.state.rommSetupState!.selectedSystemIds, isEmpty);
    });

    test('toggleLocalSystem adds and removes', () {
      final c = _createController();
      c.state = c.state.copyWith(
        rommSetupState: const RommSetupState(localOnlySystemIds: {}),
      );
      c.toggleLocalSystem('gb');
      expect(c.state.rommSetupState!.localOnlySystemIds, {'gb'});
      c.toggleLocalSystem('gb');
      expect(c.state.rommSetupState!.localOnlySystemIds, isEmpty);
    });
  });

  // =========================================================================
  // 5. Console Selection
  // =========================================================================
  group('Console selection', () {
    test('selectConsole creates ConsoleSetupState', () {
      final c = _createController();
      c.state = c.state.copyWith(
        currentStep: OnboardingStep.consoleSetup,
      );
      c.selectConsole('snes');
      expect(c.state.selectedConsoleId, 'snes');
      expect(c.state.consoleSubState, isNotNull);
      // SNES is zipped, so autoExtract should be true
      expect(c.state.consoleSubState!.autoExtract, true);
      expect(c.state.consoleSubState!.providers, isEmpty);
    });

    test('selectConsole with existing config loads from configuredSystems', () {
      final c = _createController();
      final existing = _systemConfig(
        'nes',
        targetFolder: '/custom/path',
        autoExtract: true,
        mergeMode: true,
        providers: [
          const ProviderConfig(
            type: ProviderType.web,
            priority: 0,
            url: 'https://example.com',
          ),
        ],
      );
      c.state = c.state.copyWith(
        currentStep: OnboardingStep.consoleSetup,
        configuredSystems: {'nes': existing},
      );
      c.selectConsole('nes');
      expect(c.state.consoleSubState!.targetFolder, '/custom/path');
      expect(c.state.consoleSubState!.autoExtract, true);
      expect(c.state.consoleSubState!.mergeMode, true);
      expect(c.state.consoleSubState!.providers.length, 1);
    });

    test('selectConsole with RomM match auto-adds RomM provider', () {
      final c = _createController();
      c.state = c.state.copyWith(
        currentStep: OnboardingStep.consoleSetup,
        rommSetupState: const RommSetupState(
          url: 'https://romm.example.com',
          apiKey: 'key123',
          selectedSystemIds: {'nes'},
          systemMatches: {'nes': _testPlatformNes},
        ),
      );
      c.selectConsole('nes');
      expect(c.state.consoleSubState!.providers.length, 1);
      final p = c.state.consoleSubState!.providers.first;
      expect(p.type, ProviderType.romm);
      expect(p.url, 'https://romm.example.com');
      expect(p.platformId, 10);
      expect(p.platformName, 'Nintendo Entertainment System');
      expect(p.auth?.apiKey, 'key123');
    });

    test('selectConsole without RomM match does not auto-add provider', () {
      final c = _createController();
      c.state = c.state.copyWith(
        currentStep: OnboardingStep.consoleSetup,
        rommSetupState: const RommSetupState(
          url: 'https://romm.example.com',
          selectedSystemIds: {'nes'},
          systemMatches: {'nes': _testPlatformNes},
        ),
      );
      // snes is not in selectedSystemIds/systemMatches
      c.selectConsole('snes');
      expect(c.state.consoleSubState!.providers, isEmpty);
    });

    test('deselectConsole clears all console state', () {
      final c = _createController();
      c.state = c.state.copyWith(
        selectedConsoleId: 'nes',
        consoleSubState: const ConsoleSetupState(targetFolder: '/roms/nes'),
        providerForm: const ProviderFormState(),
      );
      c.deselectConsole();
      expect(c.state.selectedConsoleId, isNull);
      expect(c.state.consoleSubState, isNull);
      expect(c.state.providerForm, isNull);
    });

    test('setTargetFolder updates consoleSubState', () {
      final c = _createController();
      c.state = c.state.copyWith(
        consoleSubState: const ConsoleSetupState(),
      );
      c.setTargetFolder('/new/path');
      expect(c.state.consoleSubState!.targetFolder, '/new/path');
    });

    test('setTargetFolder without consoleSubState is no-op', () {
      final c = _createController();
      c.setTargetFolder('/new/path');
      expect(c.state.consoleSubState, isNull);
    });

    test('setAutoExtract updates consoleSubState', () {
      final c = _createController();
      c.state = c.state.copyWith(
        consoleSubState: const ConsoleSetupState(),
      );
      c.setAutoExtract(true);
      expect(c.state.consoleSubState!.autoExtract, true);
    });

    test('setMergeMode updates consoleSubState', () {
      final c = _createController();
      c.state = c.state.copyWith(
        consoleSubState: const ConsoleSetupState(),
      );
      c.setMergeMode(true);
      expect(c.state.consoleSubState!.mergeMode, true);
    });
  });

  // =========================================================================
  // 6. Provider Form
  // =========================================================================
  group('Provider form', () {
    test('startAddProvider creates empty form', () {
      final c = _createController();
      c.startAddProvider();
      expect(c.state.providerForm, isNotNull);
      expect(c.state.providerForm!.type, ProviderType.web);
      expect(c.state.providerForm!.fields, isEmpty);
      expect(c.state.providerForm!.editingIndex, isNull);
      expect(c.state.connectionTestError, isNull);
      expect(c.state.connectionTestSuccess, false);
    });

    test('startEditProvider loads fields from existing provider', () {
      final c = _createController();
      c.state = c.state.copyWith(
        consoleSubState: const ConsoleSetupState(
          providers: [
            ProviderConfig(
              type: ProviderType.ftp,
              priority: 0,
              host: '192.168.1.1',
              port: 21,
              path: '/roms',
              auth: AuthConfig(user: 'admin', pass: 'secret'),
            ),
          ],
        ),
      );
      c.startEditProvider(0);
      final form = c.state.providerForm!;
      expect(form.type, ProviderType.ftp);
      expect(form.fields['host'], '192.168.1.1');
      expect(form.fields['port'], 21);
      expect(form.fields['path'], '/roms');
      expect(form.fields['user'], 'admin');
      expect(form.fields['pass'], 'secret');
      expect(form.editingIndex, 0);
    });

    test('startEditProvider with RomM provider restores platform', () {
      final c = _createController();
      c.state = c.state.copyWith(
        consoleSubState: const ConsoleSetupState(
          providers: [
            ProviderConfig(
              type: ProviderType.romm,
              priority: 0,
              url: 'https://romm.com',
              platformId: 42,
              platformName: 'NES',
            ),
          ],
        ),
      );
      c.startEditProvider(0);
      expect(c.state.rommMatchedPlatform, isNotNull);
      expect(c.state.rommMatchedPlatform!.id, 42);
      expect(c.state.rommMatchedPlatform!.name, 'NES');
    });

    test('startEditProvider out of bounds is no-op', () {
      final c = _createController();
      c.state = c.state.copyWith(
        consoleSubState: const ConsoleSetupState(providers: []),
      );
      c.startEditProvider(5);
      expect(c.state.providerForm, isNull);
    });

    test('startEditProvider without consoleSubState is no-op', () {
      final c = _createController();
      c.startEditProvider(0);
      expect(c.state.providerForm, isNull);
    });

    test('cancelProviderForm clears form and connection state', () {
      final c = _createController();
      c.state = c.state.copyWith(
        providerForm: const ProviderFormState(
          type: ProviderType.ftp,
          fields: {'host': '1.2.3.4'},
        ),
        connectionTestError: 'some error',
        connectionTestSuccess: true,
        rommPlatforms: [_testPlatformNes],
      );
      c.cancelProviderForm();
      expect(c.state.providerForm, isNull);
      expect(c.state.connectionTestError, isNull);
      expect(c.state.connectionTestSuccess, false);
      expect(c.state.rommPlatforms, isNull);
    });

    test('setProviderType changes type and clears fields', () {
      final c = _createController();
      c.state = c.state.copyWith(
        providerForm: const ProviderFormState(
          type: ProviderType.web,
          fields: {'url': 'https://example.com'},
        ),
      );
      c.setProviderType(ProviderType.ftp);
      expect(c.state.providerForm!.type, ProviderType.ftp);
      // FTP pre-fills default port
      expect(c.state.providerForm!.fields, {'port': '21'});
    });

    test('setProviderType without form is no-op', () {
      final c = _createController();
      c.setProviderType(ProviderType.smb);
      expect(c.state.providerForm, isNull);
    });

    test('updateProviderField sets field and clears test state', () {
      final c = _createController();
      c.state = c.state.copyWith(
        providerForm: const ProviderFormState(),
        connectionTestSuccess: true,
        connectionTestError: 'old',
      );
      c.updateProviderField('url', 'https://new.com');
      expect(c.state.providerForm!.fields['url'], 'https://new.com');
      expect(c.state.connectionTestSuccess, false);
      expect(c.state.connectionTestError, isNull);
    });

    test('updateProviderField without form is no-op', () {
      final c = _createController();
      c.updateProviderField('url', 'https://x.com');
      expect(c.state.providerForm, isNull);
    });

    test('selectRommPlatform sets platform', () {
      final c = _createController();
      c.selectRommPlatform(_testPlatformNes);
      expect(c.state.rommMatchedPlatform, isNotNull);
      expect(c.state.rommMatchedPlatform!.id, 10);
    });

    test('clearRommPlatform clears only platform, preserves rest', () {
      final c = _createController();
      c.state = c.state.copyWith(
        rommMatchedPlatform: _testPlatformNes,
        rommPlatforms: [_testPlatformNes, _testPlatformSnes],
        connectionTestSuccess: true,
        providerForm: const ProviderFormState(type: ProviderType.romm),
      );
      c.clearRommPlatform();
      expect(c.state.rommMatchedPlatform, isNull);
      expect(c.state.rommPlatforms!.length, 2);
      expect(c.state.connectionTestSuccess, true);
      expect(c.state.providerForm, isNotNull);
    });
  });

  // =========================================================================
  // 7. canTest getter
  // =========================================================================
  group('canTest', () {
    test('web needs url', () {
      final c = _createController();
      c.state = c.state.copyWith(
        providerForm: const ProviderFormState(type: ProviderType.web),
      );
      expect(c.state.canTest, false);
      c.updateProviderField('url', 'https://example.com');
      expect(c.state.canTest, true);
    });

    test('ftp needs host, port, path', () {
      final c = _createController();
      c.state = c.state.copyWith(
        providerForm: const ProviderFormState(type: ProviderType.ftp),
      );
      expect(c.state.canTest, false);
      c.updateProviderField('host', '1.2.3.4');
      expect(c.state.canTest, false);
      c.updateProviderField('port', '21');
      expect(c.state.canTest, false);
      c.updateProviderField('path', '/roms');
      expect(c.state.canTest, true);
    });

    test('smb needs host, port, share, path', () {
      final c = _createController();
      c.state = c.state.copyWith(
        providerForm: const ProviderFormState(type: ProviderType.smb),
      );
      expect(c.state.canTest, false);
      c.updateProviderField('host', '1.2.3.4');
      c.updateProviderField('port', '445');
      c.updateProviderField('share', 'roms');
      expect(c.state.canTest, false);
      c.updateProviderField('path', '/');
      expect(c.state.canTest, true);
    });

    test('romm needs url', () {
      final c = _createController();
      c.state = c.state.copyWith(
        providerForm: const ProviderFormState(type: ProviderType.romm),
      );
      expect(c.state.canTest, false);
      c.updateProviderField('url', 'https://romm.example.com');
      expect(c.state.canTest, true);
    });

    test('canTest is false without form', () {
      final c = _createController();
      expect(c.state.canTest, false);
    });

    test('whitespace-only values do not satisfy canTest', () {
      final c = _createController();
      c.state = c.state.copyWith(
        providerForm: const ProviderFormState(type: ProviderType.web),
      );
      c.updateProviderField('url', '   ');
      expect(c.state.canTest, false);
    });
  });

  // =========================================================================
  // 8. saveProvider
  // =========================================================================
  group('saveProvider', () {
    test('add mode appends to providers list', () {
      final c = _createController();
      c.state = c.state.copyWith(
        consoleSubState: const ConsoleSetupState(providers: []),
        providerForm: const ProviderFormState(
          type: ProviderType.web,
          fields: {'url': 'https://example.com'},
        ),
      );
      c.saveProvider();
      expect(c.state.consoleSubState!.providers.length, 1);
      expect(c.state.consoleSubState!.providers[0].url, 'https://example.com');
      expect(c.state.consoleSubState!.providers[0].priority, 0);
      expect(c.state.providerForm, isNull);
    });

    test('edit mode replaces at index', () {
      final c = _createController();
      c.state = c.state.copyWith(
        consoleSubState: const ConsoleSetupState(
          providers: [
            ProviderConfig(
              type: ProviderType.web,
              priority: 0,
              url: 'https://old.com',
            ),
          ],
        ),
        providerForm: const ProviderFormState(
          type: ProviderType.web,
          fields: {'url': 'https://new.com'},
          editingIndex: 0,
        ),
      );
      c.saveProvider();
      expect(c.state.consoleSubState!.providers.length, 1);
      expect(c.state.consoleSubState!.providers[0].url, 'https://new.com');
    });

    test('saveProvider with auth fields builds AuthConfig', () {
      final c = _createController();
      c.state = c.state.copyWith(
        consoleSubState: const ConsoleSetupState(providers: []),
        providerForm: const ProviderFormState(
          type: ProviderType.ftp,
          fields: {
            'host': '1.2.3.4',
            'port': 21,
            'path': '/roms',
            'user': 'admin',
            'pass': 'secret',
          },
        ),
      );
      c.saveProvider();
      final p = c.state.consoleSubState!.providers[0];
      expect(p.auth, isNotNull);
      expect(p.auth!.user, 'admin');
      expect(p.auth!.pass, 'secret');
    });

    test('saveProvider with RomM + platform includes platformId/platformName',
        () {
      final c = _createController();
      c.state = c.state.copyWith(
        consoleSubState: const ConsoleSetupState(providers: []),
        providerForm: const ProviderFormState(
          type: ProviderType.romm,
          fields: {'url': 'https://romm.com'},
        ),
        rommMatchedPlatform: _testPlatformNes,
      );
      c.saveProvider();
      final p = c.state.consoleSubState!.providers[0];
      expect(p.platformId, 10);
      expect(p.platformName, 'Nintendo Entertainment System');
    });

    test('saveProvider without form or sub is no-op', () {
      final c = _createController();
      c.saveProvider();
      expect(c.state.consoleSubState, isNull);
    });

    test('saveProvider without auth fields leaves auth null', () {
      final c = _createController();
      c.state = c.state.copyWith(
        consoleSubState: const ConsoleSetupState(providers: []),
        providerForm: const ProviderFormState(
          type: ProviderType.web,
          fields: {'url': 'https://noauth.com'},
        ),
      );
      c.saveProvider();
      expect(c.state.consoleSubState!.providers[0].auth, isNull);
    });

    test('saveProvider with port as string parses to int', () {
      final c = _createController();
      c.state = c.state.copyWith(
        consoleSubState: const ConsoleSetupState(providers: []),
        providerForm: const ProviderFormState(
          type: ProviderType.ftp,
          fields: {'host': '1.2.3.4', 'port': '2121', 'path': '/roms'},
        ),
      );
      c.saveProvider();
      expect(c.state.consoleSubState!.providers[0].port, 2121);
    });
  });

  // =========================================================================
  // 9. Provider List Management
  // =========================================================================
  group('Provider list management', () {
    test('removeProvider removes and re-indexes priorities', () {
      final c = _createController();
      c.state = c.state.copyWith(
        consoleSubState: const ConsoleSetupState(
          providers: [
            ProviderConfig(type: ProviderType.web, priority: 0, url: 'a'),
            ProviderConfig(type: ProviderType.ftp, priority: 1, host: 'b'),
            ProviderConfig(type: ProviderType.smb, priority: 2, host: 'c'),
          ],
        ),
      );
      c.removeProvider(0);
      final providers = c.state.consoleSubState!.providers;
      expect(providers.length, 2);
      expect(providers[0].host, 'b');
      expect(providers[0].priority, 0);
      expect(providers[1].host, 'c');
      expect(providers[1].priority, 1);
    });

    test('removeProvider out of bounds is no-op', () {
      final c = _createController();
      c.state = c.state.copyWith(
        consoleSubState: const ConsoleSetupState(
          providers: [
            ProviderConfig(type: ProviderType.web, priority: 0, url: 'a'),
          ],
        ),
      );
      c.removeProvider(5);
      expect(c.state.consoleSubState!.providers.length, 1);
    });

    test('removeProvider without consoleSubState is no-op', () {
      final c = _createController();
      c.removeProvider(0);
      expect(c.state.consoleSubState, isNull);
    });

    test('moveProvider reorders and re-indexes', () {
      final c = _createController();
      c.state = c.state.copyWith(
        consoleSubState: const ConsoleSetupState(
          providers: [
            ProviderConfig(type: ProviderType.web, priority: 0, url: 'a'),
            ProviderConfig(type: ProviderType.ftp, priority: 1, host: 'b'),
            ProviderConfig(type: ProviderType.smb, priority: 2, host: 'c'),
          ],
        ),
      );
      c.moveProvider(0, 2);
      final providers = c.state.consoleSubState!.providers;
      expect(providers[0].host, 'b');
      expect(providers[0].priority, 0);
      expect(providers[1].host, 'c');
      expect(providers[1].priority, 1);
      expect(providers[2].url, 'a');
      expect(providers[2].priority, 2);
    });

    test('moveProvider with invalid indices is no-op', () {
      final c = _createController();
      c.state = c.state.copyWith(
        consoleSubState: const ConsoleSetupState(
          providers: [
            ProviderConfig(type: ProviderType.web, priority: 0, url: 'a'),
          ],
        ),
      );
      c.moveProvider(-1, 0);
      expect(c.state.consoleSubState!.providers.length, 1);
      c.moveProvider(0, 5);
      expect(c.state.consoleSubState!.providers.length, 1);
    });

    test('add, reorder, remove sequence works correctly', () {
      final c = _createController();
      c.state = c.state.copyWith(
        consoleSubState: const ConsoleSetupState(providers: []),
      );

      // Add three providers
      c.state = c.state.copyWith(
        providerForm: const ProviderFormState(
          type: ProviderType.web,
          fields: {'url': 'https://first.com'},
        ),
      );
      c.saveProvider();
      c.state = c.state.copyWith(
        providerForm: const ProviderFormState(
          type: ProviderType.ftp,
          fields: {'host': 'second.com', 'port': 21, 'path': '/'},
        ),
      );
      c.saveProvider();
      c.state = c.state.copyWith(
        providerForm: const ProviderFormState(
          type: ProviderType.smb,
          fields: {
            'host': 'third.com',
            'port': 445,
            'share': 'roms',
            'path': '/',
          },
        ),
      );
      c.saveProvider();
      expect(c.state.consoleSubState!.providers.length, 3);

      // Reorder: move first to last
      c.moveProvider(0, 2);
      expect(c.state.consoleSubState!.providers[2].url, 'https://first.com');

      // Remove middle
      c.removeProvider(1);
      expect(c.state.consoleSubState!.providers.length, 2);
      expect(c.state.consoleSubState!.providers[0].priority, 0);
      expect(c.state.consoleSubState!.providers[1].priority, 1);
    });
  });

  // =========================================================================
  // 10. Console Config Save/Remove
  // =========================================================================
  group('Console config save/remove', () {
    test('saveConsoleConfig adds to configuredSystems and clears state', () {
      final c = _createController();
      c.state = c.state.copyWith(
        currentStep: OnboardingStep.consoleSetup,
        selectedConsoleId: 'nes',
        consoleSubState: const ConsoleSetupState(
          targetFolder: '/roms/nes',
          autoExtract: true,
          providers: [
            ProviderConfig(type: ProviderType.web, priority: 0, url: 'x'),
          ],
        ),
      );
      c.saveConsoleConfig();
      expect(c.state.configuredSystems.containsKey('nes'), true);
      expect(c.state.configuredSystems['nes']!.targetFolder, '/roms/nes');
      expect(c.state.configuredSystems['nes']!.autoExtract, true);
      expect(c.state.configuredSystems['nes']!.providers.length, 1);
      expect(c.state.selectedConsoleId, isNull);
      expect(c.state.consoleSubState, isNull);
      expect(c.state.providerForm, isNull);
    });

    test('saveConsoleConfig without targetFolder (incomplete) is no-op', () {
      final c = _createController();
      c.state = c.state.copyWith(
        selectedConsoleId: 'nes',
        consoleSubState: const ConsoleSetupState(),
      );
      c.saveConsoleConfig();
      expect(c.state.configuredSystems, isEmpty);
    });

    test('saveConsoleConfig overwrites existing config for same ID', () {
      final c = _createController();
      c.state = c.state.copyWith(
        configuredSystems: {'nes': _systemConfig('nes', targetFolder: '/old')},
        selectedConsoleId: 'nes',
        consoleSubState: const ConsoleSetupState(
          targetFolder: '/new/path',
        ),
      );
      c.saveConsoleConfig();
      expect(c.state.configuredSystems['nes']!.targetFolder, '/new/path');
    });

    test('saveConsoleConfig without selectedConsoleId is no-op', () {
      final c = _createController();
      c.state = c.state.copyWith(
        consoleSubState: const ConsoleSetupState(targetFolder: '/roms/nes'),
      );
      c.saveConsoleConfig();
      expect(c.state.configuredSystems, isEmpty);
    });

    test('removeConsoleConfig removes from configuredSystems', () {
      final c = _createController();
      c.state = c.state.copyWith(
        configuredSystems: {
          'nes': _systemConfig('nes'),
          'snes': _systemConfig('snes'),
        },
      );
      c.removeConsoleConfig('nes');
      expect(c.state.configuredSystems.containsKey('nes'), false);
      expect(c.state.configuredSystems.containsKey('snes'), true);
    });

    test('removeConsoleConfig non-existent does not crash', () {
      final c = _createController();
      c.state = c.state.copyWith(
        configuredSystems: {'nes': _systemConfig('nes')},
      );
      c.removeConsoleConfig('snes');
      expect(c.state.configuredSystems.length, 1);
    });
  });

  // =========================================================================
  // 11. Auto-Configure RomM Systems
  // =========================================================================
  group('Auto-configure RomM systems', () {
    test('no rommSetupState is no-op', () {
      final c = _createController();
      // Trigger via nextStep from folder sub-step
      c.state = c.state.copyWith(
        currentStep: OnboardingStep.rommSetup,
        rommSetupState: null,
      );
      // _autoConfigureRommSystems is private, but called via nextStep
      // For null rommSetupState, nextStep falls through to enum advance
      expect(c.state.configuredSystems, isEmpty);
    });

    test('selected systems create SystemConfig with RomM provider', () {
      final c = _createController();
      c.state = c.state.copyWith(
        currentStep: OnboardingStep.rommSetup,
        rommSetupState: const RommSetupState(
          subStep: RommSetupSubStep.folder,
          url: 'https://romm.example.com',
          apiKey: 'key123',
          selectedSystemIds: {'nes'},
          systemMatches: {'nes': _testPlatformNes},
        ),
      );
      c.nextStep(); // folder → consoleSetup, triggers _autoConfigureRommSystems
      expect(c.state.configuredSystems.containsKey('nes'), true);
      final cfg = c.state.configuredSystems['nes']!;
      expect(cfg.providers.length, 1);
      expect(cfg.providers[0].type, ProviderType.romm);
      expect(cfg.providers[0].url, 'https://romm.example.com');
      expect(cfg.providers[0].auth?.apiKey, 'key123');
      expect(cfg.providers[0].platformId, 10);
    });

    test('local-only systems create SystemConfig without providers', () {
      final c = _createController();
      c.state = c.state.copyWith(
        currentStep: OnboardingStep.rommSetup,
        rommSetupState: const RommSetupState(
          subStep: RommSetupSubStep.folder,
          url: 'https://romm.example.com',
          localOnlySystemIds: {'snes'},
        ),
      );
      c.nextStep();
      expect(c.state.configuredSystems.containsKey('snes'), true);
      expect(c.state.configuredSystems['snes']!.providers, isEmpty);
    });

    test('folder assignment precedence: manual > auto-match > default', () {
      final c = _createController();
      c.state = c.state.copyWith(
        currentStep: OnboardingStep.rommSetup,
        rommSetupState: const RommSetupState(
          subStep: RommSetupSubStep.folder,
          url: 'https://romm.example.com',
          selectedSystemIds: {'nes', 'snes'},
          systemMatches: {
            'nes': _testPlatformNes,
            'snes': _testPlatformSnes,
          },
          // Manual assignment for nes
          folderAssignments: {'nes': 'MyNES'},
          // Auto-match for snes via scannedFolders
          scannedFolders: [
            ScannedFolder(
              name: 'Super Nintendo',
              fileCount: 10,
              autoMatchedSystemId: 'snes',
            ),
          ],
        ),
      );
      c.nextStep();
      // nes: manual folder
      expect(
        c.state.configuredSystems['nes']!.targetFolder,
        '/storage/emulated/0/ROMs/MyNES',
      );
      // snes: auto-matched folder name
      expect(
        c.state.configuredSystems['snes']!.targetFolder,
        '/storage/emulated/0/ROMs/Super Nintendo',
      );
    });

    test('skips already-configured systems', () {
      final c = _createController();
      final existing = _systemConfig('nes', targetFolder: '/existing/nes');
      c.state = c.state.copyWith(
        currentStep: OnboardingStep.rommSetup,
        configuredSystems: {'nes': existing},
        rommSetupState: const RommSetupState(
          subStep: RommSetupSubStep.folder,
          url: 'https://romm.example.com',
          selectedSystemIds: {'nes'},
          systemMatches: {'nes': _testPlatformNes},
        ),
      );
      c.nextStep();
      // Should not overwrite existing config
      expect(c.state.configuredSystems['nes']!.targetFolder, '/existing/nes');
    });

    test('scanned-but-unselected folders create path-only configs', () {
      final c = _createController();
      c.state = c.state.copyWith(
        currentStep: OnboardingStep.rommSetup,
        rommSetupState: const RommSetupState(
          subStep: RommSetupSubStep.folder,
          url: 'https://romm.example.com',
          selectedSystemIds: {}, // none selected
          scannedFolders: [
            ScannedFolder(
              name: 'NES_Roms',
              fileCount: 10,
              autoMatchedSystemId: 'nes',
            ),
          ],
        ),
      );
      c.nextStep();
      // nes should be configured from scanned folder auto-match
      expect(c.state.configuredSystems.containsKey('nes'), true);
      expect(c.state.configuredSystems['nes']!.providers, isEmpty);
      expect(
        c.state.configuredSystems['nes']!.targetFolder,
        '/storage/emulated/0/ROMs/NES_Roms',
      );
    });

    test('manual folder assignments for non-selected systems', () {
      final c = _createController();
      c.state = c.state.copyWith(
        currentStep: OnboardingStep.rommSetup,
        rommSetupState: const RommSetupState(
          subStep: RommSetupSubStep.folder,
          url: 'https://romm.example.com',
          selectedSystemIds: {},
          localOnlySystemIds: {},
          folderAssignments: {'n64': 'N64_Folder'},
          // Need at least one non-empty condition to pass the guard
          scannedFolders: [],
        ),
      );
      c.nextStep();
      expect(c.state.configuredSystems.containsKey('n64'), true);
      expect(c.state.configuredSystems['n64']!.providers, isEmpty);
      expect(
        c.state.configuredSystems['n64']!.targetFolder,
        '/storage/emulated/0/ROMs/N64_Folder',
      );
    });

    test('uses custom romBasePath when set', () {
      final c = _createController();
      c.state = c.state.copyWith(
        currentStep: OnboardingStep.rommSetup,
        rommSetupState: const RommSetupState(
          subStep: RommSetupSubStep.folder,
          url: 'https://romm.example.com',
          romBasePath: '/custom/roms',
          selectedSystemIds: {'nes'},
          systemMatches: {'nes': _testPlatformNes},
        ),
      );
      c.nextStep();
      expect(
        c.state.configuredSystems['nes']!.targetFolder,
        '/custom/roms/nes',
      );
    });
  });

  // =========================================================================
  // 12. Auto-Configure Local Systems
  // =========================================================================
  group('Auto-configure local systems', () {
    test('no localSetupState is no-op', () {
      final c = _createController();
      c.state = c.state.copyWith(
        currentStep: OnboardingStep.localSetup,
        localSetupState: null,
      );
      // nextStep from localSetup triggers _autoConfigureLocalSystems
      // But we need localSetupState for it to actually configure
      c.nextStep();
      expect(c.state.configuredSystems, isEmpty);
    });

    test('enabled systems create SystemConfig (no providers)', () {
      final c = _createController();
      c.state = c.state.copyWith(
        currentStep: OnboardingStep.localSetup,
        localSetupState: const LocalSetupState(
          romBasePath: '/roms',
          enabledSystemIds: {'nes', 'snes'},
          scannedFolders: [
            ScannedFolder(
              name: 'NES',
              fileCount: 10,
              autoMatchedSystemId: 'nes',
            ),
            ScannedFolder(
              name: 'SNES',
              fileCount: 5,
              autoMatchedSystemId: 'snes',
            ),
          ],
        ),
      );
      c.nextStep();
      expect(c.state.configuredSystems['nes']!.providers, isEmpty);
      expect(c.state.configuredSystems['nes']!.targetFolder, '/roms/NES');
      expect(c.state.configuredSystems['snes']!.targetFolder, '/roms/SNES');
    });

    test('folder assignment precedence: manual > auto-match > default', () {
      final c = _createController();
      c.state = c.state.copyWith(
        currentStep: OnboardingStep.localSetup,
        localSetupState: const LocalSetupState(
          romBasePath: '/roms',
          enabledSystemIds: {'nes', 'snes'},
          folderAssignments: {'nes': 'Custom_NES'},
          scannedFolders: [
            ScannedFolder(
              name: 'SNES_folder',
              fileCount: 5,
              autoMatchedSystemId: 'snes',
            ),
          ],
        ),
      );
      c.nextStep();
      expect(c.state.configuredSystems['nes']!.targetFolder, '/roms/Custom_NES');
      expect(
        c.state.configuredSystems['snes']!.targetFolder,
        '/roms/SNES_folder',
      );
    });

    test('skips already-configured systems', () {
      final existing = _systemConfig('nes', targetFolder: '/existing/nes');
      final c = _createController();
      c.state = c.state.copyWith(
        currentStep: OnboardingStep.localSetup,
        configuredSystems: {'nes': existing},
        localSetupState: const LocalSetupState(
          enabledSystemIds: {'nes'},
        ),
      );
      c.nextStep();
      expect(c.state.configuredSystems['nes']!.targetFolder, '/existing/nes');
    });

    test('manual folder assignments for non-enabled systems', () {
      final c = _createController();
      c.state = c.state.copyWith(
        currentStep: OnboardingStep.localSetup,
        localSetupState: const LocalSetupState(
          romBasePath: '/roms',
          enabledSystemIds: {},
          folderAssignments: {'n64': 'N64_dir'},
        ),
      );
      c.nextStep();
      expect(c.state.configuredSystems.containsKey('n64'), true);
      expect(c.state.configuredSystems['n64']!.targetFolder, '/roms/N64_dir');
    });

    test('scanned-but-not-enabled folders create path-only configs', () {
      final c = _createController();
      c.state = c.state.copyWith(
        currentStep: OnboardingStep.localSetup,
        localSetupState: const LocalSetupState(
          romBasePath: '/roms',
          enabledSystemIds: {},
          scannedFolders: [
            ScannedFolder(
              name: 'GB_folder',
              fileCount: 3,
              autoMatchedSystemId: 'gb',
            ),
          ],
        ),
      );
      c.nextStep();
      expect(c.state.configuredSystems.containsKey('gb'), true);
      expect(c.state.configuredSystems['gb']!.targetFolder, '/roms/GB_folder');
    });

    test('uses default basePath when romBasePath is null', () {
      final c = _createController();
      c.state = c.state.copyWith(
        currentStep: OnboardingStep.localSetup,
        localSetupState: const LocalSetupState(
          enabledSystemIds: {'nes'},
        ),
      );
      c.nextStep();
      expect(
        c.state.configuredSystems['nes']!.targetFolder,
        '/storage/emulated/0/ROMs/nes',
      );
    });
  });

  // =========================================================================
  // 13. Local Setup Methods
  // =========================================================================
  group('Local setup methods', () {
    test('localSetupChoice(skip) calls nextStep', () {
      final c = _createController();
      c.state = c.state.copyWith(
        currentStep: OnboardingStep.localSetup,
        localSetupState: const LocalSetupState(),
      );
      c.localSetupChoice(LocalSetupAction.skip);
      expect(c.state.currentStep, OnboardingStep.consoleSetup);
    });

    test('localSetupChoice(createFolders) sets createSystemIds + createBasePath',
        () {
      final c = _createController();
      c.state = c.state.copyWith(
        currentStep: OnboardingStep.localSetup,
        localSetupState: const LocalSetupState(),
      );
      c.localSetupChoice(LocalSetupAction.createFolders);
      expect(c.state.localSetupState!.createSystemIds, isNotNull);
      expect(c.state.localSetupState!.createSystemIds, isEmpty);
      expect(
        c.state.localSetupState!.createBasePath,
        '/storage/emulated/0/ROMs',
      );
      expect(c.state.localSetupState!.isCreatePhase, true);
    });

    test('toggleCreateSystem adds and removes', () {
      final c = _createController();
      c.state = c.state.copyWith(
        localSetupState: const LocalSetupState(createSystemIds: {}),
      );
      c.toggleCreateSystem('nes');
      expect(c.state.localSetupState!.createSystemIds, {'nes'});
      c.toggleCreateSystem('snes');
      expect(c.state.localSetupState!.createSystemIds, {'nes', 'snes'});
      c.toggleCreateSystem('nes');
      expect(c.state.localSetupState!.createSystemIds, {'snes'});
    });

    test('toggleCreateSystem without createSystemIds is no-op', () {
      final c = _createController();
      c.state = c.state.copyWith(
        localSetupState: const LocalSetupState(),
      );
      c.toggleCreateSystem('nes');
      expect(c.state.localSetupState!.createSystemIds, isNull);
    });

    test('toggleAllCreateSystems select all / deselect all', () {
      final c = _createController();
      c.state = c.state.copyWith(
        localSetupState: const LocalSetupState(createSystemIds: {}),
      );
      c.toggleAllCreateSystems(true);
      expect(
        c.state.localSetupState!.createSystemIds!.length,
        SystemModel.supportedSystems.length,
      );
      c.toggleAllCreateSystems(false);
      expect(c.state.localSetupState!.createSystemIds, isEmpty);
    });

    test('localSetupBack from createPhase → choice', () {
      final c = _createController();
      c.state = c.state.copyWith(
        currentStep: OnboardingStep.localSetup,
        localSetupState: const LocalSetupState(
          createSystemIds: {'nes'},
          createBasePath: '/roms',
        ),
      );
      c.localSetupBack();
      expect(c.state.currentStep, OnboardingStep.localSetup);
      expect(c.state.localSetupState!.createSystemIds, isNull);
      expect(c.state.localSetupState!.createBasePath, isNull);
      expect(c.state.localSetupState!.isChoicePhase, true);
    });

    test('localSetupBack from resultsPhase → choice (preserves detectedPath)',
        () {
      final c = _createController();
      c.state = c.state.copyWith(
        currentStep: OnboardingStep.localSetup,
        localSetupState: const LocalSetupState(
          romBasePath: '/roms',
          scannedFolders: [ScannedFolder(name: 'NES', fileCount: 5)],
          detectedPath: '/storage/emulated/0/ROMs',
        ),
      );
      c.localSetupBack();
      expect(c.state.currentStep, OnboardingStep.localSetup);
      expect(c.state.localSetupState!.scannedFolders, isNull);
      expect(c.state.localSetupState!.romBasePath, isNull);
      expect(
        c.state.localSetupState!.detectedPath,
        '/storage/emulated/0/ROMs',
      );
      expect(c.state.localSetupState!.isChoicePhase, true);
    });

    test('localSetupBack from choicePhase → previousStep', () {
      final c = _createController();
      c.state = c.state.copyWith(
        currentStep: OnboardingStep.localSetup,
        localSetupState: const LocalSetupState(),
      );
      c.localSetupBack();
      expect(c.state.currentStep, OnboardingStep.rommSetup);
    });

    test('localSetupConfirm calls nextStep', () {
      final c = _createController();
      c.state = c.state.copyWith(
        currentStep: OnboardingStep.localSetup,
        localSetupState: const LocalSetupState(
          enabledSystemIds: {'nes'},
        ),
      );
      c.localSetupConfirm();
      expect(c.state.currentStep, OnboardingStep.consoleSetup);
    });

    test('toggleLocalSetupSystem adds and removes', () {
      final c = _createController();
      c.state = c.state.copyWith(
        localSetupState: const LocalSetupState(enabledSystemIds: {'nes'}),
      );
      c.toggleLocalSetupSystem('snes');
      expect(c.state.localSetupState!.enabledSystemIds, {'nes', 'snes'});
      c.toggleLocalSetupSystem('nes');
      expect(c.state.localSetupState!.enabledSystemIds, {'snes'});
    });

    test('assignLocalFolder adds assignment', () {
      final c = _createController();
      c.state = c.state.copyWith(
        localSetupState: const LocalSetupState(),
      );
      c.assignLocalFolder('NES_folder', 'nes');
      expect(c.state.localSetupState!.folderAssignments['nes'], 'NES_folder');
    });

    test('assignLocalFolder replaces previous assignment', () {
      final c = _createController();
      c.state = c.state.copyWith(
        localSetupState: const LocalSetupState(
          folderAssignments: {'nes': 'Old_NES'},
        ),
      );
      c.assignLocalFolder('New_NES', 'nes');
      expect(c.state.localSetupState!.folderAssignments['nes'], 'New_NES');
    });
  });

  // =========================================================================
  // 14. RomM Folder Methods
  // =========================================================================
  group('RomM folder methods', () {
    test('rommFolderChoice(false) clears folder state and calls nextStep', () {
      final c = _createController();
      c.state = c.state.copyWith(
        currentStep: OnboardingStep.rommSetup,
        rommSetupState: const RommSetupState(
          subStep: RommSetupSubStep.folder,
          romBasePath: '/old/path',
          scannedFolders: [ScannedFolder(name: 'NES', fileCount: 5)],
          selectedSystemIds: {'nes'},
          systemMatches: {'nes': _testPlatformNes},
          url: 'https://romm.example.com',
        ),
      );
      c.rommFolderChoice(false);
      // Should have cleared folder state and advanced to consoleSetup
      expect(c.state.currentStep, OnboardingStep.consoleSetup);
    });

    test('assignFolderToSystem adds assignment', () {
      final c = _createController();
      c.state = c.state.copyWith(
        rommSetupState: const RommSetupState(),
      );
      c.assignFolderToSystem('NES_folder', 'nes');
      expect(
        c.state.rommSetupState!.folderAssignments['nes'],
        'NES_folder',
      );
    });

    test('assignFolderToSystem replaces previous assignment for same system',
        () {
      final c = _createController();
      c.state = c.state.copyWith(
        rommSetupState: const RommSetupState(
          folderAssignments: {'nes': 'Old_Folder'},
        ),
      );
      c.assignFolderToSystem('New_Folder', 'nes');
      expect(c.state.rommSetupState!.folderAssignments['nes'], 'New_Folder');
      // Old_Folder assignment should be gone
      expect(
        c.state.rommSetupState!.folderAssignments.values.contains('Old_Folder'),
        false,
      );
    });

    test('unassignFolder removes assignment', () {
      final c = _createController();
      c.state = c.state.copyWith(
        rommSetupState: const RommSetupState(
          folderAssignments: {'nes': 'NES_folder', 'snes': 'SNES_folder'},
        ),
      );
      c.unassignFolder('NES_folder');
      expect(c.state.rommSetupState!.folderAssignments.containsKey('nes'), false);
      expect(
        c.state.rommSetupState!.folderAssignments['snes'],
        'SNES_folder',
      );
    });

    test('rommFolderConfirm calls nextStep', () {
      final c = _createController();
      c.state = c.state.copyWith(
        currentStep: OnboardingStep.rommSetup,
        rommSetupState: const RommSetupState(
          subStep: RommSetupSubStep.folder,
          selectedSystemIds: {'nes'},
          systemMatches: {'nes': _testPlatformNes},
          url: 'https://romm.example.com',
        ),
      );
      c.rommFolderConfirm();
      expect(c.state.currentStep, OnboardingStep.consoleSetup);
    });
  });

  // =========================================================================
  // 15. Build Final Config / Export
  // =========================================================================
  group('Build final config / export', () {
    test('buildFinalConfig returns AppConfig with version 2 and all systems',
        () {
      final c = _createController();
      c.state = c.state.copyWith(
        configuredSystems: {
          'nes': _systemConfig('nes'),
          'snes': _systemConfig('snes'),
        },
      );
      final config = c.buildFinalConfig();
      expect(config.version, 2);
      expect(config.systems.length, 2);
      expect(config.systems.any((s) => s.id == 'nes'), true);
      expect(config.systems.any((s) => s.id == 'snes'), true);
    });

    test('exportConfig calls ConfigStorageService.exportConfig', () async {
      final storage = FakeConfigStorageService();
      final c = OnboardingController(storage);
      c.state = c.state.copyWith(
        configuredSystems: {'nes': _systemConfig('nes')},
      );
      await c.exportConfig();
      expect(storage.lastExportedConfig, isNotNull);
      expect(storage.lastExportedConfig!.systems.length, 1);
      expect(storage.lastExportedConfig!.systems[0].id, 'nes');
    });

    test('buildFinalConfig with empty systems returns empty list', () {
      final c = _createController();
      final config = c.buildFinalConfig();
      expect(config.version, 2);
      expect(config.systems, isEmpty);
    });
  });

  // =========================================================================
  // 16. OnboardingState getters
  // =========================================================================
  group('OnboardingState getters', () {
    test('isFirstStep / isLastStep', () {
      expect(const OnboardingState().isFirstStep, true);
      expect(const OnboardingState().isLastStep, false);
      expect(
        const OnboardingState(currentStep: OnboardingStep.complete).isLastStep,
        true,
      );
    });

    test('hasConsoleSelected', () {
      expect(const OnboardingState().hasConsoleSelected, false);
      expect(
        const OnboardingState(selectedConsoleId: 'nes').hasConsoleSelected,
        true,
      );
    });

    test('hasProviderForm', () {
      expect(const OnboardingState().hasProviderForm, false);
      expect(
        const OnboardingState(providerForm: ProviderFormState())
            .hasProviderForm,
        true,
      );
    });

    test('configuredCount', () {
      final c = _createController();
      expect(c.state.configuredCount, 0);
      c.state = c.state.copyWith(
        configuredSystems: {'nes': _systemConfig('nes')},
      );
      expect(c.state.configuredCount, 1);
    });

    test('rommSelectedSystemIds delegates to rommSetupState', () {
      expect(const OnboardingState().rommSelectedSystemIds, isEmpty);
      expect(
        const OnboardingState(
          rommSetupState: RommSetupState(selectedSystemIds: {'nes'}),
        ).rommSelectedSystemIds,
        {'nes'},
      );
    });

    test('rommSystemMatches delegates to rommSetupState', () {
      expect(const OnboardingState().rommSystemMatches, isEmpty);
      expect(
        const OnboardingState(
          rommSetupState: RommSetupState(
            systemMatches: {'nes': _testPlatformNes},
          ),
        ).rommSystemMatches,
        {'nes': _testPlatformNes},
      );
    });

    test('localOnlySystemIds delegates to rommSetupState', () {
      expect(const OnboardingState().localOnlySystemIds, isEmpty);
      expect(
        const OnboardingState(
          rommSetupState: RommSetupState(localOnlySystemIds: {'gb'}),
        ).localOnlySystemIds,
        {'gb'},
      );
    });

    test('selectedSystem looks up from SystemModel.supportedSystems', () {
      expect(const OnboardingState().selectedSystem, isNull);
      final state = const OnboardingState(selectedConsoleId: 'nes');
      expect(state.selectedSystem, isNotNull);
      expect(state.selectedSystem!.id, 'nes');
    });

    test('selectedSystem returns null for unknown ID', () {
      final state = const OnboardingState(selectedConsoleId: 'unknown_xyz');
      expect(state.selectedSystem, isNull);
    });

    test('hasRommPlatformSelected', () {
      expect(const OnboardingState().hasRommPlatformSelected, false);
      expect(
        const OnboardingState(rommMatchedPlatform: _testPlatformNes)
            .hasRommPlatformSelected,
        true,
      );
    });
  });

  // =========================================================================
  // 17. RommSetupState
  // =========================================================================
  group('RommSetupState', () {
    test('hasConnection checks url not empty', () {
      expect(const RommSetupState().hasConnection, false);
      expect(const RommSetupState(url: '   ').hasConnection, false);
      expect(
        const RommSetupState(url: 'https://romm.com').hasConnection,
        true,
      );
    });

    test('authConfig builds correctly', () {
      const rs = RommSetupState(
        apiKey: 'key123',
        user: 'admin',
        pass: 'secret',
      );
      final auth = rs.authConfig;
      expect(auth, isNotNull);
      expect(auth!.apiKey, 'key123');
      expect(auth.user, 'admin');
      expect(auth.pass, 'secret');
    });

    test('authConfig returns null when all fields empty', () {
      expect(const RommSetupState().authConfig, isNull);
      expect(const RommSetupState(apiKey: '  ', user: '').authConfig, isNull);
    });

    test('matchedCount / selectedCount / localOnlyCount', () {
      const rs = RommSetupState(
        systemMatches: {'nes': _testPlatformNes, 'snes': _testPlatformSnes},
        selectedSystemIds: {'nes'},
        localOnlySystemIds: {'gb', 'gbc'},
      );
      expect(rs.matchedCount, 2);
      expect(rs.selectedCount, 1);
      expect(rs.localOnlyCount, 2);
    });
  });

  // =========================================================================
  // 18. LocalSetupState phases
  // =========================================================================
  group('LocalSetupState phases', () {
    test('isChoicePhase when no scan/create state', () {
      const ls = LocalSetupState();
      expect(ls.isChoicePhase, true);
      expect(ls.isScanningPhase, false);
      expect(ls.isResultsPhase, false);
      expect(ls.isCreatePhase, false);
    });

    test('isScanningPhase when isScanning', () {
      const ls = LocalSetupState(isScanning: true);
      expect(ls.isChoicePhase, false);
      expect(ls.isScanningPhase, true);
    });

    test('isResultsPhase when scannedFolders set and not scanning', () {
      const ls = LocalSetupState(
        scannedFolders: [ScannedFolder(name: 'NES', fileCount: 5)],
      );
      expect(ls.isResultsPhase, true);
      expect(ls.isChoicePhase, false);
    });

    test('isCreatePhase when createSystemIds set', () {
      const ls = LocalSetupState(createSystemIds: {'nes'});
      expect(ls.isCreatePhase, true);
      expect(ls.isChoicePhase, false);
    });
  });

  // =========================================================================
  // 19. ConsoleSetupState
  // =========================================================================
  group('ConsoleSetupState', () {
    test('isComplete checks targetFolder', () {
      expect(const ConsoleSetupState().isComplete, false);
      expect(
        const ConsoleSetupState(targetFolder: '/roms/nes').isComplete,
        true,
      );
    });
  });

  // =========================================================================
  // 20. ProviderFormState
  // =========================================================================
  group('ProviderFormState', () {
    test('isEditing checks editingIndex', () {
      expect(const ProviderFormState().isEditing, false);
      expect(const ProviderFormState(editingIndex: 0).isEditing, true);
    });
  });
}
