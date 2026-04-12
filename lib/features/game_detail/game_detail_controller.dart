import 'package:flutter/material.dart';
import '../../core/input/app_intents.dart';
import '../../models/game_item.dart';
import '../../models/game_metadata_info.dart';
import '../../models/system_model.dart';
import '../../models/ra_models.dart';
import '../../services/database_service.dart';
import '../../services/download_queue_manager.dart';
import '../../services/rom_manager.dart';
import '../../utils/friendly_error.dart';
import '../../utils/game_metadata.dart';
import 'game_detail_state.dart';

class GameDetailController extends ChangeNotifier {
  final GameItem game;
  final List<GameItem> variants;
  final SystemModel system;
  final String targetFolder;
  final bool isLocalOnly;
  final bool autoExtract;
  final RomManager _romManager;
  final DownloadQueueManager _queueManager;
  final DatabaseService _databaseService;

  bool _disposed = false;
  bool _hasSetInitialFocus = false;
  GameDetailState _state = const GameDetailState();
  GameDetailState get state => _state;
  GameItem get selectedVariant =>
      variants[_state.selectedIndex.clamp(0, variants.length - 1)];
  int get selectedIndex => _state.selectedIndex;

  // --- Dynamic sections ---
  List<DetailSection> _availableSections = const [DetailSection.actions];
  List<DetailSection> get availableSections => _availableSections;
  DetailSection get focusedSection =>
      _availableSections[_state.focusedSectionIndex
          .clamp(0, _availableSections.length - 1)];

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  /// Called when an item is successfully added to the download queue.
  VoidCallback? onAddedToQueue;

  GameDetailController({
    required this.game,
    required this.variants,
    required this.system,
    required this.targetFolder,
    this.isLocalOnly = false,
    this.autoExtract = false,
    bool showFullFilename = false,
    RomManager? romManager,
    required DownloadQueueManager queueManager,
    DatabaseService? databaseService,
    this.onAddedToQueue,
  })  : _romManager = romManager ?? RomManager(),
        _queueManager = queueManager,
        _databaseService = databaseService ?? DatabaseService() {
    _state = GameDetailState(showFullFilename: showFullFilename);
    checkInstallationStatus();
  }

  /// Recomputes which sections are visible based on available metadata.
  /// Called by the screen whenever metadata or RA match data changes.
  void updateAvailableSections({
    GameMetadataInfo? metadata,
    GameMetadataFull? fileMetadata,
    RaMatchResult? raMatch,
  }) {
    final sections = <DetailSection>[DetailSection.title];

    final hasRichMeta = metadata != null && metadata.hasContent;

    // Badges row: genres, age rating, or star rating
    if (hasRichMeta &&
        (metadata.genreList.isNotEmpty ||
            metadata.ageRating != null ||
            metadata.rating != null)) {
      sections.add(DetailSection.badges);
    }

    // File details row (region, language, format, size — always shown)
    sections.add(DetailSection.fileDetails);

    // Summary section
    if (hasRichMeta && metadata.summary != null) {
      sections.add(DetailSection.summary);
    }

    // Primary action (download/delete/manage — always present)
    sections.add(DetailSection.primaryAction);

    // Icon action buttons (favorite/share/collection — always present)
    sections.add(DetailSection.actions);

    // Screenshots
    if (hasRichMeta && metadata.screenshotUrlList.isNotEmpty) {
      sections.add(DetailSection.screenshots);
    }

    // Other versions (real variants + unmatched siblings shown greyed out)
    if (variants.length > 1 ||
        (hasRichMeta && metadata.siblingList.isNotEmpty)) {
      sections.add(DetailSection.otherVersions);
    }

    // Structured details (file tags — single ROM only, when tags exist)
    if (variants.length == 1 &&
        fileMetadata != null &&
        fileMetadata.primaryTags.isNotEmpty) {
      sections.add(DetailSection.details);
    }

    // RA Achievements
    if (raMatch != null && raMatch.hasMatch) {
      sections.add(DetailSection.achievements);
    }

    _availableSections = sections;

    // On first build, jump straight to the primary action (Download/Delete)
    if (!_hasSetInitialFocus) {
      _hasSetInitialFocus = true;
      final primaryIdx = sections.indexOf(DetailSection.primaryAction);
      if (primaryIdx >= 0) {
        _state = _state.copyWith(focusedSectionIndex: primaryIdx);
        return;
      }
    }

    // Ensure focused index points to an interactive section
    var focusIdx = _state.focusedSectionIndex;
    if (focusIdx >= sections.length) {
      focusIdx = sections.length - 1;
    }
    while (focusIdx >= 0 &&
        focusIdx < sections.length &&
        _nonInteractiveSections.contains(sections[focusIdx])) {
      focusIdx++;
    }
    if (focusIdx >= sections.length) {
      focusIdx = sections.length - 1;
    }
    if (focusIdx != _state.focusedSectionIndex) {
      _state = _state.copyWith(focusedSectionIndex: focusIdx);
    }
  }

