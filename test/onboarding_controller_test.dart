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
}) {
  final system = SystemModel.supportedSystems.firstWhere((s) => s.id == id);
  return SystemConfig(
    id: id,
    name: system.name,
    targetFolder: targetFolder ?? '/roms/$id',
    providers: providers,
    autoExtract: autoExtract,
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
  // 2. Console Selection
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
      expect(c.state.consoleSubState!.providers.length, 1);
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

  });

  // =========================================================================
  // 3. Provider Form
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
  // 4. canTest getter
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
  // 5. saveProvider
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
  // 6. Provider List Management
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
  // 7. Console Config Save/Remove
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
  // 8. Build Final Config / Export
  // =========================================================================
  group('Build final config / export', () {
    test('buildFinalConfig returns AppConfig and includes all systems',
        () async {
      final c = _createController();
      c.state = c.state.copyWith(
        configuredSystems: {
          'nes': _systemConfig('nes'),
          'snes': _systemConfig('snes'),
        },
      );
      final config = await c.buildFinalConfig();
      expect(config.version, AppConfig.currentVersion);
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

    test('buildFinalConfig with empty systems returns empty list', () async {
      final c = _createController();
      final config = await c.buildFinalConfig();
      expect(config.version, AppConfig.currentVersion);
      expect(config.systems, isEmpty);
    });
  });

  // =========================================================================
  // 9. OnboardingState getters
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
  // 10. ConsoleSetupState
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
  // 11. ProviderFormState
  // =========================================================================
  group('ProviderFormState', () {
    test('isEditing checks editingIndex', () {
      expect(const ProviderFormState().isEditing, false);
      expect(const ProviderFormState(editingIndex: 0).isEditing, true);
    });
  });
}
