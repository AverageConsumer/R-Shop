import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sound_settings.dart';

enum ControllerLayout { nintendo, xbox, playstation }

class StorageService {
  static const _romPathKey = 'rom_path';
  static const _hapticEnabledKey = 'haptic_enabled';
  static const _onboardingCompletedKey = 'onboarding_completed';
  static const _soundSettingsKey = 'sound_settings';
  static const _repoUrlKey = 'repo_url';
  static const _gridColumnsPrefix = 'grid_columns_';
  static const _showFullFilenameKey = 'show_full_filename';
  static const _maxConcurrentDownloadsKey = 'max_concurrent_downloads';
  static const _downloadQueueKey = 'download_queue';
  static const _filterPrefix = 'filters_';
  static const _rommUrlKey = 'romm_url';
  static const _rommAuthKey = 'romm_auth';
  static const _favoritesKey = 'favorite_games';
  static const _xboxLayoutKey = 'xbox_layout'; // legacy bool key
  static const _controllerLayoutKey = 'controller_layout';
  static const _homeLayoutKey = 'home_layout';
  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  String? getRomPath() {
    return _prefs?.getString(_romPathKey);
  }

  Future<void> setRomPath(String path) async {
    await _prefs?.setString(_romPathKey, path);
  }

  String? getRepoUrl() {
    return _prefs?.getString(_repoUrlKey);
  }

  Future<void> setRepoUrl(String url) async {
    await _prefs?.setString(_repoUrlKey, url);
  }

  bool getHapticEnabled() {
    return _prefs?.getBool(_hapticEnabledKey) ?? true;
  }

  Future<void> setHapticEnabled(bool enabled) async {
    await _prefs?.setBool(_hapticEnabledKey, enabled);
  }

  bool getOnboardingCompleted() {
    return _prefs?.getBool(_onboardingCompletedKey) ?? false;
  }

  Future<void> setOnboardingCompleted(bool completed) async {
    await _prefs?.setBool(_onboardingCompletedKey, completed);
  }

  Future<void> resetOnboarding() async {
    await _prefs?.remove(_onboardingCompletedKey);
    await _prefs?.remove(_romPathKey);
    await _prefs?.remove(_repoUrlKey);
  }

  Future<void> resetAll() async {
    await _prefs?.clear();
  }

  SoundSettings getSoundSettings() {
    final json = _prefs?.getString(_soundSettingsKey);
    if (json == null) return const SoundSettings();
    try {
      return SoundSettings.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } catch (_) {
      return const SoundSettings();
    }
  }

  Future<void> setSoundSettings(SoundSettings settings) async {
    await _prefs?.setString(_soundSettingsKey, jsonEncode(settings.toJson()));
  }

  Future<String?> pickFolder() async {
    final status = await Permission.manageExternalStorage.request();
    if (!status.isGranted) {
      return null;
    }

    final result = await FilePicker.platform.getDirectoryPath();
    if (result != null) {
      await setRomPath(result);
    }
    return result;
  }

  int getGridColumns(String systemName) {
    return _prefs?.getInt('$_gridColumnsPrefix$systemName') ?? 4;
  }

  Future<void> setGridColumns(String systemName, int columns) async {
    await _prefs?.setInt('$_gridColumnsPrefix$systemName', columns);
  }

  bool getShowFullFilename() {
    return _prefs?.getBool(_showFullFilenameKey) ?? false;
  }

  Future<void> setShowFullFilename(bool value) async {
    await _prefs?.setBool(_showFullFilenameKey, value);
  }

  // --- Max Concurrent Downloads ---

  int getMaxConcurrentDownloads() =>
      _prefs?.getInt(_maxConcurrentDownloadsKey) ?? 2;

  Future<void> setMaxConcurrentDownloads(int value) async {
    await _prefs?.setInt(_maxConcurrentDownloadsKey, value);
  }

  // --- Download Queue Persistence ---

  String? getDownloadQueue() => _prefs?.getString(_downloadQueueKey);

  Future<void> setDownloadQueue(String json) async {
    await _prefs?.setString(_downloadQueueKey, json);
  }

  Future<void> clearDownloadQueue() async {
    await _prefs?.remove(_downloadQueueKey);
  }

  // --- Filter Persistence ---

  String? getFilters(String systemId) =>
      _prefs?.getString('$_filterPrefix$systemId');

  Future<void> setFilters(String systemId, String json) async {
    await _prefs?.setString('$_filterPrefix$systemId', json);
  }

  Future<void> removeFilters(String systemId) async {
    await _prefs?.remove('$_filterPrefix$systemId');
  }

  // --- Global RomM Connection ---

  String? getRommUrl() => _prefs?.getString(_rommUrlKey);

  Future<void> setRommUrl(String? url) async {
    if (url == null || url.isEmpty) {
      await _prefs?.remove(_rommUrlKey);
    } else {
      await _prefs?.setString(_rommUrlKey, url);
    }
  }

  String? getRommAuth() => _prefs?.getString(_rommAuthKey);

  Future<void> setRommAuth(String? json) async {
    if (json == null) {
      await _prefs?.remove(_rommAuthKey);
    } else {
      await _prefs?.setString(_rommAuthKey, json);
    }
  }

  // --- Favorites Persistence ---

  List<String> getFavorites() {
    return _prefs?.getStringList(_favoritesKey) ?? [];
  }

  Future<void> setFavorites(List<String> favorites) async {
    await _prefs?.setStringList(_favoritesKey, favorites);
  }

  Future<void> toggleFavorite(String gameId) async {
    final favorites = getFavorites();
    if (favorites.contains(gameId)) {
      favorites.remove(gameId);
    } else {
      favorites.add(gameId);
    }
    await _prefs?.setStringList(_favoritesKey, favorites);
  }

  bool isFavorite(String gameId) {
    return getFavorites().contains(gameId);
  }

  // Controller Layout
  ControllerLayout getControllerLayout() {
    final stored = _prefs?.getString(_controllerLayoutKey);
    if (stored != null) {
      return ControllerLayout.values.firstWhere(
        (e) => e.name == stored,
        orElse: () => ControllerLayout.nintendo,
      );
    }
    // Migration: read old bool key
    final oldBool = _prefs?.getBool(_xboxLayoutKey);
    if (oldBool == true) return ControllerLayout.xbox;
    return ControllerLayout.nintendo;
  }

  Future<void> setControllerLayout(ControllerLayout layout) async {
    await _prefs?.setString(_controllerLayoutKey, layout.name);
  }

  // Home Layout
  bool getHomeLayoutIsGrid() {
    return _prefs?.getBool(_homeLayoutKey) ?? false;
  }

  Future<void> setHomeLayoutIsGrid(bool value) async {
    await _prefs?.setBool(_homeLayoutKey, value);
  }
}