  // --- Section navigation ---

  /// When true, up/down skips left-column sections (primaryAction + actions).
  bool skipActionsInVerticalNav = false;

  // Max item counts for horizontal sections (set by clampHorizontalIndices).
  int _screenshotMax = 0;
  int _siblingMax = 0;
  int _actionButtonMax = 0;
  Set<int> _disabledActionButtons = const {};

  static const _leftColumnSections = {
    DetailSection.primaryAction,
    DetailSection.actions,
  };

  /// Sections that are display-only and should be skipped during D-pad nav.
  /// Title is kept focusable so the user can scroll back to the top.
  static const _nonInteractiveSections = {
    DetailSection.badges,
    DetailSection.fileDetails,
  };

  bool _shouldSkip(DetailSection section) {
    if (_nonInteractiveSections.contains(section)) {
      return true;
    }
    if (skipActionsInVerticalNav &&
        _leftColumnSections.contains(section)) {
      return true;
    }
    return false;
  }

  void focusPreviousSection() {
    var idx = _state.focusedSectionIndex;
    if (idx <= 0) return;
    idx--;
    while (idx >= 0 && _shouldSkip(_availableSections[idx])) {
      idx--;
    }
    if (idx >= 0) {
      _state = _state.copyWith(focusedSectionIndex: idx);
      notifyListeners();
    }
  }

  void focusNextSection() {
    var idx = _state.focusedSectionIndex;
    if (idx >= _availableSections.length - 1) return;
    idx++;
    while (idx < _availableSections.length &&
        _shouldSkip(_availableSections[idx])) {
      idx++;
    }
    if (idx < _availableSections.length) {
      _state = _state.copyWith(focusedSectionIndex: idx);
      notifyListeners();
    }
  }

  void focusSection(DetailSection section) {
    final idx = _availableSections.indexOf(section);
    if (idx >= 0) {
      _state = _state.copyWith(focusedSectionIndex: idx);
      notifyListeners();
    }
  }

  /// Handles left/right navigation within a horizontal section.
  /// Returns true if the input was consumed.
  bool navigateInSection(GridDirection direction) {
    final section = focusedSection;

    if (direction == GridDirection.left || direction == GridDirection.right) {
      final delta = direction == GridDirection.right ? 1 : -1;

      switch (section) {
        case DetailSection.screenshots:
          final newIdx = _state.screenshotIndex + delta;
          if (newIdx >= 0 && (_screenshotMax == 0 || newIdx < _screenshotMax)) {
            _state = _state.copyWith(screenshotIndex: newIdx);
            notifyListeners();
            return true;
          }
          return false;

        case DetailSection.otherVersions:
          final newIdx = _state.siblingIndex + delta;
          if (newIdx >= 0 && (_siblingMax == 0 || newIdx < _siblingMax)) {
            _state = _state.copyWith(siblingIndex: newIdx);
            notifyListeners();
            return true;
          }
          return false;

        case DetailSection.actions:
          // Skip disabled buttons in the navigation direction
          var newIdx = _state.actionButtonIndex + delta;
          while (newIdx >= 0 &&
              (_actionButtonMax == 0 || newIdx < _actionButtonMax) &&
              _disabledActionButtons.contains(newIdx)) {
            newIdx += delta;
          }
          if (newIdx >= 0 && (_actionButtonMax == 0 || newIdx < _actionButtonMax)) {
            _state = _state.copyWith(actionButtonIndex: newIdx);
            notifyListeners();
            return true;
          }
          return false;

        default:
          return false;
      }
    }

    return false;
  }

