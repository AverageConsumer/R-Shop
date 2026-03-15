enum ActiveOverlay {
  none,
  deleteDialog,
  gameInfo,
  variantPicker,
  screenshotViewer,
}

/// Identifiers for focusable sections on the detail screen.
/// The actual list of visible sections is computed dynamically based on
/// available metadata (see [GameDetailController.availableSections]).
enum DetailSection {
  title,
  badges,
  fileDetails,
  summary,
  primaryAction,
  actions,
  screenshots,
  otherVersions,
  details,
  achievements,
}

class GameDetailState {
  final int selectedIndex;
  final Map<int, bool> installedStatus;
  final bool isDeleting;
  final String? error;
  final int dialogSelection;
  final bool isAddingToQueue;
  final bool showFullFilename;
  final ActiveOverlay activeOverlay;

  // --- Section-based navigation ---
  final int focusedSectionIndex;
  final int screenshotIndex;
  final int siblingIndex;
  final bool summaryExpanded;
  final int actionButtonIndex;
  /// Remembers which right-column section was focused before jumping to actions.
  final int? lastRightSectionIndex;

  const GameDetailState({
    this.selectedIndex = 0,
    this.installedStatus = const {},
    this.isDeleting = false,
    this.error,
    this.dialogSelection = 0,
    this.isAddingToQueue = false,
    this.showFullFilename = false,
    this.activeOverlay = ActiveOverlay.none,
    this.focusedSectionIndex = 0,
    this.screenshotIndex = 0,
    this.siblingIndex = 0,
    this.summaryExpanded = false,
    this.actionButtonIndex = 0,
    this.lastRightSectionIndex,
  });

  GameDetailState copyWith({
    int? selectedIndex,
    Map<int, bool>? installedStatus,
    bool? isDeleting,
    String? error,
    bool clearError = false,
    int? dialogSelection,
    bool? isAddingToQueue,
    bool? showFullFilename,
    ActiveOverlay? activeOverlay,
    int? focusedSectionIndex,
    int? screenshotIndex,
    int? siblingIndex,
    bool? summaryExpanded,
    int? actionButtonIndex,
    int? lastRightSectionIndex,
    bool clearLastRightSection = false,
  }) {
    return GameDetailState(
      selectedIndex: selectedIndex ?? this.selectedIndex,
      installedStatus: installedStatus ?? this.installedStatus,
      isDeleting: isDeleting ?? this.isDeleting,
      error: clearError ? null : (error ?? this.error),
      dialogSelection: dialogSelection ?? this.dialogSelection,
      isAddingToQueue: isAddingToQueue ?? this.isAddingToQueue,
      showFullFilename: showFullFilename ?? this.showFullFilename,
      activeOverlay: activeOverlay ?? this.activeOverlay,
      focusedSectionIndex: focusedSectionIndex ?? this.focusedSectionIndex,
      screenshotIndex: screenshotIndex ?? this.screenshotIndex,
      siblingIndex: siblingIndex ?? this.siblingIndex,
      summaryExpanded: summaryExpanded ?? this.summaryExpanded,
      actionButtonIndex: actionButtonIndex ?? this.actionButtonIndex,
      lastRightSectionIndex: clearLastRightSection
          ? null
          : (lastRightSectionIndex ?? this.lastRightSectionIndex),
    );
  }

  bool get isVariantInstalled => installedStatus[selectedIndex] ?? false;

  bool get showDeleteDialog => activeOverlay == ActiveOverlay.deleteDialog;
  bool get showGameInfo => activeOverlay == ActiveOverlay.gameInfo;
  bool get showVariantPicker => activeOverlay == ActiveOverlay.variantPicker;
  bool get showScreenshotViewer =>
      activeOverlay == ActiveOverlay.screenshotViewer;
  bool get isDialogOpen => showDeleteDialog;
  bool get isOverlayOpen => activeOverlay != ActiveOverlay.none;
}
