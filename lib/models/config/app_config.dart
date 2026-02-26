import 'system_config.dart';

class AppConfig {
  final int version;
  final List<SystemConfig> systems;

  const AppConfig({this.version = 2, required this.systems});

  static const empty = AppConfig(systems: []);

  SystemConfig? systemById(String id) {
    for (final system in systems) {
      if (system.id == id) return system;
    }
    return null;
  }

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      version: json['version'] as int? ?? 1,
      systems: (json['systems'] as List<dynamic>)
          .map((e) => SystemConfig.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'systems': systems.map((s) => s.toJson()).toList(),
    };
  }

  /// Like [toJson] but strips all auth credentials (passwords, API keys).
  /// Used for config export to prevent accidental credential sharing.
  Map<String, dynamic> toJsonWithoutAuth() {
    return {
      'version': version,
      'systems': systems.map((s) => s.toJsonWithoutAuth()).toList(),
    };
  }
}
