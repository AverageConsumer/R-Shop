import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/config/app_config.dart';
import '../models/config/system_config.dart';
import '../models/game_item.dart';
import '../models/system_model.dart';
import '../utils/friendly_error.dart';
import '../utils/game_merge_helper.dart';
import 'database_service.dart';
import 'rom_manager.dart';
import 'storage_service.dart';
import 'thumbnail_service.dart';
import 'unified_game_service.dart';

class LibrarySyncState {
  final bool isSyncing;
  final int totalSystems;
  final int completedSystems;
  final String? currentSystem;
  final Map<String, int> gamesPerSystem;
  final int totalGamesFound;
  final bool isUserTriggered;

  /// Systems that failed during sync, keyed by display name with reason as value.
  final Map<String, String> failedSystems;

  bool get hadFailures => failedSystems.isNotEmpty;

  const LibrarySyncState({
    this.isSyncing = false,
    this.totalSystems = 0,
    this.completedSystems = 0,
    this.currentSystem,
    this.gamesPerSystem = const {},
    this.totalGamesFound = 0,
    this.isUserTriggered = false,
    this.failedSystems = const {},
  });

  LibrarySyncState copyWith({
    bool? isSyncing,
    int? totalSystems,
    int? completedSystems,
    String? currentSystem,
    Map<String, int>? gamesPerSystem,
    int? totalGamesFound,
    bool? isUserTriggered,
    Map<String, String>? failedSystems,
  }) {
    return LibrarySyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      totalSystems: totalSystems ?? this.totalSystems,
      completedSystems: completedSystems ?? this.completedSystems,
      currentSystem: currentSystem ?? this.currentSystem,
      gamesPerSystem: gamesPerSystem ?? this.gamesPerSystem,
      totalGamesFound: totalGamesFound ?? this.totalGamesFound,
      isUserTriggered: isUserTriggered ?? this.isUserTriggered,
      failedSystems: failedSystems ?? this.failedSystems,
    );
  }
}

/// Manages library synchronization for all configured systems.
///
/// This service uses static [_lastSyncTimes] state and is designed for
/// single-isolate use only. Do not instantiate across multiple isolates.
/// The identity resolver: a source owns its own cached library.
String _ownsItself(String sourceId) => sourceId;

class LibrarySyncService extends StateNotifier<LibrarySyncState> {
  bool _isCancelled = false;
  Completer<void>? _syncCompleter;

  /// Queue of system IDs waiting to be synced (user-triggered only).
  final List<String> _pendingQueue = [];

  /// True when a queue-based sync (from [syncSystem]) is active.
  /// Used to distinguish from bulk syncs (syncAll/syncSmart/discoverAll).
  bool _isQueueActive = false;

  /// Whether the current sync was started by [syncSystem] and accepts queuing.
  bool get isQueueSync => _isQueueActive;

  /// Returns a Future that completes when the current sync operation finishes.
  /// Resolves immediately if no sync is in progress.
  Future<void> waitForCompletion() => _syncCompleter?.future ?? Future.value();

  static final Map<String, DateTime> _lastSyncTimes = {};
  static const _freshnessDuration = Duration(minutes: 5);

  static bool isFresh(String systemId) {
    final t = _lastSyncTimes[systemId];
    return t != null && DateTime.now().difference(t) < _freshnessDuration;
  }

  static void clearFreshness() => _lastSyncTimes.clear();

  /// The system ID currently being synced, or null if idle / between systems.
  /// Used by GameListController to avoid competing fetches.
  static String? _currentlySyncingSystemId;
  static bool isSyncingSystem(String systemId) =>
      _currentlySyncingSystemId == systemId;

  LibrarySyncService() : super(const LibrarySyncState());

