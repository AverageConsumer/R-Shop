import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/config/app_config.dart';
import '../models/config/system_config.dart';
import '../models/game_item.dart';
import '../models/system_model.dart';
import '../services/config_parser.dart';
import '../services/unified_game_service.dart';
import 'app_providers.dart';
import 'library_providers.dart';

/// Whether the config was recovered from a backup (corrupt primary).
final configRecoveredProvider = StateProvider<bool>((ref) => false);

/// Provides the active AppConfig from the persisted config file.
final bootstrappedConfigProvider = FutureProvider<AppConfig>((ref) async {
  final storage = ref.read(configStorageServiceProvider);
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
/// When [hideEmptyConsolesProvider] is enabled, systems whose game list is
/// empty are filtered out. Otherwise all configured systems are shown.
final visibleSystemsProvider = FutureProvider<List<SystemModel>>((ref) async {
  final config = await ref.watch(bootstrappedConfigProvider.future);

  // If no systems configured at all, return empty
  if (config.systems.isEmpty) return [];

  final configuredIds = config.systems.map((s) => s.id).toSet();
  final configured = SystemModel.supportedSystems
      .where((s) => configuredIds.contains(s.id))
      .toList();

  final hideEmpty = ref.watch(hideEmptyConsolesProvider);

  final visible = <SystemModel>[];
  for (final system in configured) {
    final sysConfig = config.systemById(system.id);
    if (sysConfig == null) continue;

    if (hideEmpty) {
      final db = ref.read(libraryDbProvider);
      final hasGames = await db.hasCache(system.id);
      if (!hasGames) continue;
    }

    visible.add(system);
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
    await ref.read(configStorageServiceProvider).saveConfig(content);

    // Reload
    ref.invalidate(bootstrappedConfigProvider);
    return (cancelled: false, error: null, config: config);
  } on ConfigParseException catch (e) {
    return (cancelled: false, error: e.message, config: null);
  } catch (e) {
    return (cancelled: false, error: 'Import failed: $e', config: null);
  }
}
