import 'provider_config.dart';

/// Top-level kinds of content sources R-Shop knows how to talk to.
///
/// `local` is the device's own filesystem (no network); `web` is an HTTP
/// directory listing (Myrient and friends). RomM is treated as its own
/// type because it self-describes its platforms via the `/api/platforms`
/// endpoint and therefore supports auto-mapping.
enum SourceType { romm, smb, ftp, web, local }

extension SourceTypeX on SourceType {
  /// Whether this source can advertise its own platform list — `true` only
  /// for RomM today. Auto-mapping (no per-system path needed) hinges on
  /// this; manual sources require an explicit [SystemSourceMapping] per
  /// system to know where their content lives.
  bool get supportsAutoMap => this == SourceType.romm;

  String get shortLabel {
    switch (this) {
      case SourceType.romm:
        return 'RomM';
      case SourceType.smb:
        return 'SMB';
      case SourceType.ftp:
        return 'FTP';
      case SourceType.web:
        return 'WEB';
      case SourceType.local:
        return 'LOCAL';
    }
  }
}

/// Per-system pointer into a manual source.
///
/// Only used for sources that cannot describe their own platforms
/// (SMB/FTP/Web). For example, an SMB source may live at `smb://nas/share`
/// and the SNES system pulls from `/share/snes`. The mapping carries the
/// remote path and an optional priority override that lets a power user
/// say "for SNES specifically, prefer this source over the others".
class SystemSourceMapping {
  final String sourceId;
  final String remotePath;
  final int? priorityOverride;

  const SystemSourceMapping({
    required this.sourceId,
    required this.remotePath,
    this.priorityOverride,
  });

  factory SystemSourceMapping.fromJson(Map<String, dynamic> json) {
    return SystemSourceMapping(
      sourceId: json['source_id'] as String,
      remotePath: json['remote_path'] as String,
      priorityOverride: json['priority_override'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'source_id': sourceId,
      'remote_path': remotePath,
      if (priorityOverride != null) 'priority_override': priorityOverride,
    };
  }

  SystemSourceMapping copyWith({
    String? sourceId,
    String? remotePath,
    int? priorityOverride,
  }) {
    return SystemSourceMapping(
      sourceId: sourceId ?? this.sourceId,
      remotePath: remotePath ?? this.remotePath,
      priorityOverride: priorityOverride ?? this.priorityOverride,
    );
  }
}

/// A top-level content source — a server (RomM/SMB/FTP/Web) or the local
/// filesystem.
///
/// Sources live in [AppConfig.sources] and can be referenced by any number
/// of [SystemConfig]s. A RomM source automatically advertises every
/// platform it ships (auto-map); a manual source has to be paired with a
/// system via [SystemConfig.manualMappings].
class Source {
  /// Stable UUID-style identifier. Generated once at creation time and
  /// never reused — system mappings reference sources by this id.
  final String id;

  /// Human-readable label shown in the Sources screen and per-system
  /// badges. Defaults to the host or share name if the user does not pick
  /// one explicitly.
  final String name;

  final SourceType type;

  // --- Connection ---
  final String? url; // romm/web
  final String? host; // smb/ftp
  final int? port; // smb/ftp
  final String? share; // smb
  final String? path; // local

  /// Credentials for this source.
  AuthConfig? get auth => _auth;
  final AuthConfig? _auth;

  // --- Behaviour ---

  /// True for RomM sources that should automatically populate every
  /// matching [SystemConfig]; false for manual sources that need explicit
  /// per-system mappings.
  final bool autoMap;

  /// Global ordering — lower wins when the same ROM is available from
  /// multiple sources. Per-system overrides via [SystemSourceMapping]
  /// take precedence.
  final int priority;

  /// Off-switch that suppresses the source from sync without deleting it
  /// or losing its credentials.
  final bool enabled;

  // --- Multi-entry Fallback Chain ---

  /// Other sources to fall back on when this one does not answer, in order of
  /// preference.
  final List<String> fallbackSourceIds;

  /// Optional: whether to automatically probe all fallback sources concurrently
  /// and pick whichever answers first (`true`), or follow [fallbackSourceIds] list
  /// order (`false`, default).
  final bool fallbackAutoSelect;

  /// Backwards compatibility getter returning the first fallback source ID.
  String? get fallbackSourceId => fallbackSourceIds.isNotEmpty ? fallbackSourceIds.first : null;

  // --- Borrow / sharing ---

  /// True when this source was paired from somebody else's RomM.
  final bool borrowed;

  /// RomM Client API Token expiry.
  final DateTime? tokenExpiresAt;

  /// Cached map of system slug → RomM numeric platform id (RomM only).
  final Map<String, int> knownPlatforms;

  const Source({
    required this.id,
    required this.name,
    required this.type,
    this.url,
    this.host,
    this.port,
    this.share,
    this.path,
    AuthConfig? auth,
    this.autoMap = false,
    this.priority = 100,
    this.enabled = true,
    this.fallbackSourceIds = const [],
    this.fallbackAutoSelect = false,
    this.borrowed = false,
    this.tokenExpiresAt,
    this.knownPlatforms = const {},
  }) : _auth = auth;

