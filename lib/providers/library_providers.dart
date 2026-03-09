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

/// Whether the last library sync had failures (and is not currently syncing).
final lastSyncHadFailuresProvider = Provider<bool>((ref) {
  final state = ref.watch(librarySyncServiceProvider);
  return !state.isSyncing && state.hadFailures;
});

/// Game counts per system, auto-refreshes when sync starts or completes.
final gameCountsPerSystemProvider = FutureProvider<Map<String, int>>((ref) async {
  // Only re-fetch when isSyncing changes (not on every completedSystems++)
  ref.watch(librarySyncServiceProvider.select((s) => s.isSyncing));
  return ref.read(libraryDbProvider).getGameCountsPerSystem();
});
