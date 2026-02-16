import 'package:flutter/material.dart';
import '../../models/game_item.dart';
import '../../models/system_model.dart';
import '../../services/download_queue_manager.dart';
import '../../services/rom_manager.dart';
import '../../utils/game_metadata.dart';
import 'game_detail_state.dart';

class GameDetailController extends ChangeNotifier {
  final GameItem game;
  final List<GameItem> variants;
  final SystemModel system;
  final String romPath;
  final RomManager _romManager;
  final DownloadQueueManager _queueManager;

  GameDetailState _state = const GameDetailState();
  GameDetailState get state => _state;
  GameItem get selectedVariant => variants[_state.selectedIndex];
  int get selectedIndex => _state.selectedIndex;

  GameDetailController({
    required this.game,
    required this.variants,
    required this.system,
    required this.romPath,
    RomManager? romManager,
    DownloadQueueManager? queueManager,
  })  : _romManager = romManager ?? RomManager(),
        _queueManager = queueManager ?? DownloadQueueManager() {
    checkInstallationStatus();
  }

  void selectVariant(int index) {
    if (index >= 0 && index < variants.length) {
      _state = _state.copyWith(selectedIndex: index, clearTagInfo: true);
      notifyListeners();
    }
  }

  Future<void> checkInstallationStatus() async {
    final status = await _romManager.checkMultipleExists(
      variants,
      system,
      romPath,
    );
    _state = _state.copyWith(installedStatus: status);
    notifyListeners();
  }

  Future<void> addToQueue() async {
    if (_state.isAddingToQueue) return;

    _state = _state.copyWith(isAddingToQueue: true, clearError: true);
    notifyListeners();

    try {
      _queueManager.addToQueue(selectedVariant, system, romPath);
      await Future.delayed(const Duration(milliseconds: 300));
      await checkInstallationStatus();
    } catch (e) {
      _state = _state.copyWith(error: e.toString());
      notifyListeners();
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
      await _romManager.delete(selectedVariant, system, romPath);
      await Future.delayed(const Duration(milliseconds: 300));
      await checkInstallationStatus();
    } catch (e) {
      _state = _state.copyWith(error: e.toString());
    } finally {
      _state = _state.copyWith(isDeleting: false);
      notifyListeners();
    }
  }

  String get cleanTitle => GameMetadata.cleanTitle(game.filename);

  void showDeleteDialog() {
    _state = _state.copyWith(
      showDeleteDialog: true,
      dialogSelection: 0,
    );
    notifyListeners();
  }

  void selectDialogOption(int index) {
    _state = _state.copyWith(dialogSelection: index);
    notifyListeners();
  }

  void cancelDialog() {
    _state = _state.copyWith(clearDialog: true);
    notifyListeners();
  }

  void toggleTagInfo() {
    _state = _state.copyWith(showTagInfo: !_state.showTagInfo);
    notifyListeners();
  }

  void closeTagInfo() {
    _state = _state.copyWith(clearTagInfo: true);
    notifyListeners();
  }

  void performAction() {
    if (_state.isOverlayOpen) return;
    if (_state.isVariantInstalled) {
      showDeleteDialog();
    } else {
      addToQueue();
    }
  }
}