  /// Cross-column navigation for landscape layout.
  /// LEFT from any right-column section → jump to primaryAction (left column).
  /// RIGHT from left-column section → jump back to last right-column section.
  /// UP/DOWN within left column → navigate between primaryAction ↔ actions.
  /// Returns true if navigation was consumed.
  bool navigateCrossColumn(GridDirection direction) {
    final section = focusedSection;
    final isInLeftColumn = _leftColumnSections.contains(section);

    // LEFT from right column → jump to primaryAction in left column
    if (direction == GridDirection.left && !isInLeftColumn) {
      final targetIdx =
          _availableSections.indexOf(DetailSection.primaryAction);
      if (targetIdx < 0) return false;
      _state = _state.copyWith(
        lastRightSectionIndex: _state.focusedSectionIndex,
        focusedSectionIndex: targetIdx,
      );
      notifyListeners();
      return true;
    }

    // RIGHT from left column → jump back to last right section
    if (direction == GridDirection.right && isInLeftColumn) {
      final targetIdx = _state.lastRightSectionIndex ??
          _availableSections
              .indexWhere((s) => !_leftColumnSections.contains(s));
      if (targetIdx >= 0 && targetIdx < _availableSections.length) {
        _state = _state.copyWith(
          focusedSectionIndex: targetIdx,
          clearLastRightSection: true,
        );
        notifyListeners();
        return true;
      }
    }

    return false;
  }

  /// UP/DOWN navigation within the left column (primaryAction ↔ actions).
  /// Returns true if consumed.
  bool navigateLeftColumn(GridDirection direction) {
    final section = focusedSection;
    if (!_leftColumnSections.contains(section)) return false;

    if (direction == GridDirection.up &&
        section == DetailSection.actions) {
      final idx = _availableSections.indexOf(DetailSection.primaryAction);
      if (idx >= 0) {
        _state = _state.copyWith(focusedSectionIndex: idx);
        notifyListeners();
        return true;
      }
    }

    if (direction == GridDirection.down &&
        section == DetailSection.primaryAction) {
      final idx = _availableSections.indexOf(DetailSection.actions);
      if (idx >= 0) {
        _state = _state.copyWith(focusedSectionIndex: idx);
        notifyListeners();
        return true;
      }
    }

    return false;
  }

  /// Clamp horizontal indices to actual item counts (called by screen
  /// after it knows screenshot/sibling counts).
  void clampHorizontalIndices({
    int screenshotCount = 0,
    int siblingCount = 0,
    int actionButtonCount = 0,
    Set<int> disabledActionButtons = const {},
  }) {
    _screenshotMax = screenshotCount;
    _siblingMax = siblingCount;
    _actionButtonMax = actionButtonCount;
    _disabledActionButtons = disabledActionButtons;

    var changed = false;
    var si = _state.screenshotIndex;
    var sib = _state.siblingIndex;
    var ab = _state.actionButtonIndex;

    if (screenshotCount > 0 && si >= screenshotCount) {
      si = screenshotCount - 1;
      changed = true;
    }
    if (siblingCount > 0 && sib >= siblingCount) {
      sib = siblingCount - 1;
      changed = true;
    }
    if (actionButtonCount > 0 && ab >= actionButtonCount) {
      ab = actionButtonCount - 1;
      changed = true;
    }

    // If current action button is disabled, find nearest enabled one
    if (disabledActionButtons.contains(ab)) {
      // Try forward first, then backward
      var found = false;
      for (var i = ab + 1; i < actionButtonCount; i++) {
        if (!disabledActionButtons.contains(i)) {
          ab = i;
          found = true;
          break;
        }
      }
      if (!found) {
        for (var i = ab - 1; i >= 0; i--) {
          if (!disabledActionButtons.contains(i)) {
            ab = i;
            found = true;
            break;
          }
        }
      }
      if (found) changed = true;
    }

    if (changed) {
      _state = _state.copyWith(
        screenshotIndex: si,
        siblingIndex: sib,
        actionButtonIndex: ab,
      );
      // Don't notify — this is typically called during build
    }
  }

  void toggleSummaryExpanded() {
    _state = _state.copyWith(summaryExpanded: !_state.summaryExpanded);
    notifyListeners();
  }

  void openScreenshotViewer() {
    _state = _state.copyWith(activeOverlay: ActiveOverlay.screenshotViewer);
    notifyListeners();
  }

  void closeScreenshotViewer() {
    _state = _state.copyWith(activeOverlay: ActiveOverlay.none);
    notifyListeners();
  }

  void selectVariant(int index) {
    if (index >= 0 && index < variants.length) {
      _state = _state.copyWith(
        selectedIndex: index,
        activeOverlay: _state.activeOverlay == ActiveOverlay.gameInfo
            ? ActiveOverlay.none
            : null,
      );
      notifyListeners();
    }
  }

