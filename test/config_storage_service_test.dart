import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:retro_eshop/services/config_storage_service.dart';

/// Minimal valid JSON that ConfigParser.parse() accepts.
String _validConfigJson({String systemId = 'snes', String name = 'SNES'}) {
  return jsonEncode({
    'version': 2,
    'systems': [
      {
        'id': systemId,
        'name': name,
        'target_folder': '/roms/$systemId',
        'providers': [
          {'type': 'web', 'priority': 1, 'url': 'http://example.com/$systemId/'},
        ],
      },
    ],
  });
}

void main() {
  late Directory tempDir;
  late ConfigStorageService service;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('config_test_');
    service = ConfigStorageService(directoryProvider: () async => tempDir);
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  // ─── saveConfig ────────────────────────────────────────

  group('saveConfig', () {
    test('creates config.json on disk', () async {
      await service.saveConfig(_validConfigJson());
      final file = File('${tempDir.path}/config.json');
      expect(file.existsSync(), isTrue);
    });

    test('file contains exact content', () async {
      final json = _validConfigJson();
      await service.saveConfig(json);
      final file = File('${tempDir.path}/config.json');
      expect(file.readAsStringSync(), json);
    });

    test('second save creates .bak with previous content', () async {
      final first = _validConfigJson(name: 'First');
      final second = _validConfigJson(name: 'Second');
      await service.saveConfig(first);
      await service.saveConfig(second);

      final backup = File('${tempDir.path}/config.json.bak');
      expect(backup.existsSync(), isTrue);
      expect(backup.readAsStringSync(), first);

      final primary = File('${tempDir.path}/config.json');
      expect(primary.readAsStringSync(), second);
    });

    test('no .tmp files remain after save', () async {
      await service.saveConfig(_validConfigJson());
      final tmpFiles = tempDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.tmp'));
      expect(tmpFiles, isEmpty);
    });

    test('concurrent rapid saves both succeed', () async {
      final json1 = _validConfigJson(name: 'Concurrent1');
      final json2 = _validConfigJson(name: 'Concurrent2');
      await Future.wait([
        service.saveConfig(json1),
        service.saveConfig(json2),
      ]);
      // Both should complete without error; final state is one of the two
      final file = File('${tempDir.path}/config.json');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content == json1 || content == json2, isTrue);
    });
  });

  // ─── loadConfig / loadConfigWithRecoveryInfo ────────────

  group('loadConfig / loadConfigWithRecoveryInfo', () {
    test('returns null when no file', () async {
      final config = await service.loadConfig();
      expect(config, isNull);
    });

    test('save then load round-trip returns AppConfig', () async {
      await service.saveConfig(_validConfigJson());
      final config = await service.loadConfig();
      expect(config, isNotNull);
      expect(config!.systems.length, 1);
      expect(config.systems.first.id, 'snes');
    });

    test('wasRecovered false for valid primary', () async {
      await service.saveConfig(_validConfigJson());
      final result = await service.loadConfigWithRecoveryInfo();
      expect(result.wasRecovered, isFalse);
      expect(result.config, isNotNull);
    });

    test('corrupt primary + valid backup → wasRecovered true', () async {
      // Write valid config, then a second so .bak exists
      await service.saveConfig(_validConfigJson(name: 'Good'));
      await service.saveConfig(_validConfigJson(name: 'AlsoGood'));

      // Corrupt the primary
      final primary = File('${tempDir.path}/config.json');
      primary.writeAsStringSync('NOT VALID JSON {{{');

      final result = await service.loadConfigWithRecoveryInfo();
      expect(result.wasRecovered, isTrue);
      expect(result.config, isNotNull);
      expect(result.config!.systems.first.name, 'Good');
    });

    test('corrupt primary + no backup → null', () async {
      // Write then corrupt
      await service.saveConfig(_validConfigJson());
      final primary = File('${tempDir.path}/config.json');
      primary.writeAsStringSync('CORRUPT');
      // Remove backup if it exists
      final backup = File('${tempDir.path}/config.json.bak');
      if (backup.existsSync()) backup.deleteSync();

      final result = await service.loadConfigWithRecoveryInfo();
      expect(result.config, isNull);
      expect(result.wasRecovered, isFalse);
    });
  });

  // ─── hasConfig / deleteConfig ──────────────────────────

  group('hasConfig / deleteConfig', () {
    test('hasConfig false when no file', () async {
      expect(await service.hasConfig(), isFalse);
    });

    test('hasConfig true after save', () async {
      await service.saveConfig(_validConfigJson());
      expect(await service.hasConfig(), isTrue);
    });

    test('deleteConfig removes file and returns true', () async {
      await service.saveConfig(_validConfigJson());
      expect(await service.deleteConfig(), isTrue);
      expect(await service.hasConfig(), isFalse);
    });

    test('deleteConfig on missing file returns false', () async {
      expect(await service.deleteConfig(), isFalse);
    });
  });

  // ─── AsyncLock ─────────────────────────────────────────

  group('AsyncLock', () {
    test('two concurrent saves execute sequentially (both succeed)', () async {
      final log = <String>[];
      final json1 = _validConfigJson(name: 'Lock1');
      final json2 = _validConfigJson(name: 'Lock2');

      final f1 = service.saveConfig(json1).then((_) => log.add('first'));
      final f2 = service.saveConfig(json2).then((_) => log.add('second'));
      await Future.wait([f1, f2]);

      expect(log.length, 2);
      // Both completed without errors
      expect(await service.hasConfig(), isTrue);
    });

    test('save during load does not deadlock', () async {
      await service.saveConfig(_validConfigJson());
      // Simultaneous load + save
      final results = await Future.wait([
        service.loadConfig(),
        service.saveConfig(_validConfigJson(name: 'Updated')),
      ]);
      expect(results[0], isNotNull); // load succeeded
      // save also succeeded — verify final state
      final config = await service.loadConfig();
      expect(config, isNotNull);
    });
  });
}
