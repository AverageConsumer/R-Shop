import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/config/app_config.dart';
import '../../models/config/provider_config.dart';
import '../../models/config/system_config.dart';
import '../../models/system_model.dart';
import '../../services/config_storage_service.dart';
import '../../services/provider_factory.dart';
import '../../services/romm_api_service.dart';
import '../../services/romm_platform_matcher.dart';

enum OnboardingStep {
  welcome,
  legalNotice,
  consoleSetup,
  complete,
}

enum ConsoleSubStep {
  folder,
  options,
  providers,
}

class ProviderFormState {
  final ProviderType type;
  final Map<String, dynamic> fields;
  final int? editingIndex;

  const ProviderFormState({
    this.type = ProviderType.web,
    this.fields = const {},
    this.editingIndex,
  });

  ProviderFormState copyWith({
    ProviderType? type,
    Map<String, dynamic>? fields,
    int? editingIndex,
    bool clearEditingIndex = false,
  }) {
    return ProviderFormState(
      type: type ?? this.type,
      fields: fields ?? this.fields,
      editingIndex: clearEditingIndex ? null : (editingIndex ?? this.editingIndex),
    );
  }

  bool get isEditing => editingIndex != null;
}

class ConsoleSetupState {
  final String? targetFolder;
  final bool autoExtract;
  final bool mergeMode;
  final List<ProviderConfig> providers;

  const ConsoleSetupState({
    this.targetFolder,
    this.autoExtract = false,
    this.mergeMode = false,
    this.providers = const [],
  });

  ConsoleSetupState copyWith({
    String? targetFolder,
    bool? autoExtract,
    bool? mergeMode,
    List<ProviderConfig>? providers,
  }) {
    return ConsoleSetupState(
      targetFolder: targetFolder ?? this.targetFolder,
      autoExtract: autoExtract ?? this.autoExtract,
      mergeMode: mergeMode ?? this.mergeMode,
      providers: providers ?? this.providers,
    );
  }

  bool get isComplete => targetFolder != null && providers.isNotEmpty;
}

class OnboardingState {
  final OnboardingStep currentStep;
  final Map<String, SystemConfig> configuredSystems;
  final String? selectedConsoleId;
  final ConsoleSetupState? consoleSubState;
  final ProviderFormState? providerForm;
  final bool isTestingConnection;
  final String? connectionTestError;
  final bool connectionTestSuccess;
  final bool canProceed;
  final List<RommPlatform>? rommPlatforms;
  final RommPlatform? rommMatchedPlatform;
  final String? rommFetchError;
  final bool isFetchingRommPlatforms;

  const OnboardingState({
    this.currentStep = OnboardingStep.welcome,
    this.configuredSystems = const {},
    this.selectedConsoleId,
    this.consoleSubState,
    this.providerForm,
    this.isTestingConnection = false,
    this.connectionTestError,
    this.connectionTestSuccess = false,
    this.canProceed = false,
    this.rommPlatforms,
    this.rommMatchedPlatform,
    this.rommFetchError,
    this.isFetchingRommPlatforms = false,
  });

  OnboardingState copyWith({
    OnboardingStep? currentStep,
    Map<String, SystemConfig>? configuredSystems,
    String? selectedConsoleId,
    ConsoleSetupState? consoleSubState,
    ProviderFormState? providerForm,
    bool? isTestingConnection,
    String? connectionTestError,
    bool? connectionTestSuccess,
    bool? canProceed,
    List<RommPlatform>? rommPlatforms,
    RommPlatform? rommMatchedPlatform,
    String? rommFetchError,
    bool? isFetchingRommPlatforms,
    bool clearSelectedConsole = false,
    bool clearConsoleSubState = false,
    bool clearProviderForm = false,
    bool clearConnectionError = false,
    bool clearRommState = false,
  }) {
    return OnboardingState(
      currentStep: currentStep ?? this.currentStep,
      configuredSystems: configuredSystems ?? this.configuredSystems,
      selectedConsoleId: clearSelectedConsole ? null : (selectedConsoleId ?? this.selectedConsoleId),
      consoleSubState: clearConsoleSubState ? null : (consoleSubState ?? this.consoleSubState),
      providerForm: clearProviderForm ? null : (providerForm ?? this.providerForm),
      isTestingConnection: isTestingConnection ?? this.isTestingConnection,
      connectionTestError: clearConnectionError ? null : (connectionTestError ?? this.connectionTestError),
      connectionTestSuccess: connectionTestSuccess ?? this.connectionTestSuccess,
      canProceed: canProceed ?? this.canProceed,
      rommPlatforms: clearRommState ? null : (rommPlatforms ?? this.rommPlatforms),
      rommMatchedPlatform: clearRommState ? null : (rommMatchedPlatform ?? this.rommMatchedPlatform),
      rommFetchError: clearRommState ? null : (rommFetchError ?? this.rommFetchError),
      isFetchingRommPlatforms: isFetchingRommPlatforms ?? this.isFetchingRommPlatforms,
    );
  }

