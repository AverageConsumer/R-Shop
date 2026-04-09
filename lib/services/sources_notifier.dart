import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/config/app_config.dart';
import '../models/config/source.dart';
import '../models/config/provider_config.dart';
import 'config_storage_service.dart';
import 'database_service.dart';
import 'romm_pairing_service.dart';
import 'source_resolver.dart';

/// Snapshot exposed by [SourcesNotifier]. Loading and error states are
/// modelled explicitly so the UI can show a spinner / retry without
/// hand-rolling its own state machine.
@immutable
class SourcesState {
  const SourcesState({
    required this.sources,
    this.loading = false,
    this.error,
  });

  static const initial = SourcesState(sources: [], loading: true);

  final List<Source> sources;
  final bool loading;
  final String? error;

  SourcesState copyWith({
    List<Source>? sources,
    bool? loading,
    Object? error = _sentinel,
  }) {
    return SourcesState(
      sources: sources ?? this.sources,
      loading: loading ?? this.loading,
      error: identical(error, _sentinel) ? this.error : error as String?,
    );
  }

  static const _sentinel = Object();
}

/// Owns the user's [Source] list and persists every mutation to disk via
/// [ConfigStorageService].
///
/// This notifier is the single write path for sources during the v3
/// transition. It loads the full [AppConfig] on init, isolates the
/// `sources` slice for state, and on every mutation re-serialises the
/// whole config back through the existing atomic-write code (so the
/// legacy `systems`/`providers` half stays consistent at the file
/// level). Once the rest of the app moves off the legacy half, this
/// notifier can become the sole owner of [AppConfig].
class SourcesNotifier extends StateNotifier<SourcesState> {
  SourcesNotifier(this._storage, {DatabaseService? db})
      : _db = db ?? DatabaseService(),
        super(SourcesState.initial) {
    _bootstrap();
  }

  final ConfigStorageService _storage;
  final DatabaseService _db;
  AppConfig _cachedConfig = AppConfig.empty;

  /// Visible for tests so they can await initial load before mutating.
  Future<void> get ready => _readyCompleter.future;
  final _readyCompleter = Completer<void>();

  Future<void> _bootstrap() async {
    try {
      final loaded = await _storage.loadConfig();
      _cachedConfig = loaded ?? AppConfig.empty;

      // One-shot upgrade for users on a v3 config whose system.providers
      // were never tagged with their source id. Without this fix-up the
      // notifier treats them as unmanaged forever, and disabling/removing
      // a source has no effect on what syncAll iterates over. Persist
      // immediately so bootstrappedConfigProvider sees the same view.
      final retagged = _retagUnmanagedProviders(_cachedConfig);
      if (!identical(retagged, _cachedConfig)) {
        _cachedConfig = retagged;
        try {
          await _storage.saveConfig(jsonEncode(_cachedConfig.toJson()));
        } catch (e) {
          debugPrint('SourcesNotifier: retag persist failed: $e');
        }
      }

      // Sync the in-memory snapshot's legacy providers lists with the
      // current sources list using the same managed/unmanaged split as
      // _writeAndPublish. Read-only — never writes back to disk.
      if (_cachedConfig.systems.isNotEmpty) {
        final rebuilt = _cachedConfig.systems.map((s) {
          final unmanaged = s.providers
              .where((p) => !p.managedBySource)
              .toList(growable: false);
          final managed =
              SourceResolver.providersFor(s, _cachedConfig.sources);
          if (unmanaged.isEmpty && managed.isEmpty) return s;
          final combined = [...unmanaged, ...managed]
            ..sort((a, b) => a.priority.compareTo(b.priority));
          return s.copyWith(providers: combined);
        }).toList(growable: false);
        _cachedConfig = _cachedConfig.copyWith(systems: rebuilt);
      }

      state = SourcesState(
        sources: List<Source>.unmodifiable(_cachedConfig.sources),
        loading: false,
      );
    } catch (e) {
      debugPrint('SourcesNotifier: bootstrap failed: $e');
      state = state.copyWith(loading: false, error: e.toString());
    } finally {
      if (!_readyCompleter.isCompleted) _readyCompleter.complete();
    }
  }

  /// Adds a new source. If a source with the same id already exists this
  /// is a no-op (use [updateSource] instead).
  Future<void> addSource(Source source) async {
    if (state.sources.any((s) => s.id == source.id)) return;
    final next = [...state.sources, source];
    await _writeAndPublish(next);
  }

