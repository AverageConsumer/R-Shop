import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/config/app_config.dart';
import '../../models/config/provider_config.dart';
import '../../models/config/source.dart';
import '../../models/config/system_config.dart';
import '../../models/system_model.dart';
import '../../providers/app_providers.dart';
import '../../services/config_storage_service.dart';
import '../../services/local_folder_matcher.dart';
import '../../services/provider_factory.dart';
import '../../services/rom_folder_service.dart';
import '../../services/romm_api_service.dart';
import '../../services/romm_platform_matcher.dart';
import '../../services/sources_notifier.dart';

import 'onboarding_state.dart';
export 'onboarding_state.dart';

class OnboardingController extends StateNotifier<OnboardingState> {
  final ConfigStorageService _configStorage;

  OnboardingController(this._configStorage) : super(const OnboardingState());

  /// Default ROM base path used by the welcome chooser shortcuts. Each
  /// auto-created system gets `<base>/<systemId>` so the user has working
  /// download targets without going through the full local-folder picker.
  static const String _welcomeChooserDefaultBase =
      '/storage/emulated/0/ROMs';

  // ---------------------------------------------------------------------------
  // Welcome chooser paths
  // ---------------------------------------------------------------------------

  /// Welcome chooser shared step: scan [basePath] for ROM subfolders and
  /// create a SystemConfig for every match that actually contains files.
  /// Used as the first step of every chooser path so the user always
  /// gets their local games surfaced — RomM/Server pairing then layers
  /// remote sources on top of these baseline systems.
  Future<void> seedLocalSystemsFromBase(String basePath) async {
    try {
      final service = RomFolderService();
      final subfolders = await service.scanAllSubfolders(basePath);
      final updated = Map<String, SystemConfig>.from(state.configuredSystems);
      for (final folder in subfolders) {
        if (folder.fileCount == 0) continue;
        final matchedId = LocalFolderMatcher.matchFolder(
          folder.name,
          SystemModel.supportedSystems,
          const [],
        );
        if (matchedId == null) continue;
        if (updated.containsKey(matchedId)) continue;
        final model = SystemModel.supportedSystems
            .where((s) => s.id == matchedId)
            .firstOrNull;
        if (model == null) continue;
        updated[matchedId] = SystemConfig(
          id: matchedId,
          name: model.name,
          targetFolder: '$basePath/${folder.name}',
          providers: const [],
          autoExtract: model.isZipped,
        );
      }
      state = state.copyWith(configuredSystems: updated);
    } catch (e) {
      debugPrint('seedLocalSystemsFromBase: $e');
    }
  }

  /// Welcome chooser → "Pair RomM" path. Persists [source] (already
  /// exchanged + platform-discovered) and creates a SystemConfig for
  /// every advertised platform so the home screen has consoles to show.
  /// Then jumps straight to the complete step.
  Future<void> completeFromRommPairing({
    required SourcesNotifier sourcesNotifier,
    required Source source,
    String? basePath,
  }) async {
    await sourcesNotifier.addSource(source);
    final base = basePath ?? _welcomeChooserDefaultBase;
    final updated = Map<String, SystemConfig>.from(state.configuredSystems);
    for (final systemId in source.knownPlatforms.keys) {
      if (updated.containsKey(systemId)) continue;
      final model = SystemModel.supportedSystems
          .where((s) => s.id == systemId)
          .firstOrNull;
      if (model == null) continue;
      updated[systemId] = SystemConfig(
        id: systemId,
        name: model.name,
        targetFolder: '$base/$systemId',
        providers: const [],
        autoExtract: model.isZipped,
      );
    }
    state = state.copyWith(
      configuredSystems: updated,
      currentStep: OnboardingStep.complete,
      canProceed: true,
    );
  }

