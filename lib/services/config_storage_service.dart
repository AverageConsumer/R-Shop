import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/config/app_config.dart';
import 'config_parser.dart';

/// Simple async mutex using a Completer chain.
class _AsyncLock {
  Future<void>? _last;

  Future<void Function()> acquire() async {
    final prev = _last;
    final completer = Completer<void>();
    _last = completer.future;
    if (prev != null) await prev;
    bool released = false;
    return () {
      if (!released) {
        released = true;
        completer.complete();
      }
    };
  }
}

/// Persists and loads a user-provided config.json from app documents.
class ConfigStorageService {
  static const _fileName = 'config.json';
  static const _backupFileName = 'config.json.bak';

  final _saveLock = _AsyncLock();
  final Future<Directory> Function() _directoryProvider;

  ConfigStorageService({
    Future<Directory> Function()? directoryProvider,
  }) : _directoryProvider = directoryProvider ?? getApplicationDocumentsDirectory;

  Future<File> _configFile() async {
    final dir = await _directoryProvider();
    return File('${dir.path}/$_fileName');
  }

  Future<File> _backupFile() async {
    final dir = await _directoryProvider();
    return File('${dir.path}/$_backupFileName');
  }

  /// Saves raw JSON content to the persistent config file atomically.
  /// Uses an async lock to prevent interleaved writes.
  Future<File> saveConfig(String jsonContent) async {
    final release = await _saveLock.acquire();
    try {
      final file = await _configFile();

      // Create backup of current config before overwriting
      try {
        if (await file.exists()) {
          final backupFile = await _backupFile();
          await file.copy(backupFile.path);
        }
      } catch (e) {
        debugPrint('ConfigStorage: backup failed (non-fatal): $e');
      }

      final tmpFile = File('${file.path}.${DateTime.now().millisecondsSinceEpoch}.tmp');
      try {
        await tmpFile.writeAsString(jsonContent);
      } catch (e) {
        try { await tmpFile.delete(); } catch (e2) { debugPrint('ConfigStorage: tmp cleanup after write fail: $e2'); }
        rethrow;
      }
      try {
        await tmpFile.rename(file.path);
      } catch (e) {
        try { await tmpFile.delete(); } catch (e2) { debugPrint('ConfigStorage: tmp cleanup after rename fail: $e2'); }
        rethrow;
      }
      return file;
    } finally {
      release();
    }
  }

  /// Loads and parses the persisted config.
  /// Returns null if no file exists or if parsing fails.
  Future<AppConfig?> loadConfig() async {
    final result = await loadConfigWithRecoveryInfo();
    return result.config;
  }

  /// Loads config with recovery metadata.
  /// Returns `wasRecovered: true` if the primary was corrupt and the backup
  /// was used instead.
  Future<({AppConfig? config, bool wasRecovered})> loadConfigWithRecoveryInfo() async {
    try {
      final file = await _configFile();
      if (!await file.exists()) {
        return (config: null, wasRecovered: false);
      }
      final content = await file.readAsString();
      final config = ConfigParser.parse(content);
      return (config: config, wasRecovered: false);
    } catch (e) {
      debugPrint('ConfigStorage: primary config corrupt: $e');
      return _loadFromBackup();
    }
  }

  /// Attempts to recover config from backup file.
  Future<({AppConfig? config, bool wasRecovered})> _loadFromBackup() async {
    try {
      final backup = await _backupFile();
      if (!await backup.exists()) {
        debugPrint('ConfigStorage: no backup file found');
        return (config: null, wasRecovered: false);
      }
      final content = await backup.readAsString();
      final config = ConfigParser.parse(content);

      // Restore backup as primary (under save lock to prevent interleaved writes)
      final release = await _saveLock.acquire();
      try {
        final file = await _configFile();
        await backup.copy(file.path);
      } catch (e) {
        debugPrint('ConfigStorage: recovery copy failed: $e');
        // Delete corrupt primary so next load doesn't get stuck
        try {
          final file = await _configFile();
          if (await file.exists()) await file.delete();
        } catch (e2) {
          debugPrint('ConfigStorage: corrupt file cleanup failed: $e2');
        }
      } finally {
        release();
      }

      debugPrint('ConfigStorage: recovered config from backup');
      return (config: config, wasRecovered: true);
    } catch (e) {
      debugPrint('ConfigStorage: backup recovery failed: $e');
      return (config: null, wasRecovered: false);
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