  bool get isFirstStep => currentStep == OnboardingStep.welcome;
  bool get isLastStep => currentStep == OnboardingStep.complete;
  bool get hasConsoleSelected => selectedConsoleId != null;
  bool get hasProviderForm => providerForm != null;
  int get configuredCount => configuredSystems.length;
  bool get hasRommPlatformSelected => rommMatchedPlatform != null;

  SystemModel? get selectedSystem {
    if (selectedConsoleId == null) return null;
    try {
      return SystemModel.supportedSystems.firstWhere(
        (s) => s.esdeFolder == selectedConsoleId,
      );
    } catch (_) {
      return null;
    }
  }
}

class OnboardingController extends StateNotifier<OnboardingState> {
  OnboardingController() : super(const OnboardingState());

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

  // --- Step navigation ---

  void nextStep() {
    final steps = OnboardingStep.values;
    final currentIndex = steps.indexOf(state.currentStep);
    if (currentIndex < steps.length - 1) {
      state = state.copyWith(
        currentStep: steps[currentIndex + 1],
        canProceed: false,
      );
    }
  }

  void previousStep() {
    final steps = OnboardingStep.values;
    final currentIndex = steps.indexOf(state.currentStep);
    if (currentIndex > 0) {
      state = state.copyWith(currentStep: steps[currentIndex - 1]);
    }
  }

  void onMessageComplete() {
    state = state.copyWith(canProceed: true);
  }

  // --- Console selection ---

  void selectConsole(String id) {
    final existing = state.configuredSystems[id];
    final system = SystemModel.supportedSystems.firstWhere(
      (s) => s.esdeFolder == id,
    );

    final subState = existing != null
        ? ConsoleSetupState(
            targetFolder: existing.targetFolder,
            autoExtract: existing.autoExtract,
            mergeMode: existing.mergeMode,
            providers: List.of(existing.providers),
          )
        : ConsoleSetupState(
            autoExtract: system.isZipped,
          );

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

  // --- Console config fields ---

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

  void setMergeMode(bool value) {
    final sub = state.consoleSubState;
    if (sub == null) return;
    state = state.copyWith(consoleSubState: sub.copyWith(mergeMode: value));
  }

  // --- Provider form ---

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
    state = state.copyWith(
      providerForm: form.copyWith(type: type, fields: {}),
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
    if ((user != null && user.isNotEmpty) ||
        (pass != null && pass.isNotEmpty) ||
        (apiKey != null && apiKey.isNotEmpty)) {
      auth = AuthConfig(
        user: user?.isNotEmpty == true ? user : null,
        pass: pass?.isNotEmpty == true ? pass : null,
        apiKey: apiKey?.isNotEmpty == true ? apiKey : null,
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

  Future<void> testProviderConnection() async {
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
      final esdeFolder = state.selectedConsoleId;
      RommPlatform? matched;
      if (esdeFolder != null) {
        matched = RommPlatformMatcher.findMatch(esdeFolder, platforms);
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

  // --- Save / remove console config ---

  void saveConsoleConfig() {
    final id = state.selectedConsoleId;
    final sub = state.consoleSubState;
    if (id == null || sub == null || !sub.isComplete) return;

    final system = SystemModel.supportedSystems.firstWhere(
      (s) => s.esdeFolder == id,
    );

    final config = SystemConfig(
      id: id,
      name: system.name,
      targetFolder: sub.targetFolder!,
      providers: sub.providers,
      autoExtract: sub.autoExtract,
      mergeMode: sub.mergeMode,
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

  // --- Build final config ---

  AppConfig buildFinalConfig() {
    return AppConfig(
      version: 2,
      systems: state.configuredSystems.values.toList(),
    );
  }

  Future<void> exportConfig() async {
    final config = buildFinalConfig();
    await ConfigStorageService().exportConfig(config);
  }
}

final onboardingControllerProvider =
    StateNotifierProvider<OnboardingController, OnboardingState>((ref) {
  return OnboardingController();
});