  /// Adds a new manual source together with the per-system path mappings
  /// the user picked in the add screen. Both halves land in the same
  /// atomic write so the resolver immediately produces working providers
  /// for every mapped system on the next rebuild.
  ///
  /// [mappingsBySystemId] is keyed by R-Shop system slug; the value is
  /// the remote path (relative to the source's base) for that system.
  /// Empty paths are dropped.
  Future<void> addSourceWithMappings(
    Source source,
    Map<String, String> mappingsBySystemId,
  ) async {
    if (state.sources.any((s) => s.id == source.id)) return;
    final next = [...state.sources, source];
    final cleaned = <String, String>{
      for (final e in mappingsBySystemId.entries)
        if (e.value.trim().isNotEmpty) e.key: e.value.trim(),
    };
    await _writeAndPublish(
      next,
      addMappings: {source.id: cleaned},
    );
  }

  /// Replaces the source with the same id. Throws [StateError] if the id
  /// is unknown.
  Future<void> updateSource(Source source) async {
    final idx = state.sources.indexWhere((s) => s.id == source.id);
    if (idx < 0) {
      throw StateError('Cannot update unknown source: ${source.id}');
    }
    final next = [...state.sources];
    next[idx] = source;
    await _writeAndPublish(next);
  }

  /// Removes the source with [id]. No-op if it doesn't exist. Also drops
  /// every cached game whose providerConfig references the source so the
  /// system grids stop showing stale entries.
  Future<void> removeSource(String id) async {
    if (!state.sources.any((s) => s.id == id)) return;
    final next = state.sources.where((s) => s.id != id).toList();
    await _writeAndPublish(next);
    await _purgeCachedGamesFor(id);
  }

  /// Toggle helper for the off-switch in the Sources screen. When the
  /// caller disables a source we also drop its cached games — otherwise
  /// the system grids would keep displaying entries from a source the
  /// user just turned off until the next manual rescan.
  Future<void> setEnabled(String id, bool enabled) async {
    final src = state.sources.firstWhere(
      (s) => s.id == id,
      orElse: () => throw StateError('Unknown source: $id'),
    );
    if (src.enabled == enabled) return;
    await updateSource(src.copyWith(enabled: enabled));
    if (!enabled) {
      await _purgeCachedGamesFor(id);
    }
  }

  Future<void> _purgeCachedGamesFor(String sourceId) async {
    try {
      final folders = <String, String>{
        for (final s in _cachedConfig.systems) s.id: s.targetFolder,
      };
      await _db.purgeOrDetachSource(
        sourceId,
        systemTargetFolders: folders,
      );
    } catch (e) {
      debugPrint('SourcesNotifier: cache purge failed for $sourceId: $e');
    }
  }

  /// Caches the platform map a RomM source advertises (slug → numeric
  /// platform id). Called after a successful sync.
  Future<void> updateKnownPlatforms(
    String id,
    Map<String, int> platforms,
  ) async {
    final src = state.sources.firstWhere(
      (s) => s.id == id,
      orElse: () => throw StateError('Unknown source: $id'),
    );
    if (mapEquals(src.knownPlatforms, platforms)) return;
    await updateSource(src.copyWith(knownPlatforms: platforms));
  }

  /// Refreshes an existing source's bearer token + expiry from a fresh
  /// [RommPairResult]. Preserves id, name, manualMappings, priority,
  /// autoMap, enabled, borrowed flag, and (unless [knownPlatforms] is
  /// passed) the previously discovered platform map. Used by the
  /// "Re-pair" action when a borrowed token is about to expire.
  Future<void> refreshTokenFromPair(
    String id,
    RommPairResult result, {
    Map<String, int>? knownPlatforms,
  }) async {
    final src = state.sources.firstWhere(
      (s) => s.id == id,
      orElse: () => throw StateError('Unknown source: $id'),
    );
    final updated = src.copyWith(
      url: result.serverUrl,
      auth: AuthConfig(
        clientToken: result.token,
        clientTokenId: result.tokenId,
        clientTokenExpiresAt: result.expiresAt,
      ),
      tokenExpiresAt: result.expiresAt,
      knownPlatforms: knownPlatforms ?? src.knownPlatforms,
    );
    await updateSource(updated);
  }

  /// Bulk replace — used by config import flows. Skips the diff and
  /// just persists the new list verbatim.
  Future<void> replaceAll(List<Source> next) async {
    await _writeAndPublish(next);
  }

