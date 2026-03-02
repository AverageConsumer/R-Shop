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
