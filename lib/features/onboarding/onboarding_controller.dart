import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/config/app_config.dart';
import '../../models/config/provider_config.dart';
import '../../models/config/system_config.dart';
import '../../models/system_model.dart';
import '../../services/config_storage_service.dart';
import '../../services/local_folder_matcher.dart';
import '../../services/provider_factory.dart';
import '../../services/rom_folder_service.dart';
import '../../services/romm_api_service.dart';
import '../../services/romm_platform_matcher.dart';

enum OnboardingStep {
  welcome,
  legalNotice,
  rommSetup,
  consoleSetup,
  complete,
}

enum ConsoleSubStep {
  folder,
  options,
  providers,
}

enum RommSetupSubStep { ask, connect, select, folder }

class ScannedFolder {
  final String name;
  final int fileCount;
  final String? autoMatchedSystemId;
  final bool isLocalOnly;

  const ScannedFolder({
    required this.name,
    required this.fileCount,
    this.autoMatchedSystemId,
    this.isLocalOnly = false,
  });
}

class RommSetupState {
  final RommSetupSubStep subStep;
  final String url;
  final String apiKey;
  final String user;
  final String pass;
  final List<RommPlatform> discoveredPlatforms;
  final Map<String, RommPlatform> systemMatches;
  final Set<String> selectedSystemIds;
  final String? romBasePath;
  final List<ScannedFolder>? scannedFolders;
  final Map<String, String> folderAssignments;
  final bool isScanning;
  final Set<String> localOnlySystemIds;

  const RommSetupState({
    this.subStep = RommSetupSubStep.ask,
    this.url = '',
    this.apiKey = '',
    this.user = '',
    this.pass = '',
    this.discoveredPlatforms = const [],
    this.systemMatches = const {},
    this.selectedSystemIds = const {},
    this.romBasePath,
    this.scannedFolders,
    this.folderAssignments = const {},
    this.isScanning = false,
    this.localOnlySystemIds = const {},
  });

  RommSetupState copyWith({
    RommSetupSubStep? subStep,
    String? url,
    String? apiKey,
    String? user,
    String? pass,
    List<RommPlatform>? discoveredPlatforms,
    Map<String, RommPlatform>? systemMatches,
    Set<String>? selectedSystemIds,
    String? romBasePath,
    List<ScannedFolder>? scannedFolders,
    Map<String, String>? folderAssignments,
    bool? isScanning,
    Set<String>? localOnlySystemIds,
    bool clearRomBasePath = false,
    bool clearScannedFolders = false,
  }) {
    return RommSetupState(
      subStep: subStep ?? this.subStep,
      url: url ?? this.url,
      apiKey: apiKey ?? this.apiKey,
      user: user ?? this.user,
      pass: pass ?? this.pass,
      discoveredPlatforms: discoveredPlatforms ?? this.discoveredPlatforms,
      systemMatches: systemMatches ?? this.systemMatches,
      selectedSystemIds: selectedSystemIds ?? this.selectedSystemIds,
      romBasePath: clearRomBasePath ? null : (romBasePath ?? this.romBasePath),
      scannedFolders: clearScannedFolders ? null : (scannedFolders ?? this.scannedFolders),
      folderAssignments: folderAssignments ?? this.folderAssignments,
      isScanning: isScanning ?? this.isScanning,
      localOnlySystemIds: localOnlySystemIds ?? this.localOnlySystemIds,
    );
  }

  bool get hasConnection => url.trim().isNotEmpty;
  int get matchedCount => systemMatches.length;
  int get selectedCount => selectedSystemIds.length;
  int get localOnlyCount => localOnlySystemIds.length;

  AuthConfig? get authConfig {
    final hasApiKey = apiKey.trim().isNotEmpty;
    final hasUser = user.trim().isNotEmpty;
    final hasPass = pass.trim().isNotEmpty;
    if (!hasApiKey && !hasUser && !hasPass) return null;
    return AuthConfig(
      apiKey: hasApiKey ? apiKey.trim() : null,
      user: hasUser ? user.trim() : null,
      pass: hasPass ? pass.trim() : null,
    );
  }
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

