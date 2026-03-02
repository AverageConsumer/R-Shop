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
  remoteSetup,
  consoleSetup,
  raSetup,
  complete,
}

enum ConsoleSubStep {
  folder,
  options,
  providers,
}

enum LocalSetupAction { scanDetected, pickFolder, createFolders, skip }

enum RommSetupSubStep { ask, connect, select, folder }

enum RemoteSetupSubStep { ask, connect, scanning, results }

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
  final String? scanError; // error message from failed scan
  final int scanProgress; // folders found so far during scan

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
    this.scanError,
    this.scanProgress = 0,
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
    String? scanError,
    int? scanProgress,
    bool clearRomBasePath = false,
    bool clearScannedFolders = false,
    bool clearDetectedPath = false,
    bool clearCreateSystemIds = false,
    bool clearCreateBasePath = false,
    bool clearScanError = false,
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
      scanError: clearScanError ? null : (scanError ?? this.scanError),
      scanProgress: scanProgress ?? this.scanProgress,
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
  final String? detectedPath;
  final bool isAutoDetecting;
  final String? scanError;
  final int scanProgress;

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
    this.detectedPath,
    this.isAutoDetecting = false,
    this.scanError,
    this.scanProgress = 0,
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
    String? detectedPath,
    bool? isAutoDetecting,
    String? scanError,
    int? scanProgress,
    bool clearRomBasePath = false,
    bool clearScannedFolders = false,
    bool clearDetectedPath = false,
    bool clearScanError = false,
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
      detectedPath: clearDetectedPath ? null : (detectedPath ?? this.detectedPath),
      isAutoDetecting: isAutoDetecting ?? this.isAutoDetecting,
      scanError: clearScanError ? null : (scanError ?? this.scanError),
      scanProgress: scanProgress ?? this.scanProgress,
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

class RemoteSetupState {
  final RemoteSetupSubStep subStep;
  final ProviderType providerType;
  final String host;
  final String url;
  final String port;
  final String share;
  final String path;
  final String user;
  final String pass;
  final String domain;
  final bool isScanning;
  final bool isTestingConnection;
  final bool connectionTestSuccess;
  final String? connectionError;
  final List<ScannedFolder>? scannedFolders;
  final Map<String, String> folderAssignments; // systemId → folderName
  final Set<String> enabledSystemIds;
  final String? scanError;

  const RemoteSetupState({
    this.subStep = RemoteSetupSubStep.ask,
    this.providerType = ProviderType.ftp,
    this.host = '',
    this.url = '',
    this.port = '',
    this.share = '',
    this.path = '',
    this.user = '',
    this.pass = '',
    this.domain = '',
    this.isScanning = false,
    this.isTestingConnection = false,
    this.connectionTestSuccess = false,
    this.connectionError,
    this.scannedFolders,
    this.folderAssignments = const {},
    this.enabledSystemIds = const {},
    this.scanError,
  });

  RemoteSetupState copyWith({
    RemoteSetupSubStep? subStep,
    ProviderType? providerType,
    String? host,
    String? url,
    String? port,
    String? share,
    String? path,
    String? user,
    String? pass,
    String? domain,
    bool? isScanning,
    bool? isTestingConnection,
    bool? connectionTestSuccess,
    String? connectionError,
    List<ScannedFolder>? scannedFolders,
    Map<String, String>? folderAssignments,
    Set<String>? enabledSystemIds,
    String? scanError,
    bool clearConnectionError = false,
    bool clearScannedFolders = false,
    bool clearScanError = false,
  }) {
    return RemoteSetupState(
      subStep: subStep ?? this.subStep,
      providerType: providerType ?? this.providerType,
      host: host ?? this.host,
      url: url ?? this.url,
      port: port ?? this.port,
      share: share ?? this.share,
      path: path ?? this.path,
      user: user ?? this.user,
      pass: pass ?? this.pass,
      domain: domain ?? this.domain,
      isScanning: isScanning ?? this.isScanning,
      isTestingConnection: isTestingConnection ?? this.isTestingConnection,
      connectionTestSuccess: connectionTestSuccess ?? this.connectionTestSuccess,
      connectionError: clearConnectionError ? null : (connectionError ?? this.connectionError),
      scannedFolders: clearScannedFolders ? null : (scannedFolders ?? this.scannedFolders),
      folderAssignments: folderAssignments ?? this.folderAssignments,
      enabledSystemIds: enabledSystemIds ?? this.enabledSystemIds,
      scanError: clearScanError ? null : (scanError ?? this.scanError),
    );
  }

  bool get hasConnection {
    switch (providerType) {
      case ProviderType.ftp:
        return host.trim().isNotEmpty;
      case ProviderType.smb:
        return host.trim().isNotEmpty && share.trim().isNotEmpty;
      case ProviderType.web:
        return url.trim().isNotEmpty;
      case ProviderType.romm:
        return false; // not used here
    }
  }

  ProviderConfig buildConfig() {
    AuthConfig? auth;
    final hasUser = user.trim().isNotEmpty;
    final hasPass = pass.trim().isNotEmpty;
    final hasDomain = domain.trim().isNotEmpty;
    if (hasUser || hasPass || hasDomain) {
      auth = AuthConfig(
        user: hasUser ? user.trim() : null,
        pass: hasPass ? pass.trim() : null,
        domain: hasDomain ? domain.trim() : null,
      );
    }

    return ProviderConfig(
      type: providerType,
      priority: 0,
      url: providerType == ProviderType.web ? url.trim() : null,
      host: providerType != ProviderType.web ? host.trim() : null,
      port: port.trim().isNotEmpty ? int.tryParse(port.trim()) : null,
      share: providerType == ProviderType.smb ? share.trim() : null,
      path: path.trim().isNotEmpty ? path.trim() : null,
      auth: auth,
    );
  }
}

