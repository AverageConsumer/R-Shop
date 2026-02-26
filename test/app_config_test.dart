import 'package:flutter_test/flutter_test.dart';
import 'package:retro_eshop/models/config/app_config.dart';
import 'package:retro_eshop/models/config/system_config.dart';

Map<String, dynamic> _providerJson({
  String type = 'web',
  int priority = 1,
  String? url,
  String? host,
  String? share,
  Map<String, dynamic>? auth,
}) {
  return {
    'type': type,
    'priority': priority,
    if (url != null) 'url': url,
    if (host != null) 'host': host,
    if (share != null) 'share': share,
    if (auth != null) 'auth': auth,
  };
}

Map<String, dynamic> _systemJson({
  String id = 'gba',
  String name = 'Game Boy Advance',
  String targetFolder = '/roms/gba',
  List<Map<String, dynamic>>? providers,
  bool? autoExtract,
  bool? mergeMode,
}) {
  return {
    'id': id,
    'name': name,
    'target_folder': targetFolder,
    'providers': providers ?? [_providerJson(url: 'https://x.com')],
    if (autoExtract != null) 'auto_extract': autoExtract,
    if (mergeMode != null) 'merge_mode': mergeMode,
  };
}

void main() {
  // ─── SystemConfig ─────────────────────────────────────────────────

  group('SystemConfig', () {
    test('fromJson round-trips via toJson', () {
      final json = _systemJson(
        autoExtract: true,
        mergeMode: true,
        providers: [
          _providerJson(url: 'https://a.com'),
          _providerJson(type: 'smb', priority: 2, host: 'nas', share: 'r'),
        ],
      );
      final config = SystemConfig.fromJson(json);
      expect(config.id, 'gba');
      expect(config.name, 'Game Boy Advance');
      expect(config.targetFolder, '/roms/gba');
      expect(config.autoExtract, isTrue);
      expect(config.mergeMode, isTrue);
      expect(config.providers, hasLength(2));

      final roundTrip = SystemConfig.fromJson(config.toJson());
      expect(roundTrip.id, config.id);
      expect(roundTrip.name, config.name);
      expect(roundTrip.autoExtract, config.autoExtract);
      expect(roundTrip.providers.length, config.providers.length);
    });

    test('fromJson sorts providers by priority ascending', () {
      final json = _systemJson(providers: [
        _providerJson(type: 'ftp', priority: 3, host: 'ftp.local'),
        _providerJson(type: 'web', priority: 1, url: 'https://x.com'),
        _providerJson(type: 'smb', priority: 2, host: 'nas', share: 'r'),
      ]);
      final config = SystemConfig.fromJson(json);
      expect(config.providers[0].priority, 1);
      expect(config.providers[1].priority, 2);
      expect(config.providers[2].priority, 3);
    });

    test('fromJson defaults autoExtract and mergeMode to false when absent',
        () {
      final json = _systemJson(); // no auto_extract or merge_mode keys
      final config = SystemConfig.fromJson(json);
      expect(config.autoExtract, isFalse);
      expect(config.mergeMode, isFalse);
    });

    test('toJsonWithoutAuth strips credentials from all providers', () {
      final json = _systemJson(providers: [
        _providerJson(
          url: 'https://x.com',
          auth: {'user': 'u', 'pass': 'p'},
        ),
        _providerJson(
          type: 'smb',
          priority: 2,
          host: 'nas',
          share: 'r',
          auth: {'user': 'admin', 'pass': 'pw'},
        ),
      ]);
      final config = SystemConfig.fromJson(json);
      final stripped = config.toJsonWithoutAuth();
      final providers = stripped['providers'] as List<dynamic>;
      for (final p in providers) {
        expect((p as Map<String, dynamic>).containsKey('auth'), isFalse);
      }
      // Non-auth fields preserved
      expect(stripped['id'], 'gba');
      expect(stripped['name'], 'Game Boy Advance');
    });

    test('copyWith overrides specified fields', () {
      final config = SystemConfig.fromJson(_systemJson());
      final copy = config.copyWith(name: 'GBA', autoExtract: true);
      expect(copy.name, 'GBA');
      expect(copy.autoExtract, isTrue);
      // Preserved
      expect(copy.id, 'gba');
      expect(copy.targetFolder, '/roms/gba');
      expect(copy.mergeMode, isFalse);
    });
  });

  // ─── AppConfig ────────────────────────────────────────────────────

  group('AppConfig', () {
    test('AppConfig.empty has version 2 and no systems', () {
      expect(AppConfig.empty.version, 2);
      expect(AppConfig.empty.systems, isEmpty);
    });

    test('fromJson round-trips via toJson', () {
      final json = {
        'version': 2,
        'systems': [
          _systemJson(id: 'gba'),
          _systemJson(id: 'snes', name: 'SNES', targetFolder: '/roms/snes'),
        ],
      };
      final config = AppConfig.fromJson(json);
      expect(config.version, 2);
      expect(config.systems, hasLength(2));

      final roundTrip = AppConfig.fromJson(config.toJson());
      expect(roundTrip.version, config.version);
      expect(roundTrip.systems.length, config.systems.length);
      expect(roundTrip.systems[0].id, 'gba');
      expect(roundTrip.systems[1].id, 'snes');
    });

    test('fromJson defaults version to 1 when missing', () {
      final config = AppConfig.fromJson({
        'systems': [_systemJson()],
      });
      expect(config.version, 1);
    });

    test('systemById returns matching system or null', () {
      final config = AppConfig.fromJson({
        'version': 2,
        'systems': [
          _systemJson(id: 'gba'),
          _systemJson(id: 'snes', name: 'SNES', targetFolder: '/roms/snes'),
        ],
      });
      expect(config.systemById('gba'), isNotNull);
      expect(config.systemById('gba')!.id, 'gba');
      expect(config.systemById('snes')!.name, 'SNES');
      expect(config.systemById('n64'), isNull);
    });

    test('toJsonWithoutAuth strips auth from nested systems', () {
      final config = AppConfig.fromJson({
        'version': 2,
        'systems': [
          _systemJson(providers: [
            _providerJson(
              url: 'https://x.com',
              auth: {'user': 'u', 'pass': 'secret'},
            ),
          ]),
        ],
      });
      final stripped = config.toJsonWithoutAuth();
      final systems = stripped['systems'] as List<dynamic>;
      final providers =
          (systems[0] as Map<String, dynamic>)['providers'] as List<dynamic>;
      expect(
        (providers[0] as Map<String, dynamic>).containsKey('auth'),
        isFalse,
      );
      // Version preserved
      expect(stripped['version'], 2);
    });
  });
}
