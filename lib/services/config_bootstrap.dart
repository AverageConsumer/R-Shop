import '../models/config/app_config.dart';
import '../models/config/provider_config.dart';
import '../models/config/system_config.dart';
import '../models/system_model.dart';

class ConfigBootstrap {
  /// Builds an AppConfig from the hardcoded SystemModel list + user's base URL.
  /// Each system gets a single WebProvider using `baseUrl/sourceSlug/`.
  static AppConfig buildDefaultConfig(String baseUrl) {
    final normalizedBase = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    final systems = <SystemConfig>[];

    for (final system in SystemModel.supportedSystems) {
      final slugs = system.sourceSlugs ?? [system.sourceSlug];
      final providers = <ProviderConfig>[];

      for (var i = 0; i < slugs.length; i++) {
        providers.add(ProviderConfig(
          type: ProviderType.web,
          priority: i,
          url: '$normalizedBase${slugs[i]}/',
        ));
      }

      systems.add(SystemConfig(
        id: system.esdeFolder,
        name: system.name,
        targetFolder: system.esdeFolder,
        providers: providers,
        autoExtract: system.isZipped,
      ));
    }

    return AppConfig(systems: systems);
  }

  /// Finds the SystemConfig matching a SystemModel by esdeFolder.
  static SystemConfig? configForSystem(AppConfig config, SystemModel system) {
    return config.systemById(system.esdeFolder);
  }
}
