import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:retro_eshop/services/config_parser.dart';

String _buildConfigJson({
  int version = 2,
  List<Map<String, dynamic>>? systems,
}) {
  systems ??= [
    {
      'id': 'nes',
      'name': 'NES',
      'target_folder': 'NES',
      'providers': [
        {'type': 'web', 'priority': 1, 'url': 'https://example.com/roms'},
      ],
    },
  ];
  return json.encode({'version': version, 'systems': systems});
}

Map<String, dynamic> _webProvider({
  String url = 'https://example.com/roms',
  int priority = 1,
}) =>
    {'type': 'web', 'priority': priority, 'url': url};

Map<String, dynamic> _smbProvider({
  String host = '192.168.1.1',
  String share = 'roms',
  int priority = 1,
}) =>
    {
      'type': 'smb',
      'priority': priority,
      'host': host,
      'share': share,
    };

Map<String, dynamic> _ftpProvider({
  String host = '192.168.1.1',
  int priority = 1,
}) =>
    {'type': 'ftp', 'priority': priority, 'host': host};

Map<String, dynamic> _rommProvider({
  String url = 'https://romm.example.com',
  int platformId = 42,
  int priority = 1,
}) =>
    {
      'type': 'romm',
      'priority': priority,
      'url': url,
      'platform_id': platformId,
    };

Map<String, dynamic> _system({
  String id = 'nes',
  String name = 'NES',
  String targetFolder = 'NES',
  List<Map<String, dynamic>>? providers,
}) =>
    {
      'id': id,
      'name': name,
      'target_folder': targetFolder,
      'providers': providers ?? [_webProvider()],
    };

