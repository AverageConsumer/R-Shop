import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:retro_eshop/services/storage_service.dart';
import 'package:retro_eshop/models/sound_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    service = StorageService();
    await service.init();
  });

  group('StorageService — initialization', () {
    test('uninitialized access throws StateError', () {
      final uninitService = StorageService();
      expect(() => uninitService.getRomPath(), throwsStateError);
    });
  });

  group('StorageService — ROM path', () {
    test('getRomPath returns null on empty storage', () {
      expect(service.getRomPath(), isNull);
    });

    test('setRomPath + getRomPath round-trip', () async {
      await service.setRomPath('/storage/ROMs');
      expect(service.getRomPath(), '/storage/ROMs');
    });
  });

  group('StorageService — haptic', () {
    test('getHapticEnabled defaults to true', () {
      expect(service.getHapticEnabled(), isTrue);
    });

    test('setHapticEnabled + getHapticEnabled round-trip', () async {
      await service.setHapticEnabled(false);
      expect(service.getHapticEnabled(), isFalse);
    });
  });

  group('StorageService — onboarding', () {
    test('getOnboardingCompleted defaults to false', () {
      expect(service.getOnboardingCompleted(), isFalse);
    });

    test('setOnboardingCompleted round-trip', () async {
      await service.setOnboardingCompleted(true);
      expect(service.getOnboardingCompleted(), isTrue);
    });
  });

  group('StorageService — sound settings', () {
    test('getSoundSettings returns defaults', () {
      final settings = service.getSoundSettings();
      expect(settings.enabled, isTrue);
      expect(settings.bgmVolume, 0.3);
      expect(settings.sfxVolume, 0.7);
    });

    test('setSoundSettings + getSoundSettings JSON round-trip', () async {
      const custom = SoundSettings(
        enabled: false,
        bgmVolume: 0.5,
        sfxVolume: 0.9,
      );
      await service.setSoundSettings(custom);
      final loaded = service.getSoundSettings();
      expect(loaded.enabled, isFalse);
      expect(loaded.bgmVolume, 0.5);
      expect(loaded.sfxVolume, 0.9);
    });

    test('getSoundSettings returns defaults on corrupt JSON', () async {
      // Write corrupt JSON directly to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('sound_settings', '{not valid json!!!');
      final settings = service.getSoundSettings();
      expect(settings.enabled, isTrue);
      expect(settings.bgmVolume, 0.3);
    });
  });

  group('StorageService — grid columns', () {
    test('getGridColumns defaults to 4', () {
      expect(service.getGridColumns('gba'), 4);
    });

    test('setGridColumns uses per-system keys', () async {
      await service.setGridColumns('gba', 3);
      await service.setGridColumns('snes', 5);
      expect(service.getGridColumns('gba'), 3);
      expect(service.getGridColumns('snes'), 5);
    });
  });

  group('StorageService — display settings', () {
    test('getShowFullFilename defaults to false', () {
      expect(service.getShowFullFilename(), isFalse);
    });

    test('setShowFullFilename round-trip', () async {
      await service.setShowFullFilename(true);
      expect(service.getShowFullFilename(), isTrue);
    });
  });

  group('StorageService — concurrent downloads', () {
    test('getMaxConcurrentDownloads defaults to 2', () {
      expect(service.getMaxConcurrentDownloads(), 2);
    });

    test('setMaxConcurrentDownloads round-trip', () async {
      await service.setMaxConcurrentDownloads(5);
      expect(service.getMaxConcurrentDownloads(), 5);
    });
  });

  group('StorageService — controller layout', () {
    test('getControllerLayout defaults to nintendo', () {
      expect(service.getControllerLayout(), ControllerLayout.nintendo);
    });

    test('setControllerLayout round-trip', () async {
      await service.setControllerLayout(ControllerLayout.xbox);
      expect(service.getControllerLayout(), ControllerLayout.xbox);
    });

    test('setControllerLayout playstation round-trip', () async {
      await service.setControllerLayout(ControllerLayout.playstation);
      expect(service.getControllerLayout(), ControllerLayout.playstation);
    });

    test('migration: old xbox_layout bool → ControllerLayout.xbox', () async {
      // Simulate old storage with only the legacy bool key
      SharedPreferences.setMockInitialValues({'xbox_layout': true});
      FlutterSecureStorage.setMockInitialValues({});
      final migrationService = StorageService();
      await migrationService.init();
      expect(migrationService.getControllerLayout(), ControllerLayout.xbox);
    });

    test('migration: old xbox_layout false → nintendo', () async {
      SharedPreferences.setMockInitialValues({'xbox_layout': false});
      FlutterSecureStorage.setMockInitialValues({});
      final migrationService = StorageService();
      await migrationService.init();
      expect(
          migrationService.getControllerLayout(), ControllerLayout.nintendo);
    });
  });

  group('StorageService — favorites', () {
    test('toggleFavorite adds game', () async {
      await service.toggleFavorite('game-123');
      expect(service.isFavorite('game-123'), isTrue);
    });

    test('toggleFavorite removes game on second call', () async {
      await service.toggleFavorite('game-123');
      await service.toggleFavorite('game-123');
      expect(service.isFavorite('game-123'), isFalse);
    });

    test('isFavorite returns false for unknown game', () {
      expect(service.isFavorite('nonexistent'), isFalse);
    });

    test('getFavorites returns list', () async {
      await service.toggleFavorite('a');
      await service.toggleFavorite('b');
      expect(service.getFavorites(), containsAll(['a', 'b']));
    });
  });

  group('StorageService — RomM', () {
    test('setRommUrl(null) removes key', () async {
      await service.setRommUrl('https://romm.example.com');
      expect(service.getRommUrl(), isNotNull);
      await service.setRommUrl(null);
      expect(service.getRommUrl(), isNull);
    });

    test('setRommUrl with empty string removes key', () async {
      await service.setRommUrl('https://romm.example.com');
      await service.setRommUrl('');
      expect(service.getRommUrl(), isNull);
    });

    test('setRommAuth + getRommAuth round-trip', () async {
      await service.setRommAuth('{"user":"admin","pass":"secret"}');
      expect(service.getRommAuth(), '{"user":"admin","pass":"secret"}');
      await service.setRommAuth(null);
      expect(service.getRommAuth(), isNull);
    });

    test('migrates auth from SharedPreferences to SecureStorage', () async {
      // Simulate old storage with RomM auth in plain SharedPreferences
      SharedPreferences.setMockInitialValues({
        'romm_url': 'https://romm.example.com',
        'romm_auth': '{"user":"admin"}',
      });
      FlutterSecureStorage.setMockInitialValues({});
      final migrationService = StorageService();
      await migrationService.init();

      // Auth should be accessible via the service
      expect(migrationService.getRommUrl(), 'https://romm.example.com');
      expect(migrationService.getRommAuth(), '{"user":"admin"}');

      // Old SharedPreferences keys should be removed
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('romm_url'), isNull);
      expect(prefs.getString('romm_auth'), isNull);

      // Migration flag should be set
      expect(prefs.getBool('secure_auth_migrated'), isTrue);
    });
  });

  group('StorageService — home layout', () {
    test('getHomeLayoutIsGrid defaults to false', () {
      expect(service.getHomeLayoutIsGrid(), isFalse);
    });

    test('setHomeLayoutIsGrid round-trip', () async {
      await service.setHomeLayoutIsGrid(true);
      expect(service.getHomeLayoutIsGrid(), isTrue);
    });
  });

  group('StorageService — resetAll', () {
    test('resetAll clears all stored values', () async {
      await service.setRomPath('/storage/ROMs');
      await service.setHapticEnabled(false);
      await service.toggleFavorite('game-1');
      await service.resetAll();

      expect(service.getRomPath(), isNull);
      expect(service.getHapticEnabled(), isTrue); // default
      expect(service.isFavorite('game-1'), isFalse);
    });
  });
}
