import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/custom_shelf.dart';
import '../models/sound_settings.dart';

enum ControllerLayout { nintendo, xbox, playstation }

class StorageService {
  static const _romPathKey = 'rom_path';
  static const _hapticEnabledKey = 'haptic_enabled';
  static const _onboardingCompletedKey = 'onboarding_completed';
  static const _soundSettingsKey = 'sound_settings';
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
  static const _favoritesVersionKey = 'favorites_version';
  static const _customShelvesKey = 'custom_shelves';
  static const _secureAuthMigratedKey = 'secure_auth_migrated';
  static const _allowNonLanHttpKey = 'allow_non_lan_http';
  SharedPreferences? _prefs;
  final FlutterSecureStorage _secureStorage;

  StorageService({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  // In-memory cache for secure values (avoid async reads on every access)
  String? _cachedRommUrl;
  String? _cachedRommAuth;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _migrateAuthToSecureStorage();
  }

  /// Migrates RomM auth credentials from SharedPreferences to SecureStorage.
  /// Runs once, then sets a flag to skip on subsequent launches.
  Future<void> _migrateAuthToSecureStorage() async {
    final alreadyMigrated = _prefs!.getBool(_secureAuthMigratedKey) ?? false;
    if (!alreadyMigrated) {
      try {
        final oldUrl = _prefs!.getString(_rommUrlKey);
        final oldAuth = _prefs!.getString(_rommAuthKey);
        if (oldUrl != null) {
          await _secureStorage.write(key: _rommUrlKey, value: oldUrl);
          await _prefs!.remove(_rommUrlKey);
        }
        if (oldAuth != null) {
          await _secureStorage.write(key: _rommAuthKey, value: oldAuth);
          await _prefs!.remove(_rommAuthKey);
        }
        await _prefs!.setBool(_secureAuthMigratedKey, true);
        debugPrint('StorageService: migrated RomM auth to secure storage');
      } catch (e) {
        debugPrint('StorageService: secure storage migration failed: $e');
        // Leave old values in place so the app still works
      }
    }

    // Load secure values into cache
    try {
      _cachedRommUrl = await _secureStorage.read(key: _rommUrlKey);
      _cachedRommAuth = await _secureStorage.read(key: _rommAuthKey);

    } catch (e) {
      debugPrint('StorageService: failed to read secure storage: $e');
      // Fallback: try plain SharedPreferences (pre-migration or migration failure)
      _cachedRommUrl = _prefs!.getString(_rommUrlKey);
      _cachedRommAuth = _prefs!.getString(_rommAuthKey);

    }
  }

  void _ensureInitialized() {
    if (_prefs == null) {
      throw StateError('StorageService not initialized. Call init() first.');
    }
  }

  String? getRomPath() {
    _ensureInitialized();
    return _prefs!.getString(_romPathKey);
  }

  Future<void> setRomPath(String path) async {
    _ensureInitialized();
    await _prefs!.setString(_romPathKey, path);
  }

  bool getHapticEnabled() {
    _ensureInitialized();
    return _prefs!.getBool(_hapticEnabledKey) ?? true;
  }

  Future<void> setHapticEnabled(bool enabled) async {
    _ensureInitialized();
    await _prefs!.setBool(_hapticEnabledKey, enabled);
  }

  bool getOnboardingCompleted() {
    _ensureInitialized();
    return _prefs!.getBool(_onboardingCompletedKey) ?? false;
  }

  Future<void> setOnboardingCompleted(bool completed) async {
    _ensureInitialized();
    await _prefs!.setBool(_onboardingCompletedKey, completed);
  }

  Future<void> resetOnboarding() async {
    _ensureInitialized();
    await _prefs!.remove(_onboardingCompletedKey);
    await _prefs!.remove(_romPathKey);
  }

  Future<void> resetAll() async {
    _ensureInitialized();
    await _prefs!.clear();
    try {
      await _secureStorage.deleteAll();
      _cachedRommUrl = null;
      _cachedRommAuth = null;
    } catch (e) {
      debugPrint('StorageService: failed to clear secure storage: $e');
    }
  }

  SoundSettings getSoundSettings() {
    _ensureInitialized();
    final json = _prefs!.getString(_soundSettingsKey);
    if (json == null) return const SoundSettings();
    try {
      return SoundSettings.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('StorageService: sound settings parse failed, using defaults: $e');
      return const SoundSettings();
    }
  }

  Future<void> setSoundSettings(SoundSettings settings) async {
    _ensureInitialized();
    await _prefs!.setString(_soundSettingsKey, jsonEncode(settings.toJson()));
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
    _ensureInitialized();
    return _prefs!.getInt('$_gridColumnsPrefix$systemName') ?? 4;
  }

  Future<void> setGridColumns(String systemName, int columns) async {
    _ensureInitialized();
    await _prefs!.setInt('$_gridColumnsPrefix$systemName', columns);
  }

  bool getShowFullFilename() {
    _ensureInitialized();
    return _prefs!.getBool(_showFullFilenameKey) ?? false;
  }

  Future<void> setShowFullFilename(bool value) async {
    _ensureInitialized();
    await _prefs!.setBool(_showFullFilenameKey, value);
  }

  // --- Max Concurrent Downloads ---

  int getMaxConcurrentDownloads() {
    _ensureInitialized();
    return _prefs!.getInt(_maxConcurrentDownloadsKey) ?? 2;
  }

  Future<void> setMaxConcurrentDownloads(int value) async {
    _ensureInitialized();
    await _prefs!.setInt(_maxConcurrentDownloadsKey, value);
  }

  // --- Download Queue Persistence ---

  String? getDownloadQueue() {
    _ensureInitialized();
    return _prefs!.getString(_downloadQueueKey);
  }

  Future<void> setDownloadQueue(String json) async {
    _ensureInitialized();
    await _prefs!.setString(_downloadQueueKey, json);
  }

  Future<void> clearDownloadQueue() async {
    _ensureInitialized();
    await _prefs!.remove(_downloadQueueKey);
  }

  // --- Filter Persistence ---

  String? getFilters(String systemId) {
    _ensureInitialized();
    return _prefs!.getString('$_filterPrefix$systemId');
  }

  Future<void> setFilters(String systemId, String json) async {
    _ensureInitialized();
    await _prefs!.setString('$_filterPrefix$systemId', json);
  }

  Future<void> removeFilters(String systemId) async {
    _ensureInitialized();
    await _prefs!.remove('$_filterPrefix$systemId');
  }

  // --- Global RomM Connection (encrypted via SecureStorage) ---

  String? getRommUrl() {
    _ensureInitialized();
    return _cachedRommUrl;
  }

  Future<void> setRommUrl(String? url) async {
    _ensureInitialized();
    if (url == null || url.isEmpty) {
      await _secureStorage.delete(key: _rommUrlKey);
      _cachedRommUrl = null;
    } else {
      await _secureStorage.write(key: _rommUrlKey, value: url);
      _cachedRommUrl = url;
    }
  }

  String? getRommAuth() {
    _ensureInitialized();
    return _cachedRommAuth;
  }

  Future<void> setRommAuth(String? json) async {
    _ensureInitialized();
    if (json == null) {
      await _secureStorage.delete(key: _rommAuthKey);
      _cachedRommAuth = null;
    } else {
      await _secureStorage.write(key: _rommAuthKey, value: json);
      _cachedRommAuth = json;
    }
  }

  // --- Favorites Persistence ---

  int getFavoritesVersion() {
    _ensureInitialized();
    return _prefs!.getInt(_favoritesVersionKey) ?? 0;
  }

  Future<void> setFavoritesVersion(int version) async {
    _ensureInitialized();
    await _prefs!.setInt(_favoritesVersionKey, version);
  }

  List<String> getFavorites() {
    _ensureInitialized();
    return _prefs!.getStringList(_favoritesKey) ?? [];
  }

  Future<void> setFavorites(List<String> favorites) async {
    _ensureInitialized();
    await _prefs!.setStringList(_favoritesKey, favorites);
  }

  Future<void> toggleFavorite(String gameId) async {
    _ensureInitialized();
    final favorites = getFavorites();
    if (favorites.contains(gameId)) {
      favorites.remove(gameId);
    } else {
      favorites.add(gameId);
    }
    await _prefs!.setStringList(_favoritesKey, favorites);
  }

  bool isFavorite(String gameId) {
    return getFavorites().contains(gameId);
  }

  // Controller Layout
  ControllerLayout getControllerLayout() {
    _ensureInitialized();
    final stored = _prefs!.getString(_controllerLayoutKey);
    if (stored != null) {
      return ControllerLayout.values.firstWhere(
        (e) => e.name == stored,
        orElse: () => ControllerLayout.nintendo,
      );
    }
    // Migration: read old bool key
    final oldBool = _prefs!.getBool(_xboxLayoutKey);
    if (oldBool == true) return ControllerLayout.xbox;
    return ControllerLayout.nintendo;
  }

  Future<void> setControllerLayout(ControllerLayout layout) async {
    _ensureInitialized();
    await _prefs!.setString(_controllerLayoutKey, layout.name);
  }

  // Home Layout
  bool getHomeLayoutIsGrid() {
    _ensureInitialized();
    return _prefs!.getBool(_homeLayoutKey) ?? false;
  }

  Future<void> setHomeLayoutIsGrid(bool value) async {
    _ensureInitialized();
    await _prefs!.setBool(_homeLayoutKey, value);
  }

  // --- Custom Shelves ---

  List<CustomShelf> getCustomShelves() {
    _ensureInitialized();
    final json = _prefs!.getString(_customShelvesKey);
    if (json == null) return [];
    try {
      final list = jsonDecode(json) as List<dynamic>;
      return list
          .map((e) => CustomShelf.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('StorageService: custom shelves parse failed: $e');
      return [];
    }
  }

  Future<void> setCustomShelves(List<CustomShelf> shelves) async {
    _ensureInitialized();
    await _prefs!.setString(
      _customShelvesKey,
      jsonEncode(shelves.map((s) => s.toJson()).toList()),
    );
  }

  // --- Non-LAN HTTP ---

  bool getAllowNonLanHttp() {
    _ensureInitialized();
    return _prefs!.getBool(_allowNonLanHttpKey) ?? false;
  }

  Future<void> setAllowNonLanHttp(bool allowed) async {
    _ensureInitialized();
    await _prefs!.setBool(_allowNonLanHttpKey, allowed);
  }
}
