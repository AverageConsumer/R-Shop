import 'provider_config.dart';
import 'source.dart';
import 'system_config.dart';

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

  const AppConfig({
    this.version = currentVersion,
    required this.systems,
    this.sources = const [],
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
      return AppConfig(
        version: rawVersion,
        systems: systems,
        sources: sources,
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
    };
  }

  /// Like [toJson] but strips all auth credentials (passwords, API keys).
  /// Used for config export to prevent accidental credential sharing.
  Map<String, dynamic> toJsonWithoutAuth() {
    return {
      'version': version,
      'systems': systems.map((s) => s.toJsonWithoutAuth()).toList(),
      'sources': sources.map((s) => s.toJsonWithoutAuth()).toList(),
    };
  }

  AppConfig copyWith({
    int? version,
    List<SystemConfig>? systems,
    List<Source>? sources,
  }) {
    return AppConfig(
      version: version ?? this.version,
      systems: systems ?? this.systems,
      sources: sources ?? this.sources,
    );
  }
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
    }

    migratedSystems.add(system.copyWith(manualMappings: newMappings));
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
