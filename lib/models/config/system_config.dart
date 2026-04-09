import 'provider_config.dart';
import 'source.dart';

class SystemConfig {
  final String id;
  final String name;
  final String targetFolder;

  /// Legacy provider list. Kept alive during the v2 → v3 transition so that
  /// existing services keep working unchanged. New code should consume
  /// [Source]s from `AppConfig.sources` via the resolver instead. The
  /// migration step keeps `providers` and the new fields in sync; once all
  /// callers move over, this field will be removed.
  final List<ProviderConfig> providers;

  final bool autoExtract;
  final bool mergeMode;
  final bool autoSync;

  /// Optional explicit allow-list of source ids that contribute to this
  /// system. `null` means "use every auto-mapped source plus everything in
  /// [manualMappings]" (the default after migration). A non-null list lets
  /// power users opt out of specific RomMs for a given system without
  /// touching their global priority.
  final List<String>? enabledSourceIds;

  /// Per-system pointers into manual sources (SMB/FTP/Web). Empty for
  /// pure-RomM setups since RomM advertises its platforms automatically.
  final List<SystemSourceMapping> manualMappings;

  const SystemConfig({
    required this.id,
    required this.name,
    required this.targetFolder,
    required this.providers,
    this.autoExtract = false,
    this.mergeMode = false,
    this.autoSync = true,
    this.enabledSourceIds,
    this.manualMappings = const [],
  });

  factory SystemConfig.fromJson(Map<String, dynamic> json) {
    final providerList = (json['providers'] as List<dynamic>? ?? const [])
        .map((e) => ProviderConfig.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));

    final mappings = (json['manual_mappings'] as List<dynamic>?)
            ?.map((e) =>
                SystemSourceMapping.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const <SystemSourceMapping>[];

    final allowList = (json['enabled_source_ids'] as List<dynamic>?)
        ?.map((e) => e.toString())
        .toList();

    return SystemConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      targetFolder: json['target_folder'] as String,
      providers: providerList,
      autoExtract: json['auto_extract'] as bool? ?? false,
      mergeMode: json['merge_mode'] as bool? ?? false,
      autoSync: json['auto_sync'] as bool? ?? true,
      enabledSourceIds: allowList,
      manualMappings: mappings,
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
      'auto_sync': autoSync,
      if (enabledSourceIds != null) 'enabled_source_ids': enabledSourceIds,
      if (manualMappings.isNotEmpty)
        'manual_mappings': manualMappings.map((m) => m.toJson()).toList(),
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
      'auto_sync': autoSync,
      if (enabledSourceIds != null) 'enabled_source_ids': enabledSourceIds,
      if (manualMappings.isNotEmpty)
        'manual_mappings': manualMappings.map((m) => m.toJson()).toList(),
    };
  }

  SystemConfig copyWith({
    String? id,
    String? name,
    String? targetFolder,
    List<ProviderConfig>? providers,
    bool? autoExtract,
    bool? mergeMode,
    bool? autoSync,
    List<String>? enabledSourceIds,
    bool clearEnabledSourceIds = false,
    List<SystemSourceMapping>? manualMappings,
  }) {
    return SystemConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      targetFolder: targetFolder ?? this.targetFolder,
      providers: providers ?? this.providers,
      autoExtract: autoExtract ?? this.autoExtract,
      mergeMode: mergeMode ?? this.mergeMode,
      autoSync: autoSync ?? this.autoSync,
      enabledSourceIds: clearEnabledSourceIds
          ? null
          : (enabledSourceIds ?? this.enabledSourceIds),
      manualMappings: manualMappings ?? this.manualMappings,
    );
  }
}