  Future<void> syncAll(
    AppConfig config, {
    Duration? syncTimeout,
    StorageService? storageService,
  }) async {
    if (state.isSyncing) return;
    if (config.systems.isEmpty) return;

    _isCancelled = false;
    _syncCompleter = Completer<void>();
    state = LibrarySyncState(
      isSyncing: true,
      totalSystems: config.systems.length,
      completedSystems: 0,
      isUserTriggered: true,
    );

    final db = DatabaseService();
    final gameService = UnifiedGameService(syncTimeout: syncTimeout);
    var completed = 0;
    final failures = <String, String>{};
    final perSystem = <String, int>{};
    var totalGames = 0;

    for (final systemConfig in config.systems) {
      if (_isCancelled) break;

      final systemModel = SystemModel.supportedSystems
          .where((s) => s.id == systemConfig.id)
          .firstOrNull;
      final displayName = systemModel?.name ?? systemConfig.name;

      state = state.copyWith(currentSystem: displayName);
      _currentlySyncingSystemId = systemConfig.id;

      try {
        if (systemConfig.providers.isEmpty) {
          // Local-only: scan filesystem
          if (systemModel != null) {
            final games = await RomManager.scanLocalGamesIsolate(
              systemModel, systemConfig.targetFolder);
            await db.saveGamesByRoute(systemConfig.id, games,
            forceDeleteOrphans: true, cacheOwnerOf: config.cacheOwnerIdFor);
            perSystem[systemConfig.id] = games.length;
            totalGames += games.length;
          }
        } else {
          // Remote + local merge (same quality as discoverAll)
          final remoteGames = await gameService.fetchGamesForSystem(
            systemConfig);
          final List<GameItem> games;
          if (systemModel != null) {
            final localGames = await RomManager.scanLocalGamesIsolate(
              systemModel, systemConfig.targetFolder);
            games = GameMergeHelper.merge(remoteGames, localGames, systemModel);
          } else {
            games = remoteGames;
          }
          await db.saveGamesByRoute(systemConfig.id, games,
              deleteOrphans: true, forceDeleteOrphans: true,
              cacheOwnerOf: config.cacheOwnerIdFor);
          perSystem[systemConfig.id] = games.length;
          totalGames += games.length;
        }
        _lastSyncTimes[systemConfig.id] = DateTime.now();
        storageService?.setLastSyncTime(systemConfig.id, DateTime.now());
      } catch (e) {
        debugPrint('Library sync failed for ${systemConfig.id}: $e');
        failures[displayName] = _userFriendlyError(e);
        // Remote failed — try to at least save local games so the system isn't empty
        if (systemModel != null && systemConfig.providers.isNotEmpty) {
          try {
            final localGames = await RomManager.scanLocalGamesIsolate(
              systemModel, systemConfig.targetFolder);
            if (localGames.isNotEmpty) {
              await db.saveGamesByRoute(systemConfig.id, localGames,
                cacheOwnerOf: config.cacheOwnerIdFor);
              perSystem[systemConfig.id] = localGames.length;
              totalGames += localGames.length;
              debugPrint('LibrarySync: saved ${localGames.length} local fallback games for ${systemConfig.id}');
            }
          } catch (localErr) {
            debugPrint('LibrarySync: local fallback failed for ${systemConfig.id}: $localErr');
          }
        }
      } finally {
        _currentlySyncingSystemId = null;
      }

      completed++;
      state = state.copyWith(
        completedSystems: completed,
        gamesPerSystem: Map.of(perSystem),
        totalGamesFound: totalGames,
      );
    }

    state = state.copyWith(
      isSyncing: false,
      currentSystem: null,
      failedSystems: failures,
      gamesPerSystem: Map.of(perSystem),
      totalGamesFound: totalGames,
    );
    _syncCompleter?.complete();
    _syncCompleter = null;

    // Clean orphan thumbnails after sync
    ThumbnailService.cleanOrphans(db).catchError((e) {
      debugPrint('LibrarySyncService: orphan cleanup failed: $e');
    });
  }

