import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/config/app_config.dart';
import '../models/config/source.dart';
import '../models/config/system_config.dart';
import '../models/config/provider_config.dart';
import '../models/system_model.dart';
import 'config_storage_service.dart';
import 'database_service.dart';
import 'romm_pairing_service.dart';
import 'source_resolver.dart';

/// Snapshot exposed by [SourcesNotifier].
@immutable
class SourcesState {
  const SourcesState({
    required this.sources,
    this.loading = false,
    this.error,
    this.primarySourceId,
    this.activeSourceId,
  });

  static const initial = SourcesState(sources: [], loading: true);

  final List<Source> sources;
  final bool loading;
  final String? error;

  final String? primarySourceId;
  final String? activeSourceId;

  SourcesState copyWith({
    List<Source>? sources,
    bool? loading,
    Object? error = _sentinel,
    String? primarySourceId,
    String? activeSourceId,
  }) {
    return SourcesState(
      sources: sources ?? this.sources,
      loading: loading ?? this.loading,
      error: identical(error, _sentinel) ? this.error : error as String?,
      primarySourceId: primarySourceId ?? this.primarySourceId,
      activeSourceId: activeSourceId ?? this.activeSourceId,
    );
  }

  static const _sentinel = Object();
}

/// Owns the user's [Source] list and persists every mutation to disk via [ConfigStorageService].
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

      final retagged = _retagUnmanagedProviders(_cachedConfig);
      if (!identical(retagged, _cachedConfig)) {
        _cachedConfig = retagged;
        try {
          await _storage.saveConfig(jsonEncode(_cachedConfig.toJson()));
        } catch (e) {
          debugPrint('SourcesNotifier: retag persist failed: $e');
        }
      }

      state = SourcesState(
        sources: List<Source>.unmodifiable(_cachedConfig.sources),
        loading: false,
        primarySourceId: _cachedConfig.primarySourceId,
        activeSourceId: _cachedConfig.activeSourceId,
      );
    } catch (e) {
      debugPrint('SourcesNotifier: bootstrap failed: $e');
      state = state.copyWith(loading: false, error: e.toString());
    } finally {
      if (!_readyCompleter.isCompleted) _readyCompleter.complete();
    }
  }

  /// Creates SystemConfigs for platforms present on [source] that do not have
  /// a system entry in [AppConfig] yet.
  Future<({List<String> names})> ensureSystemsForSource(
    Source source, {
    required String basePath,
  }) async {
    if (source.type != SourceType.romm || source.knownPlatforms.isEmpty) {
      return (names: const <String>[]);
    }
    final existingIds = _cachedConfig.systems.map((s) => s.id).toSet();
    final newSystems = <SystemConfig>[];
    final names = <String>[];

    for (final entry in source.knownPlatforms.entries) {
      final slug = entry.key;
      if (existingIds.contains(slug)) continue;

      final model =
          SystemModel.supportedSystems.where((s) => s.id == slug).firstOrNull;
      final name = model?.name ?? slug.toUpperCase();
      final folderName = slug;
      final folder = '$basePath/$folderName';

      newSystems.add(SystemConfig(
        id: slug,
        name: name,
        targetFolder: folder,
        providers: const [],
      ));
      names.add(name);
    }

    if (newSystems.isNotEmpty) {
      await _writeAndPublish(state.sources, addSystems: newSystems);
    }
    return (names: names);
  }

  /// Appends [source] to the sources list, optionally attaching per-system
  /// remote paths via [manualMappings] (systemSlug → remotePath).
  Future<void> addSource(
    Source source, {
    Map<String, String> manualMappings = const {},
    List<SystemConfig> addSystems = const [],
  }) async {
    if (state.sources.any((s) => s.id == source.id)) return;
    final next = [...state.sources, source];
    final addMap = manualMappings.isNotEmpty
        ? {
            source.id: manualMappings,
          }
        : const <String, Map<String, String>>{};
    await _writeAndPublish(next, addMappings: addMap, addSystems: addSystems);
  }

  /// Edits an existing source in place (id must match).
  Future<void> updateSource(Source source) async {
    final idx = state.sources.indexWhere((s) => s.id == source.id);
    if (idx < 0) {
      throw StateError('Unknown source: ${source.id}');
    }
    final next = [...state.sources]..[idx] = source;
    await _writeAndPublish(next);
  }

  /// Replaces [sourceId]'s per-system manual mappings with [mappings]
  Future<void> setManualMappings(
    String sourceId,
    Map<String, String> mappings,
  ) async {
    if (!state.sources.any((s) => s.id == sourceId)) {
      throw StateError('Unknown source: $sourceId');
    }
    final addMap = mappings.isNotEmpty
        ? {sourceId: mappings}
        : const <String, Map<String, String>>{};
    await _writeAndPublish(
      state.sources,
      replaceMappingsForSource: sourceId,
      addMappings: addMap,
    );
  }

  /// Removes [id] from the sources list, drops its per-system mappings,
  /// and purges its cached games from the database.
  Future<void> removeSource(String id) async {
    if (!state.sources.any((s) => s.id == id)) return;
    await _purgeCachedGamesFor(id);

    final next = state.sources.where((s) => s.id != id).toList();

    // Clean up references in other sources' fallback lists
    final cleaned = next.map((s) {
      if (s.fallbackSourceIds.contains(id)) {
        return s.copyWith(
          fallbackSourceIds: s.fallbackSourceIds.where((f) => f != id).toList(),
        );
      }
      return s;
    }).toList();

    final activeWasMe = _cachedConfig.activeSourceId == id;
    final primaryWasMe = _cachedConfig.primarySourceId == id;
    await _writeAndPublish(
      cleaned,
      activeSourceId: activeWasMe ? null : _cachedConfig.activeSourceId,
      setActive: activeWasMe,
      primarySourceId: primaryWasMe ? null : _cachedConfig.primarySourceId,
      setPrimary: primaryWasMe,
    );
  }

  /// Toggles [id]'s enabled state.
  Future<void> setEnabled(String id, bool enabled) async {
    final src = state.sources.firstWhere(
      (s) => s.id == id,
      orElse: () => throw StateError('Unknown source: $id'),
    );
    if (src.enabled == enabled) return;
    await updateSource(src.copyWith(enabled: enabled));
  }

  // --- Fallback Chain Management ---

  /// Appends [fallbackSourceId] to [primarySourceId]'s fallback list.
  Future<void> addFallbackSource(
    String primarySourceId,
    String fallbackSourceId,
  ) async {
    final src = state.sources.firstWhere(
      (s) => s.id == primarySourceId,
      orElse: () => throw StateError('Unknown source: $primarySourceId'),
    );
    if (primarySourceId == fallbackSourceId) return;
    if (!state.sources.any((s) => s.id == fallbackSourceId)) return;
    if (src.fallbackSourceIds.contains(fallbackSourceId)) return;

    final updated = src.copyWith(
      fallbackSourceIds: [...src.fallbackSourceIds, fallbackSourceId],
    );
    await updateSource(updated);
  }

  /// Removes [fallbackSourceId] from [primarySourceId]'s fallback list.
  Future<void> removeFallbackSource(
    String primarySourceId,
    String fallbackSourceId,
  ) async {
    final src = state.sources.firstWhere(
      (s) => s.id == primarySourceId,
      orElse: () => throw StateError('Unknown source: $primarySourceId'),
    );
    if (!src.fallbackSourceIds.contains(fallbackSourceId)) return;

    final updated = src.copyWith(
      fallbackSourceIds:
          src.fallbackSourceIds.where((f) => f != fallbackSourceId).toList(),
    );
    await updateSource(updated);
  }

  /// Reorders [primarySourceId]'s fallback list to match [orderedIds].
  Future<void> reorderFallbackSources(
    String primarySourceId,
    List<String> orderedIds,
  ) async {
    final src = state.sources.firstWhere(
      (s) => s.id == primarySourceId,
      orElse: () => throw StateError('Unknown source: $primarySourceId'),
    );
    final validIds = orderedIds
        .where((id) => id != primarySourceId && state.sources.any((s) => s.id == id))
        .toList();
    final updated = src.copyWith(fallbackSourceIds: validIds);
    await updateSource(updated);
  }

  /// Sets or toggles [fallbackAutoSelect] mode for [primarySourceId].
  Future<void> setFallbackAutoSelect(
    String primarySourceId,
    bool autoSelect,
  ) async {
    final src = state.sources.firstWhere(
      (s) => s.id == primarySourceId,
      orElse: () => throw StateError('Unknown source: $primarySourceId'),
    );
    if (src.fallbackAutoSelect == autoSelect) return;
    final updated = src.copyWith(fallbackAutoSelect: autoSelect);
    await updateSource(updated);
  }

  /// Legacy single fallback setter (maps to fallbackSourceIds).
  Future<void> setFallbackSource(String sourceId, String? fallbackId) async {
    if (fallbackId == null) {
      final src = state.sources.firstWhere((s) => s.id == sourceId);
      await updateSource(src.copyWith(clearFallbacks: true));
    } else {
      await addFallbackSource(sourceId, fallbackId);
    }
  }

  /// Puts the library on one source, or on all of them when [id] is null.
  Future<void> setActiveSource(String? id) async {
    if (id != null && !state.sources.any((s) => s.id == id)) {
      throw StateError('Unknown source: $id');
    }
    if (_cachedConfig.activeSourceId == id) return;
    await _writeAndPublish(state.sources, activeSourceId: id, setActive: true);
  }

  /// Designates the source in use: the one that syncs, and the one the home
  /// screen shows by default.
  Future<void> setPrimarySource(String? id) async {
    if (id != null && !state.sources.any((s) => s.id == id)) {
      throw StateError('Unknown source: $id');
    }
    final wasOff =
        id != null && state.sources.any((s) => s.id == id && !s.enabled);
    final next = wasOff
        ? [
            for (final s in state.sources)
              if (s.id == id) s.copyWith(enabled: true) else s,
          ]
        : state.sources;
    final alreadySet = _cachedConfig.primarySourceId == id &&
        _cachedConfig.activeSourceId == id;
    if (alreadySet && !wasOff) return;
    await _writeAndPublish(
      next,
      activeSourceId: id,
      setActive: true,
      primarySourceId: id,
      setPrimary: true,
    );
  }

  Future<void> _purgeCachedGamesFor(
    String sourceId, {
    Set<String> protectedOwnerIds = const {},
  }) async {
    try {
      final folders = <String, String>{
        for (final s in _cachedConfig.systems) s.id: s.targetFolder,
      };
      await _db.purgeOrDetachSource(
        sourceId,
        systemTargetFolders: folders,
        protectedOwnerIds: protectedOwnerIds,
      );
    } catch (e) {
      debugPrint('SourcesNotifier: cache purge failed for $sourceId: $e');
    }
  }

  /// Caches the platform map a RomM source advertises (slug → numeric platform id).
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

  /// Refreshes an existing source's bearer token + expiry from a fresh [RommPairResult].
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

  /// Bulk replace — used by config import flows.
  Future<void> replaceAll(List<Source> next) async {
    await _writeAndPublish(next);
  }

  /// Persists [next] as the new sources list.
  Future<void> _writeAndPublish(
    List<Source> next, {
    Map<String, Map<String, String>> addMappings = const {},
    String? replaceMappingsForSource,
    List<SystemConfig> addSystems = const [],
    String? activeSourceId,
    bool setActive = false,
    String? primarySourceId,
    bool setPrimary = false,
  }) async {
    AppConfig latest;
    try {
      latest = (await _storage.loadConfig()) ?? _cachedConfig;
    } catch (e) {
      debugPrint('SourcesNotifier: re-read failed, using cache: $e');
      latest = _cachedConfig;
    }

    if (addSystems.isNotEmpty) {
      final existingIds = latest.systems.map((s) => s.id).toSet();
      final truly = addSystems.where((s) => !existingIds.contains(s.id));
      if (truly.isNotEmpty) {
        latest = latest.copyWith(
          systems: [...latest.systems, ...truly],
        );
      }
    }

    if (replaceMappingsForSource != null) {
      latest = latest.copyWith(
        systems: latest.systems.map((s) {
          if (s.manualMappings.isEmpty) return s;
          final filtered = s.manualMappings
              .where((m) => m.sourceId != replaceMappingsForSource)
              .toList(growable: false);
          if (filtered.length == s.manualMappings.length) return s;
          return s.copyWith(manualMappings: filtered);
        }).toList(growable: false),
      );
    }

    if (addMappings.isNotEmpty) {
      latest = latest.copyWith(
        systems: latest.systems.map((s) {
          final extras = <SystemSourceMapping>[];
          for (final entry in addMappings.entries) {
            final sourceId = entry.key;
            final path = entry.value[s.id];
            if (path != null && path.isNotEmpty) {
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

    final rebuiltSystems = latest.systems.map((s) {
      final unmanaged =
          s.providers.where((p) => !p.managedBySource).toList(growable: false);
      final effectiveActive =
          setActive ? activeSourceId : latest.activeSourceId;
      final managed = SourceResolver.providersFor(s, next,
          activeSourceId: effectiveActive);
      final combined = [...unmanaged, ...managed]
        ..sort((a, b) => a.priority.compareTo(b.priority));
      return s.copyWith(providers: combined);
    }).toList(growable: false);

    final updated = latest.copyWith(
      version: AppConfig.currentVersion,
      sources: next,
      activeSourceId: setActive ? activeSourceId : null,
      clearActiveSource: setActive && activeSourceId == null,
      primarySourceId: setPrimary ? primarySourceId : null,
      clearPrimarySource: setPrimary && primarySourceId == null,
      systems: rebuiltSystems,
    );
    try {
      await _storage.saveConfig(jsonEncode(updated.toJson()));
      _cachedConfig = updated;
      state = SourcesState(
        sources: List<Source>.unmodifiable(next),
        loading: false,
        primarySourceId: updated.primarySourceId,
        activeSourceId: updated.activeSourceId,
      );
    } catch (e) {
      debugPrint('SourcesNotifier: persist failed: $e');
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

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

  @visibleForTesting
  AppConfig get debugCachedConfig => _cachedConfig;
}