  /// Persists [next] as the new sources list.
  ///
  /// [addMappings] (sourceId → systemSlug → remotePath) lets callers
  /// inject SystemSourceMapping entries into the systems list as part of
  /// the same atomic write. Used by [addSourceWithMappings] so a manual
  /// source's per-system paths land alongside the source itself.
  Future<void> _writeAndPublish(
    List<Source> next, {
    Map<String, Map<String, String>> addMappings = const {},
  }) async {
    // Re-read the config from disk so any writes that happened outside
    // this notifier (e.g. the onboarding flow adding new systems) are
    // picked up before we touch the file. This prevents the notifier's
    // stale in-memory snapshot from clobbering work done by other code
    // paths.
    AppConfig latest;
    try {
      latest = (await _storage.loadConfig()) ?? _cachedConfig;
    } catch (e) {
      debugPrint('SourcesNotifier: re-read failed, using cache: $e');
      latest = _cachedConfig;
    }

    // Inject any caller-supplied SystemSourceMappings before the rebuild
    // so the resolver picks them up in the same atomic write.
    if (addMappings.isNotEmpty) {
      latest = latest.copyWith(
        systems: latest.systems.map((s) {
          final extras = <SystemSourceMapping>[];
          for (final entry in addMappings.entries) {
            final sourceId = entry.key;
            final path = entry.value[s.id];
            if (path != null && path.isNotEmpty) {
              // Skip if a mapping for this source already exists.
              final exists =
                  s.manualMappings.any((m) => m.sourceId == sourceId);
              if (!exists) {
                extras.add(SystemSourceMapping(
                  sourceId: sourceId,
                  remotePath: path,
                ));
              }
            }
          }
          if (extras.isEmpty) return s;
          return s.copyWith(
            manualMappings: [...s.manualMappings, ...extras],
          );
        }).toList(growable: false),
      );
    }

    // Tracked rebuild: drop every provider previously written by the
    // notifier (managedBySource=true), then re-append the resolver's
    // current output. Unmanaged providers (legacy onboarding entries,
    // local folders, manually configured providers) survive untouched —
    // they were not put there by us so we have no business removing them.
    final rebuiltSystems = latest.systems.map((s) {
      final unmanaged =
          s.providers.where((p) => !p.managedBySource).toList(growable: false);
      final managed = SourceResolver.providersFor(s, next);
      // NB: do NOT early-return when both lists are empty — that would
      // leave the system's old providers in place after a disable, which
      // is exactly the bug where syncAll keeps hitting a turned-off
      // source. Always rewrite providers to the (possibly empty) combo.
      final combined = [...unmanaged, ...managed]
        ..sort((a, b) => a.priority.compareTo(b.priority));
      return s.copyWith(providers: combined);
    }).toList(growable: false);

    final updated = latest.copyWith(
      version: AppConfig.currentVersion,
      sources: next,
      systems: rebuiltSystems,
    );
    try {
      await _storage.saveConfig(jsonEncode(updated.toJson()));
      _cachedConfig = updated;
      state = SourcesState(
        sources: List<Source>.unmodifiable(next),
        loading: false,
      );
    } catch (e) {
      debugPrint('SourcesNotifier: persist failed: $e');
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  /// Walks every system's provider list and tags any unmanaged provider
  /// whose connection details match an existing [Source] as belonging to
  /// that source. Used as a one-shot upgrade for v3 configs that were
  /// written before the managedBySource tagging existed; without it, an
  /// untagged provider would survive disable/remove forever.
  AppConfig _retagUnmanagedProviders(AppConfig config) {
    if (config.sources.isEmpty || config.systems.isEmpty) return config;
    var anyChange = false;
    final newSystems = config.systems.map((s) {
      var systemChanged = false;
      final newProviders = s.providers.map((p) {
        if (p.managedBySource) return p;
        for (final source in config.sources) {
          if (_providerMatchesSource(p, source)) {
            systemChanged = true;
            anyChange = true;
            return p.copyWith(
              managedBySource: true,
              sourceId: source.id,
            );
          }
        }
        return p;
      }).toList(growable: false);
      return systemChanged ? s.copyWith(providers: newProviders) : s;
    }).toList(growable: false);
    if (!anyChange) return config;
    return config.copyWith(systems: newSystems);
  }

  static bool _providerMatchesSource(ProviderConfig p, Source s) {
    // Reuse SourceResolver's matching rules.
    switch (s.type) {
      case SourceType.romm:
      case SourceType.web:
        return s.url != null && s.url == p.url;
      case SourceType.smb:
        return s.host == p.host && s.share == p.share && s.port == p.port;
      case SourceType.ftp:
        return s.host == p.host && s.port == p.port;
      case SourceType.local:
        return false;
    }
  }

  /// Visible for tests only — exposes the in-memory AppConfig snapshot so
  /// the suite can verify that legacy `providers` lists are kept in sync
  /// with the canonical sources state after each mutation.
  @visibleForTesting
  AppConfig get debugCachedConfig => _cachedConfig;
}