  /// Welcome chooser → "Add server" path. The source + mappings have
  /// already been persisted by [ManualSourceAddScreen]/[SourceMappingsScreen]
  /// via SourcesNotifier. We only need to create matching SystemConfigs
  /// for the systems the user mapped, so the home screen knows about
  /// them. The actual provider list will be filled in by the next
  /// SourcesNotifier rebuild — we don't need to set it here.
  Future<void> completeFromManualSource({
    required String sourceId,
    required Iterable<String> mappedSystemIds,
    String? basePath,
  }) async {
    final base = basePath ?? _welcomeChooserDefaultBase;
    final updated = Map<String, SystemConfig>.from(state.configuredSystems);
    for (final systemId in mappedSystemIds) {
      if (updated.containsKey(systemId)) continue;
      final model = SystemModel.supportedSystems
          .where((s) => s.id == systemId)
          .firstOrNull;
      if (model == null) continue;
      updated[systemId] = SystemConfig(
        id: systemId,
        name: model.name,
        targetFolder: '$base/$systemId',
        providers: const [],
        autoExtract: model.isZipped,
      );
    }
    state = state.copyWith(
      configuredSystems: updated,
      currentStep: OnboardingStep.complete,
      canProceed: true,
    );
  }

  /// Welcome chooser → "Local games only" path. Seeds SystemConfigs from
  /// the picked base folder (handled by [seedLocalSystemsFromBase] before
  /// this is called) and jumps straight to the complete step. No legacy
  /// linear local-setup screens — the chooser is the whole flow.
  void completeFromLocalOnly({required String basePath}) {
    state = state.copyWith(
      currentStep: OnboardingStep.complete,
      canProceed: true,
    );
  }

  /// Pre-initializes the controller from an existing config (for config mode).
  void loadFromConfig(AppConfig config) {
    final systems = <String, SystemConfig>{};
    for (final system in config.systems) {
      systems[system.id] = system;
    }
    state = state.copyWith(
      configuredSystems: systems,
      currentStep: OnboardingStep.consoleSetup,
      canProceed: true,
    );
  }

  // ---------------------------------------------------------------------------
  // Chat bubble callback
  // ---------------------------------------------------------------------------

  void onMessageComplete() {
    state = state.copyWith(canProceed: true);
  }

  // ---------------------------------------------------------------------------
  // Console selection (used by ConsoleSetupStep in config mode)
  // ---------------------------------------------------------------------------

  void selectConsole(String id) {
    final existing = state.configuredSystems[id];
    final system = SystemModel.supportedSystems.firstWhere(
      (s) => s.id == id,
    );

    ConsoleSetupState subState;
    if (existing != null) {
      subState = ConsoleSetupState(
        targetFolder: existing.targetFolder,
        autoExtract: existing.autoExtract,
        autoSync: existing.autoSync,
        providers: List.of(existing.providers),
      );
    } else {
      subState = ConsoleSetupState(
        autoExtract: system.isZipped,
      );
    }

    state = state.copyWith(
      selectedConsoleId: id,
      consoleSubState: subState,
    );
  }

  void deselectConsole() {
    state = state.copyWith(
      clearSelectedConsole: true,
      clearConsoleSubState: true,
      clearProviderForm: true,
    );
  }

  // ---------------------------------------------------------------------------
  // Console config fields
  // ---------------------------------------------------------------------------

  void setTargetFolder(String path) {
    final sub = state.consoleSubState;
    if (sub == null) return;
    state = state.copyWith(consoleSubState: sub.copyWith(targetFolder: path));
  }

  void setAutoExtract(bool value) {
    final sub = state.consoleSubState;
    if (sub == null) return;
    state = state.copyWith(consoleSubState: sub.copyWith(autoExtract: value));
  }

  void setAutoSync(bool value) {
    final sub = state.consoleSubState;
    if (sub == null) return;
    state = state.copyWith(consoleSubState: sub.copyWith(autoSync: value));
  }

  // ---------------------------------------------------------------------------
  // Provider form
  // ---------------------------------------------------------------------------

  void startAddProvider() {
    state = state.copyWith(
      providerForm: const ProviderFormState(),
      clearConnectionError: true,
      connectionTestSuccess: false,
    );
  }