  bool get isComplete => targetFolder != null;
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
  final RommSetupState? rommSetupState;

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
    this.rommSetupState,
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
    RommSetupState? rommSetupState,
    bool clearSelectedConsole = false,
    bool clearConsoleSubState = false,
    bool clearProviderForm = false,
    bool clearConnectionError = false,
    bool clearRommState = false,
    bool clearRommSetupState = false,
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
      rommSetupState: clearRommSetupState ? null : (rommSetupState ?? this.rommSetupState),
    );
  }

  bool get isFirstStep => currentStep == OnboardingStep.welcome;
  bool get isLastStep => currentStep == OnboardingStep.complete;
  bool get hasConsoleSelected => selectedConsoleId != null;
  bool get hasProviderForm => providerForm != null;
  int get configuredCount => configuredSystems.length;
  bool get hasRommPlatformSelected => rommMatchedPlatform != null;

  Set<String> get rommSelectedSystemIds =>
      rommSetupState?.selectedSystemIds ?? const {};
  Map<String, RommPlatform> get rommSystemMatches =>
      rommSetupState?.systemMatches ?? const {};
  Set<String> get localOnlySystemIds =>
      rommSetupState?.localOnlySystemIds ?? const {};

  bool get canTest {
    final form = providerForm;
    if (form == null) return false;
    final fields = form.fields;
    bool has(String k) => (fields[k]?.toString() ?? '').trim().isNotEmpty;
    switch (form.type) {
      case ProviderType.web:
        return has('url');
      case ProviderType.ftp:
        return has('host') && has('port') && has('path');
      case ProviderType.smb:
        return has('host') && has('port') && has('share') && has('path');
      case ProviderType.romm:
        return has('url');
    }
  }

  SystemModel? get selectedSystem {
    if (selectedConsoleId == null) return null;
    try {
      return SystemModel.supportedSystems.firstWhere(
        (s) => s.id == selectedConsoleId,
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
    // Handle RomM sub-step transitions within rommSetup
    if (state.currentStep == OnboardingStep.rommSetup) {
      final rs = state.rommSetupState;
      if (rs != null && rs.subStep == RommSetupSubStep.select) {
        // select → folder
        state = state.copyWith(
          rommSetupState: rs.copyWith(subStep: RommSetupSubStep.folder),
          canProceed: true,
        );
        return;
      }
      // folder → consoleSetup (fall through to normal step advance)
    }

    const steps = OnboardingStep.values;
    final currentIndex = steps.indexOf(state.currentStep);
    if (currentIndex < steps.length - 1) {
      final nextStepValue = steps[currentIndex + 1];

      if (nextStepValue == OnboardingStep.rommSetup) {
        state = state.copyWith(
          currentStep: nextStepValue,
          rommSetupState: state.rommSetupState ?? const RommSetupState(),
          canProceed: true,
        );
        return;
      }

      if (nextStepValue == OnboardingStep.consoleSetup) {
        _autoConfigureRommSystems();
        state = state.copyWith(
          currentStep: nextStepValue,
          canProceed: state.configuredSystems.isNotEmpty,
        );
        return;
      }

      state = state.copyWith(
        currentStep: nextStepValue,
        canProceed: false,
      );
    }
  }

  static const _defaultRomBasePath = '/storage/emulated/0/Roms';

  void _autoConfigureRommSystems() {
    final rommSetup = state.rommSetupState;
    if (rommSetup == null ||
        (rommSetup.selectedSystemIds.isEmpty &&
            rommSetup.localOnlySystemIds.isEmpty)) {
      return;
    }

    final basePath = rommSetup.romBasePath ?? _defaultRomBasePath;
    final updated = Map<String, SystemConfig>.from(state.configuredSystems);

    // RomM-selected systems with provider
    for (final systemId in rommSetup.selectedSystemIds) {
      if (updated.containsKey(systemId)) continue;

      final match = rommSetup.systemMatches[systemId];
      if (match == null) continue;

      final system = SystemModel.supportedSystems.firstWhere(
        (s) => s.id == systemId,
      );

      final rommProvider = ProviderConfig(
        type: ProviderType.romm,
        priority: 0,
        url: rommSetup.url.trim(),
        auth: rommSetup.authConfig,
        platformId: match.id,
        platformName: match.name,
      );

      final folderName = _folderForSystem(rommSetup, systemId);

      updated[systemId] = SystemConfig(
        id: systemId,
        name: system.name,
        targetFolder: '$basePath/$folderName',
        providers: [rommProvider],
        autoExtract: system.isZipped,
        mergeMode: false,
      );
    }

    // Local-only systems — folder path but no providers
    for (final systemId in rommSetup.localOnlySystemIds) {
      if (updated.containsKey(systemId)) continue;

      final system = SystemModel.supportedSystems.firstWhere(
        (s) => s.id == systemId,
      );

      final folderName = _folderForSystem(rommSetup, systemId);

      updated[systemId] = SystemConfig(
        id: systemId,
        name: system.name,
        targetFolder: '$basePath/$folderName',
        providers: const [],
        autoExtract: system.isZipped,
        mergeMode: false,
      );
    }

    // Manual folder assignments to non-RomM/non-local systems
    for (final entry in rommSetup.folderAssignments.entries) {
      final systemId = entry.key;
      if (updated.containsKey(systemId)) continue;
      if (rommSetup.selectedSystemIds.contains(systemId)) continue;
      if (rommSetup.localOnlySystemIds.contains(systemId)) continue;

      final system = SystemModel.supportedSystems
          .where((s) => s.id == systemId)
          .firstOrNull;
      if (system == null) continue;

      updated[systemId] = SystemConfig(
        id: systemId,
        name: system.name,
        targetFolder: '$basePath/${entry.value}',
        providers: const [],
        autoExtract: system.isZipped,
        mergeMode: false,
      );
    }

    state = state.copyWith(configuredSystems: updated);
  }

  String _folderForSystem(RommSetupState rommSetup, String systemId) {
    // 1. Manual assignment from dropdown
    final manual = rommSetup.folderAssignments[systemId];
    if (manual != null) return manual;

    // 2. Auto-match from scan
    final scanned = rommSetup.scannedFolders;
    if (scanned != null) {
      final autoMatch = scanned.where((f) => f.autoMatchedSystemId == systemId);
      if (autoMatch.isNotEmpty) return autoMatch.first.name;
    }

    // 3. Default: system.id
    return systemId;
  }

  void previousStep() {
    const steps = OnboardingStep.values;
    final currentIndex = steps.indexOf(state.currentStep);
    if (currentIndex > 0) {
      final prevStep = steps[currentIndex - 1];
      if (prevStep == OnboardingStep.rommSetup) {
        state = state.copyWith(
          currentStep: prevStep,
          rommSetupState: state.rommSetupState ?? const RommSetupState(),
          canProceed: true,
        );
        return;
      }
      state = state.copyWith(currentStep: prevStep);
    }
  }

  void onMessageComplete() {
    state = state.copyWith(canProceed: true);
  }

  // --- Console selection ---

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
        mergeMode: existing.mergeMode,
        providers: List.of(existing.providers),
      );
    } else {
      subState = ConsoleSetupState(
        autoExtract: system.isZipped,
      );

      // Auto-add RomM provider for newly selected consoles with a RomM match
      final rommSetup = state.rommSetupState;
      if (rommSetup != null &&
          rommSetup.selectedSystemIds.contains(id) &&
          rommSetup.systemMatches.containsKey(id)) {
        final match = rommSetup.systemMatches[id]!;
        final rommProvider = ProviderConfig(
          type: ProviderType.romm,
          priority: 0,
          url: rommSetup.url.trim(),
          auth: rommSetup.authConfig,
          platformId: match.id,
          platformName: match.name,
        );
        subState = subState.copyWith(providers: [rommProvider]);
      }
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

  // --- RomM setup step methods ---

  void rommSetupAnswer(bool useRomm) {
    if (useRomm) {
      final rs = state.rommSetupState ?? const RommSetupState();
      state = state.copyWith(
        rommSetupState: rs.copyWith(subStep: RommSetupSubStep.connect),
      );
    } else {
      state = state.copyWith(clearRommSetupState: true);
      nextStep();
    }
  }

  void rommSetupBack() {
    final rs = state.rommSetupState;
    if (rs == null) return;

    switch (rs.subStep) {
      case RommSetupSubStep.ask:
        previousStep();
      case RommSetupSubStep.connect:
        state = state.copyWith(
          rommSetupState: rs.copyWith(subStep: RommSetupSubStep.ask),
          clearConnectionError: true,
          connectionTestSuccess: false,
          isTestingConnection: false,
        );
      case RommSetupSubStep.select:
        state = state.copyWith(
          rommSetupState: rs.copyWith(subStep: RommSetupSubStep.connect),
        );
      case RommSetupSubStep.folder:
        state = state.copyWith(
          rommSetupState: rs.copyWith(subStep: RommSetupSubStep.select),
        );
    }
  }

  void updateRommSetupField(String key, String value) {
    final rs = state.rommSetupState;
    if (rs == null) return;

    RommSetupState updated;
    switch (key) {
      case 'url':
        updated = rs.copyWith(url: value);
      case 'apiKey':
        updated = rs.copyWith(apiKey: value);
      case 'user':
        updated = rs.copyWith(user: value);
      case 'pass':
        updated = rs.copyWith(pass: value);
      default:
        return;
    }
    state = state.copyWith(
      rommSetupState: updated,
      clearConnectionError: true,
      connectionTestSuccess: false,
    );
  }

  Future<void> testRommSetupConnection() async {
    final rs = state.rommSetupState;
    if (rs == null || !rs.hasConnection) return;
    if (state.isTestingConnection) return;

    state = state.copyWith(
      isTestingConnection: true,
      clearConnectionError: true,
      connectionTestSuccess: false,
    );

    try {
      final api = RommApiService();
      final platforms = await api.fetchPlatforms(
        rs.url.trim(),
        auth: rs.authConfig,
      );

      if (!mounted) return;

      // Auto-match all supported systems
      final matches = <String, RommPlatform>{};
      for (final system in SystemModel.supportedSystems) {
        final match = RommPlatformMatcher.findMatch(system.id, platforms);
        if (match != null) {
          matches[system.id] = match;
        }
      }

      // Pre-select all matched systems
      final selected = Set<String>.from(matches.keys);

      state = state.copyWith(
        isTestingConnection: false,
        connectionTestSuccess: true,
        rommSetupState: rs.copyWith(
          discoveredPlatforms: platforms,
          systemMatches: matches,
          selectedSystemIds: selected,
          subStep: RommSetupSubStep.select,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isTestingConnection: false,
        connectionTestError: e.toString(),
      );
    }
  }

  void toggleRommSystem(String systemId) {
    final rs = state.rommSetupState;
    if (rs == null) return;

    final updated = Set<String>.from(rs.selectedSystemIds);
    if (updated.contains(systemId)) {
      updated.remove(systemId);
    } else {
      updated.add(systemId);
    }
    state = state.copyWith(
      rommSetupState: rs.copyWith(selectedSystemIds: updated),
    );
  }

  void toggleAllRommSystems(bool selectAll) {
    final rs = state.rommSetupState;
    if (rs == null) return;

    final updated = selectAll ? Set<String>.from(rs.systemMatches.keys) : <String>{};
    state = state.copyWith(
      rommSetupState: rs.copyWith(selectedSystemIds: updated),
    );
  }

  void toggleLocalSystem(String systemId) {
    final rs = state.rommSetupState;
    if (rs == null) return;

    final updated = Set<String>.from(rs.localOnlySystemIds);
    if (updated.contains(systemId)) {
      updated.remove(systemId);
    } else {
      updated.add(systemId);
    }
    state = state.copyWith(
      rommSetupState: rs.copyWith(localOnlySystemIds: updated),
    );
  }

  // --- RomM folder step methods ---

  void rommFolderChoice(bool pickExisting) {
    if (pickExisting) {
      pickRomFolder();
    } else {
      // "Create new" — skip folder selection, use defaults
      final rs = state.rommSetupState;
      if (rs == null) return;
      state = state.copyWith(
        rommSetupState: rs.copyWith(
          clearRomBasePath: true,
          clearScannedFolders: true,
          folderAssignments: const {},
          localOnlySystemIds: const {},
        ),
      );
      nextStep();
    }
  }

  Future<void> pickRomFolder() async {
    final rs = state.rommSetupState;
    if (rs == null) return;

    final path = await FilePicker.platform.getDirectoryPath();
    if (path == null) return;
    if (!mounted) return;

    state = state.copyWith(
      rommSetupState: rs.copyWith(
        romBasePath: path,
        isScanning: true,
        clearScannedFolders: true,
        folderAssignments: const {},
        localOnlySystemIds: const {},
      ),
    );

    try {
      final service = RomFolderService();
      final subfolders = await service.scanAllSubfolders(path);
      if (!mounted) return;

      // Match against ALL supported systems, not just RomM-selected ones
      const allSystems = SystemModel.supportedSystems;
      final selectedIds = state.rommSetupState!.selectedSystemIds;
      final platforms = state.rommSetupState!.discoveredPlatforms;

      final localOnlyIds = <String>{};

      final scanned = subfolders.map((f) {
        final matchedId = LocalFolderMatcher.matchFolder(
          f.name,
          allSystems,
          platforms,
        );
        final isLocalOnly = matchedId != null && !selectedIds.contains(matchedId);

        if (isLocalOnly && f.fileCount > 0) {
          localOnlyIds.add(matchedId);
        }

        return ScannedFolder(
          name: f.name,
          fileCount: f.fileCount,
          autoMatchedSystemId: matchedId,
          isLocalOnly: isLocalOnly,
        );
      }).toList();

      state = state.copyWith(
        rommSetupState: state.rommSetupState!.copyWith(
          scannedFolders: scanned,
          isScanning: false,
          localOnlySystemIds: localOnlyIds,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(
        rommSetupState: state.rommSetupState!.copyWith(
          isScanning: false,
          scannedFolders: const [],
          localOnlySystemIds: const {},
        ),
      );
    }
  }

  void assignFolderToSystem(String folderName, String? systemId) {
    final rs = state.rommSetupState;
    if (rs == null) return;

    final updated = Map<String, String>.from(rs.folderAssignments);

    // Remove any previous assignment of this folder
    updated.removeWhere((_, v) => v == folderName);

    if (systemId != null) {
      // Remove any previous assignment for this system
      updated.remove(systemId);
      updated[systemId] = folderName;
    }

    state = state.copyWith(
      rommSetupState: rs.copyWith(folderAssignments: updated),
    );
  }

  void rommFolderConfirm() {
    nextStep();
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
      (s) => s.id == id,
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
