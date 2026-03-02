import 'package:flutter_test/flutter_test.dart';
import 'package:retro_eshop/models/config/app_config.dart';
import 'package:retro_eshop/models/config/system_config.dart';
import 'package:retro_eshop/models/system_model.dart';
import 'package:retro_eshop/services/config_bootstrap.dart';

void main() {
  const snesConfig = SystemConfig(
    id: 'snes',
    name: 'SNES',
    targetFolder: '/roms/snes',
    providers: [],
  );

  const gbaConfig = SystemConfig(
    id: 'gba',
    name: 'GBA',
    targetFolder: '/roms/gba',
    providers: [],
  );

  const snesModel = SystemModel(
    id: 'snes',
    name: 'Super Nintendo',
    manufacturer: 'Nintendo',
    releaseYear: 1990,
  );

  const n64Model = SystemModel(
    id: 'n64',
    name: 'Nintendo 64',
    manufacturer: 'Nintendo',
    releaseYear: 1996,
  );

  group('configForSystem', () {
    test('returns SystemConfig when system exists in config', () {
      const config = AppConfig(systems: [snesConfig, gbaConfig]);

      final result = ConfigBootstrap.configForSystem(config, snesModel);

      expect(result, isNotNull);
      expect(result!.id, 'snes');
      expect(result.name, 'SNES');
    });

    test('returns null when system is not in config', () {
      const config = AppConfig(systems: [snesConfig, gbaConfig]);

      final result = ConfigBootstrap.configForSystem(config, n64Model);

      expect(result, isNull);
    });

    test('returns null for empty systems list', () {
      const config = AppConfig(systems: []);

      final result = ConfigBootstrap.configForSystem(config, snesModel);

      expect(result, isNull);
    });
  });
}
