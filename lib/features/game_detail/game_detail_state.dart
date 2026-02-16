class GameDetailState {
  final int selectedIndex;
  final Map<int, bool> installedStatus;
  final bool isDeleting;
  final String? error;
  final bool showDeleteDialog;
  final int dialogSelection;
  final bool showTagInfo;
  final bool isAddingToQueue;

  const GameDetailState({
    this.selectedIndex = 0,
    this.installedStatus = const {},
    this.isDeleting = false,
    this.error,
    this.showDeleteDialog = false,
    this.dialogSelection = 0,
    this.showTagInfo = false,
    this.isAddingToQueue = false,
  });

  GameDetailState copyWith({
    int? selectedIndex,
    Map<int, bool>? installedStatus,
    bool? isDeleting,
    String? error,
    bool clearError = false,
    bool? showDeleteDialog,
    bool clearDialog = false,
    int? dialogSelection,
    bool? showTagInfo,
    bool clearTagInfo = false,
    bool? isAddingToQueue,
  }) {
    return GameDetailState(
      selectedIndex: selectedIndex ?? this.selectedIndex,
      installedStatus: installedStatus ?? this.installedStatus,
      isDeleting: isDeleting ?? this.isDeleting,
      error: clearError ? null : (error ?? this.error),
      showDeleteDialog:
          clearDialog ? false : (showDeleteDialog ?? this.showDeleteDialog),
      dialogSelection: dialogSelection ?? this.dialogSelection,
      showTagInfo: clearTagInfo ? false : (showTagInfo ?? this.showTagInfo),
      isAddingToQueue: isAddingToQueue ?? this.isAddingToQueue,
    );
  }

  bool get isVariantInstalled => installedStatus[selectedIndex] ?? false;

  bool get isDialogOpen => showDeleteDialog;

  bool get isOverlayOpen => showDeleteDialog || showTagInfo;
}
