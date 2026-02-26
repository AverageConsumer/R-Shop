import 'provider_config.dart';

class SystemConfig {
  final String id;
  final String name;
  final String targetFolder;
  final List<ProviderConfig> providers;
  final bool autoExtract;
  final bool mergeMode;

  const SystemConfig({
    required this.id,
    required this.name,
    required this.targetFolder,
    required this.providers,
    this.autoExtract = false,
    this.mergeMode = false,
  });

  factory SystemConfig.fromJson(Map<String, dynamic> json) {
    final providerList = (json['providers'] as List<dynamic>)
        .map((e) => ProviderConfig.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));

    return SystemConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      targetFolder: json['target_folder'] as String,
      providers: providerList,
      autoExtract: json['auto_extract'] as bool? ?? false,
      mergeMode: json['merge_mode'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'target_folder': targetFolder,
      'providers': providers.map((p) => p.toJson()).toList(),
      'auto_extract': autoExtract,
      'merge_mode': mergeMode,
    };
  }

  /// Like [toJson] but strips auth credentials from all providers.
  Map<String, dynamic> toJsonWithoutAuth() {
    return {
      'id': id,
      'name': name,
      'target_folder': targetFolder,
      'providers': providers.map((p) => p.toJsonWithoutAuth()).toList(),
      'auto_extract': autoExtract,
      'merge_mode': mergeMode,
    };
  }

  SystemConfig copyWith({
    String? id,
    String? name,
    String? targetFolder,
    List<ProviderConfig>? providers,
    bool? autoExtract,
    bool? mergeMode,
  }) {
    return SystemConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      targetFolder: targetFolder ?? this.targetFolder,
      providers: providers ?? this.providers,
      autoExtract: autoExtract ?? this.autoExtract,
      mergeMode: mergeMode ?? this.mergeMode,
    );
  }
}
