import '../models/config/app_config.dart';
import '../models/config/system_config.dart';
import '../models/system_model.dart';

class ConfigBootstrap {
  /// Finds the SystemConfig matching a SystemModel by id.
  static SystemConfig? configForSystem(AppConfig config, SystemModel system) {
    return config.systemById(system.id);
  }
}
