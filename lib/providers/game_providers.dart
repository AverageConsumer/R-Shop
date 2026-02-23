import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/config/app_config.dart';
import '../models/config/system_config.dart';
import '../models/game_item.dart';
import '../models/system_model.dart';
import '../services/config_parser.dart';
import '../services/config_storage_service.dart';
import '../services/unified_game_service.dart';

/// Whether the config was recovered from a backup (corrupt primary).
final configRecoveredProvider = StateProvider<bool>((ref) => false);

/// Provides the active AppConfig from the persisted config file.
final bootstrappedConfigProvider = FutureProvider<AppConfig>((ref) async {
  final storage = ConfigStorageService();
  final result = await storage.loadConfigWithRecoveryInfo();
  if (result.wasRecovered) {
    ref.read(configRecoveredProvider.notifier).state = true;
  }
  if (result.config != null) return result.config!;
  return AppConfig.empty;
});

final unifiedGameServiceProvider = Provider<UnifiedGameService>((ref) {
  return UnifiedGameService();
});

final gamesProvider =
    FutureProvider.family<List<GameItem>, SystemConfig>((ref, system) {
  final service = ref.read(unifiedGameServiceProvider);
  return service.fetchGamesForSystem(system, merge: system.mergeMode);
});

/// Systems visible on the home screen.
///
/// Hides consoles that have no providers configured (local-only systems)
/// AND have no local files in their target folder. They reappear once a
/// provider is added or a file is placed in the folder.
final visibleSystemsProvider = FutureProvider<List<SystemModel>>((ref) async {
  final config = await ref.watch(bootstrappedConfigProvider.future);
  
  // If no systems configured at all, return empty
  if (config.systems.isEmpty) return [];

  final configuredIds = config.systems.map((s) => s.id).toSet();
  final configured = SystemModel.supportedSystems
      .where((s) => configuredIds.contains(s.id))
      .toList();

  final visible = <SystemModel>[];
  for (final system in configured) {
    final sysConfig = config.systemById(system.id);
    if (sysConfig == null) continue;

    // Has remote providers configured → always visible
    if (sysConfig.providers.isNotEmpty) {
      visible.add(system);
      continue;
    }

    // Local-only: visible only if targetFolder actually exists and contains ROM files
    final dir = Directory(sysConfig.targetFolder);
    if (await dir.exists()) {
      final romExts = system.romExtensions.map((e) => e.toLowerCase()).toList();
      
      // Standard extra extensions for archives
      romExts.addAll(['.zip', '.rar', '.7z']);

      bool hasRoms = false;
      try {
        await for (final entity in dir.list(followLinks: false).timeout(
          const Duration(seconds: 2),
          onTimeout: (sink) {
            debugPrint('visibleSystemsProvider: timeout scanning '
                '${dir.path}, treating as empty');
            sink.close();
          },
        )) {
          if (entity is File) {
            final name = entity.path.toLowerCase();
            if (romExts.any((ext) => name.endsWith(ext))) {
              hasRoms = true;
              break;
            }
          }
        }
      } catch (e) {
        // Ignore permission or access errors when scanning directory
      }
      
      if (hasRoms) {
        visible.add(system);
      }
    }
  }

  return visible;
});

// ---------------------------------------------------------------------------
// Config import helper
// ---------------------------------------------------------------------------

/// Opens a file picker for JSON files, validates the content, persists it,
/// and invalidates the config provider so the app reloads immediately.
///
/// Returns a record: `cancelled` is true when the user dismissed the picker,
/// `error` is non-null on failure, and both false/null means success.
Future<({bool cancelled, String? error, AppConfig? config})> importConfigFile(WidgetRef ref) async {
  try {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.single.path == null) {
      return (cancelled: true, error: null, config: null);
    }

    final file = File(result.files.single.path!);
    final content = await file.readAsString();

    // Validate & parse JSON structure
    final config = ConfigParser.parse(content);

    // Persist
    await ConfigStorageService().saveConfig(content);

    // Reload
    ref.invalidate(bootstrappedConfigProvider);
    return (cancelled: false, error: null, config: config);
  } on ConfigParseException catch (e) {
    return (cancelled: false, error: e.message, config: null);
  } catch (e) {
    return (cancelled: false, error: 'Import failed: $e', config: null);
  }
}
