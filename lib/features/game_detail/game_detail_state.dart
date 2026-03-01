class GameDetailState {
  final int selectedIndex;
  final Map<int, bool> installedStatus;
  final bool isDeleting;
  final String? error;
  final bool showDeleteDialog;
  final int dialogSelection;
  final bool showTagInfo;
  final bool isAddingToQueue;
  final bool showFullFilename;
  final bool showVariantPicker;
  final bool showDescription;

  const GameDetailState({
    this.selectedIndex = 0,
    this.installedStatus = const {},
    this.isDeleting = false,
    this.error,
    this.showDeleteDialog = false,
    this.dialogSelection = 0,
    this.showTagInfo = false,
    this.isAddingToQueue = false,
    this.showFullFilename = false,
    this.showVariantPicker = false,
    this.showDescription = false,
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
    bool? showFullFilename,
    bool? showVariantPicker,
    bool clearVariantPicker = false,
    bool? showDescription,
    bool clearDescription = false,
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
      showFullFilename: showFullFilename ?? this.showFullFilename,
      showVariantPicker: clearVariantPicker
          ? false
          : (showVariantPicker ?? this.showVariantPicker),
      showDescription: clearDescription
          ? false
          : (showDescription ?? this.showDescription),
    );
  }

  bool get isVariantInstalled => installedStatus[selectedIndex] ?? false;

  bool get isDialogOpen => showDeleteDialog;

  bool get isOverlayOpen => showDeleteDialog || showTagInfo || showVariantPicker || showDescription;
}
