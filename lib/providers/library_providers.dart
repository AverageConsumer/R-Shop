import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/database_service.dart';
import '../services/library_sync_service.dart';

final libraryDbProvider = Provider<DatabaseService>((ref) {
  return DatabaseService();
});

final librarySyncServiceProvider =
    StateNotifierProvider<LibrarySyncService, LibrarySyncState>((ref) {
  return LibrarySyncService();
});

/// Bumped when games are saved to DB outside of LibrarySyncService
/// (e.g. by GameListController). Watched by count providers to re-query.
final gameDbChangedProvider = StateProvider<int>((ref) => 0);

/// Whether the last library sync had failures (and is not currently syncing).
final lastSyncHadFailuresProvider = Provider<bool>((ref) {
  final state = ref.watch(librarySyncServiceProvider);
  return !state.isSyncing && state.hadFailures;
});

/// Game counts per system, auto-refreshes when sync starts or completes.
final gameCountsPerSystemProvider = FutureProvider<Map<String, int>>((ref) async {
  // Re-fetch after each system completes sync
  ref.watch(librarySyncServiceProvider.select((s) => s.completedSystems));
  ref.watch(gameDbChangedProvider);
  return ref.read(libraryDbProvider).getGameCountsPerSystem();
});
