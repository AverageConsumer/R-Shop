import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/config/app_config.dart';
import 'config_parser.dart';

/// Persists and loads a user-provided config.json from app documents.
class ConfigStorageService {
  static const _fileName = 'config.json';

  Future<File> _configFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  /// Saves raw JSON content to the persistent config file atomically.
  Future<File> saveConfig(String jsonContent) async {
    final file = await _configFile();
    final tmpFile = File('${file.path}.tmp');
    await tmpFile.writeAsString(jsonContent);
    await tmpFile.rename(file.path);
    return file;
  }

  /// Loads and parses the persisted config.
  /// Returns null if no file exists or if parsing fails.
  Future<AppConfig?> loadConfig() async {
    try {
      final file = await _configFile();
      if (!await file.exists()) return null;
      final content = await file.readAsString();
      return ConfigParser.parse(content);
    } catch (e) {
      debugPrint('Failed to load config: $e');
      return null;
    }
  }

  /// Deletes the persisted config file. Returns true if it was deleted.
  Future<bool> deleteConfig() async {
    try {
      final file = await _configFile();
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Failed to delete config: $e');
      return false;
    }
  }

  /// Quick check whether a saved config exists.
  Future<bool> hasConfig() async {
    final file = await _configFile();
    return file.exists();
  }

  /// Exports the config as a formatted JSON file via the system share sheet.
  Future<void> exportConfig(AppConfig config) async {
    final jsonString =
        const JsonEncoder.withIndent('  ').convert(config.toJson());
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/r_shop_config.json');
    await file.writeAsString(jsonString);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json')],
      subject: 'R-Shop Config',
    );
  }
}
