import 'dart:async';

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

  /// The source the choice is measured against.
  ///
  /// For a source that stands alone this is simply the one the user selected.
  /// **Inside a group it is the group's own first choice** — the head of
  /// [SourceGroup.memberIds] — because members of a group are addresses of one
  /// server, so which of them the user happened to have selected is not the
  /// preference; the order they arranged is.
  final Source? preferred;

  /// The group [source] was picked out of, or null when it stands alone.
  ///
  /// Handed back so the home screen can answer "**this group is currently on
  /// which member?**" without re-deriving anything.
  final SourceGroup? group;

  const SourceChoice({this.source, this.preferred, this.group});

  /// True when a stand-in is covering for a preference that did not answer, so
  /// the banner can say so — silently showing a different server's library
  /// would look like games had gone missing.
  ///
  /// **Never true in [SourceGroupMode.auto].** There the user stated no order,
  /// so no member is a substitute for another and warning about a perfectly
  /// normal outcome would train them to ignore the warning.
  bool get isFallback =>
      source != null &&
      preferred != null &&
      source!.id != preferred!.id &&
      group?.mode != SourceGroupMode.auto;

  /// The member each resolved group settled on, keyed by group id — pass
  /// straight to [AppConfig.collapsedSources] so a group's cell names the
  /// server that is really answering.
  Map<String, String> get effectiveMemberByGroupId {
    final g = group;
    final s = source;
    if (g == null || s == null) return const {};
    return {g.id: s.id};
  }

  static const none = SourceChoice();
}

/// Picks the member of [group] to use, given what answered.
///
/// Pure, and the exact analogue of `Source.resolveEndpoint` one level up:
/// routes inside a source, members inside a group.
///
/// [responded] is the ids that answered **in the order they answered**, which
/// is what lets one function serve both modes:
///
/// * [SourceGroupMode.auto] — the first id in [responded] that is a member.
///   "我要先回應的那台": measured, not configured.
/// * [SourceGroupMode.ordered] — the first *member* that is in [responded].
///   "A 通就先用 A，我有順序": the order is the setting, so a member further down
///   never wins by being quicker, only by everything above it being silent.
///
/// Disabled members are skipped in both modes. The eye is an off-switch, and a
/// group must not quietly hand the library to a server the user turned off.
///
/// Null when nothing usable answered — the caller decides what to do with that,
/// and [chooseSource] deliberately stays on the preference so the sync reports a
/// real error against the server the user asked for.
String? chooseGroupMember({
  required SourceGroup group,
  required List<Source> sources,
  required List<String> responded,
}) {
  final byId = {for (final s in sources) s.id: s};
  bool usable(String id) =>
      group.contains(id) && (byId[id]?.enabled ?? false);

  if (group.mode == SourceGroupMode.auto) {
    for (final id in responded) {
      if (usable(id)) return id;
    }
    return null;
  }
  final answered = responded.toSet();
  for (final id in group.memberIds) {
    if (answered.contains(id) && usable(id)) return id;
  }
  return null;
}

/// Picks the source to use, substituting another member of its group when the
/// preferred one is unreachable.
///
/// **A substitution is temporary, not a change of preference.** The user chose
/// "the one on my LAN"; being out of the house does not change that. Keeping
/// the stored preference untouched is what lets the LAN address come back on
/// its own when they walk in the door, instead of leaving them on the external
/// one until they remember to switch back.
///
/// Pure — [reachable] holds the ids the caller has already probed, **in the
/// order they answered**. Callers that have not probed anything should pass
/// every id, which reduces this to "use the preferred source".
///
/// `Source.fallbackSourceId` is **not** consulted: every pairing it expressed
/// is migrated into [AppConfig.sourceGroups] on load
/// ([sourceGroupsFromFallbacks]). Reading both would be two mechanisms racing
/// over one decision.
SourceChoice chooseSource({
  required List<Source> sources,
  required String? activeSourceId,
  required List<String> reachable,
  List<SourceGroup> groups = const [],
}) {
  Source? byId(String? id) {
    if (id == null) return null;
    for (final s in sources) {
      if (s.id == id) return s;
    }
    return null;
  }

  final selected = byId(activeSourceId);
  // No selection, or a selection that has since been deleted: the caller is
  // showing every source, and failover has nothing to act on.
  if (selected == null) return SourceChoice.none;

  // A disabled preference is a deliberate off-switch, not an outage.
  if (!selected.enabled) return SourceChoice.none;

  SourceGroup? group;
  for (final g in groups) {
    if (g.contains(selected.id)) {
      group = g;
      break;
    }
  }

  if (group == null) {
    // Nothing to fail over to. Stay put so a failed sync names the server the
    // user actually asked for.
    return SourceChoice(source: selected, preferred: selected);
  }

  // Inside a group the group's own head is the preference, not whichever
  // member happened to be selected — they are one server either way.
  Source? preferred;
  for (final id in group.memberIds) {
    final s = byId(id);
    if (s != null && s.enabled) {
      preferred = s;
      break;
    }
  }
  preferred ??= selected;

  final winnerId = chooseGroupMember(
    group: group,
    sources: sources,
    responded: reachable,
  );
  final winner = byId(winnerId);
  if (winner == null) {
    // Nothing in the group answered. Stay on the preference rather than
    // reporting some other member's error and sending them to debug the wrong
    // machine.
    return SourceChoice(source: preferred, preferred: preferred, group: group);
  }
  return SourceChoice(source: winner, preferred: preferred, group: group);
}

