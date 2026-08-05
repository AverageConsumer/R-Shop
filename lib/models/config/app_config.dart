import 'provider_config.dart';
import 'source.dart';
import 'system_config.dart';

/// How a [SourceGroup] decides which of its members to use right now.
///
/// Only two, and neither is "always this one": a group whose member never
/// moves is a group of one, and the user would have written that as a plain
/// source.
enum SourceGroupMode {
  /// **Whoever answers first.** No order to maintain, no preference to state —
  /// being at home or away is not a setting, and the address that got back to
  /// us first is the one that is usable first.
  ///
  /// First-to-answer, not fastest-of-all: waiting for every member so they can
  /// be ranked spends the slowest one's timeout on every decision, and by then
  /// the answer is stale anyway.
  auto,

  /// **Follow the user's own order.** Take the first member of [
  /// SourceGroup.memberIds] that answers, however slow it is, and only move
  /// down the list when everything above it is silent.
  ///
  /// "A 通就先用 A，我有順序." The order *is* the setting, so a member further
  /// down never wins just by being quicker — it wins when the ones above it are
  /// down. This is exactly what the old `fallbackSourceId` pair did, which is
  /// why migrated groups land here.
  ordered,
}

/// Several [Source]s that are really **one server**, reached different ways.
///
/// The user's words: "應該不是備援，而是我想指定兩個來源、其實是指向同一台
/// 伺服器，那它們可以選擇誰優先、或者自動." A group generalises the old
/// one-way `Source.fallbackSourceId` pairing into an ordered set with a policy:
/// [SourceGroupMode.ordered] walks [memberIds] and takes the first that
/// answers; [SourceGroupMode.auto] takes whichever answers first.
///
/// **Why this is not a contradiction of "同一台也當不同台".** That rule says
/// the app must never *infer* that two addresses are the same machine. A group
/// is not an inference — it is the user declaring it. Nothing groups itself.
///
/// Two consequences follow from "one group is one server":
///
/// * **One cached library per group, not per member.** See [cacheOwnerId]. The
///   same reasoning that collapsed a source's routes onto one list, one level
///   up: storing the same games twice makes a switch cost a re-scan and makes
///   the two copies drift.
/// * **The home screen shows a group as one cell.** L2/R2 must not walk
///   through the members one at a time — see [AppConfig.collapsedSources].
///
/// Selecting a member is a *runtime* decision and is never written to disk.
/// See `source_failover.dart`; that is what lets the preferred member resume by
/// itself the moment it answers again.
class SourceGroup {
  /// Stable identifier. Generated once and never reused.
  final String id;

  /// User-facing label, e.g. "家裡的 RomM". Falls back to the first member's
  /// name when the user does not pick one.
  final String name;

  final SourceGroupMode mode;

  /// The members, **in the user's order of preference** — first is preferred.
  ///
  /// The order is meaningful in [SourceGroupMode.ordered] and is kept (rather
  /// than sorted away) in [SourceGroupMode.auto] so that flipping the mode back
  /// does not lose what the user arranged. It also decides which member the
  /// home screen shows as the group's face when nothing has been probed yet.
  final List<String> memberIds;

  /// Which id owns the group's cached games — read and write both go through
  /// it, so every member sees the same library. Resolve it with
  /// [AppConfig.cacheOwnerIdFor], which also answers for ungrouped sources.
  ///
  /// Defaults to the first member at creation time and then **stays put**:
  /// reordering members is a statement about which server to talk to first, not
  /// an instruction to move the cache, and a cache owner that moved on reorder
  /// would strand the rows under the old id. Only [withoutMember] re-points it,
  /// and only when the owner itself leaves.
  ///
  /// Storing it rather than deriving it also means the common migration —
  /// a LAN source with a WAN fallback — keeps the LAN's existing rows instead
  /// of orphaning them under a brand-new key.
  String get cacheOwnerId =>
      _cacheOwnerId ?? (memberIds.isEmpty ? id : memberIds.first);

  final String? _cacheOwnerId;

