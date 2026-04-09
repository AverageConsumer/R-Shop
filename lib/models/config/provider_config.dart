enum ProviderType { web, smb, ftp, romm }

class AuthConfig {
  final String? user;
  final String? pass;
  final String? apiKey;
  final String? domain;

  /// RomM 4.8+ Client API Token (Bearer). When present, takes precedence
  /// over [apiKey] and [user]/[pass] in [RommProvider].
  final String? clientToken;

  /// Server-side id of the client token, used for revoke and status polling.
  final int? clientTokenId;

  /// Optional expiry of the client token (null = never expires). Surfaced
  /// in the Sources screen as a "läuft in N Tagen ab" badge.
  final DateTime? clientTokenExpiresAt;

  const AuthConfig({
    this.user,
    this.pass,
    this.apiKey,
    this.domain,
    this.clientToken,
    this.clientTokenId,
    this.clientTokenExpiresAt,
  });

  factory AuthConfig.fromJson(Map<String, dynamic> json) {
    DateTime? expires;
    final raw = json['client_token_expires_at'];
    if (raw is String && raw.isNotEmpty) {
      expires = DateTime.tryParse(raw);
    }
    return AuthConfig(
      user: json['user'] as String?,
      pass: json['pass'] as String?,
      apiKey: json['api_key'] as String?,
      domain: json['domain'] as String?,
      clientToken: json['client_token'] as String?,
      clientTokenId: json['client_token_id'] as int?,
      clientTokenExpiresAt: expires,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (user != null) 'user': user,
      if (pass != null) 'pass': pass,
      if (apiKey != null) 'api_key': apiKey,
      if (domain != null) 'domain': domain,
      if (clientToken != null) 'client_token': clientToken,
      if (clientTokenId != null) 'client_token_id': clientTokenId,
      if (clientTokenExpiresAt != null)
        'client_token_expires_at': clientTokenExpiresAt!.toIso8601String(),
    };
  }

  AuthConfig copyWith({
    String? user,
    String? pass,
    String? apiKey,
    String? domain,
    String? clientToken,
    int? clientTokenId,
    DateTime? clientTokenExpiresAt,
  }) {
    return AuthConfig(
      user: user ?? this.user,
      pass: pass ?? this.pass,
      apiKey: apiKey ?? this.apiKey,
      domain: domain ?? this.domain,
      clientToken: clientToken ?? this.clientToken,
      clientTokenId: clientTokenId ?? this.clientTokenId,
      clientTokenExpiresAt: clientTokenExpiresAt ?? this.clientTokenExpiresAt,
    );
  }
}

class ProviderConfig {
  final ProviderType type;
  final int priority;
  final String? url;
  final String? host;
  final int? port;
  final String? share;
  final String? path;
  final AuthConfig? auth;
  final int? platformId;
  final String? platformName;

  /// True when this provider was synthesised by [SourcesNotifier] from a
  /// top-level [Source]. Marked entries are owned by the dual-write code
  /// and get replaced wholesale on every sources mutation; unmarked
  /// entries (legacy onboarding output, manually edited config) survive
  /// untouched.
  final bool managedBySource;

  /// Optional id of the [Source] that contributed this provider. Set when
  /// [managedBySource] is true so the dual-write can map managed entries
  /// back to their owner source for diffing.
  final String? sourceId;

  const ProviderConfig({
    required this.type,
    required this.priority,
    this.url,
    this.host,
    this.port,
    this.share,
    this.path,
    this.auth,
    this.platformId,
    this.platformName,
    this.managedBySource = false,
    this.sourceId,
  });