/// The member of [members] whose server answers **first** — returned the moment
/// it does, without waiting for the slow ones.
///
/// This is [SourceGroupMode.auto], and it is a *different race* from
/// `EndpointProbeService.firstResponder`, which races the routes **inside one
/// source**. The two nest:
///
/// * `firstResponder(source)` — one server, several front doors (LAN address vs
///   DDNS name). Answers "how do I get in".
/// * this function — several sources the user declared to be one server.
///   Answers "which of them is answering". Each entrant is itself a route race,
///   so a member with two addresses is represented by whichever of them replies
///   first, which is exactly the member's own best case.
///
/// The service cannot do this one: it takes a single [Source] and its TTL cache
/// is keyed by source id, so racing across sources has to live a level up. What
/// it does give us is that each entrant costs one round of sockets, shared with
/// anything else probing that source at the same moment.
///
/// Losing probes are **not** cancelled — they finish and fill the service's
/// cache, so a picker that later wants every member's latency gets it without
/// opening a second set of sockets.
///
/// Null when no member answered. Each entrant is bounded by the probe service's
/// own overall budget, so this cannot outlive a plain `probeFor`.
Future<String?> firstRespondingSource(
  List<Source> members, {
  required EndpointProbeService probe,
}) async {
  final entrants = members.where((s) => s.enabled).toList(growable: false);
  if (entrants.isEmpty) return null;
  if (entrants.length == 1) {
    final only = await probe.firstResponder(entrants.first);
    return only == null ? null : entrants.first.id;
  }

  final winner = Completer<String?>();
  var pending = entrants.length;
  for (final source in entrants) {
    unawaited(
      probe.firstResponder(source).then(
        (answer) {
          if (answer != null && !winner.isCompleted) {
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

/// Probes [group] and returns the member to use, or null when none answered.
///
/// Each mode gets the probe it actually needs — the same split
/// `EndpointProbeService.resolve` makes between routes:
///
/// * [SourceGroupMode.auto] — race every member at once
///   ([firstRespondingSource]) and take whoever replies first. Waiting for the
///   rest could only tell us one of them was a few milliseconds quicker, which
///   is not what the user asked for.
/// * [SourceGroupMode.ordered] — walk the user's order and **stop at the first
///   member that answers**. Probing the rest cannot change the answer, and on a
///   handheld every skipped connect is a second not spent. The one on top being
///   up is the common case, so the common case costs one probe.
Future<String?> resolveGroupMember({
  required SourceGroup group,
  required List<Source> members,
  required EndpointProbeService probe,
}) async {
  final usable = [
    for (final id in group.memberIds)
      ...members.where((s) => s.id == id && s.enabled),
  ];
  if (usable.isEmpty) return null;

  if (group.mode == SourceGroupMode.auto) {
    return firstRespondingSource(usable, probe: probe);
  }
  for (final member in usable) {
    if ((await probe.reachableFor(member)).isNotEmpty) return member.id;
  }
  return null;
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

/// Probes the selected source — or its whole group — and returns the config to
/// actually sync with.
///
/// Deliberately probes as little as the mode allows rather than everything:
/// the question is "which of these addresses is answering", not "which of
/// everything is fastest". An ungrouped source costs one connect;
/// `ordered` stops at the first member that answers; only `auto` fans out, and
/// it returns the moment the first reply lands.
///
/// **Only the returned config is rewritten. Nothing is written to disk.** That
/// is the whole self-healing mechanism: no preference is reassigned, so the
/// member the user put first is used again the next time it answers, without
/// anyone switching back by hand.
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
  final selected = config.sourceById(activeId);
  if (selected == null || !selected.enabled) {
    return (config: config, choice: SourceChoice.none);
  }

  final group = config.groupContaining(activeId);
  final reachable = <String>[];
  if (group == null) {
    if ((await svc.reachableFor(selected)).isNotEmpty) {
      reachable.add(selected.id);
    }
  } else {
    final winner = await resolveGroupMember(
      group: group,
      members: config.membersOf(group),
      probe: svc,
    );
    if (winner != null) reachable.add(winner);
  }

  final choice = chooseSource(
    sources: config.sources,
    groups: config.sourceGroups,
    activeSourceId: activeId,
    reachable: reachable,
  );
  final effective = choice.source?.id ?? activeId;

  var currentConfig = config;
  var currentChoice = choice;
  if (choice.source != null) {
    final resolvedEp = await svc.resolve(choice.source!);
    if (resolvedEp != null) {
      final updatedSource = choice.source!.withLiveEndpoint(resolvedEp);
      final updatedSources = config.sources
          .map((s) => s.id == updatedSource.id ? updatedSource : s)
          .toList(growable: false);
      currentConfig = config.copyWith(sources: updatedSources);
      currentChoice = SourceChoice(
        source: updatedSource,
        preferred: choice.preferred?.id == updatedSource.id
            ? updatedSource
            : choice.preferred,
        group: choice.group,
      );
    }
  }

  return (
    config: withEffectiveSource(currentConfig, effective),
    choice: currentChoice,
  );
}