  factory Source.fromJson(Map<String, dynamic> json) {
    DateTime? exp;
    final raw = json['token_expires_at'];
    if (raw is String && raw.isNotEmpty) {
      exp = DateTime.tryParse(raw);
    }
    final type = SourceType.values
            .asNameMap()[json['type'] as String? ?? 'romm'] ??
        SourceType.romm;

    // Parse fallback source IDs, maintaining backwards compatibility with `fallback_source_id`
    var fallbacks = <String>[];
    if (json['fallback_source_ids'] is List) {
      fallbacks = (json['fallback_source_ids'] as List).cast<String>();
    } else if (json['fallback_source_id'] is String && (json['fallback_source_id'] as String).isNotEmpty) {
      fallbacks = [json['fallback_source_id'] as String];
    }

    return Source(
      id: json['id'] as String,
      name: json['name'] as String,
      type: type,
      url: json['url'] as String?,
      host: json['host'] as String?,
      port: json['port'] as int?,
      share: json['share'] as String?,
      path: json['path'] as String?,
      auth: json['auth'] != null
          ? AuthConfig.fromJson(json['auth'] as Map<String, dynamic>)
          : null,
      autoMap: json['auto_map'] as bool? ?? false,
      priority: json['priority'] as int? ?? 100,
      enabled: json['enabled'] as bool? ?? true,
      fallbackSourceIds: fallbacks,
      fallbackAutoSelect: json['fallback_auto_select'] as bool? ?? false,
      borrowed: json['borrowed'] as bool? ?? false,
      tokenExpiresAt: exp,
      knownPlatforms: (json['known_platforms'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, (v as num).toInt())) ??
          const {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      if (url != null) 'url': url,
      if (host != null) 'host': host,
      if (port != null) 'port': port,
      if (share != null) 'share': share,
      if (path != null) 'path': path,
      if (_auth != null) 'auth': _auth!.toJson(),
      'auto_map': autoMap,
      'priority': priority,
      'enabled': enabled,
      if (fallbackSourceIds.isNotEmpty) 'fallback_source_ids': fallbackSourceIds,
      if (fallbackAutoSelect) 'fallback_auto_select': fallbackAutoSelect,
      'borrowed': borrowed,
      if (tokenExpiresAt != null)
        'token_expires_at': tokenExpiresAt!.toIso8601String(),
      if (knownPlatforms.isNotEmpty) 'known_platforms': knownPlatforms,
    };
  }

  /// Convenience: returns true if this source advertises [systemId].
  bool advertisesSystem(String systemId) => knownPlatforms.containsKey(systemId);

  /// Convenience: returns the RomM numeric platform id for [systemId],
  /// or null if this source does not know about that system.
  int? rommPlatformIdFor(String systemId) => knownPlatforms[systemId];

  /// Like [toJson] but strips credentials. Used by config export.
  Map<String, dynamic> toJsonWithoutAuth() {
    final map = toJson();
    map.remove('auth');
    return map;
  }

  /// Stable identity used for deduplication during legacy migration.
  String get connectionKey {
    switch (type) {
      case SourceType.romm:
      case SourceType.web:
        return '${type.name}|${_normalizeUrl(url)}';
      case SourceType.smb:
        return 'smb|${host?.toLowerCase()}|$port|${share?.toLowerCase()}';
      case SourceType.ftp:
        return 'ftp|${host?.toLowerCase()}|$port';
      case SourceType.local:
        return 'local|$path';
    }
  }

  static String _normalizeUrl(String? raw) {
    if (raw == null) return '';
    final uri = Uri.tryParse(raw.trim());
    if (uri == null) return raw.trim().toLowerCase();
    var path = uri.path;
    while (path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    return '${uri.scheme.toLowerCase()}://${uri.host.toLowerCase()}'
        '${uri.hasPort ? ':${uri.port}' : ''}$path';
  }

  /// Short label suitable for the Sources screen.
  String get hostLabel {
    switch (type) {
      case SourceType.romm:
      case SourceType.web:
        if (url == null) return name;
        final uri = Uri.tryParse(url!);
        if (uri == null) return name;
        return uri.hasPort ? '${uri.host}:${uri.port}' : uri.host;
      case SourceType.smb:
      case SourceType.ftp:
        return host ?? name;
      case SourceType.local:
        return path ?? name;
    }
  }

  Source copyWith({
    String? id,
    String? name,
    SourceType? type,
    String? url,
    String? host,
    int? port,
    String? share,
    String? path,
    AuthConfig? auth,
    bool? autoMap,
    int? priority,
    bool? enabled,
    List<String>? fallbackSourceIds,
    bool? fallbackAutoSelect,
    bool clearFallbacks = false,
    bool? borrowed,
    DateTime? tokenExpiresAt,
    Map<String, int>? knownPlatforms,
  }) {
    return Source(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      url: url ?? this.url,
      host: host ?? this.host,
      port: port ?? this.port,
      share: share ?? this.share,
      path: path ?? this.path,
      auth: auth ?? _auth,
      autoMap: autoMap ?? this.autoMap,
      priority: priority ?? this.priority,
      enabled: enabled ?? this.enabled,
      fallbackSourceIds: clearFallbacks
          ? const []
          : (fallbackSourceIds ?? this.fallbackSourceIds),
      fallbackAutoSelect: fallbackAutoSelect ?? this.fallbackAutoSelect,
      borrowed: borrowed ?? this.borrowed,
      tokenExpiresAt: tokenExpiresAt ?? this.tokenExpiresAt,
      knownPlatforms: knownPlatforms ?? this.knownPlatforms,
    );
  }
}
