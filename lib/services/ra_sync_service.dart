import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/game_item.dart';
import '../models/ra_models.dart';
import '../models/system_model.dart';
import '../utils/ra_name_matcher.dart';
import 'config_storage_service.dart';
import 'database_service.dart';
import 'ra_api_service.dart';
import 'ra_hash_service.dart';
import 'rom_manager.dart';
import 'storage_service.dart';

class RaSyncState {
  final bool isSyncing;
  final int totalSystems;
  final int completedSystems;
  final String? currentSystem;
  final String? error;

  const RaSyncState({
    this.isSyncing = false,
    this.totalSystems = 0,
    this.completedSystems = 0,
    this.currentSystem,
    this.error,
  });

  RaSyncState copyWith({
    bool? isSyncing,
    int? totalSystems,
    int? completedSystems,
    String? currentSystem,
    String? error,
    bool clearError = false,
  }) {
    return RaSyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      totalSystems: totalSystems ?? this.totalSystems,
      completedSystems: completedSystems ?? this.completedSystems,
      currentSystem: currentSystem ?? this.currentSystem,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class RaSyncService extends StateNotifier<RaSyncState> {
  static const _freshnessDuration = Duration(hours: 24);

  final RetroAchievementsService _raService;
  final DatabaseService _db;
  final StorageService _storage;
  final ConfigStorageService _configStorage;
  bool _isCancelled = false;

  RaSyncService(this._raService, this._db, this._storage, this._configStorage)
      : super(const RaSyncState());

  /// Syncs RA game catalogs for all RA-enabled configured systems.
  /// Skips systems whose cache is still fresh (< 24h old).
  Future<void> syncAll(List<SystemModel> systems) async {
    if (state.isSyncing) return;

    final apiKey = _storage.getRaApiKey();
    if (apiKey == null || apiKey.isEmpty) return;

    final raSystems =
        systems.where((s) => s.raConsoleId != null).toList();
    if (raSystems.isEmpty) return;

    _isCancelled = false;
    state = RaSyncState(
      isSyncing: true,
      totalSystems: raSystems.length,
    );

    try {
      // Phase 1: Fetch RA game catalogs from API
      for (var i = 0; i < raSystems.length; i++) {
        if (_isCancelled || !mounted) break;

        final system = raSystems[i];
        state = state.copyWith(
          currentSystem: system.name,
          completedSystems: i,
          clearError: true,
        );

        // Check freshness
        if (await _isFresh(system.raConsoleId!)) {
          debugPrint('RetroAchievements: ${system.name} cache is fresh, skipping');
          continue;
        }

        await _syncSystem(system.raConsoleId!, apiKey);
        // Yield to event loop between systems for UI responsiveness
        await Future.delayed(Duration.zero);
      }

      // Phase 2: Match local games against RA catalog
      for (final system in raSystems) {
        if (_isCancelled || !mounted) break;

        state = state.copyWith(currentSystem: '${system.name} (matching)');
        final localGames = await _db.getGames(system.id);
        if (localGames.isNotEmpty) {
          await matchGamesForSystem(
            system.id,
            system.raConsoleId!,
            localGames,
          );
        }
      }

      // Phase 3: Hash-verify installed ROMs (upgrades nameMatch → hashVerified)
      await _hashVerifyInstalled(raSystems, apiKey);

      await _storage.setRaLastSync(DateTime.now());
    } catch (e) {
      debugPrint('RetroAchievements: sync failed: $e');
      if (mounted) {
        state = state.copyWith(error: e.toString());
      }
    } finally {
      if (mounted) {
        state = state.copyWith(
          isSyncing: false,
          completedSystems: state.totalSystems,
          currentSystem: null,
        );
      }
    }
  }

  /// Sync a single system's RA catalog.
  Future<void> _syncSystem(int consoleId, String apiKey) async {
    try {
      final games = await _raService.fetchGameList(
        consoleId,
        apiKey: apiKey,
      );

      if (_isCancelled || !mounted) return;

      debugPrint(
          'RetroAchievements: fetched ${games.length} games for console $consoleId');
      await _db.saveRaGames(consoleId, games);
    } catch (e) {
      debugPrint('RetroAchievements: failed to sync console $consoleId: $e');
      // Continue with other systems
    }
  }

  /// Run name matching for all games in a system.
  /// Heavy name comparison runs in a background isolate to keep UI responsive.
  Future<int> matchGamesForSystem(
    String systemSlug,
    int consoleId,
    List<GameItem> games,
  ) async {
    final apiKey = _storage.getRaApiKey();
    if (apiKey == null || apiKey.isEmpty) return 0;

    final raGames = await _db.getRaGames(consoleId);
    if (raGames.isEmpty) return 0;

    final romNames = await _db.getRaRomNames(consoleId);

    // Run CPU-heavy matching in a background isolate
    final filenames = games.map((g) => g.filename).toList();
    final matches = await compute(
      _matchInIsolate,
      _MatchParams(
        filenames: filenames,
        raGames: raGames,
        romNames: romNames,
      ),
    );

    // Write results to DB on main thread, yielding between batches
    int matchCount = 0;
    final entries = matches.entries.toList();
    for (var i = 0; i < entries.length; i++) {
      if (_isCancelled || !mounted) break;
      await _db.saveRaMatch(entries[i].key, systemSlug, entries[i].value);
      matchCount++;
      // Yield to event loop every 50 writes
      if (i % 50 == 49) await Future.delayed(Duration.zero);
    }

    debugPrint(
        'RetroAchievements: matched $matchCount/${games.length} games for $systemSlug');
    return matchCount;
  }

  /// Phase 3: Hash-verify installed ROMs for systems that support hashing.
  /// Upgrades nameMatch → hashVerified, or discovers matches for ROMs that
  /// name matching missed (e.g. non-English titles).
  Future<void> _hashVerifyInstalled(
    List<SystemModel> systems,
    String apiKey,
  ) async {
    // Load config to get target folders
    final config = await _configStorage.loadConfig();
    if (config == null) return;

    final targetFolders = <String, String>{};
    for (final sys in config.systems) {
      targetFolders[sys.id] = sys.targetFolder;
    }

    for (final system in systems) {
      if (_isCancelled || !mounted) break;

      final hashMethod = RaHashService.getHashMethod(system.id);
      if (hashMethod == null) continue;

      final targetFolder = targetFolders[system.id];
      if (targetFolder == null) continue;

      state = state.copyWith(currentSystem: '${system.name} (verifying)');

      final localGames = await _db.getGames(system.id);
      if (localGames.isEmpty) continue;

      final existingMatches = await _db.getRaMatchesForSystem(system.id);
      int verified = 0;

      for (final game in localGames) {
        if (_isCancelled || !mounted) break;

        // Skip if already hash-verified
        final existing = existingMatches[game.filename];
        if (existing?.type == RaMatchType.hashVerified ||
            existing?.type == RaMatchType.hashIncompatible) {
          continue;
        }

        // Check if file is installed (resolves actual path on disk)
        final filePath = await RomManager.resolveInstalledPath(
            game, system, targetFolder);
        if (filePath == null) continue;

        // Compute hash in isolate
        final hash = await RaHashService.computeHash(filePath, system.id);
        if (hash == null) continue;

        // Look up hash: local DB first, then API
        int? raGameId = await _db.lookupRaGameByHash(hash);
        raGameId ??= await _raService.lookupGameByHash(
          hash,
          apiKey: apiKey,
        );

        if (raGameId != null && raGameId > 0) {
          final raGame = await _db.getRaGame(raGameId);
          final match = raGame != null
              ? RaMatchResult.hashVerified(raGame)
              : RaMatchResult(
                  type: RaMatchType.hashVerified,
                  raGameId: raGameId,
                );
          await _db.saveRaMatch(game.filename, system.id, match);
          verified++;
        } else if (existing == null) {
          // Only mark incompatible if there's no existing name match
          await _db.saveRaMatch(
            game.filename,
            system.id,
            const RaMatchResult.hashIncompatible(),
          );
        }

        // Yield every 10 games (hashing is already async via isolate)
        if (verified % 10 == 9) await Future.delayed(Duration.zero);
      }

      if (verified > 0) {
        debugPrint(
          'RetroAchievements: hash-verified $verified games for ${system.id}',
        );
      }
    }
  }

  void cancel() {
    _isCancelled = true;
  }

  Future<bool> _isFresh(int consoleId) async {
    final db = await _db.database;
    final rows = await db.query(
      'ra_games',
      columns: ['last_updated'],
      where: 'console_id = ?',
      whereArgs: [consoleId],
      limit: 1,
    );
    if (rows.isEmpty) return false;

    final lastUpdated = rows.first['last_updated'] as int;
    final age = DateTime.now().millisecondsSinceEpoch - lastUpdated;
    return age < _freshnessDuration.inMilliseconds;
  }
}

/// Parameters for the isolate matching function.
class _MatchParams {
  final List<String> filenames;
  final List<RaGame> raGames;
  final Map<int, List<String>>? romNames;

  const _MatchParams({
    required this.filenames,
    required this.raGames,
    this.romNames,
  });
}

/// Top-level function for compute() — runs name matching off main isolate.
Map<String, RaMatchResult> _matchInIsolate(_MatchParams params) {
  final results = <String, RaMatchResult>{};
  for (final filename in params.filenames) {
    final match = RaNameMatcher.findBestMatch(
      filename,
      params.raGames,
      romNames: params.romNames,
    );
    if (match != null) {
      results[filename] = match;
    }
  }
  return results;
}