  void startEditProvider(int index) {
    final sub = state.consoleSubState;
    if (sub == null || index >= sub.providers.length) return;

    final provider = sub.providers[index];
    final fields = <String, dynamic>{};

    if (provider.url != null) fields['url'] = provider.url;
    if (provider.host != null) fields['host'] = provider.host;
    if (provider.port != null) fields['port'] = provider.port;
    if (provider.share != null) fields['share'] = provider.share;
    if (provider.path != null) fields['path'] = provider.path;
    if (provider.auth?.user != null) fields['user'] = provider.auth!.user;
    if (provider.auth?.pass != null) fields['pass'] = provider.auth!.pass;
    if (provider.auth?.apiKey != null) fields['apiKey'] = provider.auth!.apiKey;
    if (provider.auth?.domain != null) fields['domain'] = provider.auth!.domain;

    // Restore RomM platform selection when editing
    RommPlatform? restoredPlatform;
    if (provider.type == ProviderType.romm &&
        provider.platformId != null &&
        provider.platformName != null) {
      restoredPlatform = RommPlatform(
        id: provider.platformId!,
        slug: '',
        fsSlug: '',
        name: provider.platformName!,
        romCount: 0,
      );
    }

    state = state.copyWith(
      providerForm: ProviderFormState(
        type: provider.type,
        fields: fields,
        editingIndex: index,
      ),
      clearConnectionError: true,
      connectionTestSuccess: false,
      rommMatchedPlatform: restoredPlatform,
    );
  }

  void cancelProviderForm() {
    state = state.copyWith(
      clearProviderForm: true,
      clearConnectionError: true,
      connectionTestSuccess: false,
      clearRommState: true,
    );
  }

  void setProviderType(ProviderType type) {
    final form = state.providerForm;
    if (form == null) return;

    // Save current fields before switching
    final saved = Map<ProviderType, Map<String, dynamic>>.from(form.savedFieldsByType);
    saved[form.type] = Map<String, dynamic>.from(form.fields);

    // Restore saved fields for the new type, or use defaults
    final restored = saved[type] ?? <String, dynamic>{};
    final newFields = Map<String, dynamic>.from(restored);
    if (newFields.isEmpty) {
      if (type == ProviderType.smb) {
        newFields['port'] = '445';
      } else if (type == ProviderType.ftp) {
        newFields['port'] = '21';
      }
    }

    state = state.copyWith(
      providerForm: form.copyWith(
        type: type,
        fields: newFields,
        savedFieldsByType: saved,
      ),
      clearConnectionError: true,
      connectionTestSuccess: false,
      clearRommState: true,
    );
  }

  void updateProviderField(String key, dynamic value) {
    final form = state.providerForm;
    if (form == null) return;
    final newFields = Map<String, dynamic>.from(form.fields);
    newFields[key] = value;
    state = state.copyWith(
      providerForm: form.copyWith(fields: newFields),
      clearConnectionError: true,
      connectionTestSuccess: false,
    );
  }

  ProviderConfig? _buildProviderFromForm({required int priority}) {
    final form = state.providerForm;
    if (form == null) return null;

    AuthConfig? auth;
    final user = form.fields['user'] as String?;
    final pass = form.fields['pass'] as String?;
    final apiKey = form.fields['apiKey'] as String?;
    final domain = form.fields['domain'] as String?;
    if ((user != null && user.isNotEmpty) ||
        (pass != null && pass.isNotEmpty) ||
        (apiKey != null && apiKey.isNotEmpty) ||
        (domain != null && domain.isNotEmpty)) {
      auth = AuthConfig(
        user: user?.isNotEmpty == true ? user : null,
        pass: pass?.isNotEmpty == true ? pass : null,
        apiKey: apiKey?.isNotEmpty == true ? apiKey : null,
        domain: domain?.isNotEmpty == true ? domain : null,
      );
    }

    int? platformId;
    String? platformName;
    if (form.type == ProviderType.romm && state.rommMatchedPlatform != null) {
      platformId = state.rommMatchedPlatform!.id;
      platformName = state.rommMatchedPlatform!.name;
    }

    return ProviderConfig(
      type: form.type,
      priority: priority,
      url: form.fields['url'] as String?,
      host: form.fields['host'] as String?,
      port: form.fields['port'] is int
          ? form.fields['port'] as int
          : int.tryParse('${form.fields['port'] ?? ''}'),
      share: form.fields['share'] as String?,
      path: form.fields['path'] as String?,
      auth: auth,
      platformId: platformId,
      platformName: platformName,
    );
  }

  // ---------------------------------------------------------------------------
  // Connection testing
  // ---------------------------------------------------------------------------

