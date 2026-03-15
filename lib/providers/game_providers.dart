import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../models/config/app_config.dart';
import '../models/config/system_config.dart';
import '../models/game_item.dart';
import '../models/game_metadata_info.dart';
import '../models/system_model.dart';
import '../services/config_parser.dart';
import '../services/database_service.dart';
import '../services/unified_game_service.dart';
import 'app_providers.dart';
import 'installed_files_provider.dart';
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
  final timeoutSeconds = ref.watch(syncTimeoutProvider);
  return UnifiedGameService(syncTimeout: Duration(seconds: timeoutSeconds));
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

  // Filter to systems that have a valid config entry
  final withConfig = configured
      .where((s) => config.systemById(s.id) != null)
      .toList();

  if (!hideEmpty) return withConfig;

  // Single batch query instead of N individual hasCache() calls
  final db = ref.read(libraryDbProvider);
  final populated = await db.systemsWithCache(
    withConfig.map((s) => s.id).toList(),
  );
  final filtered = withConfig.where((s) => populated.contains(s.id)).toList();

  // Never hide ALL systems — show everything rather than a dead-end empty state
  if (filtered.isEmpty && withConfig.isNotEmpty) return withConfig;

  return filtered;
});

// ---------------------------------------------------------------------------
// Game metadata (RomM / IGDB)
// ---------------------------------------------------------------------------

/// Batch query returning remote and local game counts for every system slug.
/// Remote = DB count (games with a provider_config).
/// Local = filesystem count of ROM files in each system's targetFolder.
final systemSourceCountsProvider =
    FutureProvider<Map<String, ({int remote, int local})>>((ref) async {
  // Re-fetch when sync finishes or files change on disk
  ref.watch(librarySyncServiceProvider.select((s) => s.isSyncing));
  final db = ref.read(libraryDbProvider);
  final remoteCounts = await db.getRemoteGameCountsPerSystem();
  final installed = await ref.watch(installedFilesProvider.future);

  final extsBySystem = {
    for (final s in SystemModel.supportedSystems) s.id: s.romExtensions.toSet(),
  };

  final systemIds = {...remoteCounts.keys, ...installed.bySystem.keys};
  return {
    for (final id in systemIds)
      id: (
        remote: remoteCounts[id] ?? 0,
        local: _countRomFiles(installed.bySystem[id], extsBySystem[id]),
      ),
  };
});

int _countRomFiles(Set<String>? filenames, Set<String>? extensions) {
  if (filenames == null || filenames.isEmpty) return 0;
  if (extensions == null || extensions.isEmpty) return filenames.length;
  return filenames.where((f) => extensions.contains(p.extension(f).toLowerCase())).length;
}

/// Cached game metadata lookup for the detail screen.
final gameMetadataProvider = FutureProvider.autoDispose.family<GameMetadataInfo?,
    ({String filename, String systemSlug})>(
  (ref, params) async {
    final db = DatabaseService();
    return db.getGameMetadata(params.filename, params.systemSlug);
  },
);

/// Metadata lookup across all variants of a grouped game.
/// Returns the first metadata with content found, so grouped games show
/// metadata even when the selected variant has none (e.g. non-RomM source).
/// [filenames] is a '\n'-joined string to ensure stable Riverpod family equality.
final groupMetadataProvider = FutureProvider.autoDispose.family<GameMetadataInfo?,
    ({String filenames, String systemSlug})>(
  (ref, params) async {
    final db = DatabaseService();
    for (final filename in params.filenames.split('\n')) {
      final meta = await db.getGameMetadata(filename, params.systemSlug);
      if (meta != null && meta.hasContent) return meta;
    }
    return null;
  },
);

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
