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

/// How R-Shop decides which [SourceEndpoint] of a source to talk to.
enum EndpointSelection {
  /// Probe the endpoints in list order and use the first one that answers.
  /// Falls back to the first endpoint when nothing is reachable, so a sync
  /// still produces a real error instead of silently doing nothing.
  auto,

  /// Always use [Source.pinnedEndpointId]. The user asked for this exact
  /// route, so we do not silently switch away from it even if it is down —
  /// a failed sync is more honest than a route that moves behind their back.
  pinned,
}

/// One way to reach a [Source].
///
/// The same RomM server is typically reachable both over the LAN
/// (`http://192.168.1.50:8090`, fast, only at home) and over the internet
/// (`https://roms.example.org`, slower, works anywhere). Those are not two
/// sources — same server, same library, same credentials — they are two
/// routes to one source.
///
/// **Exactly one endpoint is live at a time.** The live endpoint's connection
/// fields are mirrored onto the parent [Source] (`url` / `host` / `port` /
/// `share`), which is what every downstream consumer — [SourceResolver],
/// [Source.connectionKey], the providers — actually reads. Switching routes
/// is therefore a config-only change: no re-sync is required and no cached
/// game is touched.
class SourceEndpoint {
  /// Stable identifier, unique within the parent source.
  final String id;

  /// User-facing label, e.g. "區網" or "遠端". Never empty in practice; the
  /// editor falls back to the host when the user leaves it blank.
  final String label;

  // --- Connection (same shape as the parent Source) ---
  final String? url; // romm/web
  final String? host; // smb/ftp
  final int? port; // smb/ftp
  final String? share; // smb

  const SourceEndpoint({
    required this.id,
    required this.label,
    this.url,
    this.host,
    this.port,
    this.share,
  });

  factory SourceEndpoint.fromJson(Map<String, dynamic> json) {
    return SourceEndpoint(
      id: json['id'] as String,
      label: json['label'] as String? ?? '',
      url: json['url'] as String?,
      host: json['host'] as String?,
      port: json['port'] as int?,
      share: json['share'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      if (url != null) 'url': url,
      if (host != null) 'host': host,
      if (port != null) 'port': port,
      if (share != null) 'share': share,
    };
  }

  SourceEndpoint copyWith({
    String? id,
    String? label,
    String? url,
    String? host,
    int? port,
    String? share,
  }) {
    return SourceEndpoint(
      id: id ?? this.id,
      label: label ?? this.label,
      url: url ?? this.url,
      host: host ?? this.host,
      port: port ?? this.port,
      share: share ?? this.share,
    );
  }

  /// True when [other] points at the same place as this endpoint, ignoring
  /// the label. Used to avoid creating a duplicate route for an address the
  /// source already knows.
  bool sameAddressAs(SourceEndpoint other) =>
      Source._normalizeUrl(url) == Source._normalizeUrl(other.url) &&
      host?.toLowerCase() == other.host?.toLowerCase() &&
      port == other.port &&
      share?.toLowerCase() == other.share?.toLowerCase();

  /// Short address label for the switcher, e.g. "192.168.1.50:8090".
  /// Falls back to [label] when there is no address to show.
  String get addressLabel {
    if (url != null && url!.isNotEmpty) {
      final uri = Uri.tryParse(url!);
      if (uri == null || uri.host.isEmpty) return url!;
      return uri.hasPort ? '${uri.host}:${uri.port}' : uri.host;
    }
    if (host != null && host!.isNotEmpty) {
      return port != null ? '$host:$port' : host!;
    }
    return label;
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

  // --- Connection (the live route) ---
  //
  // These fields are the single source of truth for "where do we connect
  // right now". When [endpoints] is non-empty they mirror whichever endpoint
  // is currently live — see [withLiveEndpoint]. Everything downstream
  // (SourceResolver, connectionKey, hostLabel, the providers) reads only
  // these, which is why switching routes needs no changes outside this file.
  final String? url; // romm/web
  final String? host; // smb/ftp
  final int? port; // smb/ftp
  final String? share; // smb
  final String? path; // local
  final AuthConfig? auth;

  // --- Routes ---

  /// Alternative ways to reach this same source, e.g. LAN vs internet.
  ///
  /// **Every route shares this source's [auth].** A RomM token is issued by a
  /// server, not by an address, so two addresses of one server work with one
  /// token — but pointing a route at a *different* server sends it the wrong
  /// token and fails with a 401 that reads like the server is down.
  ///
  /// Two genuinely different servers are two [Source]s, each with its own
  /// login, optionally paired through [fallbackSourceId]. That path switches
  /// the whole source, credentials included.
  ///
  /// Empty for sources created before routes existed and for sources that
  /// only ever had one address; in that case the connection fields above
  /// stand alone. [Source.fromJson] backfills a single endpoint from the
  /// legacy fields so the rest of the app can assume a list.
  final List<SourceEndpoint> endpoints;

  /// Whether to probe for a working route or stick to [pinnedEndpointId].
  final EndpointSelection endpointSelection;

  /// The route the user explicitly chose. Only meaningful when
  /// [endpointSelection] is [EndpointSelection.pinned].
  final String? pinnedEndpointId;

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

  /// Whether this source's library appears on the home screen.
  ///
  /// A tick-box, not a choice between sources: any number of them can be on
  /// at once, and the home screen shows all of them together. Off hides the
  /// library from view and nothing more — the source still syncs when it is
  /// the one in use, and **its cached games are kept**, which is what
  /// separates hiding from [enabled] = false.
  final bool showOnHome;

  /// Another source to fall back on when this one does not answer — the
  /// typical pair being an internal-network server and its external address.
  ///
  /// Falling back is a temporary substitution, not a change of preference:
  /// whichever source the user selected stays selected, so once this one is
  /// reachable again it is used without anyone having to switch back.
  final String? fallbackSourceId;

  // --- Borrow / sharing ---

  /// True when this source was paired from somebody else's RomM (the
  /// token role/scopes determine that). Surfaced as a "borrowed" badge
  /// in the Sources screen.
  final bool borrowed;

  /// RomM Client API Token expiry, mirrored from `auth.clientTokenExpiresAt`
  /// for convenience so the Sources screen doesn't have to dive into auth.
  final DateTime? tokenExpiresAt;

  /// Cached map of system slug → RomM numeric platform id (RomM only).
  ///
  /// Populated on the first successful sync; used by the resolver to
  /// answer "does this source even know about NDS, and if so what is its
  /// numeric id?" without a network round-trip. For non-RomM sources
  /// this is always empty.
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
    this.auth,
    this.endpoints = const [],
    this.endpointSelection = EndpointSelection.auto,
    this.pinnedEndpointId,
    this.autoMap = false,
    this.priority = 100,
    this.enabled = true,
    this.showOnHome = true,
    this.fallbackSourceId,
    this.borrowed = false,
    this.tokenExpiresAt,
    this.knownPlatforms = const {},
  });

