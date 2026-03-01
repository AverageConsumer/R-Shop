import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ra_models.dart';
import '../models/system_model.dart';
import '../services/database_service.dart';
import '../services/ra_api_service.dart';
import '../services/ra_sync_service.dart';
import '../services/storage_service.dart';
import 'app_providers.dart';

/// Singleton RA API service.
final raApiServiceProvider = Provider<RetroAchievementsService>((ref) {
  return RetroAchievementsService();
});

/// Whether RA is enabled (has credentials + toggle on).
final raEnabledProvider = Provider<bool>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return storage.isRaConfigured;
});

/// RA credentials (reactive read).
final raCredentialsProvider =
    Provider<({String? username, String? apiKey})>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return (username: storage.getRaUsername(), apiKey: storage.getRaApiKey());
});

/// Cached RA match results for a system. Keyed by game filename.
/// Re-fetches when sync completes or [raRefreshSignalProvider] is bumped.
final raMatchesForSystemProvider =
    FutureProvider.family<Map<String, RaMatchResult>, String>(
  (ref, systemSlug) async {
    if (!ref.watch(raEnabledProvider)) return {};
    ref.watch(raRefreshSignalProvider);
    // Re-fetch when sync finishes
    final syncState = ref.watch(raSyncServiceProvider);
    if (syncState.isSyncing) return ref.state.valueOrNull ?? {};
    final db = DatabaseService();
    return db.getRaMatchesForSystem(systemSlug);
  },
);

/// Fetches full achievement list (with user progress if username available).
final raGameProgressProvider =
    FutureProvider.family<RaGameProgress?, int>((ref, raGameId) async {
  final creds = ref.read(raCredentialsProvider);
  if (creds.apiKey == null || creds.apiKey!.isEmpty) return null;

  final service = ref.read(raApiServiceProvider);

  if (creds.username != null && creds.username!.isNotEmpty) {
    return service.fetchUserProgress(
      raGameId,
      username: creds.username!,
      apiKey: creds.apiKey!,
    );
  }

  return service.fetchAchievements(raGameId, apiKey: creds.apiKey!);
});

/// Sync service (StateNotifier) for background RA catalog sync.
final raSyncServiceProvider =
    StateNotifierProvider<RaSyncService, RaSyncState>((ref) {
  return RaSyncService(
    ref.read(raApiServiceProvider),
    DatabaseService(),
    ref.read(storageServiceProvider),
    ref.read(configStorageServiceProvider),
  );
});

/// Signal provider to trigger RA match refresh.
final raRefreshSignalProvider = StateProvider<int>((ref) => 0);

/// Persists mastered status to the local DB and refreshes match providers.
/// Called from UI when [raGameProgressProvider] resolves.
Future<void> persistMasteredStatus(
  WidgetRef ref, {
  required String filename,
  required String systemSlug,
  required bool isMastered,
}) async {
  final db = DatabaseService();
  await db.updateRaMastered(filename, systemSlug, isMastered);
  ref.read(raRefreshSignalProvider.notifier).state++;
}

/// Triggers RA sync if RA is configured and not already syncing.
/// Safe to call multiple times — freshness cache and isSyncing guard prevent
/// redundant work.
void triggerRaSync(
  RaSyncService syncNotifier,
  StorageService storage, {
  bool force = false,
}) {
  if (!storage.getRaEnabled()) return;
  final apiKey = storage.getRaApiKey();
  if (apiKey == null || apiKey.isEmpty) return;

  final raSystems = SystemModel.supportedSystems
      .where((s) => s.raConsoleId != null)
      .toList();
  if (raSystems.isNotEmpty) {
    syncNotifier.syncAll(raSystems, force: force);
  }
}
