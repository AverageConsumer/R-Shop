import 'package:flutter/foundation.dart';

import '../../models/config/provider_config.dart';
import '../../models/config/system_config.dart';
import '../../models/system_model.dart';
import '../../services/romm_api_service.dart';

enum OnboardingStep {
  welcome,
  legalNotice,
  rommSetup,
  localSetup,
  consoleSetup,
  complete,
}

enum ConsoleSubStep {
  folder,
  options,
  providers,
}

enum LocalSetupAction { scanDetected, pickFolder, createFolders, skip }

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

class LocalSetupState {
  final String? romBasePath;
  final List<ScannedFolder>? scannedFolders;
  final Map<String, String> folderAssignments; // systemId → folderName
  final Set<String> enabledSystemIds; // matched systems (default: all on)
  final bool isScanning;
  final String? detectedPath; // auto-detected ROM folder
  final Set<String>? createSystemIds; // systems selected for folder creation
  final String? createBasePath; // base path for folder creation
  final bool isAutoDetecting; // true while checking known paths

  const LocalSetupState({
    this.romBasePath,
    this.scannedFolders,
    this.folderAssignments = const {},
    this.enabledSystemIds = const {},
    this.isScanning = false,
    this.detectedPath,
    this.createSystemIds,
    this.createBasePath,
    this.isAutoDetecting = false,
  });

  LocalSetupState copyWith({
    String? romBasePath,
    List<ScannedFolder>? scannedFolders,
    Map<String, String>? folderAssignments,
    Set<String>? enabledSystemIds,
    bool? isScanning,
    String? detectedPath,
    Set<String>? createSystemIds,
    String? createBasePath,
    bool? isAutoDetecting,
    bool clearRomBasePath = false,
    bool clearScannedFolders = false,
    bool clearDetectedPath = false,
    bool clearCreateSystemIds = false,
    bool clearCreateBasePath = false,
  }) {
    return LocalSetupState(
      romBasePath: clearRomBasePath ? null : (romBasePath ?? this.romBasePath),
      scannedFolders:
          clearScannedFolders ? null : (scannedFolders ?? this.scannedFolders),
      folderAssignments: folderAssignments ?? this.folderAssignments,
      enabledSystemIds: enabledSystemIds ?? this.enabledSystemIds,
      isScanning: isScanning ?? this.isScanning,
      detectedPath: clearDetectedPath ? null : (detectedPath ?? this.detectedPath),
      createSystemIds: clearCreateSystemIds ? null : (createSystemIds ?? this.createSystemIds),
      createBasePath: clearCreateBasePath ? null : (createBasePath ?? this.createBasePath),
      isAutoDetecting: isAutoDetecting ?? this.isAutoDetecting,
    );
  }

  bool get isChoicePhase => scannedFolders == null && !isScanning && createSystemIds == null && !isAutoDetecting;
  bool get isScanningPhase => isScanning;
  bool get isResultsPhase => scannedFolders != null && !isScanning;
  bool get isCreatePhase => createSystemIds != null && !isScanning;
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
  final LocalSetupState? localSetupState;

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
    this.localSetupState,
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
    LocalSetupState? localSetupState,
    bool clearSelectedConsole = false,
    bool clearConsoleSubState = false,
    bool clearProviderForm = false,
    bool clearConnectionError = false,
    bool clearRommState = false,
    bool clearRommSetupState = false,
    bool clearLocalSetupState = false,
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
      localSetupState: clearLocalSetupState ? null : (localSetupState ?? this.localSetupState),
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
    } catch (e) {
      debugPrint('OnboardingState: system lookup failed for $selectedConsoleId: $e');
      return null;
    }
  }
}
