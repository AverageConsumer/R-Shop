import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sound_settings.dart';

class StorageService {
  static const _romPathKey = 'rom_path';
  static const _hapticEnabledKey = 'haptic_enabled';
  static const _onboardingCompletedKey = 'onboarding_completed';
  static const _soundSettingsKey = 'sound_settings';
  static const _repoUrlKey = 'repo_url';
  static const _gridColumnsPrefix = 'grid_columns_';
  static const _showFullFilenameKey = 'show_full_filename';
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
}
