import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/config/app_config.dart';
import '../models/config/source.dart';
import 'config_storage_service.dart';
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
  SourcesNotifier(this._storage) : super(SourcesState.initial) {
    _bootstrap();
  }

  final ConfigStorageService _storage;
  AppConfig _cachedConfig = AppConfig.empty;

  /// Visible for tests so they can await initial load before mutating.
  Future<void> get ready => _readyCompleter.future;
  final _readyCompleter = Completer<void>();

  Future<void> _bootstrap() async {
    try {
      final loaded = await _storage.loadConfig();
      _cachedConfig = loaded ?? AppConfig.empty;

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

  /// Removes the source with [id]. No-op if it doesn't exist.
  Future<void> removeSource(String id) async {
    if (!state.sources.any((s) => s.id == id)) return;
    final next = state.sources.where((s) => s.id != id).toList();
    await _writeAndPublish(next);
  }

  /// Toggle helper for the off-switch in the Sources screen.
  Future<void> setEnabled(String id, bool enabled) async {
    final src = state.sources.firstWhere(
      (s) => s.id == id,
      orElse: () => throw StateError('Unknown source: $id'),
    );
    if (src.enabled == enabled) return;
    await updateSource(src.copyWith(enabled: enabled));
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

  /// Bulk replace — used by config import flows. Skips the diff and
  /// just persists the new list verbatim.
  Future<void> replaceAll(List<Source> next) async {
    await _writeAndPublish(next);
  }

  Future<void> _writeAndPublish(List<Source> next) async {
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

    // Tracked rebuild: drop every provider previously written by the
    // notifier (managedBySource=true), then re-append the resolver's
    // current output. Unmanaged providers (legacy onboarding entries,
    // local folders, manually configured providers) survive untouched —
    // they were not put there by us so we have no business removing them.
    final rebuiltSystems = latest.systems.map((s) {
      final unmanaged =
          s.providers.where((p) => !p.managedBySource).toList(growable: false);
      final managed = SourceResolver.providersFor(s, next);
      if (unmanaged.isEmpty && managed.isEmpty) return s;
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

  /// Visible for tests only — exposes the in-memory AppConfig snapshot so
  /// the suite can verify that legacy `providers` lists are kept in sync
  /// with the canonical sources state after each mutation.
  @visibleForTesting
  AppConfig get debugCachedConfig => _cachedConfig;
}