  Future<void> checkInstallationStatus() async {
    final status = await _romManager.checkMultipleExists(
      variants,
      system,
      targetFolder,
    );
    _state = _state.copyWith(installedStatus: status);
    notifyListeners();
  }

  Future<bool> addToQueue() async {
    if (_state.isAddingToQueue) return false;

    _state = _state.copyWith(isAddingToQueue: true, clearError: true);
    notifyListeners();

    try {
      final queueSizeBefore = _queueManager.state.queue.length;
      _queueManager.addToQueue(selectedVariant, system, targetFolder, autoExtract: autoExtract);
      final actuallyAdded = _queueManager.state.queue.length > queueSizeBefore;
      await Future.delayed(const Duration(milliseconds: 300));
      await checkInstallationStatus();
      return actuallyAdded;
    } catch (e) {
      _state = _state.copyWith(error: getUserFriendlyError(e));
      notifyListeners();
      return false;
    } finally {
      _state = _state.copyWith(isAddingToQueue: false);
      notifyListeners();
    }
  }

  Future<void> deleteRom() async {
    if (_state.isDeleting) return;
    _state = _state.copyWith(isDeleting: true, clearError: true);
    notifyListeners();
    try {
      await _romManager.delete(selectedVariant, system, targetFolder);
      if (isLocalOnly) {
        await _databaseService.deleteGame(system.id, selectedVariant.filename);
      }
      await Future.delayed(const Duration(milliseconds: 300));
      await checkInstallationStatus();
    } catch (e) {
      _state = _state.copyWith(error: getUserFriendlyError(e));
    } finally {
      _state = _state.copyWith(isDeleting: false);
      notifyListeners();
    }
  }

  void setSharing(bool value) {
    _state = _state.copyWith(isSharing: value);
    notifyListeners();
  }

  String get cleanTitle => GameMetadata.cleanTitle(selectedVariant.filename);

  String get displayTitle =>
      _state.showFullFilename ? selectedVariant.filename : cleanTitle;

  void toggleFullFilename() {
    _state = _state.copyWith(showFullFilename: !_state.showFullFilename);
    notifyListeners();
  }

  // --- Overlay management ---

  void closeOverlay() {
    _state = _state.copyWith(activeOverlay: ActiveOverlay.none);
    notifyListeners();
  }

  void showDeleteDialog() {
    _state = _state.copyWith(
      activeOverlay: ActiveOverlay.deleteDialog,
      dialogSelection: 1,
    );
    notifyListeners();
  }

  void selectDialogOption(int index) {
    _state = _state.copyWith(dialogSelection: index);
    notifyListeners();
  }

  void cancelDialog() {
    _state = _state.copyWith(activeOverlay: ActiveOverlay.none);
    notifyListeners();
  }

  void openGameInfo() {
    _state = _state.copyWith(activeOverlay: ActiveOverlay.gameInfo);
    notifyListeners();
  }

  void closeGameInfo() {
    _state = _state.copyWith(activeOverlay: ActiveOverlay.none);
    notifyListeners();
  }

  void openVariantPicker() {
    _state = _state.copyWith(activeOverlay: ActiveOverlay.variantPicker);
    notifyListeners();
  }

  void closeVariantPicker() {
    _state = _state.copyWith(activeOverlay: ActiveOverlay.none);
    notifyListeners();
  }

  Future<bool> addVariantToQueue(int index) async {
    if (_state.isAddingToQueue) return false;
    if (index < 0 || index >= variants.length) return false;

    _state = _state.copyWith(isAddingToQueue: true, clearError: true);
    notifyListeners();

    try {
      final variant = variants[index];
      final queueSizeBefore = _queueManager.state.queue.length;
      _queueManager.addToQueue(variant, system, targetFolder, autoExtract: autoExtract);
      final actuallyAdded = _queueManager.state.queue.length > queueSizeBefore;
      await Future.delayed(const Duration(milliseconds: 300));
      await checkInstallationStatus();
      return actuallyAdded;
    } catch (e) {
      _state = _state.copyWith(error: getUserFriendlyError(e));
      notifyListeners();
      return false;
    } finally {
      _state = _state.copyWith(isAddingToQueue: false);
      notifyListeners();
    }
  }

  Future<void> performAction() async {
    if (_state.isOverlayOpen) return;
    if (variants.length > 1) {
      openVariantPicker();
    } else if (_state.isVariantInstalled) {
      showDeleteDialog();
    } else {
      if (isLocalOnly) return;
      final success = await addToQueue();
      if (success) onAddedToQueue?.call();
    }
  }
}