  const SourceGroup({
    required this.id,
    required this.name,
    this.mode = SourceGroupMode.ordered,
    this.memberIds = const [],
    String? cacheOwnerId,
  }) : _cacheOwnerId = cacheOwnerId;

  /// The member the user prefers, or null for an empty group. In
  /// [SourceGroupMode.ordered] this is the one tried first.
  String? get preferredMemberId => memberIds.isEmpty ? null : memberIds.first;

  bool contains(String sourceId) => memberIds.contains(sourceId);

  /// Position in the user's order, or -1. Lower is preferred.
  int indexOf(String sourceId) => memberIds.indexOf(sourceId);

  factory SourceGroup.fromJson(Map<String, dynamic> json) {
    final raw = (json['member_ids'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        const <String>[];
    // Duplicates would make "first that answers" depend on which copy the
    // walker hit and would let one member be probed twice per decision.
    final seen = <String>{};
    final members = [
      for (final id in raw)
        if (seen.add(id)) id,
    ];
    return SourceGroup(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      // An unrecognised mode written by a newer build degrades to the one that
      // respects the stored order rather than to one that ignores it.
      mode: SourceGroupMode.values.asNameMap()[json['mode'] as String?] ??
          SourceGroupMode.ordered,
      memberIds: List<String>.unmodifiable(members),
      cacheOwnerId: json['cache_owner_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'mode': mode.name,
        'member_ids': memberIds,
        'cache_owner_id': cacheOwnerId,
      };

  SourceGroup copyWith({
    String? id,
    String? name,
    SourceGroupMode? mode,
    List<String>? memberIds,
    String? cacheOwnerId,
  }) {
    return SourceGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      mode: mode ?? this.mode,
      memberIds: memberIds ?? this.memberIds,
      cacheOwnerId: cacheOwnerId ?? _cacheOwnerId,
    );
  }

  /// Appends [sourceId] if the group does not already have it.
  ///
  /// Appending rather than inserting is deliberate: a new member is the one the
  /// user knows least about, so it goes last and cannot displace a preference
  /// they already stated. They can move it with [withMemberMoved].
  SourceGroup withMember(String sourceId) {
    if (memberIds.contains(sourceId)) return this;
    return copyWith(
      memberIds: List<String>.unmodifiable([...memberIds, sourceId]),
    );
  }

  /// Drops [sourceId]. If it owned the cache, ownership moves to the first
  /// remaining member — the rows themselves have to be re-pointed by the
  /// database layer, which is why the caller does that in the same step.
  SourceGroup withoutMember(String sourceId) {
    if (!memberIds.contains(sourceId)) return this;
    final remaining = List<String>.unmodifiable(
      memberIds.where((id) => id != sourceId),
    );
    return SourceGroup(
      id: id,
      name: name,
      mode: mode,
      memberIds: remaining,
      cacheOwnerId: cacheOwnerId == sourceId
          ? (remaining.isEmpty ? null : remaining.first)
          : cacheOwnerId,
    );
  }

  /// Returns a copy whose members are arranged in [orderedIds] order.
  ///
  /// Ids this group does not have are ignored, and members [orderedIds] does
  /// not mention keep their relative order at the end — a stale list from a
  /// screen opened before a member was added reorders what it knew about
  /// rather than dropping the rest. Same contract as
  /// `Source.withEndpointsReordered`, and for the same reason: the order is a
  /// setting, so losing part of it silently is worse than ignoring a stale id.
  ///
  /// The cache owner does not move: see [cacheOwnerId].
  SourceGroup withMembersReordered(List<String> orderedIds) {
    if (memberIds.length < 2) return this;
    final remaining = [...memberIds];
    final reordered = <String>[];
    for (final id in orderedIds) {
      final at = remaining.indexOf(id);
      if (at >= 0) reordered.add(remaining.removeAt(at));
    }
    reordered.addAll(remaining);
    return copyWith(memberIds: List<String>.unmodifiable(reordered));
  }

  /// Single-step form of [withMembersReordered] for an up/down button or a
  /// drag handle. [newIndex] is clamped, so "move the top one up" is a no-op
  /// rather than an error, and an unknown id leaves the group untouched.
  SourceGroup withMemberMoved(String sourceId, int newIndex) {
    final from = memberIds.indexOf(sourceId);
    if (from < 0) return this;
    final to = newIndex.clamp(0, memberIds.length - 1);
    if (from == to) return this;
    final moved = [...memberIds];
    moved.insert(to, moved.removeAt(from));
    return copyWith(memberIds: List<String>.unmodifiable(moved));
  }

  @override
  bool operator ==(Object other) =>
      other is SourceGroup &&
      other.id == id &&
      other.name == name &&
      other.mode == mode &&
      other.cacheOwnerId == cacheOwnerId &&
      _sameOrder(other.memberIds, memberIds);

  @override
  int get hashCode =>
      Object.hash(id, name, mode, cacheOwnerId, Object.hashAll(memberIds));

  @override
  String toString() => 'SourceGroup($id, ${mode.name}, $memberIds)';

  static bool _sameOrder(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Folds every legacy `Source.fallbackSourceId` pairing into [SourceGroup]s.
///
/// Run once, when a config with no `source_groups` key is read. The result is
/// the exact behaviour the pairing already had: preferred first, stand-in
/// second, [SourceGroupMode.ordered] — "take the first one in my order that
/// answers".
///
/// Chains fold into one group rather than several overlapping pairs: `A→B` and
/// `B→C` give `[A, B, C]`, because three addresses of one server is what the
/// user was expressing with two pairings, and two groups sharing a member would
/// make "which group is this source in" unanswerable.
///
/// **Cross-type pairings migrate too**, even though new members are restricted
/// to one type. A config that pairs an SMB source with a RomM one was legal
/// before groups existed; refusing to migrate it would leave that install with
/// a fallback that no longer fires and no group to explain why — two mechanisms
/// at once, which is the thing this replaces.
///
/// `fallbackSourceId` itself is left on the [Source]. It stays readable by an
/// older build, but nothing in the selection path consults it any more.
List<SourceGroup> sourceGroupsFromFallbacks(List<Source> sources) {
  final known = {for (final s in sources) s.id: s};
  final chains = <List<String>>[];
  final chainOf = <String, int>{};

  for (final s in sources) {
    final fb = s.fallbackSourceId;
    // A dangling id pairs with nothing, and a self-pairing is a group of one.
    if (fb == null || fb == s.id || !known.containsKey(fb)) continue;

    final a = chainOf[s.id];
    final b = chainOf[fb];
    if (a == null && b == null) {
      chainOf[s.id] = chains.length;
      chainOf[fb] = chains.length;
      chains.add([s.id, fb]);
    } else if (a != null && b == null) {
      // The stand-in goes directly behind the source that named it.
      chains[a].insert(chains[a].indexOf(s.id) + 1, fb);
      chainOf[fb] = a;
    } else if (a == null && b != null) {
      // The source that named it goes directly in front of the stand-in.
      chains[b].insert(chains[b].indexOf(fb), s.id);
      chainOf[s.id] = b;
    } else if (a != b) {
      // Two chains that turn out to be the same server: keep both orders,
      // the one that named the other first.
      for (final id in chains[b!]) {
        if (!chains[a!].contains(id)) chains[a].add(id);
        chainOf[id] = a;
      }
      chains[b] = const [];
    }
  }

  final groups = <SourceGroup>[];
  for (final chain in chains) {
    if (chain.length < 2) continue;
    final head = known[chain.first]!;
    groups.add(SourceGroup(
      id: 'grp-${chain.first}',
      name: head.name,
      mode: SourceGroupMode.ordered,
      memberIds: List<String>.unmodifiable(chain),
      // The head kept its rows under its own id, so pointing the group at it
      // means the migration costs no re-sync.
      cacheOwnerId: chain.first,
    ));
  }
  return List<SourceGroup>.unmodifiable(groups);
}

/// Top-level immutable configuration.
///
/// Schema versions:
/// - **v1/v2**: each [SystemConfig] embedded its own list of
///   [ProviderConfig]. Sources were duplicated across systems and there
///   was no way to share a single RomM instance between consoles cleanly.
/// - **v3**: top-level [sources] list. Each [SystemConfig] still carries
///   its legacy `providers` list during the transition, plus optional
///   per-system overrides via `enabledSourceIds` / `manualMappings`. The
///   migration from v2 → v3 happens transparently inside [fromJson] and
///   yields a config that is byte-for-byte equivalent at the resolver
///   level — old code paths keep reading `providers`, new code paths read
///   `sources`.
class AppConfig {
  static const int currentVersion = 3;

  final int version;
  final List<SystemConfig> systems;
  final List<Source> sources;

  /// The one source the library is currently **showing**, or null to show
  /// every enabled source at once (the historical behaviour, and what a
  /// single-source setup gets).
  ///
  /// This is the cheap, reversible one: the home screen flips it with the
  /// triggers to look at another library. It is not what syncs — see
  /// [primarySourceId].
  ///
  /// Sources are always treated as independent libraries — **even when two of
  /// them happen to point at the same server**. Switching only changes which
  /// one is in view; it never touches cached games, so switching back is
  /// instant rather than a re-sync.
  final String? activeSourceId;

  /// The source in use: what syncs, and what the home screen shows by default.
  ///
  /// Separate from [activeSourceId] because looking at another library and
  /// changing which server you actually work with are different decisions.
  /// Browsing over to a borrowed library should not silently redirect the next
  /// sync at it. Set from the sources list; null means no source has been
  /// designated and sync falls back to whatever is in view.
  final String? primarySourceId;

  /// Sources the user has declared to be the same server, reached different
  /// ways. See [SourceGroup].
  ///
  /// Groups never overlap: a source is in at most one, which is what makes
  /// [groupContaining] and [cacheOwnerIdFor] single-valued answers.
  final List<SourceGroup> sourceGroups;

  const AppConfig({
    this.version = currentVersion,
    required this.systems,
    this.sources = const [],
    this.activeSourceId,
    this.primarySourceId,
    this.sourceGroups = const [],
  });

  static const empty = AppConfig(systems: []);

  SystemConfig? systemById(String id) {
    for (final system in systems) {
      if (system.id == id) return system;
    }
    return null;
  }

  Source? sourceById(String id) {
    for (final source in sources) {
      if (source.id == id) return source;
    }
    return null;
  }

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    final rawVersion = json['version'] as int? ?? 1;
    final systems = (json['systems'] as List<dynamic>)
        .map((e) => SystemConfig.fromJson(e as Map<String, dynamic>))
        .toList();

    final rawSources = json['sources'] as List<dynamic>?;
    if (rawSources != null) {
      // Already v3+. Trust the persisted sources list verbatim.
      final sources = rawSources
          .map((e) => Source.fromJson(e as Map<String, dynamic>))
          .toList();
      // The **presence of the key** is what says the fallback→group migration
      // has already run — not whether it holds anything. [toJson] therefore
      // always writes it, even empty: deriving groups from `fallback_source_id`
      // again would resurrect a group the user had just deleted, since that
      // field is deliberately left in place for older builds to read.
      final rawGroups = json['source_groups'] as List<dynamic>?;
      final groups = rawGroups != null
          ? _sanitizeGroups(
              rawGroups
                  .map((e) => SourceGroup.fromJson(e as Map<String, dynamic>))
                  .toList(),
              sources,
            )
          : sourceGroupsFromFallbacks(sources);
      return AppConfig(
        version: rawVersion,
        systems: systems,
        sources: sources,
        activeSourceId: json['active_source_id'] as String?,
        // Absent in configs written before the two were separated. Falling
        // back to the shown source keeps those installs syncing exactly what
        // they synced before, with no migration step.
        primarySourceId: json['primary_source_id'] as String? ??
            json['active_source_id'] as String?,
        sourceGroups: groups,
      );
    }

    // v2 (or older) → derive sources from per-system providers and rewrite
    // both halves so callers see a consistent v3 shape going forward.
    return _migrateLegacyToV3(systems);
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'systems': systems.map((s) => s.toJson()).toList(),
      'sources': sources.map((s) => s.toJson()).toList(),
      if (activeSourceId != null) 'active_source_id': activeSourceId,
      if (primarySourceId != null) 'primary_source_id': primarySourceId,
      // Written unconditionally — its presence is the marker that the
      // fallback→group migration has run. See [fromJson].
      'source_groups': sourceGroups.map((g) => g.toJson()).toList(),
    };
  }

  /// Like [toJson] but strips all auth credentials (passwords, API keys).
  /// Used for config export to prevent accidental credential sharing.
  Map<String, dynamic> toJsonWithoutAuth() {
    return {
      'version': version,
      'systems': systems.map((s) => s.toJsonWithoutAuth()).toList(),
      'sources': sources.map((s) => s.toJsonWithoutAuth()).toList(),
      if (activeSourceId != null) 'active_source_id': activeSourceId,
      if (primarySourceId != null) 'primary_source_id': primarySourceId,
      'source_groups': sourceGroups.map((g) => g.toJson()).toList(),
    };
  }

  AppConfig copyWith({
    int? version,
    List<SystemConfig>? systems,
    List<Source>? sources,
    String? activeSourceId,
    bool clearActiveSource = false,
    String? primarySourceId,
    bool clearPrimarySource = false,
    List<SourceGroup>? sourceGroups,
  }) {
    return AppConfig(
      version: version ?? this.version,
      systems: systems ?? this.systems,
      sources: sources ?? this.sources,
      activeSourceId:
          clearActiveSource ? null : (activeSourceId ?? this.activeSourceId),
      primarySourceId:
          clearPrimarySource ? null : (primarySourceId ?? this.primarySourceId),
      sourceGroups: sourceGroups ?? this.sourceGroups,
    );
  }

  /// The source currently in view, or null when every enabled source is used.
  ///
  /// Returns null when [activeSourceId] names a source that no longer exists
  /// (deleted while selected), which degrades to "show everything" rather than
  /// to an empty library.
  Source? get activeSource {
    final id = activeSourceId;
    if (id == null) return null;
    for (final s in sources) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// The source in use, or null when none is designated or the designated one
  /// has been deleted. Same degrade-to-everything rule as [activeSource].
  Source? get primarySource {
    final id = primarySourceId;
    if (id == null) return null;
    for (final s in sources) {
      if (s.id == id) return s;
    }
    return null;
  }

  // --- Groups ---------------------------------------------------------------
  //
  // Everything below is a *read* helper. Creating and editing groups goes
  // through SourcesNotifier; deciding which member is in use right now goes
  // through source_failover.dart and is never persisted.

  SourceGroup? groupById(String groupId) {
    for (final g in sourceGroups) {
      if (g.id == groupId) return g;
    }
    return null;
  }

  /// The group [sourceId] belongs to, or null when it stands alone.
  ///
  /// This is the question the home screen asks about every source before it
  /// draws a cell: a grouped source is drawn as its group, not as itself.
  SourceGroup? groupContaining(String sourceId) {
    for (final g in sourceGroups) {
      if (g.contains(sourceId)) return g;
    }
    return null;
  }

  /// Every source id that belongs to some group.
  Set<String> get groupedSourceIds => {
        for (final g in sourceGroups) ...g.memberIds,
      };

  /// [group]'s members as [Source]s, **in the group's order**, skipping ids
  /// that no longer name a source.
  ///
  /// Order matters to the caller: this list is what
  /// `SourceGroupMode.ordered` walks.
  List<Source> membersOf(SourceGroup group) {
    final byId = {for (final s in sources) s.id: s};
    return [
      for (final id in group.memberIds)
        if (byId[id] != null) byId[id]!,
    ];
  }

  /// Which id owns the cached games for [sourceId].
  ///
  /// **The one call both the read and the write side of the database make.**
  /// A group is one server, so its members share one list; an ungrouped source
  /// owns its own. Routing every query through here is what stops a switch
  /// inside a group from landing on an empty grid, and what stops the same
  /// game being stored twice under two ids.
  String cacheOwnerIdFor(String sourceId) =>
      groupContaining(sourceId)?.cacheOwnerId ?? sourceId;

  /// The sources the home screen should offer as cells, **with each group
  /// collapsed to a single entry**.
  ///
  /// A group is one server and therefore one cell: L2/R2 stepping through
  /// `LAN → WAN → …` would walk the user through several views of the same
  /// library, which is the "third library nobody asked for" problem again, one
  /// level up.
  ///
  /// Which member represents its group:
  ///   1. [effectiveMemberByGroupId] — the member failover actually settled on,
  ///      if the caller has resolved one. Pass
  ///      `SourceChoice.effectiveMemberByGroupId` so the cell names the server
  ///      that is really answering.
  ///   2. otherwise the first *listed* member that is still enabled, i.e. the
  ///      user's stated preference.
  ///
  /// [enabledOnly] mirrors the eye toggle: a group all of whose members are
  /// switched off does not appear at all. Ordering follows [sources], with each
  /// group taking the position of its earliest member.
  List<Source> collapsedSources({
    Map<String, String> effectiveMemberByGroupId = const {},
    bool enabledOnly = true,
  }) {
    final out = <Source>[];
    final done = <String>{};
    for (final s in sources) {
      if (enabledOnly && !s.enabled) continue;
      final group = groupContaining(s.id);
      if (group == null) {
        out.add(s);
        continue;
      }
      if (!done.add(group.id)) continue;
      final rep = representativeOf(
        group,
        effectiveMemberId: effectiveMemberByGroupId[group.id],
        enabledOnly: enabledOnly,
      );
      if (rep != null) out.add(rep);
    }
    return List<Source>.unmodifiable(out);
  }

  /// The member that stands for [group] on screen — see [collapsedSources].
  ///
  /// Returns null only when the group has no usable member left.
  Source? representativeOf(
    SourceGroup group, {
    String? effectiveMemberId,
    bool enabledOnly = true,
  }) {
    final byId = {for (final s in sources) s.id: s};
    final effective = effectiveMemberId == null ? null : byId[effectiveMemberId];
    if (effective != null && group.contains(effective.id)) return effective;
    for (final id in group.memberIds) {
      final s = byId[id];
      if (s == null) continue;
      if (enabledOnly && !s.enabled) continue;
      return s;
    }
    return null;
  }
}

/// Drops what a stored group list must never contain: members that no longer
/// name a source, a source claimed by two groups, and groups left with fewer
/// than two members.
///
/// A group of one is not a group — it says nothing the plain source does not
/// already say — and leaving one behind would put a "group" badge on a single
/// server. Overlap is dropped rather than merged because "which group is this
/// source in" has to have one answer; the earlier group wins so the result does
/// not depend on set iteration order.
List<SourceGroup> _sanitizeGroups(
  List<SourceGroup> groups,
  List<Source> sources,
) {
  final known = {for (final s in sources) s.id};
  final claimed = <String>{};
  final out = <SourceGroup>[];
  for (final g in groups) {
    final members = [
      for (final id in g.memberIds)
        if (known.contains(id) && claimed.add(id)) id,
    ];
    if (members.length < 2) {
      claimed.removeAll(members);
      continue;
    }
    out.add(g.copyWith(
      memberIds: List<String>.unmodifiable(members),
      cacheOwnerId:
          members.contains(g.cacheOwnerId) ? g.cacheOwnerId : members.first,
    ));
  }
  return List<SourceGroup>.unmodifiable(out);
}

/// Walks every legacy [ProviderConfig] and folds them into a deduplicated
/// [Source] list.
///
/// Behaviour:
/// - Two providers with the same connection identity (URL/host+share)
///   collapse into a single [Source]; the first one's metadata wins.
/// - RomM providers become `autoMap: true` sources and contribute their
///   system slug to the source's `knownPlatforms` cache so the resolver
///   doesn't have to round-trip on the next launch.
/// - SMB/FTP/Web providers become `autoMap: false` sources and a
///   [SystemSourceMapping] is added to the owning system carrying the
///   remote path that the legacy provider used.
/// - The original `providers` lists are kept intact on each system so
///   nothing in the read path breaks during the transition window.
AppConfig _migrateLegacyToV3(List<SystemConfig> legacySystems) {
  final sourcesByKey = <String, Source>{};
  final migratedSystems = <SystemConfig>[];
  var seq = 0;

  String nextSourceId(SourceType type, String hint) {
    seq++;
    return 'src-${type.name}-$seq-${hint.hashCode.abs()}';
  }

  for (final system in legacySystems) {
    final newMappings = <SystemSourceMapping>[];
    final taggedProviders = <ProviderConfig>[];

    for (final provider in system.providers) {
      final probe = Source(
        id: 'tmp',
        name: '',
        type: _typeFromProvider(provider.type),
        url: provider.url,
        host: provider.host,
        port: provider.port,
        share: provider.share,
        path: provider.path,
      );
      final key = probe.connectionKey;

      var source = sourcesByKey[key];
      if (source == null) {
        source = Source(
          id: nextSourceId(probe.type, key),
          name: _deriveName(provider),
          type: probe.type,
          url: provider.url,
          host: provider.host,
          port: provider.port,
          share: provider.share,
          path: provider.path,
          auth: provider.auth,
          autoMap: probe.type.supportsAutoMap,
          priority: provider.priority,
          knownPlatforms: probe.type.supportsAutoMap &&
                  provider.platformId != null
              ? {system.id: provider.platformId!}
              : const <String, int>{},
        );
        sourcesByKey[key] = source;
      } else if (probe.type.supportsAutoMap &&
          provider.platformId != null &&
          !source.knownPlatforms.containsKey(system.id)) {
        sourcesByKey[key] = source.copyWith(
          knownPlatforms: {
            ...source.knownPlatforms,
            system.id: provider.platformId!,
          },
        );
      }

      // Manual sources need a per-system path mapping; auto-map sources
      // (RomM today) advertise their own platforms so they don't.
      if (!probe.type.supportsAutoMap) {
        final remotePath = _legacyRemotePath(provider);
        if (remotePath.isNotEmpty) {
          newMappings.add(
            SystemSourceMapping(
              sourceId: sourcesByKey[key]!.id,
              remotePath: remotePath,
              priorityOverride: provider.priority,
            ),
          );
        }
      }

      // Tag the legacy provider so the SourcesNotifier rebuild recognises
      // it as belonging to a source. Without this the provider would be
      // treated as unmanaged forever and survive a source disable/remove,
      // which is exactly the "sync still hits the disabled RomM" bug.
      taggedProviders.add(
        provider.copyWith(
          managedBySource: true,
          sourceId: sourcesByKey[key]!.id,
        ),
      );
    }

    migratedSystems.add(
      system.copyWith(
        manualMappings: newMappings,
        providers: taggedProviders,
      ),
    );
  }

  return AppConfig(
    version: AppConfig.currentVersion,
    systems: migratedSystems,
    sources: sourcesByKey.values.toList()
      ..sort((a, b) => a.priority.compareTo(b.priority)),
  );
}

SourceType _typeFromProvider(ProviderType t) {
  switch (t) {
    case ProviderType.romm:
      return SourceType.romm;
    case ProviderType.smb:
      return SourceType.smb;
    case ProviderType.ftp:
      return SourceType.ftp;
    case ProviderType.web:
      return SourceType.web;
  }
}

String _deriveName(ProviderConfig p) {
  switch (p.type) {
    case ProviderType.romm:
    case ProviderType.web:
      final uri = p.url != null ? Uri.tryParse(p.url!) : null;
      return uri?.host ?? p.shortLabel;
    case ProviderType.smb:
      return p.host ?? 'SMB';
    case ProviderType.ftp:
      return p.host ?? 'FTP';
  }
}

String _legacyRemotePath(ProviderConfig p) {
  switch (p.type) {
    case ProviderType.smb:
    case ProviderType.ftp:
      return p.path ?? '';
    case ProviderType.web:
      if (p.url == null) return '';
      final uri = Uri.tryParse(p.url!);
      return uri?.path ?? '';
    case ProviderType.romm:
      return '';
  }
}
