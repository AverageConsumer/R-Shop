enum ProviderType { web, smb, ftp, romm }

class AuthConfig {
  final String? user;
  final String? pass;
  final String? apiKey;
  final String? domain;

  const AuthConfig({this.user, this.pass, this.apiKey, this.domain});

  factory AuthConfig.fromJson(Map<String, dynamic> json) {
    return AuthConfig(
      user: json['user'] as String?,
      pass: json['pass'] as String?,
      apiKey: json['api_key'] as String?,
      domain: json['domain'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (user != null) 'user': user,
      if (pass != null) 'pass': pass,
      if (apiKey != null) 'api_key': apiKey,
      if (domain != null) 'domain': domain,
    };
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
    );
  }
}
