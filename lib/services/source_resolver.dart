import '../models/config/app_config.dart';
import '../models/config/provider_config.dart';
import '../models/config/source.dart';
import '../models/config/system_config.dart';

/// Reconstructs a priority-ordered list of [ProviderConfig]s for a single
/// [SystemConfig], given the top-level [Source]s from [AppConfig].
///
/// This is the bridge between the new Source-centric data model and the
/// existing service layer (UnifiedGameService, LibrarySyncService,
/// ProviderFactory) that still consumes [ProviderConfig]s. The resolver
/// is the *only* place where the v3 model is translated into the legacy
/// shape — once the services are migrated to consume sources directly,
/// this helper can be deleted.
///
/// Resolution rules (in order):
/// 1. Each enabled source contributes if either:
///    - it auto-maps and `system.id` is in its `knownPlatforms`, OR
///    - the system has a [SystemSourceMapping] pointing at it.
/// 2. If `system.enabledSourceIds` is non-null, only sources in that
///    allow-list survive (power-user override).
/// 3. Per-mapping `priorityOverride` beats the source's global priority.
/// 4. Final order is ascending by effective priority; ties are stable.
class SourceResolver {
  const SourceResolver._();

  /// Returns the effective providers for [system].
  /// [activeSourceId] narrows the result to a single source — the library is
  /// showing and syncing that one alone. Null keeps every enabled source, which
  /// is what a one-source setup gets and what the app did before switching
  /// existed.
  ///
  /// An unknown id is ignored rather than yielding nothing: a source deleted
  /// while selected should leave the user with a full library, not an empty one.
  static List<ProviderConfig> providersFor(
    SystemConfig system,
    List<Source> allSources, {
    String? activeSourceId,
  }) {
    final allow = system.enabledSourceIds?.toSet();
    final mappingBySourceId = {
      for (final m in system.manualMappings) m.sourceId: m,
    };
    final active = activeSourceId != null &&
            allSources.any((s) => s.id == activeSourceId)
        ? activeSourceId
        : null;

    final entries = <_ResolvedEntry>[];

    for (final source in allSources) {
      if (!source.enabled) continue;
      if (active != null && source.id != active) continue;
      if (allow != null && !allow.contains(source.id)) continue;

      final mapping = mappingBySourceId[source.id];
      final autoContrib = source.autoMap && source.advertisesSystem(system.id);
      final manualContrib = mapping != null;
      if (!autoContrib && !manualContrib) continue;

      final effectivePriority = mapping?.priorityOverride ?? source.priority;
      entries.add(_ResolvedEntry(
        source: source,
        mapping: mapping,
        effectivePriority: effectivePriority,
      ));
    }

    entries.sort(
      (a, b) => a.effectivePriority.compareTo(b.effectivePriority),
    );

    return entries
        .map((e) => _toProviderConfig(system, e))
        .toList(growable: false);
  }

  /// Returns just the [Source] objects (without flattening) for callers
  /// that want to render UI badges or count contributing sources.
  static List<Source> sourcesFor(
    SystemConfig system,
    List<Source> allSources,
  ) {
    return providersFor(system, allSources)
        .map((p) => _findSourceForProvider(p, allSources))
        .whereType<Source>()
        .toList();
  }

  static Source? _findSourceForProvider(
      ProviderConfig provider, List<Source> sources) {
    for (final s in sources) {
      if (_typeMatches(s.type, provider.type) &&
          _connectionMatches(s, provider)) {
        return s;
      }
    }
    return null;
  }

  static bool _typeMatches(SourceType st, ProviderType pt) {
    switch (st) {
      case SourceType.romm:
        return pt == ProviderType.romm;
      case SourceType.smb:
        return pt == ProviderType.smb;
      case SourceType.ftp:
        return pt == ProviderType.ftp;
      case SourceType.web:
        return pt == ProviderType.web;
      case SourceType.local:
        return false;
    }
  }

  static bool _connectionMatches(Source s, ProviderConfig p) {
    switch (s.type) {
      case SourceType.romm:
      case SourceType.web:
        return s.url == p.url;
      case SourceType.smb:
        return s.host == p.host && s.share == p.share && s.port == p.port;
      case SourceType.ftp:
        return s.host == p.host && s.port == p.port;
      case SourceType.local:
        return false;
    }
  }

  static ProviderConfig _toProviderConfig(
    SystemConfig system,
    _ResolvedEntry entry,
  ) {
    final source = entry.source;
    final mapping = entry.mapping;
    switch (source.type) {
      case SourceType.romm:
        return ProviderConfig(
          type: ProviderType.romm,
          priority: entry.effectivePriority,
          url: source.url,
          auth: source.auth,
          platformId: source.rommPlatformIdFor(system.id),
          platformName: system.id,
          managedBySource: true,
          sourceId: source.id,
          endpointId: source.liveEndpoint?.id,
        );
      case SourceType.smb:
        return ProviderConfig(
          type: ProviderType.smb,
          priority: entry.effectivePriority,
          host: source.host,
          port: source.port,
          share: source.share,
          path: mapping?.remotePath,
          auth: source.auth,
          managedBySource: true,
          sourceId: source.id,
          endpointId: source.liveEndpoint?.id,
        );
      case SourceType.ftp:
        return ProviderConfig(
          type: ProviderType.ftp,
          priority: entry.effectivePriority,
          host: source.host,
          port: source.port,
          path: mapping?.remotePath,
          auth: source.auth,
          managedBySource: true,
          sourceId: source.id,
          endpointId: source.liveEndpoint?.id,
        );
      case SourceType.web:
        final base = source.url ?? '';
        final segment = mapping?.remotePath ?? '';
        final joined = _joinUrl(base, segment);
        return ProviderConfig(
          type: ProviderType.web,
          priority: entry.effectivePriority,
          url: joined,
          auth: source.auth,
          managedBySource: true,
          sourceId: source.id,
          endpointId: source.liveEndpoint?.id,
        );
      case SourceType.local:
        return ProviderConfig(
          type: ProviderType.web, // placeholder; never resolved in practice
          priority: entry.effectivePriority,
          managedBySource: true,
          sourceId: source.id,
          endpointId: source.liveEndpoint?.id,
        );
    }
  }

  static String _joinUrl(String base, String segment) {
    if (segment.isEmpty) return base;
    if (segment.startsWith('http://') || segment.startsWith('https://')) {
      return segment;
    }
    final b = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final s = segment.startsWith('/') ? segment : '/$segment';
    return '$b$s';
  }
}

class _ResolvedEntry {
  _ResolvedEntry({
    required this.source,
    required this.mapping,
    required this.effectivePriority,
  });
  final Source source;
  final SystemSourceMapping? mapping;
  final int effectivePriority;
}