  /// Smart sync: only syncs systems that need it based on cooldown and autoSync.
  ///
  /// Systems in [forceSystemIds] are always synced (e.g. newly added consoles).
  /// Other systems are skipped if autoSync is false or last sync is within [cooldown].
  Future<void> syncSmart(
    AppConfig config, {
    Duration? syncTimeout,
    Duration cooldown = const Duration(minutes: 60),
    Set<String> forceSystemIds = const {},
    required StorageService storageService,
  }) async {
    if (state.isSyncing) return;
    if (config.systems.isEmpty) return;

    // Filter systems that actually need syncing
    final now = DateTime.now();
    final systemsToSync = config.systems.where((sc) {
      if (forceSystemIds.contains(sc.id)) return true;
      if (!sc.autoSync) return false;
      if (cooldown == Duration.zero) return true;
      final lastSync = storageService.getLastSyncTime(sc.id);
      return lastSync == null || now.difference(lastSync) >= cooldown;
    }).toList();

    if (systemsToSync.isEmpty) {
      debugPrint('LibrarySyncService: all systems fresh, skipping sync');
      return;
    }

    _isCancelled = false;
    _syncCompleter = Completer<void>();
    state = LibrarySyncState(
      isSyncing: true,
      totalSystems: systemsToSync.length,
      completedSystems: 0,
    );

    final db = DatabaseService();
    final gameService = UnifiedGameService(syncTimeout: syncTimeout);
    var completed = 0;
    final failures = <String, String>{};
    final perSystem = <String, int>{};
    var totalGames = 0;

    for (final systemConfig in systemsToSync) {
      if (_isCancelled) break;

      final systemModel = SystemModel.supportedSystems
          .where((s) => s.id == systemConfig.id)
          .firstOrNull;
      final displayName = systemModel?.name ?? systemConfig.name;

      state = state.copyWith(currentSystem: displayName);
      _currentlySyncingSystemId = systemConfig.id;

      try {
        if (systemConfig.providers.isEmpty) {
          if (systemModel != null) {
            final games = await RomManager.scanLocalGamesIsolate(
              systemModel, systemConfig.targetFolder);
            await db.saveGamesByRoute(systemConfig.id, games,
            forceDeleteOrphans: true, cacheOwnerOf: config.cacheOwnerIdFor);
            perSystem[systemConfig.id] = games.length;
            totalGames += games.length;
          }
        } else {
          final remoteGames = await gameService.fetchGamesForSystem(
            systemConfig);
          final List<GameItem> games;
          if (systemModel != null) {
            final localGames = await RomManager.scanLocalGamesIsolate(
              systemModel, systemConfig.targetFolder);
            games = GameMergeHelper.merge(remoteGames, localGames, systemModel);
          } else {
            games = remoteGames;
          }
          await db.saveGamesByRoute(systemConfig.id, games, deleteOrphans: true,
              cacheOwnerOf: config.cacheOwnerIdFor);
          perSystem[systemConfig.id] = games.length;
          totalGames += games.length;
        }
        _lastSyncTimes[systemConfig.id] = DateTime.now();
        storageService.setLastSyncTime(systemConfig.id, DateTime.now());
      } catch (e) {
        debugPrint('Library sync failed for ${systemConfig.id}: $e');
        failures[displayName] = _userFriendlyError(e);
        if (systemModel != null && systemConfig.providers.isNotEmpty) {
          try {
            final localGames = await RomManager.scanLocalGamesIsolate(
              systemModel, systemConfig.targetFolder);
            if (localGames.isNotEmpty) {
              await db.saveGamesByRoute(systemConfig.id, localGames,
                cacheOwnerOf: config.cacheOwnerIdFor);
              perSystem[systemConfig.id] = localGames.length;
              totalGames += localGames.length;
              debugPrint('LibrarySync: saved ${localGames.length} local fallback games for ${systemConfig.id}');
            }
          } catch (localErr) {
            debugPrint('LibrarySync: local fallback failed for ${systemConfig.id}: $localErr');
          }
        }
      } finally {
        _currentlySyncingSystemId = null;
      }

      completed++;
      state = state.copyWith(
        completedSystems: completed,
        gamesPerSystem: Map.of(perSystem),
        totalGamesFound: totalGames,
      );
    }

    state = state.copyWith(
      isSyncing: false,
      currentSystem: null,
      failedSystems: failures,
      gamesPerSystem: Map.of(perSystem),
      totalGamesFound: totalGames,
    );
    _syncCompleter?.complete();
    _syncCompleter = null;

    ThumbnailService.cleanOrphans(db).catchError((e) {
      debugPrint('LibrarySyncService: orphan cleanup failed: $e');
    });
  }

