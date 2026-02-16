import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/system_model.dart';
import '../../providers/app_providers.dart';
import '../../services/repo_manager.dart';
import '../../services/rom_folder_service.dart';
import '../../services/storage_service.dart';

enum OnboardingStep {
  welcome,
  legalNotice,
  repoUrl,
  folderSelect,
  folderAnalysis,
  complete,
}

class OnboardingState {
  final OnboardingStep currentStep;
  final String? romPath;
  final String? repoUrl;
  final FolderAnalysisResult? folderAnalysis;
  final bool isAnalyzing;
  final bool isCreatingFolders;
  final List<String> createdFolders;
  final bool canProceed;
  final bool isTestingConnection;
  final String? repoUrlError;

  const OnboardingState({
    this.currentStep = OnboardingStep.welcome,
    this.romPath,
    this.repoUrl,
    this.folderAnalysis,
    this.isAnalyzing = false,
    this.isCreatingFolders = false,
    this.createdFolders = const [],
    this.canProceed = false,
    this.isTestingConnection = false,
    this.repoUrlError,
  });

  OnboardingState copyWith({
    OnboardingStep? currentStep,
    String? romPath,
    String? repoUrl,
    FolderAnalysisResult? folderAnalysis,
    bool? isAnalyzing,
    bool? isCreatingFolders,
    List<String>? createdFolders,
    bool? canProceed,
    bool? isTestingConnection,
    String? repoUrlError,
    bool clearRepoUrlError = false,
  }) {
    return OnboardingState(
      currentStep: currentStep ?? this.currentStep,
      romPath: romPath ?? this.romPath,
      repoUrl: repoUrl ?? this.repoUrl,
      folderAnalysis: folderAnalysis ?? this.folderAnalysis,
      isAnalyzing: isAnalyzing ?? this.isAnalyzing,
      isCreatingFolders: isCreatingFolders ?? this.isCreatingFolders,
      createdFolders: createdFolders ?? this.createdFolders,
      canProceed: canProceed ?? this.canProceed,
      isTestingConnection: isTestingConnection ?? this.isTestingConnection,
      repoUrlError: clearRepoUrlError ? null : (repoUrlError ?? this.repoUrlError),
    );
  }

  bool get isFirstStep => currentStep == OnboardingStep.welcome;
  bool get isLastStep => currentStep == OnboardingStep.complete;
  bool get needsFolderSelection => currentStep == OnboardingStep.folderSelect;
  bool get needsRepoUrl => currentStep == OnboardingStep.repoUrl;
}

class OnboardingController extends StateNotifier<OnboardingState> {
  final RomFolderService _folderService;
  final StorageService? _storageService;

  OnboardingController({
    RomFolderService? folderService,
    StorageService? storageService,
  })  : _folderService = folderService ?? RomFolderService(),
        _storageService = storageService,
        super(const OnboardingState());

  void nextStep() {
    if (state.currentStep == OnboardingStep.folderSelect && state.romPath == null) {
      return;
    }
    if (state.currentStep == OnboardingStep.repoUrl && state.repoUrl == null) {
      return;
    }
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

  Future<void> submitRepoUrl(String url) async {
    final trimmed = url.trim();

    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      state = state.copyWith(repoUrlError: 'URL must start with http:// or https://');
      return;
    }

    state = state.copyWith(
      isTestingConnection: true,
      clearRepoUrlError: true,
    );

    final result = await RepoManager.testConnection(trimmed);

    if (!mounted) return;

    if (result.success) {
      state = state.copyWith(
        repoUrl: trimmed,
        isTestingConnection: false,
        clearRepoUrlError: true,
      );
      await _storageService?.setRepoUrl(trimmed);
      nextStep();
    } else {
      state = state.copyWith(
        isTestingConnection: false,
        repoUrlError: result.error,
      );
    }
  }

  Future<void> setRomPath(String path) async {
    state = state.copyWith(romPath: path, isAnalyzing: true, canProceed: false);

    final analysis = await _folderService.analyze(path);
    state = state.copyWith(folderAnalysis: analysis, isAnalyzing: false);
    if (analysis.missingFolders.isNotEmpty) {
      state = state.copyWith(isCreatingFolders: true);
      final created = await _folderService.createMissingFolders(path);
      state = state.copyWith(createdFolders: created, isCreatingFolders: false);
    }
    nextStep();
  }

  SystemModel getFirstAvailableSystem() {
    if (state.folderAnalysis == null) {
      return SystemModel.supportedSystems.first;
    }
    for (final folder in state.folderAnalysis!.folders) {
      if (folder.exists && folder.gameCount > 0) {
        return SystemModel.supportedSystems.firstWhere(
          (s) => s.esdeFolder == folder.folderName,
          orElse: () => SystemModel.supportedSystems.first,
        );
      }
    }
    return SystemModel.supportedSystems.first;
  }
}

final onboardingControllerProvider =
    StateNotifierProvider<OnboardingController, OnboardingState>((ref) {
  return OnboardingController(
    storageService: ref.read(storageServiceProvider),
  );
});
