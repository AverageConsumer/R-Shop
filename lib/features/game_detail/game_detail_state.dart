enum ActiveOverlay { none, deleteDialog, tagInfo, variantPicker, description }

class GameDetailState {
  final int selectedIndex;
  final Map<int, bool> installedStatus;
  final bool isDeleting;
  final String? error;
  final int dialogSelection;
  final bool isAddingToQueue;
  final bool showFullFilename;
  final ActiveOverlay activeOverlay;

  const GameDetailState({
    this.selectedIndex = 0,
    this.installedStatus = const {},
    this.isDeleting = false,
    this.error,
    this.dialogSelection = 0,
    this.isAddingToQueue = false,
    this.showFullFilename = false,
    this.activeOverlay = ActiveOverlay.none,
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
    );
  }

  bool get isVariantInstalled => installedStatus[selectedIndex] ?? false;

  bool get showDeleteDialog => activeOverlay == ActiveOverlay.deleteDialog;
  bool get showTagInfo => activeOverlay == ActiveOverlay.tagInfo;
  bool get showVariantPicker => activeOverlay == ActiveOverlay.variantPicker;
  bool get showDescription => activeOverlay == ActiveOverlay.description;
  bool get isDialogOpen => showDeleteDialog;
  bool get isOverlayOpen => activeOverlay != ActiveOverlay.none;
}