  factory ProviderConfig.fromJson(Map<String, dynamic> json) {
    return ProviderConfig(
      type: ProviderType.values.asNameMap()[json['type'] as String] ?? ProviderType.web,
      priority: json['priority'] as int,
      url: json['url'] as String?,
      host: json['host'] as String?,
      port: json['port'] as int?,
      share: json['share'] as String?,
      path: json['path'] as String?,
      auth: json['auth'] != null
          ? AuthConfig.fromJson(json['auth'] as Map<String, dynamic>)
          : null,
      platformId: json['platform_id'] as int?,
      platformName: json['platform_name'] as String?,
      managedBySource: json['managed_by_source'] as bool? ?? false,
      sourceId: json['source_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'priority': priority,
      if (url != null) 'url': url,
      if (host != null) 'host': host,
      if (port != null) 'port': port,
      if (share != null) 'share': share,
      if (path != null) 'path': path,
      if (auth != null) 'auth': auth!.toJson(),
      if (platformId != null) 'platform_id': platformId,
      if (platformName != null) 'platform_name': platformName,
      if (managedBySource) 'managed_by_source': true,
      if (sourceId != null) 'source_id': sourceId,
    };
  }

  /// Like [toJson] but omits auth credentials.
  /// Used for download queue persistence to avoid storing secrets.
  Map<String, dynamic> toJsonWithoutAuth() {
    return {
      'type': type.name,
      'priority': priority,
      if (url != null) 'url': url,
      if (host != null) 'host': host,
      if (port != null) 'port': port,
      if (share != null) 'share': share,
      if (path != null) 'path': path,
      if (platformId != null) 'platform_id': platformId,
      if (platformName != null) 'platform_name': platformName,
    };
  }

  String get shortLabel {
    switch (type) {
      case ProviderType.web:
        return 'WEB';
      case ProviderType.smb:
        return 'SMB';
      case ProviderType.ftp:
        return 'FTP';
      case ProviderType.romm:
        return 'RomM';
    }
  }

  String get hostLabel {
    switch (type) {
      case ProviderType.web:
      case ProviderType.romm:
        if (url == null) return '';
        final uri = Uri.tryParse(url!);
        return uri?.host ?? '';
      case ProviderType.ftp:
      case ProviderType.smb:
        return host ?? '';
    }
  }

  String get detailLabel {
    final h = hostLabel;
    return h.isEmpty ? shortLabel : '$shortLabel · $h';
  }

  /// Validates this config. Returns null if valid, or an error message.
  String? validate() {
    switch (type) {
      case ProviderType.web:
        if (url == null || url!.isEmpty) return 'URL is required for web provider';
        final uri = Uri.tryParse(url!);
        if (uri == null || !uri.hasScheme) return 'Invalid URL';
        break;
      case ProviderType.smb:
        if (host == null || host!.isEmpty) return 'Host is required for SMB provider';
        if (share == null || share!.isEmpty) return 'Share is required for SMB provider';
        if (port != null && (port! < 1 || port! > 65535)) return 'Port must be 1–65535';
        break;
      case ProviderType.ftp:
        if (host == null || host!.isEmpty) return 'Host is required for FTP provider';
        if (port != null && (port! < 1 || port! > 65535)) return 'Port must be 1–65535';
        break;
      case ProviderType.romm:
        if (url == null || url!.isEmpty) return 'URL is required for RomM provider';
        final uri = Uri.tryParse(url!);
        if (uri == null || !uri.hasScheme) return 'Invalid URL';
        break;
    }
    return null;
  }

  /// Returns a warning if credentials are sent over HTTP to a non-private host.
  String? get insecureWarning {
    if (type != ProviderType.web && type != ProviderType.romm) return null;
    if (url == null || !url!.startsWith('http://')) return null;
    final uri = Uri.tryParse(url!);
    if (uri == null) return null;
    final host = uri.host;
    if (host == 'localhost' || host == '127.0.0.1') return null;
    final privateIp = RegExp(
      r'^(10\.\d+\.\d+\.\d+|192\.168\.\d+\.\d+|172\.(1[6-9]|2\d|3[01])\.\d+\.\d+)$',
    );
    if (privateIp.hasMatch(host)) return null;
    final hasAuth = auth != null &&
        ((auth!.user != null && auth!.user!.isNotEmpty) ||
            (auth!.apiKey != null && auth!.apiKey!.isNotEmpty) ||
            (auth!.clientToken != null && auth!.clientToken!.isNotEmpty));
    if (!hasAuth) return null;
    return 'Credentials will be sent unencrypted over HTTP';
  }

  /// True if this provider has no credentials configured.
  bool get needsAuth => auth == null ||
      ((auth!.user?.isEmpty ?? true) &&
       (auth!.pass?.isEmpty ?? true) &&
       (auth!.apiKey?.isEmpty ?? true) &&
       (auth!.clientToken?.isEmpty ?? true));

  /// Finds a [ProviderConfig] in [providers] that matches this config's type
  /// and connection details (host/url/share), ignoring auth credentials.
  ProviderConfig? findMatchIn(List<ProviderConfig> providers) {
    for (final p in providers) {
      if (p.type != type) continue;
      switch (type) {
        case ProviderType.web:
        case ProviderType.romm:
          if (_normalizeUrl(p.url) == _normalizeUrl(url)) return p;
        case ProviderType.smb:
          if (p.host?.toLowerCase() == host?.toLowerCase() &&
              p.share == share) {
            return p;
          }
        case ProviderType.ftp:
          if (p.host?.toLowerCase() == host?.toLowerCase()) {
            return p;
          }
      }
    }
    return null;
  }

  /// Normalizes a URL for comparison: lowercase scheme/host, strip trailing
  /// slashes. Prevents auth rehydration failures from cosmetic URL differences.
  static String? _normalizeUrl(String? rawUrl) {
    if (rawUrl == null) return null;
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null) return rawUrl.trim().toLowerCase();
    // Rebuild with lowercase scheme + host, preserving path/port
    final scheme = uri.scheme.toLowerCase();
    final host = uri.host.toLowerCase();
    final port = uri.hasPort && uri.port != _defaultPort(scheme)
        ? ':${uri.port}'
        : '';
    var path = uri.path;
    while (path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    return '$scheme://$host$port$path';
  }

  static int _defaultPort(String scheme) =>
      scheme == 'https' ? 443 : 80;

  ProviderConfig copyWith({
    ProviderType? type,
    int? priority,
    String? url,
    String? host,
    int? port,
    String? share,
    String? path,
    AuthConfig? auth,
    int? platformId,
    String? platformName,
    bool? managedBySource,
    String? sourceId,
  }) {
    return ProviderConfig(
      type: type ?? this.type,
      priority: priority ?? this.priority,
      url: url ?? this.url,
      host: host ?? this.host,
      port: port ?? this.port,
      share: share ?? this.share,
      path: path ?? this.path,
      auth: auth ?? this.auth,
      platformId: platformId ?? this.platformId,
      platformName: platformName ?? this.platformName,
      managedBySource: managedBySource ?? this.managedBySource,
      sourceId: sourceId ?? this.sourceId,
    );
  }
}
