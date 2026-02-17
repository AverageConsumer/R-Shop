enum ProviderType { web, smb, ftp, romm }

class AuthConfig {
  final String? user;
  final String? pass;
  final String? apiKey;

  const AuthConfig({this.user, this.pass, this.apiKey});

  factory AuthConfig.fromJson(Map<String, dynamic> json) {
    return AuthConfig(
      user: json['user'] as String?,
      pass: json['pass'] as String?,
      apiKey: json['api_key'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (user != null) 'user': user,
      if (pass != null) 'pass': pass,
      if (apiKey != null) 'api_key': apiKey,
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
