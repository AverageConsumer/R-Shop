import 'package:flutter/material.dart';
import '../../models/game_item.dart';
import '../../models/system_model.dart';
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
  GameDetailState _state = const GameDetailState();
  GameDetailState get state => _state;
  GameItem get selectedVariant =>
      variants[_state.selectedIndex.clamp(0, variants.length - 1)];
  int get selectedIndex => _state.selectedIndex;

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

  void selectVariant(int index) {
    if (index >= 0 && index < variants.length) {
      _state = _state.copyWith(
        selectedIndex: index,
        activeOverlay: _state.activeOverlay == ActiveOverlay.tagInfo
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

  void toggleTagInfo() {
    _state = _state.copyWith(
      activeOverlay: _state.showTagInfo ? ActiveOverlay.none : ActiveOverlay.tagInfo,
    );
    notifyListeners();
  }

  void closeTagInfo() {
    _state = _state.copyWith(activeOverlay: ActiveOverlay.none);
    notifyListeners();
  }

  void openDescription() {
    _state = _state.copyWith(activeOverlay: ActiveOverlay.description);
    notifyListeners();
  }

  void closeDescription() {
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