  factory Source.fromJson(Map<String, dynamic> json) {
    DateTime? exp;
    final raw = json['token_expires_at'];
    if (raw is String && raw.isNotEmpty) {
      exp = DateTime.tryParse(raw);
    }
    final type = SourceType.values
            .asNameMap()[json['type'] as String? ?? 'romm'] ??
        SourceType.romm;
    final url = json['url'] as String?;
    final host = json['host'] as String?;
    final port = json['port'] as int?;
    final share = json['share'] as String?;

    // Routes are additive: a config written before they existed has no
    // `endpoints` key, so synthesize one from the connection fields. That
    // keeps "every source has at least one route" true everywhere else and
    // means no config migration step is needed.
    var endpoints = (json['endpoints'] as List<dynamic>?)
            ?.map((e) => SourceEndpoint.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const <SourceEndpoint>[];
    if (endpoints.isEmpty && type != SourceType.local) {
      endpoints = [
        SourceEndpoint(
          id: _primaryEndpointId,
          label: json['name'] as String,
          url: url,
          host: host,
          port: port,
          share: share,
        ),
      ];
    }

    return Source(
      id: json['id'] as String,
      name: json['name'] as String,
      type: type,
      url: url,
      host: host,
      port: port,
      share: share,
      path: json['path'] as String?,
      auth: json['auth'] != null
          ? AuthConfig.fromJson(json['auth'] as Map<String, dynamic>)
          : null,
      endpoints: endpoints,
      endpointSelection: EndpointSelection.values
              .asNameMap()[json['endpoint_selection'] as String? ?? 'auto'] ??
          EndpointSelection.auto,
      pinnedEndpointId: json['pinned_endpoint_id'] as String?,
      autoMap: json['auto_map'] as bool? ?? false,
      priority: json['priority'] as int? ?? 100,
      enabled: json['enabled'] as bool? ?? true,
      // Absent for every source configured before the tick-box existed —
      // they were all visible, so that is what absent has to mean.
      showOnHome: json['show_on_home'] as bool? ?? true,
      fallbackSourceId: json['fallback_source_id'] as String?,
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
      if (auth != null) 'auth': auth!.toJson(),
      if (endpoints.isNotEmpty)
        'endpoints': endpoints.map((e) => e.toJson()).toList(),
      'endpoint_selection': endpointSelection.name,
      if (pinnedEndpointId != null) 'pinned_endpoint_id': pinnedEndpointId,
      'auto_map': autoMap,
      'priority': priority,
      'enabled': enabled,
      'show_on_home': showOnHome,
      if (fallbackSourceId != null) 'fallback_source_id': fallbackSourceId,
      'borrowed': borrowed,
      if (tokenExpiresAt != null)
        'token_expires_at': tokenExpiresAt!.toIso8601String(),
      if (knownPlatforms.isNotEmpty) 'known_platforms': knownPlatforms,
    };
  }

  /// Id given to the endpoint backfilled from a pre-routes config.
  static const String _primaryEndpointId = 'primary';

  /// The route whose address is currently mirrored onto the connection
  /// fields, or null when this source has no routes (local sources).
  ///
  /// This is derived by matching addresses rather than stored, so it stays
  /// correct even if something edits the connection fields directly.
  SourceEndpoint? get liveEndpoint {
    if (endpoints.isEmpty) return null;
    final probe = SourceEndpoint(
      id: '',
      label: '',
      url: url,
      host: host,
      port: port,
      share: share,
    );
    for (final ep in endpoints) {
      if (ep.sameAddressAs(probe)) return ep;
    }
    return null;
  }

  SourceEndpoint? endpointById(String endpointId) {
    for (final ep in endpoints) {
      if (ep.id == endpointId) return ep;
    }
    return null;
  }

  /// Which route *should* be live, given what is reachable right now.
  ///
  /// - `pinned`: the user's choice wins outright. If it is unreachable they
  ///   get a failed sync, not a silent reroute — a route that moves on its
  ///   own is exactly what pinning exists to prevent.
  /// - `auto`: first endpoint in list order that is in [reachable]. List
  ///   order is the user's preference order, so putting the LAN address
  ///   first is what makes "fast at home, works away" fall out.
  /// - `auto` with nothing reachable: the first endpoint, so the sync runs
  ///   and surfaces a real connection error instead of doing nothing.
  ///
  /// Pure — [reachable] comes from the caller's probe, never from I/O here.
  SourceEndpoint? resolveEndpoint({Set<String> reachable = const {}}) {
    if (endpoints.isEmpty) return null;
    if (endpointSelection == EndpointSelection.pinned &&
        pinnedEndpointId != null) {
      final pinned = endpointById(pinnedEndpointId!);
      if (pinned != null) return pinned;
      // Pinned route was deleted — fall through to auto rather than stall.
    }
    for (final ep in endpoints) {
      if (reachable.contains(ep.id)) return ep;
    }
    return endpoints.first;
  }

  /// Returns a copy with [endpoint]'s address mirrored onto the connection
  /// fields, making it the live route.
  ///
  /// [pin] records it as the user's explicit choice; leave it false when the
  /// switch came from auto-selection, so a later probe can still move.
  ///
  /// Credentials are deliberately untouched: two routes to one server share
  /// one account, and re-authenticating on every switch would defeat the
  /// point. Cached games are untouched too — the source id does not change,
  /// so nothing in the database is orphaned by a switch.
  Source withLiveEndpoint(SourceEndpoint endpoint, {bool pin = false}) {
    return Source(
      id: id,
      name: name,
      type: type,
      url: endpoint.url,
      host: endpoint.host,
      port: endpoint.port,
      share: endpoint.share,
      path: path,
      auth: auth,
      endpoints: endpoints,
      endpointSelection:
          pin ? EndpointSelection.pinned : endpointSelection,
      pinnedEndpointId: pin ? endpoint.id : pinnedEndpointId,
      autoMap: autoMap,
      priority: priority,
      enabled: enabled,
      showOnHome: showOnHome,
      borrowed: borrowed,
      tokenExpiresAt: tokenExpiresAt,
      knownPlatforms: knownPlatforms,
    );
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
  ///
  /// Two providers from the old `SystemConfig.providers` list that share
  /// the same connection details should collapse into a single [Source]
  /// even if they were attached to different systems. This identity is
  /// per-type so that an SMB and a Web source with the same hostname stay
  /// separate.
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

  /// Short label suitable for the Sources screen (e.g. "tim.duckdns.org"
  /// or "192.168.1.50:8090"). Falls back to [name] if no host is known.
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
    List<SourceEndpoint>? endpoints,
    EndpointSelection? endpointSelection,
    String? pinnedEndpointId,
    bool clearPinnedEndpoint = false,
    bool? autoMap,
    int? priority,
    bool? enabled,
    bool? showOnHome,
    String? fallbackSourceId,
    bool clearFallback = false,
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
      auth: auth ?? this.auth,
      endpoints: endpoints ?? this.endpoints,
      endpointSelection: endpointSelection ?? this.endpointSelection,
      pinnedEndpointId: clearPinnedEndpoint
          ? null
          : (pinnedEndpointId ?? this.pinnedEndpointId),
      autoMap: autoMap ?? this.autoMap,
      priority: priority ?? this.priority,
      enabled: enabled ?? this.enabled,
      showOnHome: showOnHome ?? this.showOnHome,
      fallbackSourceId:
          clearFallback ? null : (fallbackSourceId ?? this.fallbackSourceId),
      borrowed: borrowed ?? this.borrowed,
      tokenExpiresAt: tokenExpiresAt ?? this.tokenExpiresAt,
      knownPlatforms: knownPlatforms ?? this.knownPlatforms,
    );
  }
}