  Future<void> testProviderConnection() async {
    if (!state.canTest) return;
    final form = state.providerForm;
    if (form == null) return;

    // For RomM, use dedicated platform fetch flow
    if (form.type == ProviderType.romm) {
      await _testRommConnection();
      return;
    }

    final config = _buildProviderFromForm(priority: 0);
    if (config == null) return;

    state = state.copyWith(
      isTestingConnection: true,
      clearConnectionError: true,
      connectionTestSuccess: false,
    );

    try {
      final provider = ProviderFactory.getProvider(config);
      final result = await provider.testConnection();

      if (!mounted) return;

      if (result.success) {
        state = state.copyWith(
          isTestingConnection: false,
          connectionTestSuccess: true,
        );
      } else {
        state = state.copyWith(
          isTestingConnection: false,
          connectionTestError: result.error ?? 'Connection failed',
        );
      }
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isTestingConnection: false,
        connectionTestError: e.toString(),
      );
    }
  }

  Future<void> _testRommConnection() async {
    final form = state.providerForm;
    if (form == null) return;

    final url = form.fields['url'] as String?;
    if (url == null || url.isEmpty) return;

    final apiKey = form.fields['apiKey'] as String?;
    final user = form.fields['user'] as String?;
    final pass = form.fields['pass'] as String?;

    AuthConfig? auth;
    if ((apiKey != null && apiKey.isNotEmpty) ||
        (user != null && user.isNotEmpty)) {
      auth = AuthConfig(
        apiKey: apiKey?.isNotEmpty == true ? apiKey : null,
        user: user?.isNotEmpty == true ? user : null,
        pass: pass?.isNotEmpty == true ? pass : null,
      );
    }

    state = state.copyWith(
      isTestingConnection: true,
      isFetchingRommPlatforms: true,
      clearConnectionError: true,
      connectionTestSuccess: false,
      clearRommState: true,
    );

    try {
      final api = RommApiService();
      final platforms = await api.fetchPlatforms(url, auth: auth);

      if (!mounted) return;

      // Try auto-match
      final systemId = state.selectedConsoleId;
      RommPlatform? matched;
      if (systemId != null) {
        matched = RommPlatformMatcher.findMatch(systemId, platforms);
      }

      state = state.copyWith(
        isTestingConnection: false,
        isFetchingRommPlatforms: false,
        connectionTestSuccess: true,
        rommPlatforms: platforms,
        rommMatchedPlatform: matched,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isTestingConnection: false,
        isFetchingRommPlatforms: false,
        connectionTestError: e.toString(),
        rommFetchError: e.toString(),
      );
    }
  }

  void selectRommPlatform(RommPlatform platform) {
    state = state.copyWith(rommMatchedPlatform: platform);
  }

  void clearRommPlatform() {
    state = OnboardingState(
      currentStep: state.currentStep,
      configuredSystems: state.configuredSystems,
      selectedConsoleId: state.selectedConsoleId,
      consoleSubState: state.consoleSubState,
      providerForm: state.providerForm,
      isTestingConnection: state.isTestingConnection,
      connectionTestError: state.connectionTestError,
      connectionTestSuccess: state.connectionTestSuccess,
      canProceed: state.canProceed,
      rommPlatforms: state.rommPlatforms,
      rommMatchedPlatform: null,
      rommFetchError: state.rommFetchError,
      isFetchingRommPlatforms: state.isFetchingRommPlatforms,
    );
  }

  // ---------------------------------------------------------------------------
  // Test + save, save, remove, move providers
  // ---------------------------------------------------------------------------

  Future<void> testAndSaveProvider() async {
    if (state.connectionTestSuccess) {
      if (state.providerForm?.type == ProviderType.romm &&
          !state.hasRommPlatformSelected) {
        return;
      }
      saveProvider();
      return;
    }

    // Show missing fields instead of silently doing nothing
    if (!state.canTest) {
      final message = state.missingFieldsMessage;
      if (message != null) {
        state = state.copyWith(connectionTestError: message);
      }
      return;
    }

    await testProviderConnection();

    if (state.connectionTestSuccess) {
      if (state.providerForm?.type == ProviderType.romm &&
          !state.hasRommPlatformSelected) {
        return; // platform dropdown now visible, user picks, presses again
      }
      // Brief delay so the user sees the success indicator before closing
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      saveProvider();
    }
  }

  void saveProvider() {
    final form = state.providerForm;
    final sub = state.consoleSubState;
    if (form == null || sub == null) return;

    final providers = List<ProviderConfig>.from(sub.providers);

    if (form.isEditing) {
      final config = _buildProviderFromForm(priority: form.editingIndex!);
      if (config == null) return;
      providers[form.editingIndex!] = config;
    } else {
      final config = _buildProviderFromForm(priority: providers.length);
      if (config == null) return;
      providers.add(config);
    }

    state = state.copyWith(
      consoleSubState: sub.copyWith(providers: providers),
      clearProviderForm: true,
      clearConnectionError: true,
      connectionTestSuccess: false,
      clearRommState: true,
    );
  }

  void removeProvider(int index) {
    final sub = state.consoleSubState;
    if (sub == null) return;

    final providers = List<ProviderConfig>.from(sub.providers);
    if (index < providers.length) {
      providers.removeAt(index);
      // Re-index priorities
      for (var i = 0; i < providers.length; i++) {
        providers[i] = providers[i].copyWith(priority: i);
      }
    }

    state = state.copyWith(
      consoleSubState: sub.copyWith(providers: providers),
    );
  }

  void moveProvider(int fromIndex, int toIndex) {
    final sub = state.consoleSubState;
    if (sub == null) return;

    final providers = List<ProviderConfig>.from(sub.providers);
    if (fromIndex < 0 || fromIndex >= providers.length) return;
    if (toIndex < 0 || toIndex >= providers.length) return;

    final item = providers.removeAt(fromIndex);
    providers.insert(toIndex, item);

    // Re-index priorities
    for (var i = 0; i < providers.length; i++) {
      providers[i] = providers[i].copyWith(priority: i);
    }

    state = state.copyWith(
      consoleSubState: sub.copyWith(providers: providers),
    );
  }

  // ---------------------------------------------------------------------------
  // Save / remove console config
  // ---------------------------------------------------------------------------

  void saveConsoleConfig() {
    final id = state.selectedConsoleId;
    final sub = state.consoleSubState;
    if (id == null || sub == null || !sub.isComplete) return;

    final system = SystemModel.supportedSystems.firstWhere(
      (s) => s.id == id,
    );

    final config = SystemConfig(
      id: id,
      name: system.name,
      targetFolder: sub.targetFolder!,
      providers: sub.providers,
      autoExtract: sub.autoExtract,
      autoSync: sub.autoSync,
    );

    final updated = Map<String, SystemConfig>.from(state.configuredSystems);
    updated[id] = config;

    state = state.copyWith(
      configuredSystems: updated,
      clearSelectedConsole: true,
      clearConsoleSubState: true,
      clearProviderForm: true,
    );
  }

  void removeConsoleConfig(String id) {
    final updated = Map<String, SystemConfig>.from(state.configuredSystems);
    updated.remove(id);
    state = state.copyWith(configuredSystems: updated);
  }

  // ---------------------------------------------------------------------------
  // Build final config
  // ---------------------------------------------------------------------------

  /// Builds the final AppConfig that gets persisted at the end of
  /// onboarding. Reads any sources that were written to disk during the
  /// flow (e.g. by the welcome chooser → SourcesNotifier path) so the
  /// final save doesn't clobber them with an empty list.
  Future<AppConfig> buildFinalConfig() async {
    List<Source> existingSources = const [];
    try {
      final loaded = await _configStorage.loadConfig();
      if (loaded != null) existingSources = loaded.sources;
    } catch (e) {
      debugPrint('buildFinalConfig: failed to read existing sources: $e');
    }
    return AppConfig(
      version: AppConfig.currentVersion,
      systems: state.configuredSystems.values.toList(),
      sources: existingSources,
    );
  }

  Future<void> exportConfig() async {
    final config = await buildFinalConfig();
    await _configStorage.exportConfig(config);
  }
}

final onboardingControllerProvider =
    StateNotifierProvider<OnboardingController, OnboardingState>((ref) {
  return OnboardingController(ref.read(configStorageServiceProvider));
});
