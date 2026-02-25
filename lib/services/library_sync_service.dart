import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/config/app_config.dart';
import '../models/game_item.dart';
import '../models/system_model.dart';
import '../utils/game_merge_helper.dart';
import 'database_service.dart';
import 'rom_manager.dart';
import 'thumbnail_service.dart';
import 'unified_game_service.dart';

class LibrarySyncState {
  final bool isSyncing;
  final int totalSystems;
  final int completedSystems;
  final String? currentSystem;
  final String? error;
  final Map<String, int> gamesPerSystem;
  final int totalGamesFound;
  final bool isUserTriggered;
  final bool hadFailures;

  const LibrarySyncState({
    this.isSyncing = false,
    this.totalSystems = 0,
    this.completedSystems = 0,
    this.currentSystem,
    this.error,
    this.gamesPerSystem = const {},
    this.totalGamesFound = 0,
    this.isUserTriggered = false,
    this.hadFailures = false,
  });

  LibrarySyncState copyWith({
    bool? isSyncing,
    int? totalSystems,
    int? completedSystems,
    String? currentSystem,
    String? error,
    Map<String, int>? gamesPerSystem,
    int? totalGamesFound,
    bool? isUserTriggered,
    bool? hadFailures,
  }) {
    return LibrarySyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      totalSystems: totalSystems ?? this.totalSystems,
      completedSystems: completedSystems ?? this.completedSystems,
      currentSystem: currentSystem ?? this.currentSystem,
      error: error ?? this.error,
      gamesPerSystem: gamesPerSystem ?? this.gamesPerSystem,
      totalGamesFound: totalGamesFound ?? this.totalGamesFound,
      isUserTriggered: isUserTriggered ?? this.isUserTriggered,
      hadFailures: hadFailures ?? this.hadFailures,
    );
  }
}

/// Manages library synchronization for all configured systems.
///
/// This service uses static [_lastSyncTimes] state and is designed for
/// single-isolate use only. Do not instantiate across multiple isolates.
class LibrarySyncService extends StateNotifier<LibrarySyncState> {
  bool _isCancelled = false;

  static final Map<String, DateTime> _lastSyncTimes = {};
  static const _freshnessDuration = Duration(minutes: 5);

  static bool isFresh(String systemId) {
    final t = _lastSyncTimes[systemId];
    return t != null && DateTime.now().difference(t) < _freshnessDuration;
  }

  static void clearFreshness() => _lastSyncTimes.clear();

  LibrarySyncService() : super(const LibrarySyncState());

  Future<void> syncAll(AppConfig config) async {
    if (state.isSyncing) return;
    if (config.systems.isEmpty) return;

    _isCancelled = false;
    state = LibrarySyncState(
      isSyncing: true,
      totalSystems: config.systems.length,
      completedSystems: 0,
    );

    final db = DatabaseService();
    final gameService = UnifiedGameService();
    var completed = 0;
    var anyFailed = false;

    for (final systemConfig in config.systems) {
      if (_isCancelled) break;

      final systemModel = SystemModel.supportedSystems
          .where((s) => s.id == systemConfig.id)
          .firstOrNull;
      final displayName = systemModel?.name ?? systemConfig.name;

      state = state.copyWith(currentSystem: displayName);

      try {
        if (systemConfig.providers.isEmpty) {
          // Local-only: scan filesystem
          if (systemModel != null) {
            final games = await RomManager.scanLocalGamesIsolate(
              systemModel, systemConfig.targetFolder);
            await db.saveGames(systemConfig.id, games);
          }
        } else {
          // Remote + local merge (same quality as discoverAll)
          final remoteGames = await gameService.fetchGamesForSystem(
            systemConfig, merge: systemConfig.mergeMode);
          final List<GameItem> games;
          if (systemModel != null) {
            final localGames = await RomManager.scanLocalGamesIsolate(
              systemModel, systemConfig.targetFolder);
            games = GameMergeHelper.merge(remoteGames, localGames, systemModel);
          } else {
            games = remoteGames;
          }
          await db.saveGames(systemConfig.id, games);
        }
        _lastSyncTimes[systemConfig.id] = DateTime.now();
      } catch (e) {
        debugPrint('Library sync failed for ${systemConfig.id}: $e');
        final reason = _userFriendlyError(e);
        state = state.copyWith(error: 'Sync failed for $displayName: $reason');
        anyFailed = true;
      }

      completed++;
      state = state.copyWith(completedSystems: completed);
    }

    state = state.copyWith(isSyncing: false, currentSystem: null, hadFailures: anyFailed);

    // Clean orphan thumbnails after sync
    ThumbnailService.cleanOrphans(db).catchError((e) {
      debugPrint('LibrarySyncService: orphan cleanup failed: $e');
    });
  }

