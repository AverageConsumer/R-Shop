import 'package:flutter/foundation.dart';

import '../models/config/app_config.dart';
import '../models/config/source.dart';
import 'endpoint_probe_service.dart';
import 'source_resolver.dart';

/// Which source is actually going to be used, and whether that is the one the
/// user picked or a stand-in.
@immutable
class SourceChoice {
  /// The source to sync from and show. Null when there is nothing usable.
  final Source? source;

  /// The source the user actually selected. Differs from [source] only when
  /// the preferred one did not answer and its fallback took over.
  final Source? preferred;

  const SourceChoice({this.source, this.preferred});

  /// True when a fallback is standing in for an unreachable preference. The
  /// banner says so, because silently showing a different server's library
  /// would look like games had gone missing.
  bool get isFallback =>
      source != null && preferred != null && source!.id != preferred!.id;

  static const none = SourceChoice();
}

/// Picks the source to use, substituting the fallback when the preferred one
/// is unreachable.
///
/// **A fallback is a temporary stand-in, not a change of preference.** The
/// user chose "the one on my LAN"; being out of the house does not change
/// that. Keeping the preference untouched is what lets the LAN source come
/// back on its own when they walk in the door, instead of leaving them on the
/// external address until they remember to switch back.
///
/// Pure — [reachable] holds the ids the caller has already probed. Callers
/// that have not probed anything should pass every id, which reduces this to
/// "use the preferred source".
SourceChoice chooseSource({
  required List<Source> sources,
  required String? activeSourceId,
  required Set<String> reachable,
}) {
  Source? byId(String? id) {
    if (id == null) return null;
    for (final s in sources) {
      if (s.id == id) return s;
    }
    return null;
  }

  final preferred = byId(activeSourceId);
  // No selection, or a selection that has since been deleted: the caller is
  // showing every source, and failover has nothing to act on.
  if (preferred == null) return SourceChoice.none;

  // A disabled preference is a deliberate off-switch, not an outage.
  if (!preferred.enabled) return SourceChoice.none;

  if (reachable.contains(preferred.id)) {
    return SourceChoice(source: preferred, preferred: preferred);
  }

  final fallback = byId(preferred.fallbackSourceId);
  final usable = fallback != null &&
      fallback.enabled &&
      fallback.id != preferred.id &&
      reachable.contains(fallback.id);
  if (usable) {
    return SourceChoice(source: fallback, preferred: preferred);
  }

  // Neither answered. Stay on the preference so the sync reports a real
  // connection error against the server the user actually asked for —
  // reporting the fallback's error instead would send them debugging the
  // wrong machine.
  return SourceChoice(source: preferred, preferred: preferred);
}

/// Rebuilds every system's provider list as if [effectiveSourceId] were the
/// selected source, without persisting anything.
///
/// This is how failover reaches the sync: the config handed to
/// [LibrarySyncService] is rewritten in memory, so the sync talks to the
/// stand-in while the user's stored preference is left alone. Nothing on disk
/// changes, which is exactly what makes the preferred source resume by itself
/// once it answers again.
///
/// Providers the notifier did not create (`managedBySource == false`) survive
/// untouched — legacy onboarding entries and hand-configured providers were
/// not ours to remove.
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

/// Probes the selected source and, only if needed, its stand-in — then returns
/// the config to actually sync with.
///
/// Deliberately probes at most two servers rather than all of them: the
/// question is "is my source up, and if not can its partner cover", not "which
/// of everything is fastest". Two TCP connects with a short timeout, and none
/// at all when the preference answers first.
Future<({AppConfig config, SourceChoice choice})> resolveForSync({
  required AppConfig config,
  EndpointProbeService? probe,
}) async {
  // Syncs follow the source **in use**, not the one on screen. Browsing over
  // to another library with the triggers is a look, not a decision to start
  // working against that server — and a borrowed library is exactly the kind
  // of thing you look at without wanting the next sync redirected at it.
  // Falls back to the shown source when nothing has been designated, which is
  // both the pre-split behaviour and what a single-source setup wants.
  final activeId = config.primarySourceId ?? config.activeSourceId;
  if (activeId == null) {
    // Nothing designated and showing everything — nothing to fail over between.
    return (config: config, choice: SourceChoice.none);
  }

  final svc = probe ?? EndpointProbeService();
  final byId = {for (final s in config.sources) s.id: s};
  final preferred = byId[activeId];
  if (preferred == null) {
    return (config: config, choice: SourceChoice.none);
  }

  final reachable = <String>{};
  if ((await svc.reachableFor(preferred)).isNotEmpty) {
    reachable.add(preferred.id);
  } else {
    final fb = byId[preferred.fallbackSourceId];
    if (fb != null && (await svc.reachableFor(fb)).isNotEmpty) {
      reachable.add(fb.id);
    }
  }

  final choice = chooseSource(
    sources: config.sources,
    activeSourceId: activeId,
    reachable: reachable,
  );
  final effective = choice.source?.id ?? activeId;
  return (config: withEffectiveSource(config, effective), choice: choice);
}
