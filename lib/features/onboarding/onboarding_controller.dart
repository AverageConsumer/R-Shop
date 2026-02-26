import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/config/app_config.dart';
import '../../models/config/provider_config.dart';
import '../../models/config/system_config.dart';
import '../../models/system_model.dart';
import '../../providers/app_providers.dart';
import '../../services/config_storage_service.dart';
import '../../services/local_folder_matcher.dart';
import '../../services/provider_factory.dart';
import '../../services/rom_folder_service.dart';
import '../../services/romm_api_service.dart';
import '../../services/romm_platform_matcher.dart';

import 'onboarding_state.dart';
export 'onboarding_state.dart';

class OnboardingController extends StateNotifier<OnboardingState> {
  final ConfigStorageService _configStorage;

  OnboardingController(this._configStorage) : super(const OnboardingState());

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
          rommSetupState: rs.copyWith(
            subStep: RommSetupSubStep.folder,
            isAutoDetecting: true,
          ),
          canProceed: true,
        );
        _autoDetectRommRomFolder();
        return;
      }
      // folder → skip localSetup, go directly to consoleSetup
      if (rs != null && rs.subStep == RommSetupSubStep.folder) {
        _autoConfigureRommSystems();
        state = state.copyWith(
          currentStep: OnboardingStep.consoleSetup,
          canProceed: state.configuredSystems.isNotEmpty,
        );
        return;
      }
    }

    // localSetup → consoleSetup
    if (state.currentStep == OnboardingStep.localSetup) {
      _autoConfigureLocalSystems();
      state = state.copyWith(
        currentStep: OnboardingStep.consoleSetup,
        canProceed: state.configuredSystems.isNotEmpty,
      );
      return;
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

      if (nextStepValue == OnboardingStep.localSetup) {
        state = state.copyWith(
          currentStep: nextStepValue,
          localSetupState: state.localSetupState ?? const LocalSetupState(isAutoDetecting: true),
          canProceed: false,
        );
        _autoDetectRomFolder();
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

  static const _defaultRomBasePath = '/storage/emulated/0/ROMs';

  void _autoConfigureRommSystems() {
    final rommSetup = state.rommSetupState;
    if (rommSetup == null ||
        (rommSetup.selectedSystemIds.isEmpty &&
            rommSetup.localOnlySystemIds.isEmpty &&
            rommSetup.scannedFolders == null)) {
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

    // Pre-save scanned+matched but not explicitly enabled consoles (path only)
    final scannedFolders = rommSetup.scannedFolders;
    if (scannedFolders != null) {
      for (final folder in scannedFolders) {
        final systemId = folder.autoMatchedSystemId;
        if (systemId == null) continue;
        if (updated.containsKey(systemId)) continue;

        final system = SystemModel.supportedSystems
            .where((s) => s.id == systemId)
            .firstOrNull;
        if (system == null) continue;

        updated[systemId] = SystemConfig(
          id: systemId,
          name: system.name,
          targetFolder: '$basePath/${folder.name}',
          providers: const [],
          autoExtract: system.isZipped,
          mergeMode: false,
        );
      }
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
    // consoleSetup → back: if RomM user, skip localSetup to rommSetup
    if (state.currentStep == OnboardingStep.consoleSetup) {
      if (state.rommSetupState != null) {
        state = state.copyWith(
          currentStep: OnboardingStep.rommSetup,
          rommSetupState: state.rommSetupState,
          canProceed: true,
        );
        return;
      }
      // Non-RomM user → back to localSetup
      state = state.copyWith(
        currentStep: OnboardingStep.localSetup,
        localSetupState: state.localSetupState ?? const LocalSetupState(),
        canProceed: true,
      );
      return;
    }

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
      localSetupState: state.localSetupState,
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
      // Clear RomM state, advance to localSetup (next step in enum)
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
          rommSetupState: rs.copyWith(
            subStep: RommSetupSubStep.select,
            clearDetectedPath: true,
            clearScannedFolders: true,
            isAutoDetecting: false,
          ),
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

    _scanRommFolder(path);
  }

  void scanDetectedRommFolder() {
    final rs = state.rommSetupState;
    if (rs?.detectedPath == null) return;
    _scanRommFolder(rs!.detectedPath!);
  }

  Future<void> _scanRommFolder(String path) async {
    final rs = state.rommSetupState;
    if (rs == null) return;

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
    } catch (e) {
      debugPrint('Onboarding: RomM scan failed: $e');
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

  void unassignFolder(String folderName) {
    final rs = state.rommSetupState;
    if (rs == null) return;

    final updated = Map<String, String>.from(rs.folderAssignments);
    updated.removeWhere((_, v) => v == folderName);

    state = state.copyWith(
      rommSetupState: rs.copyWith(folderAssignments: updated),
    );
  }

  void rommFolderConfirm() {
    nextStep();
  }

  // --- Local setup step methods ---

  Future<void> _autoDetectRomFolder() async {
    final ls = state.localSetupState;
    if (ls == null) return;

    const knownPaths = [
      '/storage/emulated/0/ROMs',
      '/storage/emulated/0/Roms',
      '/storage/emulated/0/roms',
    ];

    String? found;
    for (final path in knownPaths) {
      if (await Directory(path).exists()) {
        found = path;
        break;
      }
    }

    if (!mounted) return;
    // Guard against step change during async gap
    if (state.currentStep != OnboardingStep.localSetup) return;

    state = state.copyWith(
      localSetupState: state.localSetupState?.copyWith(
        detectedPath: found,
        isAutoDetecting: false,
        clearDetectedPath: found == null,
      ),
      canProceed: true,
    );
  }

  Future<void> _autoDetectRommRomFolder() async {
    final rs = state.rommSetupState;
    if (rs == null) return;

    const knownPaths = [
      '/storage/emulated/0/ROMs',
      '/storage/emulated/0/Roms',
      '/storage/emulated/0/roms',
    ];

    String? found;
    for (final path in knownPaths) {
      if (await Directory(path).exists()) {
        found = path;
        break;
      }
    }

    if (!mounted) return;
    // Guard against step/sub-step change during async gap
    if (state.currentStep != OnboardingStep.rommSetup) return;
    if (state.rommSetupState?.subStep != RommSetupSubStep.folder) return;

    state = state.copyWith(
      rommSetupState: state.rommSetupState?.copyWith(
        detectedPath: found,
        isAutoDetecting: false,
        clearDetectedPath: found == null,
      ),
    );
  }

  void localSetupChoice(LocalSetupAction action) {
    switch (action) {
      case LocalSetupAction.scanDetected:
        final ls = state.localSetupState;
        if (ls?.detectedPath == null) return;
        _scanLocalFolder(ls!.detectedPath!);
      case LocalSetupAction.pickFolder:
        pickLocalFolder();
      case LocalSetupAction.createFolders:
        final ls = state.localSetupState ?? const LocalSetupState();
        state = state.copyWith(
          localSetupState: ls.copyWith(
            createSystemIds: <String>{},
            createBasePath: _defaultRomBasePath,
          ),
        );
      case LocalSetupAction.skip:
        nextStep();
    }
  }

  void toggleCreateSystem(String systemId) {
    final ls = state.localSetupState;
    if (ls == null || ls.createSystemIds == null) return;

    final updated = Set<String>.from(ls.createSystemIds!);
    if (updated.contains(systemId)) {
      updated.remove(systemId);
    } else {
      updated.add(systemId);
    }
    state = state.copyWith(
      localSetupState: ls.copyWith(createSystemIds: updated),
    );
  }

  void toggleAllCreateSystems(bool selectAll) {
    final ls = state.localSetupState;
    if (ls == null || ls.createSystemIds == null) return;

    final updated = selectAll
        ? Set<String>.from(SystemModel.supportedSystems.map((s) => s.id))
        : <String>{};
    state = state.copyWith(
      localSetupState: ls.copyWith(createSystemIds: updated),
    );
  }

  Future<void> pickCreateBasePath() async {
    final ls = state.localSetupState;
    if (ls == null) return;

    final path = await FilePicker.platform.getDirectoryPath();
    if (path == null) return;
    if (!mounted) return;

    state = state.copyWith(
      localSetupState: ls.copyWith(createBasePath: path),
    );
  }

  /// Returns null on success, or an error message on partial/total failure.
  Future<String?> confirmCreateFolders() async {
    final ls = state.localSetupState;
    if (ls == null || ls.createSystemIds == null || ls.createSystemIds!.isEmpty) return null;

    final basePath = ls.createBasePath ?? _defaultRomBasePath;
    final requested = ls.createSystemIds!.length;

    state = state.copyWith(
      localSetupState: ls.copyWith(isScanning: true),
    );

    final updated = Map<String, SystemConfig>.from(state.configuredSystems);
    var failedCount = 0;

    for (final systemId in ls.createSystemIds!) {
      if (updated.containsKey(systemId)) continue;

      final system = SystemModel.supportedSystems
          .where((s) => s.id == systemId)
          .firstOrNull;
      if (system == null) continue;

      final dirPath = '$basePath/$systemId';
      try {
        await Directory(dirPath).create(recursive: true);
      } catch (e) {
        debugPrint('Onboarding: directory creation failed for $dirPath: $e');
        failedCount++;
        continue;
      }

      updated[systemId] = SystemConfig(
        id: systemId,
        name: system.name,
        targetFolder: dirPath,
        providers: const [],
        autoExtract: system.isZipped,
        mergeMode: false,
      );
    }

    if (!mounted) return null;

    // All failed — stay on create phase, show error
    if (failedCount == requested) {
      state = state.copyWith(
        localSetupState: state.localSetupState?.copyWith(isScanning: false),
      );
      return 'Could not create folders at $basePath — check permissions.';
    }

    state = state.copyWith(
      configuredSystems: updated,
      localSetupState: state.localSetupState?.copyWith(
        isScanning: false,
        clearCreateSystemIds: true,
      ),
    );

    nextStep();

    if (failedCount > 0) {
      return '$failedCount folder${failedCount == 1 ? '' : 's'} could not be created.';
    }
    return null;
  }

  Future<void> _scanLocalFolder(String path) async {
    final ls = state.localSetupState ?? const LocalSetupState();

    state = state.copyWith(
      localSetupState: ls.copyWith(
        romBasePath: path,
        isScanning: true,
        clearScannedFolders: true,
        folderAssignments: const {},
        enabledSystemIds: const {},
      ),
    );

    try {
      final service = RomFolderService();
      final subfolders = await service.scanAllSubfolders(path);
      if (!mounted) return;

      const allSystems = SystemModel.supportedSystems;
      final enabledIds = <String>{};

      final scanned = subfolders.map((f) {
        final matchedId = LocalFolderMatcher.matchFolder(
          f.name,
          allSystems,
          const [],
        );

        if (matchedId != null && f.fileCount > 0) {
          enabledIds.add(matchedId);
        }

        return ScannedFolder(
          name: f.name,
          fileCount: f.fileCount,
          autoMatchedSystemId: matchedId,
        );
      }).toList();

      state = state.copyWith(
        localSetupState: state.localSetupState!.copyWith(
          scannedFolders: scanned,
          isScanning: false,
          enabledSystemIds: enabledIds,
        ),
      );
    } catch (e) {
      debugPrint('Onboarding: local folder scan failed: $e');
      if (!mounted) return;
      state = state.copyWith(
        localSetupState: state.localSetupState!.copyWith(
          isScanning: false,
          scannedFolders: const [],
          enabledSystemIds: const {},
        ),
      );
    }
  }

  Future<void> pickLocalFolder() async {
    final path = await FilePicker.platform.getDirectoryPath();
    if (path == null) return;
    if (!mounted) return;
    _scanLocalFolder(path);
  }

  void assignLocalFolder(String folderName, String? systemId) {
    final ls = state.localSetupState;
    if (ls == null) return;

    final updated = Map<String, String>.from(ls.folderAssignments);

    // Remove any previous assignment of this folder
    updated.removeWhere((_, v) => v == folderName);

    if (systemId != null) {
      // Remove any previous assignment for this system
      updated.remove(systemId);
      updated[systemId] = folderName;
    }

    state = state.copyWith(
      localSetupState: ls.copyWith(folderAssignments: updated),
    );
  }

  void toggleLocalSetupSystem(String systemId) {
    final ls = state.localSetupState;
    if (ls == null) return;

    final updated = Set<String>.from(ls.enabledSystemIds);
    if (updated.contains(systemId)) {
      updated.remove(systemId);
    } else {
      updated.add(systemId);
    }
    state = state.copyWith(
      localSetupState: ls.copyWith(enabledSystemIds: updated),
    );
  }

  void localSetupConfirm() {
    nextStep();
  }

  void localSetupBack() {
    final ls = state.localSetupState;
    if (ls != null && ls.isCreatePhase) {
      // Create → Choice (clear createSystemIds)
      state = state.copyWith(
        localSetupState: ls.copyWith(
          clearCreateSystemIds: true,
          clearCreateBasePath: true,
        ),
      );
      return;
    }
    if (ls != null && ls.isResultsPhase) {
      // Results → Choice (reset scan state, preserve detectedPath)
      state = state.copyWith(
        localSetupState: LocalSetupState(
          detectedPath: ls.detectedPath,
        ),
      );
      return;
    }
    // Choice → rommSetup/ask
    previousStep();
  }

  void _autoConfigureLocalSystems() {
    final ls = state.localSetupState;
    if (ls == null) return;

    final basePath = ls.romBasePath ?? _defaultRomBasePath;
    final updated = Map<String, SystemConfig>.from(state.configuredSystems);

    for (final systemId in ls.enabledSystemIds) {
      if (updated.containsKey(systemId)) continue;

      final system = SystemModel.supportedSystems
          .where((s) => s.id == systemId)
          .firstOrNull;
      if (system == null) continue;

      final folderName = _folderForLocalSystem(ls, systemId);

      updated[systemId] = SystemConfig(
        id: systemId,
        name: system.name,
        targetFolder: '$basePath/$folderName',
        providers: const [],
        autoExtract: system.isZipped,
        mergeMode: false,
      );
    }

    // Manual folder assignments to non-enabled systems
    for (final entry in ls.folderAssignments.entries) {
      final systemId = entry.key;
      if (updated.containsKey(systemId)) continue;

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

    // Pre-save scanned+matched but not explicitly enabled consoles (path only)
    final scannedFolders = ls.scannedFolders;
    if (scannedFolders != null) {
      for (final folder in scannedFolders) {
        final systemId = folder.autoMatchedSystemId;
        if (systemId == null) continue;
        if (updated.containsKey(systemId)) continue;

        final system = SystemModel.supportedSystems
            .where((s) => s.id == systemId)
            .firstOrNull;
        if (system == null) continue;

        updated[systemId] = SystemConfig(
          id: systemId,
          name: system.name,
          targetFolder: '$basePath/${folder.name}',
          providers: const [],
          autoExtract: system.isZipped,
          mergeMode: false,
        );
      }
    }

    state = state.copyWith(configuredSystems: updated);
  }

  String _folderForLocalSystem(LocalSetupState ls, String systemId) {
    // 1. Manual assignment from dropdown
    final manual = ls.folderAssignments[systemId];
    if (manual != null) return manual;

    // 2. Auto-match from scan
    final scanned = ls.scannedFolders;
    if (scanned != null) {
      final autoMatch = scanned.where((f) => f.autoMatchedSystemId == systemId);
      if (autoMatch.isNotEmpty) return autoMatch.first.name;
    }

    // 3. Default: system.id
    return systemId;
  }

  Future<void> testAndSaveProvider() async {
    if (state.connectionTestSuccess) {
      if (state.providerForm?.type == ProviderType.romm &&
          !state.hasRommPlatformSelected) {
        return;
      }
      saveProvider();
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
    await _configStorage.exportConfig(config);
  }
}

final onboardingControllerProvider =
    StateNotifierProvider<OnboardingController, OnboardingState>((ref) {
  return OnboardingController(ref.read(configStorageServiceProvider));
});