  /// Discovers all games across ALL configured systems (including local-only).
  /// Used by the "Scan Library" feature in Settings.
  Future<void> discoverAll(AppConfig config, {Duration? syncTimeout}) async {
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
    final gameService = UnifiedGameService(syncTimeout: syncTimeout);
    var completed = 0;
    var totalGames = 0;
    final failures = <String, String>{};
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
      _currentlySyncingSystemId = systemConfig.id;

      try {
        final List<GameItem> games;
        if (systemConfig.providers.isEmpty) {
          // Local-only: scan filesystem via isolate
          games = await RomManager.scanLocalGamesIsolate(
            systemModel,
            systemConfig.targetFolder,
          );
          await db.saveGamesByRoute(systemConfig.id, games,
            forceDeleteOrphans: true, cacheOwnerOf: config.cacheOwnerIdFor);
        } else {
          // Remote + local merge
          final remoteGames = await gameService.fetchGamesForSystem(
            systemConfig,
          );
          final localGames = await RomManager.scanLocalGamesIsolate(
            systemModel,
            systemConfig.targetFolder,
          );
          games = GameMergeHelper.merge(remoteGames, localGames, systemModel);
          await db.saveGamesByRoute(systemConfig.id, games, deleteOrphans: true,
              cacheOwnerOf: config.cacheOwnerIdFor);
        }

        perSystem[systemConfig.id] = games.length;
        totalGames += games.length;
        _lastSyncTimes[systemConfig.id] = DateTime.now();
      } catch (e) {
        debugPrint('Library discover failed for ${systemConfig.id}: $e');
        failures[displayName] = _userFriendlyError(e);
        if (systemConfig.providers.isNotEmpty) {
          try {
            final localGames = await RomManager.scanLocalGamesIsolate(
              systemModel, systemConfig.targetFolder);
            if (localGames.isNotEmpty) {
              await db.saveGamesByRoute(systemConfig.id, localGames,
                cacheOwnerOf: config.cacheOwnerIdFor);
              perSystem[systemConfig.id] = localGames.length;
              totalGames += localGames.length;
              debugPrint('LibrarySync: saved ${localGames.length} local fallback games for ${systemConfig.id}');
            }
          } catch (localErr) {
            debugPrint('LibrarySync: local fallback failed for ${systemConfig.id}: $localErr');
          }
        }
      } finally {
        _currentlySyncingSystemId = null;
      }

      completed++;
      state = state.copyWith(
        completedSystems: completed,
        gamesPerSystem: Map.of(perSystem),
        totalGamesFound: totalGames,
        failedSystems: Map.of(failures),
      );
    }

    // Keep final summary visible (don't reset like syncAll does)
    state = state.copyWith(
      isSyncing: false,
      currentSystem: null,
      failedSystems: failures,
    );

