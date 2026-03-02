import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:retro_eshop/services/native_smb_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SmbFileEntry', () {
    test('stores all fields correctly', () {
      const entry = SmbFileEntry(
        name: 'game.zip',
        path: '/roms/game.zip',
        isDirectory: false,
        size: 1024,
        parentPath: '/roms',
      );
      expect(entry.name, 'game.zip');
      expect(entry.path, '/roms/game.zip');
      expect(entry.isDirectory, false);
      expect(entry.size, 1024);
      expect(entry.parentPath, '/roms');
    });

    test('parentPath is optional', () {
      const entry = SmbFileEntry(
        name: 'roms',
        path: '/roms',
        isDirectory: true,
        size: 0,
      );
      expect(entry.parentPath, isNull);
    });
  });

  group('NativeSmbService', () {
    late NativeSmbService service;
    late List<MethodCall> methodCalls;

    setUp(() {
      service = NativeSmbService();
      methodCalls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.retro.rshop/smb'),
        (call) async {
          methodCalls.add(call);
          switch (call.method) {
            case 'testConnection':
              return {'success': true, 'error': null};
            case 'listFiles':
              return [
                {
                  'name': 'game.zip',
                  'path': '/roms/game.zip',
                  'isDirectory': false,
                  'size': 2048,
                  'parentPath': '/roms',
                },
                {
                  'name': 'subfolder',
                  'path': '/roms/subfolder',
                  'isDirectory': true,
                  'size': 0,
                  'parentPath': '/roms',
                },
              ];
            case 'startDownload':
              return null;
            case 'cancelDownload':
              return null;
            default:
              return null;
          }
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.retro.rshop/smb'),
        null,
      );
    });

    group('testConnection', () {
      test('returns success when connection succeeds', () async {
        final result = await service.testConnection(
          host: '192.168.1.100',
          share: 'roms',
        );
        expect(result.success, true);
        expect(result.error, isNull);
      });

      test('passes correct arguments to channel', () async {
        await service.testConnection(
          host: '192.168.1.100',
          port: 445,
          share: 'roms',
          path: '/snes',
          user: 'admin',
          pass: 'secret',
          domain: 'WORKGROUP',
        );

        expect(methodCalls.length, 1);
        expect(methodCalls.first.method, 'testConnection');
        final args = methodCalls.first.arguments as Map;
        expect(args['host'], '192.168.1.100');
        expect(args['port'], 445);
        expect(args['share'], 'roms');
        expect(args['path'], '/snes');
        expect(args['user'], 'admin');
        expect(args['pass'], 'secret');
        expect(args['domain'], 'WORKGROUP');
      });

      test('returns failure on connection error', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('com.retro.rshop/smb'),
          (call) async => {'success': false, 'error': 'Host unreachable'},
        );

        final result = await service.testConnection(
          host: '10.0.0.1',
          share: 'roms',
        );
        expect(result.success, false);
        expect(result.error, 'Host unreachable');
      });

      test('handles PlatformException', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('com.retro.rshop/smb'),
          (call) async =>
              throw PlatformException(code: 'SMB_ERROR', message: 'Timeout'),
        );

        final result = await service.testConnection(
          host: '10.0.0.1',
          share: 'roms',
        );
        expect(result.success, false);
        expect(result.error, 'Timeout');
      });

      test('handles null response', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('com.retro.rshop/smb'),
          (call) async => null,
        );

        final result = await service.testConnection(
          host: '10.0.0.1',
          share: 'roms',
        );
        expect(result.success, false);
        expect(result.error, 'No response from SMB service');
      });

      test('uses default values for optional parameters', () async {
        await service.testConnection(
          host: '192.168.1.1',
          share: 'share',
        );

        final args = methodCalls.first.arguments as Map;
        expect(args['port'], 445);
        expect(args['path'], '');
        expect(args['user'], 'guest');
        expect(args['pass'], '');
        expect(args['domain'], '');
      });
    });

    group('listFiles', () {
      test('returns parsed file entries', () async {
        final files = await service.listFiles(
          host: '192.168.1.100',
          share: 'roms',
          path: '/snes',
        );

        expect(files.length, 2);
        expect(files[0].name, 'game.zip');
        expect(files[0].isDirectory, false);
        expect(files[0].size, 2048);
        expect(files[1].name, 'subfolder');
        expect(files[1].isDirectory, true);
      });

      test('passes maxDepth argument', () async {
        await service.listFiles(
          host: '192.168.1.100',
          share: 'roms',
          path: '/',
          maxDepth: 3,
        );

        final args = methodCalls.first.arguments as Map;
        expect(args['maxDepth'], 3);
      });

      test('returns empty list on null response', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('com.retro.rshop/smb'),
          (call) async => null,
        );

        final files = await service.listFiles(
          host: '192.168.1.100',
          share: 'roms',
          path: '/',
        );
        expect(files, isEmpty);
      });

      test('throws on PlatformException', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('com.retro.rshop/smb'),
          (call) async => throw PlatformException(
              code: 'SMB_ERROR', message: 'Access denied'),
        );

        expect(
          () => service.listFiles(
            host: '192.168.1.100',
            share: 'roms',
            path: '/',
          ),
          throwsException,
        );
      });
    });

    group('startDownload', () {
      test('passes all arguments correctly', () async {
        await service.startDownload(
          downloadId: 'dl-123',
          host: '192.168.1.100',
          share: 'roms',
          filePath: '/snes/game.zip',
          outputPath: '/data/game.zip',
          user: 'admin',
          pass: 'pass123',
          domain: 'WORKGROUP',
        );

        expect(methodCalls.length, 1);
        expect(methodCalls.first.method, 'startDownload');
        final args = methodCalls.first.arguments as Map;
        expect(args['downloadId'], 'dl-123');
        expect(args['host'], '192.168.1.100');
        expect(args['share'], 'roms');
        expect(args['filePath'], '/snes/game.zip');
        expect(args['outputPath'], '/data/game.zip');
        expect(args['user'], 'admin');
        expect(args['pass'], 'pass123');
        expect(args['domain'], 'WORKGROUP');
      });

      test('throws on PlatformException', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('com.retro.rshop/smb'),
          (call) async => throw PlatformException(
              code: 'SMB_ERROR', message: 'Write failed'),
        );

        expect(
          () => service.startDownload(
            downloadId: 'dl-123',
            host: '192.168.1.100',
            share: 'roms',
            filePath: '/game.zip',
            outputPath: '/out/game.zip',
          ),
          throwsException,
        );
      });
    });

    group('cancelDownload', () {
      test('sends cancel command', () async {
        await service.cancelDownload('dl-123');

        expect(methodCalls.length, 1);
        expect(methodCalls.first.method, 'cancelDownload');
        final args = methodCalls.first.arguments as Map;
        expect(args['downloadId'], 'dl-123');
      });

      test('handles PlatformException gracefully', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('com.retro.rshop/smb'),
          (call) async => throw PlatformException(
              code: 'ERROR', message: 'Not found'),
        );

        // Should not throw — cancel failures are logged, not thrown
        await service.cancelDownload('dl-999');
      });
    });
  });
}
