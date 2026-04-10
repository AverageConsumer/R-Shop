import 'package:flutter/foundation.dart';

import '../../models/config/provider_config.dart';
import '../../models/config/system_config.dart';
import '../../models/system_model.dart';
import '../../services/romm_api_service.dart';

enum OnboardingStep {
  welcome,
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
  final bool autoSync;
  final List<ProviderConfig> providers;

  const ConsoleSetupState({
    this.targetFolder,
    this.autoExtract = false,
    this.autoSync = true,
    this.providers = const [],
  });

  ConsoleSetupState copyWith({
    String? targetFolder,
    bool? autoExtract,
    bool? autoSync,
    List<ProviderConfig>? providers,
  }) {
    return ConsoleSetupState(
      targetFolder: targetFolder ?? this.targetFolder,
      autoExtract: autoExtract ?? this.autoExtract,
      autoSync: autoSync ?? this.autoSync,
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
  // RomM platform fields — used by provider_form when editing a RomM provider
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
}
