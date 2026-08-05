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

/// Snapshot exposed by [SourcesNotifier]. Loading and error states are
/// modelled explicitly so the UI can show a spinner / retry without
/// hand-rolling its own state machine.
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

  /// Mirrors of the same two fields on [AppConfig], published here so a screen
  /// can render them the frame the toggle is pressed.
  ///
  /// Reading them back through `bootstrappedConfigProvider` means invalidating
  /// it and waiting for a disk read, during which the old value is still what
  /// comes out — the press looked like it had not registered.
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

      // With more than one source switched on and none of them singled out,
      // the home screen shows all of them merged — a third library that is
      // not on the sources list and that nobody asked for. Land on one.
      // Single-source setups keep the null, which is what they have always
      // had and what "show everything" correctly means there.
      final onCount = _cachedConfig.sources.where((s) => s.enabled).length;
      if (_cachedConfig.activeSourceId == null && onCount > 1) {
        final landOn = _cachedConfig.primarySourceId ??
            _cachedConfig.sources.firstWhere((s) => s.enabled).id;
        _cachedConfig = _cachedConfig.copyWith(activeSourceId: landOn);
        try {
          await _storage.saveConfig(jsonEncode(_cachedConfig.toJson()));
        } catch (e) {
          debugPrint('SourcesNotifier: initial source pick persist failed: $e');
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
              SourceResolver.providersFor(s, _cachedConfig.sources,
                  activeSourceId: _cachedConfig.activeSourceId);
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

  /// Adds a new source. If a source with the same id already exists this
  /// is a no-op (use [updateSource] instead).
  Future<void> addSource(Source source) async {
    if (state.sources.any((s) => s.id == source.id)) return;
    final next = [...state.sources, source];
    await _writeAndPublish(next);
  }

  /// Creates [SystemConfig] entries for any platforms in [source.knownPlatforms]
  /// that don't already have a config. Returns `(ids, names)` of newly
  /// created systems so callers can queue syncs and notify the user.
  ///
  /// Uses [basePath] to build `<basePath>/<systemId>` as the target folder
  /// for each new system (same convention as onboarding).
  Future<({List<String> ids, List<String> names})> ensureSystemsForSource(
    Source source, {
    required String basePath,
  }) async {
    if (source.knownPlatforms.isEmpty) {
      return (ids: const <String>[], names: const <String>[]);
    }

    AppConfig latest;
    try {
      latest = (await _storage.loadConfig()) ?? _cachedConfig;
    } catch (e) {
      debugPrint('SourcesNotifier: re-read failed: $e');
      latest = _cachedConfig;
    }

    final existingIds = latest.systems.map((s) => s.id).toSet();
    final newSystems = <SystemConfig>[];
    final newIds = <String>[];
    final newNames = <String>[];

    for (final systemId in source.knownPlatforms.keys) {
      if (existingIds.contains(systemId)) continue;
      final model = SystemModel.supportedSystems
          .where((s) => s.id == systemId)
          .firstOrNull;
      if (model == null) continue;
      newSystems.add(SystemConfig(
        id: systemId,
        name: model.name,
        targetFolder: '$basePath/$systemId',
        providers: const [],
        autoExtract: model.isZipped,
      ));
      newIds.add(systemId);
      newNames.add(model.name);
    }

    if (newSystems.isEmpty) {
      return (ids: const <String>[], names: const <String>[]);
    }

    // Use _writeAndPublish with the extra systems so SourceResolver
    // builds provider lists for them in the same atomic write.
    await _writeAndPublish(state.sources, addSystems: newSystems);

    return (ids: newIds, names: newNames);
  }

  /// Adds a new manual source together with the per-system path mappings
  /// the user picked in the add screen. Both halves land in the same
  /// atomic write so the resolver immediately produces working providers
  /// for every mapped system on the next rebuild.
  ///
  /// [mappingsBySystemId] is keyed by R-Shop system slug; the value is
  /// the remote path (relative to the source's base) for that system.
  /// Empty paths are dropped.
  /// Replaces every [SystemSourceMapping] for [sourceId] across all
  /// systems with the entries in [mappingsBySystemId]. Empty paths drop
  /// the mapping. Used by the manual-source mapping editor.
  Future<void> setMappingsForSource(
    String sourceId,
    Map<String, String> mappingsBySystemId,
  ) async {
    final cleaned = <String, String>{
      for (final e in mappingsBySystemId.entries)
        if (e.value.trim().isNotEmpty) e.key: e.value.trim(),
    };
    await _writeAndPublish(
      state.sources,
      replaceMappingsForSource: sourceId,
      addMappings: {sourceId: cleaned},
    );
  }

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

  /// Toggle helper for the on/off switch in the Sources screen.
  ///
  /// **Keeps the cached games.** It used to purge them, on the reasoning that
  /// the grids would otherwise keep showing a source you just turned off —
  /// which stopped being true at schema v14, where rows are stored per route
  /// and read back through the system's current providers. A disabled source
  /// is not in those providers, so its rows are simply never queried.
  ///
  /// Purging made off-on cost a full re-sync, which is what the user felt as
  /// a pause on the second press, and it raced: the purge ran in the
  /// background and could delete rows the re-enabled source had just fetched.
  /// [removeSource] still purges — that source is not coming back.
  ///
  /// The one place that reads rows without going through providers is the
  /// library screen, which filters disabled sources out itself.
  Future<void> setEnabled(String id, bool enabled) async {
    final src = state.sources.firstWhere(
      (s) => s.id == id,
      orElse: () => throw StateError('Unknown source: $id'),
    );
    if (src.enabled == enabled) return;
    await updateSource(src.copyWith(enabled: enabled));
  }

  /// Designates [fallbackId] as the stand-in to use when [sourceId] does not
  /// answer — typically an external address paired with an internal one.
  ///
  /// Pass null to clear. Refuses to point a source at itself, which would
  /// make failover a no-op that looks configured.
  ///
  /// Does not purge: naming a fallback changes nothing about what is cached.
  Future<void> setFallbackSource(String sourceId, String? fallbackId) async {
    final src = state.sources.firstWhere(
      (s) => s.id == sourceId,
      orElse: () => throw StateError('Unknown source: $sourceId'),
    );
    if (fallbackId == sourceId) {
      throw ArgumentError('A source cannot fall back on itself: $sourceId');
    }
    if (fallbackId != null && !state.sources.any((s) => s.id == fallbackId)) {
      throw StateError('Unknown fallback source: $fallbackId');
    }
    if (src.fallbackSourceId == fallbackId) return;
    await updateSource(src.copyWith(
      fallbackSourceId: fallbackId,
      clearFallback: fallbackId == null,
    ));
  }

  /// Puts the library on one source, or on all of them when [id] is null.
  ///
  /// Sources are independent libraries **even when two of them point at the
  /// same server** — that is the user's model, not an inference from the URLs.
  /// So this only changes which source is in view and which one a sync talks
  /// to; it deliberately **does not purge cached games**, which is what makes
  /// switching back instant instead of a re-sync. `setEnabled(false)` and
  /// `removeSource` remain the operations that discard a cache.
  Future<void> setActiveSource(String? id) async {
    if (id != null && !state.sources.any((s) => s.id == id)) {
      throw StateError('Unknown source: $id');
    }
    if (_cachedConfig.activeSourceId == id) return;
    // Republish with the same source list: _writeAndPublish rebuilds every
    // system's providers through the resolver, which now filters on the
    // active id, so sync and the game list follow in one step.
    await _writeAndPublish(state.sources, activeSourceId: id, setActive: true);
  }

  /// Designates the source in use: the one that syncs, and the one the home
  /// screen shows by default.
  ///
  /// Also puts it in view and switches it back on if it was off, because "use
  /// this" while it is turned off would designate a library that cannot sync.
  ///
  /// **Clearing does not switch it back off.** Giving up the designation says
  /// nothing about whether you still want the library, and turning something
  /// off nobody asked to turn off is the worse of the two guesses — it would
  /// also discard that source's cached games.
  ///
  /// Purges nothing, for the same reason [setActiveSource] does not.
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

  // --- Routes (endpoints) ---
  //
  // A route change is *not* a source change: same server, same library, only a
  // different way in — possibly one with its own login, since the LAN address
  // and a proxied DDNS name can want different credentials. Every method below
  // goes through [updateSource] and therefore **never calls
  // [_purgeCachedGamesFor]** — dropping the cached games on a route switch
  // would make switching cost a full re-sync, which defeats the point.
  // [setEnabled] and [removeSource] purge; routes must not.

  /// Makes [endpointId] the live route for [sourceId].
  ///
  /// [pin] records it as the user's explicit choice so auto-selection stops
  /// moving it. Pass false when the switch came from a probe.
  Future<void> switchEndpoint(
    String sourceId,
    String endpointId, {
    bool pin = true,
  }) async {
    final src = state.sources.firstWhere(
      (s) => s.id == sourceId,
      orElse: () => throw StateError('Unknown source: $sourceId'),
    );
    final ep = src.endpointById(endpointId);
    if (ep == null) {
      throw StateError('Unknown endpoint $endpointId on source $sourceId');
    }
    if (src.liveEndpoint?.id == endpointId &&
        (!pin || src.pinnedEndpointId == endpointId)) {
      return;
    }
    await updateSource(src.withLiveEndpoint(ep, pin: pin));
  }

  /// Switches between probing for a working route and staying on the pinned
  /// one. Selecting [EndpointSelection.auto] clears the pin.
  Future<void> setEndpointSelection(
    String sourceId,
    EndpointSelection selection,
  ) async {
    final src = state.sources.firstWhere(
      (s) => s.id == sourceId,
      orElse: () => throw StateError('Unknown source: $sourceId'),
    );
    if (src.endpointSelection == selection) return;
    if (selection == EndpointSelection.auto) {
      await updateSource(
        src.copyWith(
          endpointSelection: selection,
          clearPinnedEndpoint: true,
        ),
      );
    } else {
      // Pinning with nothing chosen yet pins whatever is live right now,
      // which is what the user sees and therefore what they mean.
      await updateSource(
        src.copyWith(
          endpointSelection: selection,
          pinnedEndpointId: src.pinnedEndpointId ?? src.liveEndpoint?.id,
        ),
      );
    }
  }

  /// Adds another way to reach [sourceId], optionally with credentials of its
  /// own ([SourceEndpoint.auth]; null means "use the source's login").
  ///
  /// Returns false without changing anything if the source already has a
  /// route to that address — two entries for one address would make the
  /// switcher ambiguous, [Source.liveEndpoint] arbitrary, and therefore which
  /// token gets sent a matter of list order.
  Future<bool> addEndpoint(String sourceId, SourceEndpoint endpoint) async {
    final src = state.sources.firstWhere(
      (s) => s.id == sourceId,
      orElse: () => throw StateError('Unknown source: $sourceId'),
    );
    if (src.endpoints.any((e) => e.sameAddressAs(endpoint))) return false;
    if (src.endpoints.any((e) => e.id == endpoint.id)) return false;
    await updateSource(
      src.copyWith(endpoints: [...src.endpoints, endpoint]),
    );
    return true;
  }

  /// Edits an existing route in place, credentials included. If it is the live
  /// one, the source's connection fields and [Source.auth] follow it, so
  /// editing the address or the login you are currently using takes effect
  /// immediately.
  ///
  /// Returns false without changing anything if the edit would move this route
  /// onto an address another route already occupies — same reason
  /// [addEndpoint] refuses a duplicate.
  Future<bool> updateEndpoint(
    String sourceId,
    SourceEndpoint endpoint,
  ) async {
    final src = state.sources.firstWhere(
      (s) => s.id == sourceId,
      orElse: () => throw StateError('Unknown source: $sourceId'),
    );
    final idx = src.endpoints.indexWhere((e) => e.id == endpoint.id);
    if (idx < 0) {
      throw StateError('Unknown endpoint ${endpoint.id} on source $sourceId');
    }
    final collides = src.endpoints.any(
      (e) => e.id != endpoint.id && e.sameAddressAs(endpoint),
    );
    if (collides) return false;
    final wasLive = src.liveEndpoint?.id == endpoint.id;
    final next = [...src.endpoints]..[idx] = endpoint;
    final updated = src.copyWith(endpoints: next);
    await updateSource(
      wasLive ? updated.withLiveEndpoint(endpoint) : updated,
    );
    return true;
  }

  /// Sets or clears the credentials of a single route.
  ///
  /// Pass null for [auth] to drop the route's own login and go back to the
  /// source's — [SourceEndpoint.copyWith] cannot express that on its own, and
  /// "leave it alone" is not the same request as "stop using it".
  ///
  /// A no-op when the route already has exactly this, so the settings screen
  /// can call it unconditionally. Never purges: credentials do not invalidate
  /// a cached list, and re-scanning the library because a token was rotated is
  /// exactly the cost this feature exists to avoid.
  Future<void> setEndpointAuth(
    String sourceId,
    String endpointId,
    AuthConfig? auth,
  ) async {
    final src = state.sources.firstWhere(
      (s) => s.id == sourceId,
      orElse: () => throw StateError('Unknown source: $sourceId'),
    );
    final ep = src.endpointById(endpointId);
    if (ep == null) {
      throw StateError('Unknown endpoint $endpointId on source $sourceId');
    }
    if (identical(ep.auth, auth)) return;
    await updateEndpoint(
      sourceId,
      ep.copyWith(auth: auth, clearAuth: auth == null),
    );
  }

  /// Removes a route.
  ///
  /// Refuses to remove the last one — a source with no route has no address
  /// at all. If the removed route was live, the first remaining one takes
  /// over; if it was pinned, the pin is cleared rather than left dangling.
  /// Cached games are untouched: the source still exists.
  Future<bool> removeEndpoint(String sourceId, String endpointId) async {
    final src = state.sources.firstWhere(
      (s) => s.id == sourceId,
      orElse: () => throw StateError('Unknown source: $sourceId'),
    );
    if (src.endpoints.length <= 1) return false;
    final remaining =
        src.endpoints.where((e) => e.id != endpointId).toList();
    if (remaining.length == src.endpoints.length) return false;

    final wasLive = src.liveEndpoint?.id == endpointId;
    final wasPinned = src.pinnedEndpointId == endpointId;
    var updated = src.copyWith(
      endpoints: remaining,
      clearPinnedEndpoint: wasPinned,
      endpointSelection:
          wasPinned ? EndpointSelection.auto : src.endpointSelection,
    );
    if (wasLive) {
      updated = updated.withLiveEndpoint(remaining.first);
    }
    await updateSource(updated);
    return true;
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
    String? replaceMappingsForSource,
    List<SystemConfig> addSystems = const [],
    String? activeSourceId,
    bool setActive = false,
    String? primarySourceId,
    bool setPrimary = false,
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

    // Add any new systems (from ensureSystemsForSource) that don't
    // already exist in the config. Must happen before the SourceResolver
    // rebuild so the new systems get their provider lists populated.
    if (addSystems.isNotEmpty) {
      final existingIds = latest.systems.map((s) => s.id).toSet();
      final truly = addSystems.where((s) => !existingIds.contains(s.id));
      if (truly.isNotEmpty) {
        latest = latest.copyWith(
          systems: [...latest.systems, ...truly],
        );
      }
    }

    // Strip out every existing mapping for the targeted source so the
    // mapping editor's "replace all" semantics work cleanly.
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
      final effectiveActive =
          setActive ? activeSourceId : latest.activeSourceId;
      final managed = SourceResolver.providersFor(s, next,
          activeSourceId: effectiveActive);
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

