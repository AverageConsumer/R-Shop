import 'provider_config.dart';
import 'source.dart';
import 'system_config.dart';

/// Top-level immutable configuration.
///
/// Schema versions:
/// - **v1/v2**: each [SystemConfig] embedded its own list of
///   [ProviderConfig].
/// - **v3**: top-level [sources] list with multi-entry fallback chains.
class AppConfig {
  static const int currentVersion = 3;

  final int version;
  final List<SystemConfig> systems;
  final List<Source> sources;

  /// The one source the library is currently **showing**, or null to show
  /// every enabled source at once.
  final String? activeSourceId;

  /// The source in use: what syncs, and what the home screen shows by default.
  final String? primarySourceId;

  const AppConfig({
    this.version = currentVersion,
    required this.systems,
    this.sources = const [],
    this.activeSourceId,
    this.primarySourceId,
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
      var sources = rawSources
          .map((e) => Source.fromJson(e as Map<String, dynamic>))
          .toList();

      // Migrate legacy `source_groups` into `fallbackSourceIds` if present
      final rawGroups = json['source_groups'] as List<dynamic>?;
      if (rawGroups != null && rawGroups.isNotEmpty) {
        sources = _migrateGroupsToFallbacks(sources, rawGroups);
      }

      return AppConfig(
        version: rawVersion,
        systems: systems,
        sources: sources,
        activeSourceId: json['active_source_id'] as String?,
        primarySourceId: json['primary_source_id'] as String? ??
            json['active_source_id'] as String?,
      );
    }

    return _migrateLegacyToV3(systems);
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'systems': systems.map((s) => s.toJson()).toList(),
      'sources': sources.map((s) => s.toJson()).toList(),
      if (activeSourceId != null) 'active_source_id': activeSourceId,
      if (primarySourceId != null) 'primary_source_id': primarySourceId,
    };
  }

  Map<String, dynamic> toJsonWithoutAuth() {
    return {
      'version': version,
      'systems': systems.map((s) => s.toJsonWithoutAuth()).toList(),
      'sources': sources.map((s) => s.toJsonWithoutAuth()).toList(),
      if (activeSourceId != null) 'active_source_id': activeSourceId,
      if (primarySourceId != null) 'primary_source_id': primarySourceId,
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
  }) {
    return AppConfig(
      version: version ?? this.version,
      systems: systems ?? this.systems,
      sources: sources ?? this.sources,
      activeSourceId:
          clearActiveSource ? null : (activeSourceId ?? this.activeSourceId),
      primarySourceId:
          clearPrimarySource ? null : (primarySourceId ?? this.primarySourceId),
    );
  }

  /// The source currently in view, or null when every enabled source is used.
  Source? get activeSource {
    final id = activeSourceId;
    if (id == null) return null;
    for (final s in sources) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// The source in use, or null when none is designated.
  Source? get primarySource {
    final id = primarySourceId;
    if (id == null) return null;
    for (final s in sources) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// Which id owns the cached games for [sourceId].
  /// Each source owns its own library cache.
  String cacheOwnerIdFor(String sourceId) => sourceId;

  /// Returns the sources available for display on the home screen.
  List<Source> collapsedSources({
    Map<String, String> effectiveMemberByGroupId = const {},
    bool enabledOnly = true,
  }) {
    return sources.where((s) => !enabledOnly || s.enabled).toList();
  }

  static List<Source> _migrateGroupsToFallbacks(
    List<Source> sources,
    List<dynamic> rawGroups,
  ) {
    final map = {for (final s in sources) s.id: s};
    for (final raw in rawGroups) {
      if (raw is! Map<String, dynamic>) continue;
      final members = (raw['member_ids'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[];
      final mode = raw['mode'] as String? ?? 'ordered';
      final isAuto = mode == 'auto';
      if (members.length >= 2) {
        final headId = members.first;
        final fallbacks = members.sublist(1);
        final head = map[headId];
        if (head != null) {
          final mergedFallbacks = [
            ...head.fallbackSourceIds,
            for (final f in fallbacks)
              if (!head.fallbackSourceIds.contains(f)) f,
          ];
          map[headId] = head.copyWith(
            fallbackSourceIds: mergedFallbacks,
            fallbackAutoSelect: isAuto || head.fallbackAutoSelect,
          );
        }
      }
    }
    return map.values.toList();
  }
}

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
