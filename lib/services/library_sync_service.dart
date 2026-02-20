import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/config/app_config.dart';
import '../models/system_model.dart';
import 'database_service.dart';
import 'unified_game_service.dart';

class LibrarySyncState {
  final bool isSyncing;
  final int totalSystems;
  final int completedSystems;
  final String? currentSystem;
  final String? error;

  const LibrarySyncState({
    this.isSyncing = false,
    this.totalSystems = 0,
    this.completedSystems = 0,
    this.currentSystem,
    this.error,
  });

  LibrarySyncState copyWith({
    bool? isSyncing,
    int? totalSystems,
    int? completedSystems,
    String? currentSystem,
    String? error,
  }) {
    return LibrarySyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      totalSystems: totalSystems ?? this.totalSystems,
      completedSystems: completedSystems ?? this.completedSystems,
      currentSystem: currentSystem ?? this.currentSystem,
      error: error ?? this.error,
    );
  }
}

class LibrarySyncService extends StateNotifier<LibrarySyncState> {
  bool _isCancelled = false;

  LibrarySyncService() : super(const LibrarySyncState());

  Future<void> syncAll(AppConfig config) async {
    if (state.isSyncing) return;

    // Only sync systems that have remote providers configured
    final syncableSystems = config.systems
        .where((s) => s.providers.isNotEmpty)
        .toList();

    if (syncableSystems.isEmpty) return;

    _isCancelled = false;
    state = LibrarySyncState(
      isSyncing: true,
      totalSystems: syncableSystems.length,
      completedSystems: 0,
    );

    final db = DatabaseService();
    final gameService = UnifiedGameService();
    var completed = 0;

    for (final systemConfig in syncableSystems) {
      if (_isCancelled) break;

      // Resolve display name from SystemModel
      final systemModel = SystemModel.supportedSystems
          .where((s) => s.id == systemConfig.id)
          .firstOrNull;
      final displayName = systemModel?.name ?? systemConfig.name;

      state = state.copyWith(currentSystem: displayName);

      try {
        final games = await gameService.fetchGamesForSystem(
          systemConfig,
          merge: systemConfig.mergeMode,
        );
        await db.saveGames(systemConfig.id, games);
      } catch (e) {
        debugPrint('Library sync failed for ${systemConfig.id}: $e');
        state = state.copyWith(error: 'Sync failed: ${systemConfig.id}');
      }

      completed++;
      state = state.copyWith(completedSystems: completed);
    }

    state = const LibrarySyncState(isSyncing: false);
  }

  void cancel() {
    _isCancelled = true;
  }

  @override
  void dispose() {
    _isCancelled = true;
    super.dispose();
  }
}