void main() {
  group('parse — valid configs', () {
    test('parses minimal valid config', () {
      final config = ConfigParser.parse(_buildConfigJson());
      expect(config.systems.length, 1);
      expect(config.systems.first.id, 'nes');
      expect(config.systems.first.providers.length, 1);
    });

    test('parses config with multiple systems', () {
      final config = ConfigParser.parse(_buildConfigJson(systems: [
        _system(id: 'nes', name: 'NES'),
        _system(id: 'snes', name: 'SNES', targetFolder: 'SNES'),
      ]));
      expect(config.systems.length, 2);
      expect(config.systems[0].id, 'nes');
      expect(config.systems[1].id, 'snes');
    });

    test('parses config with all provider types', () {
      final config = ConfigParser.parse(_buildConfigJson(systems: [
        _system(id: 'nes', providers: [_webProvider()]),
        _system(id: 'snes', targetFolder: 'SNES', providers: [_smbProvider()]),
        _system(id: 'gba', name: 'GBA', targetFolder: 'GBA', providers: [_ftpProvider()]),
        _system(id: 'ps1', name: 'PS1', targetFolder: 'PS1', providers: [_rommProvider()]),
      ]));
      expect(config.systems.length, 4);
    });

    test('preserves version field', () {
      final config = ConfigParser.parse(_buildConfigJson(version: 3));
      expect(config.version, 3);
    });
  });

  group('parse — JSON errors', () {
    test('throws on invalid JSON', () {
      expect(
        () => ConfigParser.parse('not json {{{'),
        throwsA(isA<ConfigParseException>()),
      );
    });

    test('throws on non-Map root', () {
      expect(
        () => ConfigParser.parse('[1, 2, 3]'),
        throwsA(isA<ConfigParseException>()),
      );
    });
  });

  group('_validate — system-level', () {
    test('throws on empty system ID', () {
      expect(
        () => ConfigParser.parse(_buildConfigJson(systems: [
          _system(id: ''),
        ])),
        throwsA(isA<ConfigParseException>().having(
          (e) => e.message,
          'message',
          contains('System ID'),
        )),
      );
    });

    test('throws on empty system name', () {
      expect(
        () => ConfigParser.parse(_buildConfigJson(systems: [
          _system(name: ''),
        ])),
        throwsA(isA<ConfigParseException>().having(
          (e) => e.message,
          'message',
          contains('System name'),
        )),
      );
    });

    test('throws on empty target_folder', () {
      expect(
        () => ConfigParser.parse(_buildConfigJson(systems: [
          _system(targetFolder: ''),
        ])),
        throwsA(isA<ConfigParseException>().having(
          (e) => e.message,
          'message',
          contains('target_folder'),
        )),
      );
    });

    test('throws on target_folder containing ".."', () {
      expect(
        () => ConfigParser.parse(_buildConfigJson(systems: [
          _system(targetFolder: '../etc'),
        ])),
        throwsA(isA<ConfigParseException>().having(
          (e) => e.message,
          'message',
          contains('..'),
        )),
      );
    });

    test('throws on duplicate system IDs', () {
      expect(
        () => ConfigParser.parse(_buildConfigJson(systems: [
          _system(id: 'nes', name: 'NES 1'),
          _system(id: 'nes', name: 'NES 2'),
        ])),
        throwsA(isA<ConfigParseException>().having(
          (e) => e.message,
          'message',
          contains('Duplicate'),
        )),
      );
    });
  });

  group('_validateProvider — web', () {
    test('throws on web provider with missing url', () {
      expect(
        () => ConfigParser.parse(_buildConfigJson(systems: [
          _system(providers: [
            {'type': 'web', 'priority': 1},
          ]),
        ])),
        throwsA(isA<ConfigParseException>().having(
          (e) => e.message,
          'message',
          contains('WEB'),
        )),
      );
    });

    test('throws on web provider with empty url', () {
      expect(
        () => ConfigParser.parse(_buildConfigJson(systems: [
          _system(providers: [_webProvider(url: '')]),
        ])),
        throwsA(isA<ConfigParseException>().having(
          (e) => e.message,
          'message',
          contains('WEB'),
        )),
      );
    });
  });

  group('_validateProvider — smb', () {
    test('throws on smb provider with missing host', () {
      expect(
        () => ConfigParser.parse(_buildConfigJson(systems: [
          _system(providers: [
            {'type': 'smb', 'priority': 1, 'share': 'roms'},
          ]),
        ])),
        throwsA(isA<ConfigParseException>().having(
          (e) => e.message,
          'message',
          contains('SMB'),
        )),
      );
    });

    test('throws on smb provider with missing share', () {
      expect(
        () => ConfigParser.parse(_buildConfigJson(systems: [
          _system(providers: [
            {'type': 'smb', 'priority': 1, 'host': '192.168.1.1'},
          ]),
        ])),
        throwsA(isA<ConfigParseException>().having(
          (e) => e.message,
          'message',
          contains('SMB'),
        )),
      );
    });
  });

  group('_validateProvider — ftp', () {
    test('throws on ftp provider with missing host', () {
      expect(
        () => ConfigParser.parse(_buildConfigJson(systems: [
          _system(providers: [
            {'type': 'ftp', 'priority': 1},
          ]),
        ])),
        throwsA(isA<ConfigParseException>().having(
          (e) => e.message,
          'message',
          contains('FTP'),
        )),
      );
    });
  });

  group('_validateProvider — romm', () {
    test('throws on romm provider with missing url', () {
      expect(
        () => ConfigParser.parse(_buildConfigJson(systems: [
          _system(providers: [
            {'type': 'romm', 'priority': 1, 'platform_id': 42},
          ]),
        ])),
        throwsA(isA<ConfigParseException>().having(
          (e) => e.message,
          'message',
          contains('ROMM'),
        )),
      );
    });

    test('throws on romm provider with missing platformId', () {
      expect(
        () => ConfigParser.parse(_buildConfigJson(systems: [
          _system(providers: [
            {'type': 'romm', 'priority': 1, 'url': 'https://romm.test'},
          ]),
        ])),
        throwsA(isA<ConfigParseException>().having(
          (e) => e.message,
          'message',
          contains('platformId'),
        )),
      );
    });
  });

  group('parseFile', () {
    test('throws on non-existent file', () async {
      await expectLater(
        ConfigParser.parseFile('/tmp/nonexistent_rshop_config.json'),
        throwsA(isA<ConfigParseException>().having(
          (e) => e.message,
          'message',
          contains('not found'),
        )),
      );
    });

    test('parses valid file from temp directory', () async {
      final tmpDir = Directory.systemTemp.createTempSync('config_parser_test_');
      final file = File('${tmpDir.path}/config.json');
      try {
        await file.writeAsString(_buildConfigJson());
        final config = await ConfigParser.parseFile(file.path);
        expect(config.systems.length, 1);
        expect(config.systems.first.id, 'nes');
      } finally {
        tmpDir.deleteSync(recursive: true);
      }
    });
  });

  group('ConfigParseException', () {
    test('toString() includes message', () {
      const e = ConfigParseException('bad config');
      expect(e.toString(), contains('bad config'));
      expect(e.toString(), contains('ConfigParseException'));
    });

    test('can be caught as Exception', () {
      expect(
        () => throw const ConfigParseException('test'),
        throwsA(isA<Exception>()),
      );
    });
  });
}