  /// Discovers all games across ALL configured systems (including local-only).
  /// Used by the "Scan Library" feature in Settings.
  Future<void> discoverAll(AppConfig config) async {
    if (state.isSyncing) return;
    if (config.systems.isEmpty) return;

    _isCancelled = false;
    state = LibrarySyncState(
      isSyncing: true,
      totalSystems: config.systems.length,
      completedSystems: 0,
      isUserTriggered: true,
    );

    final db = DatabaseService();
    final gameService = UnifiedGameService();
    var completed = 0;
    var totalGames = 0;
    var anyFailed = false;
    final perSystem = <String, int>{};

    for (final systemConfig in config.systems) {
      if (_isCancelled) break;

      final systemModel = SystemModel.supportedSystems
          .where((s) => s.id == systemConfig.id)
          .firstOrNull;
      if (systemModel == null) {
        completed++;
        state = state.copyWith(completedSystems: completed);
        continue;
      }

      final displayName = systemModel.name;
      state = state.copyWith(currentSystem: displayName);

      try {
        final List<GameItem> games;
        if (systemConfig.providers.isEmpty) {
          // Local-only: scan filesystem via isolate
          games = await RomManager.scanLocalGamesIsolate(
            systemModel,
            systemConfig.targetFolder,
          );
        } else {
          // Remote + local merge
          final remoteGames = await gameService.fetchGamesForSystem(
            systemConfig,
            merge: systemConfig.mergeMode,
          );
          final localGames = await RomManager.scanLocalGamesIsolate(
            systemModel,
            systemConfig.targetFolder,
          );
          games = GameMergeHelper.merge(remoteGames, localGames, systemModel);
        }

        await db.saveGames(systemConfig.id, games);
        perSystem[systemConfig.id] = games.length;
        totalGames += games.length;
        _lastSyncTimes[systemConfig.id] = DateTime.now();
      } catch (e) {
        debugPrint('Library discover failed for ${systemConfig.id}: $e');
        perSystem[systemConfig.id] = 0;
        anyFailed = true;
      }

      completed++;
      state = state.copyWith(
        completedSystems: completed,
        gamesPerSystem: Map.of(perSystem),
        totalGamesFound: totalGames,
      );
    }

    // Keep final summary visible (don't reset like syncAll does)
    state = state.copyWith(
      isSyncing: false,
      currentSystem: null,
      hadFailures: anyFailed,
    );

    // Clean orphan thumbnails after discover
    ThumbnailService.cleanOrphans(db).catchError((e) {
      debugPrint('LibrarySyncService: orphan cleanup failed: $e');
    });
  }

  static String _userFriendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('SocketException') || msg.contains('Connection refused')) {
      return 'Server unreachable — check your network connection';
    }
    if (msg.contains('HandshakeException') || msg.contains('CERTIFICATE_VERIFY')) {
      return 'SSL/TLS error — check server certificate';
    }
    if (msg.contains('TimeoutException') || msg.contains('timed out')) {
      return 'Connection timed out';
    }
    if (msg.contains('401') || msg.contains('Unauthorized')) {
      return 'Authentication failed — check credentials';
    }
    if (msg.contains('403') || msg.contains('Forbidden')) {
      return 'Access denied — check permissions';
    }
    if (msg.contains('404') || msg.contains('Not Found')) {
      return 'Resource not found — check URL';
    }
    if (msg.contains('SMB') || msg.contains('smb')) {
      return 'SMB connection failed — check share settings';
    }
    if (msg.contains('FTP') || msg.contains('ftp')) {
      return 'FTP connection failed — check host/credentials';
    }
    // Truncate long error messages
    if (msg.length > 100) return '${msg.substring(0, 100)}…';
    return msg;
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
