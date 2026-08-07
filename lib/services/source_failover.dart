import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/config/app_config.dart';
import '../models/config/source.dart';
import 'endpoint_probe_service.dart';
import 'source_resolver.dart';

/// Which source is actually going to be used, and whether that is the one the
/// user picked or a fallback stand-in.
@immutable
class SourceChoice {
  /// The source to sync from and show. Null when there is nothing usable.
  final Source? source;

  /// The primary source the user selected.
  final Source? preferred;

  const SourceChoice({this.source, this.preferred});

  /// True when a fallback stand-in is covering for a preferred source that did not answer.
  bool get isFallback =>
      source != null &&
      preferred != null &&
      source!.id != preferred!.id &&
      !(preferred!.fallbackAutoSelect);

  static const none = SourceChoice();
}

/// Picks the source to use, substituting a fallback source when the preferred one is unreachable.
SourceChoice chooseSource({
  required List<Source> sources,
  required String? activeSourceId,
  required List<String> reachable,
}) {
  Source? byId(String? id) {
    if (id == null) return null;
    for (final s in sources) {
      if (s.id == id) return s;
    }
    return null;
  }

  final selected = byId(activeSourceId);
  if (selected == null || !selected.enabled) return SourceChoice.none;

  final reachableSet = reachable.toSet();

  // Primary source answered
  if (reachableSet.contains(selected.id)) {
    return SourceChoice(source: selected, preferred: selected);
  }

  // Primary source did not answer -> check fallback chain
  if (selected.fallbackAutoSelect) {
    for (final respondedId in reachable) {
      if (selected.fallbackSourceIds.contains(respondedId)) {
        final winner = byId(respondedId);
        if (winner != null && winner.enabled) {
          return SourceChoice(source: winner, preferred: selected);
        }
      }
    }
  } else {
    for (final fbId in selected.fallbackSourceIds) {
      if (reachableSet.contains(fbId)) {
        final winner = byId(fbId);
        if (winner != null && winner.enabled) {
          return SourceChoice(source: winner, preferred: selected);
        }
      }
    }
  }

  // Nothing answered: stay on preference so sync reports error against preferred server.
  return SourceChoice(source: selected, preferred: selected);
}

/// The member of [sources] whose server answers **first**.
Future<String?> firstRespondingSource(
  List<Source> sources, {
  required EndpointProbeService probe,
}) async {
  final entrants = sources.where((s) => s.enabled).toList(growable: false);
  if (entrants.isEmpty) return null;
  if (entrants.length == 1) {
    final ok = (await probe.reachableFor(entrants.first)).isNotEmpty;
    return ok ? entrants.first.id : null;
  }

  final winner = Completer<String?>();
  var pending = entrants.length;
  for (final source in entrants) {
    unawaited(
      probe.reachableFor(source).then(
        (answer) {
          if (answer.isNotEmpty && !winner.isCompleted) {
            winner.complete(source.id);
          }
          if (--pending == 0 && !winner.isCompleted) winner.complete(null);
        },
        onError: (Object e) {
          debugPrint('SourceFailover: probe failed for ${source.id}: $e');
          if (--pending == 0 && !winner.isCompleted) winner.complete(null);
        },
      ),
    );
  }
  return winner.future;
}

/// Probes the selected source and its fallback chain, returning the config to sync with.
Future<({AppConfig config, SourceChoice choice})> resolveForSync({
  required AppConfig config,
  EndpointProbeService? probe,
}) async {
  final activeId = config.primarySourceId ?? config.activeSourceId;
  if (activeId == null) {
    return (config: config, choice: SourceChoice.none);
  }

  final svc = probe ?? EndpointProbeService();
  final selected = config.sourceById(activeId);
  if (selected == null || !selected.enabled) {
    return (config: config, choice: SourceChoice.none);
  }

  final reachable = <String>[];
  if ((await svc.reachableFor(selected)).isNotEmpty) {
    reachable.add(selected.id);
  } else if (selected.fallbackSourceIds.isNotEmpty) {
    final fallbackSources = [
      for (final id in selected.fallbackSourceIds)
        ...config.sources.where((s) => s.id == id && s.enabled),
    ];
    if (selected.fallbackAutoSelect) {
      final winnerId = await firstRespondingSource(fallbackSources, probe: svc);
      if (winnerId != null) reachable.add(winnerId);
    } else {
      for (final fb in fallbackSources) {
        if ((await svc.reachableFor(fb)).isNotEmpty) {
          reachable.add(fb.id);
          break;
        }
      }
    }
  }

  final choice = chooseSource(
    sources: config.sources,
    activeSourceId: activeId,
    reachable: reachable,
  );
  final effective = choice.source?.id ?? activeId;

  return (
    config: withEffectiveSource(config, effective),
    choice: choice,
  );
}

/// Rebuilds every system's provider list as if [effectiveSourceId] were the
/// selected source, without persisting anything.
AppConfig withEffectiveSource(AppConfig config, String? effectiveSourceId) {
  final systems = config.systems.map((s) {
    final unmanaged =
        s.providers.where((p) => !p.managedBySource).toList(growable: false);
    final managed = SourceResolver.providersFor(
      s,
      config.sources,
      activeSourceId: effectiveSourceId,
    );
    final combined = [...unmanaged, ...managed]
      ..sort((a, b) => a.priority.compareTo(b.priority));
    return s.copyWith(providers: combined);
  }).toList(growable: false);
  return config.copyWith(systems: systems);
}