    // Clean orphan thumbnails after discover
    ThumbnailService.cleanOrphans(db).catchError((e) {
      debugPrint('LibrarySyncService: orphan cleanup failed: $e');
    });
  }

  /// Syncs a single system (user-triggered). Supports queuing: if a queue sync
  /// is already running, the system is appended to the queue instead of being
  /// rejected. Deletes orphans since this is an explicit action.
  Future<void> syncSystem(
    String systemId,
    AppConfig config, {
    Duration? syncTimeout,
    StorageService? storageService,
  }) async {
    final systemConfig = config.systems
        .where((s) => s.id == systemId)
        .firstOrNull;
    if (systemConfig == null) return;

    // Dedup: don't queue if already syncing or already queued
    if (_currentlySyncingSystemId == systemId) return;
    if (_pendingQueue.contains(systemId)) return;

    // If a queue sync is already running, just enqueue
    if (state.isSyncing && _isQueueActive) {
      _pendingQueue.add(systemId);
      state = state.copyWith(totalSystems: state.totalSystems + 1);
      return;
    }

    // If a bulk sync (syncAll/syncSmart/discoverAll) is running, reject
    if (state.isSyncing) return;

    // Start a new queue sync
    _isCancelled = false;
    _isQueueActive = true;
    _syncCompleter = Completer<void>();
    state = LibrarySyncState(
      isSyncing: true,
      totalSystems: 1,
      completedSystems: 0,
      currentSystem: _displayName(systemId, systemConfig),
      isUserTriggered: true,
    );

    final db = DatabaseService();
    final gameService = UnifiedGameService(syncTimeout: syncTimeout);

    await _syncOneSystem(systemConfig, systemId, db, gameService,
        cacheOwnerOf: config.cacheOwnerIdFor);

    // Process any systems that were queued while the first was syncing
    await _processQueue(config, db, gameService,
        syncTimeout: syncTimeout, storageService: storageService);

    _isQueueActive = false;
    state = state.copyWith(
      isSyncing: false,
      currentSystem: null,
    );
    _syncCompleter?.complete();
    _syncCompleter = null;

    ThumbnailService.cleanOrphans(db).catchError((e) {
      debugPrint('LibrarySyncService: orphan cleanup failed: $e');
    });
  }

  /// Processes queued systems in FIFO order.
  Future<void> _processQueue(
    AppConfig config,
    DatabaseService db,
    UnifiedGameService gameService, {
    Duration? syncTimeout,
    StorageService? storageService,
  }) async {
    while (_pendingQueue.isNotEmpty && !_isCancelled) {
      final nextId = _pendingQueue.removeAt(0);
      final systemConfig = config.systems
          .where((s) => s.id == nextId)
          .firstOrNull;
      if (systemConfig == null) {
        // System removed from config while queued — skip it
        state = state.copyWith(completedSystems: state.completedSystems + 1);
        continue;
      }
      state = state.copyWith(
        currentSystem: _displayName(nextId, systemConfig),
      );
      await _syncOneSystem(systemConfig, nextId, db, gameService,
          cacheOwnerOf: config.cacheOwnerIdFor,
          storageService: storageService);
    }
  }

  /// Syncs one system and updates state accumulators.
  Future<void> _syncOneSystem(
    SystemConfig systemConfig,
    String systemId,
    DatabaseService db,
    UnifiedGameService gameService, {
    StorageService? storageService,
    // Sources the user grouped write into one shared library. Defaulting to
    // "every source owns its own" keeps a caller that has no config working
    // the way it always did.
    String Function(String sourceId) cacheOwnerOf = _ownsItself,
  }) async {
    final systemModel = SystemModel.supportedSystems
        .where((s) => s.id == systemId)
        .firstOrNull;
    final displayName = _displayName(systemId, systemConfig);

    _currentlySyncingSystemId = systemConfig.id;
    try {
      final List<GameItem> games;
      if (systemConfig.providers.isEmpty) {
        if (systemModel != null) {
          games = await RomManager.scanLocalGamesIsolate(
            systemModel, systemConfig.targetFolder);
        } else {
          games = [];
        }
        await db.saveGamesByRoute(systemConfig.id, games,
            forceDeleteOrphans: true, cacheOwnerOf: cacheOwnerOf);
      } else {
        final remoteGames = await gameService.fetchGamesForSystem(
          systemConfig);
        if (systemModel != null) {
          final localGames = await RomManager.scanLocalGamesIsolate(
            systemModel, systemConfig.targetFolder);
          games = GameMergeHelper.merge(remoteGames, localGames, systemModel);
        } else {
          games = remoteGames;
        }
        await db.saveGamesByRoute(systemConfig.id, games,
            deleteOrphans: true,
            forceDeleteOrphans: true,
            cacheOwnerOf: cacheOwnerOf);
      }

      final perSystem = Map<String, int>.of(state.gamesPerSystem);
      perSystem[systemConfig.id] = games.length;
      state = state.copyWith(
        gamesPerSystem: perSystem,
        totalGamesFound: state.totalGamesFound + games.length,
      );
      _lastSyncTimes[systemConfig.id] = DateTime.now();
      storageService?.setLastSyncTime(systemConfig.id, DateTime.now());
    } catch (e) {
      debugPrint('Library sync failed for $systemId: $e');
      final failures = Map<String, String>.of(state.failedSystems);
      failures[displayName] = _userFriendlyError(e);
      state = state.copyWith(failedSystems: failures);
      if (systemModel != null && systemConfig.providers.isNotEmpty) {
        try {
          final localGames = await RomManager.scanLocalGamesIsolate(
            systemModel, systemConfig.targetFolder);
          if (localGames.isNotEmpty) {
            await db.saveGamesByRoute(systemConfig.id, localGames,
                cacheOwnerOf: cacheOwnerOf);
            final perSystem = Map<String, int>.of(state.gamesPerSystem);
            perSystem[systemConfig.id] = localGames.length;
            state = state.copyWith(
              gamesPerSystem: perSystem,
              totalGamesFound: state.totalGamesFound + localGames.length,
            );
            debugPrint('LibrarySync: saved ${localGames.length} local fallback games for $systemId');
          }
        } catch (localErr) {
          debugPrint('LibrarySync: local fallback failed for $systemId: $localErr');
        }
      }
    } finally {
      _currentlySyncingSystemId = null;
    }

    state = state.copyWith(completedSystems: state.completedSystems + 1);
  }

  String _displayName(String systemId, SystemConfig systemConfig) {
    return SystemModel.supportedSystems
        .where((s) => s.id == systemId)
        .firstOrNull?.name ?? systemConfig.name;
  }

  static String _userFriendlyError(Object e) =>
      getUserFriendlyError(e, returnRawOnNoMatch: true);

  void cancel() {
    _pendingQueue.clear();
    _isCancelled = true;
  }

  @override
  void dispose() {
    _pendingQueue.clear();
    _isCancelled = true;
    super.dispose();
  }
}