class RaSetupState {
  final String username;
  final String apiKey;
  final bool isTestingConnection;
  final bool connectionSuccess;
  final String? connectionError;
  final bool skipped;
  final bool wantsSetup;

  const RaSetupState({
    this.username = '',
    this.apiKey = '',
    this.isTestingConnection = false,
    this.connectionSuccess = false,
    this.connectionError,
    this.skipped = false,
    this.wantsSetup = false,
  });

  RaSetupState copyWith({
    String? username,
    String? apiKey,
    bool? isTestingConnection,
    bool? connectionSuccess,
    String? connectionError,
    bool? skipped,
    bool? wantsSetup,
    bool clearError = false,
  }) {
    return RaSetupState(
      username: username ?? this.username,
      apiKey: apiKey ?? this.apiKey,
      isTestingConnection: isTestingConnection ?? this.isTestingConnection,
      connectionSuccess: connectionSuccess ?? this.connectionSuccess,
      connectionError: clearError ? null : (connectionError ?? this.connectionError),
      skipped: skipped ?? this.skipped,
      wantsSetup: wantsSetup ?? this.wantsSetup,
    );
  }

  bool get hasCredentials =>
      username.trim().isNotEmpty && apiKey.trim().isNotEmpty;
}

class ProviderFormState {
  final ProviderType type;
  final Map<String, dynamic> fields;
  final int? editingIndex;
  final Map<ProviderType, Map<String, dynamic>> savedFieldsByType;

  const ProviderFormState({
    this.type = ProviderType.web,
    this.fields = const {},
    this.editingIndex,
    this.savedFieldsByType = const {},
  });

  ProviderFormState copyWith({
    ProviderType? type,
    Map<String, dynamic>? fields,
    int? editingIndex,
    bool clearEditingIndex = false,
    Map<ProviderType, Map<String, dynamic>>? savedFieldsByType,
  }) {
    return ProviderFormState(
      type: type ?? this.type,
      fields: fields ?? this.fields,
      editingIndex: clearEditingIndex ? null : (editingIndex ?? this.editingIndex),
      savedFieldsByType: savedFieldsByType ?? this.savedFieldsByType,
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

class ConfiguredServerSummary {
  final ProviderType type;
  final String hostLabel;
  final String detailLabel;
  final int systemCount;

  const ConfiguredServerSummary({
    required this.type,
    required this.hostLabel,
    required this.detailLabel,
    required this.systemCount,
  });
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
  final RemoteSetupState? remoteSetupState;
  final RaSetupState? raSetupState;

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
    this.remoteSetupState,
    this.raSetupState,
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
    RemoteSetupState? remoteSetupState,
    RaSetupState? raSetupState,
    bool clearSelectedConsole = false,
    bool clearConsoleSubState = false,
    bool clearProviderForm = false,
    bool clearConnectionError = false,
    bool clearRommState = false,
    bool clearRommSetupState = false,
    bool clearLocalSetupState = false,
    bool clearRemoteSetupState = false,
    bool clearRaSetupState = false,
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
      remoteSetupState: clearRemoteSetupState ? null : (remoteSetupState ?? this.remoteSetupState),
      raSetupState: clearRaSetupState ? null : (raSetupState ?? this.raSetupState),
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

  String? get missingFieldsMessage {
    final form = providerForm;
    if (form == null) return null;
    final fields = form.fields;
    bool has(String k) => (fields[k]?.toString() ?? '').trim().isNotEmpty;
    final missing = <String>[];
    switch (form.type) {
      case ProviderType.ftp:
        if (!has('host')) missing.add('Host');
        if (!has('port')) missing.add('Port');
        if (!has('path')) missing.add('Path');
      case ProviderType.smb:
        if (!has('host')) missing.add('Host');
        if (!has('port')) missing.add('Port');
        if (!has('share')) missing.add('Share');
        if (!has('path')) missing.add('Path');
      case ProviderType.web:
      case ProviderType.romm:
        if (!has('url')) missing.add('URL');
    }
    if (missing.isEmpty) return null;
    return 'Required: ${missing.join(', ')}';
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

  /// Deduplicated list of remote servers already configured across all systems.
  List<ConfiguredServerSummary> get configuredRemoteServers {
    final serverMap = <String, ({ProviderType type, String hostLabel, String detailLabel, Set<String> systemIds})>{};

    for (final system in configuredSystems.values) {
      for (final provider in system.providers) {
        if (provider.type == ProviderType.romm) continue;
        final key = '${provider.type.name}:${provider.hostLabel}';
        final existing = serverMap[key];
        if (existing != null) {
          existing.systemIds.add(system.id);
        } else {
          serverMap[key] = (
            type: provider.type,
            hostLabel: provider.hostLabel,
            detailLabel: provider.detailLabel,
            systemIds: {system.id},
          );
        }
      }
    }

    return serverMap.values
        .map((e) => ConfiguredServerSummary(
              type: e.type,
              hostLabel: e.hostLabel,
              detailLabel: e.detailLabel,
              systemCount: e.systemIds.length,
            ))
        .toList();
  }
}
