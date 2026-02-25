import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:retro_eshop/services/crash_log_service.dart';

class _FakePathProvider extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  final String tempPath;
  _FakePathProvider(this.tempPath);

  @override
  Future<String?> getTemporaryPath() async => tempPath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late CrashLogService service;
  late File logFile;

  Future<CrashLogService> createInitializedService() async {
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
    final svc = CrashLogService();
    await svc.init();
    return svc;
  }

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('crash_log_test_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('CrashLogService — before init', () {
    test('log() before init is a no-op', () {
      final svc = CrashLogService();
      svc.log('INFO', 'test message');
    });

    test('getLogContent() before init returns empty string', () {
      final svc = CrashLogService();
      expect(svc.getLogContent(), '');
    });

    test('getLogFile() before init returns null', () {
      final svc = CrashLogService();
      expect(svc.getLogFile(), isNull);
    });

    test('clearLog() before init is a no-op', () {
      final svc = CrashLogService();
      svc.clearLog();
    });

    test('logError() before init is a no-op', () {
      final svc = CrashLogService();
      svc.logError('test error', StackTrace.current);
    });
  });

  group('CrashLogService — after init', () {
    setUp(() async {
      service = await createInitializedService();
      logFile = File('${tempDir.path}/crash_logs/rshop_crash.log');
    });

    test('init creates crash_logs directory', () {
      expect(Directory('${tempDir.path}/crash_logs').existsSync(), isTrue);
    });

    test('log() writes timestamped line', () {
      service.log('INFO', 'Hello world');
      final content = logFile.readAsStringSync();
      expect(content, contains('[INFO] Hello world'));
      expect(content, matches(RegExp(r'\[\d{4}-\d{2}-\d{2}T')));
    });

    test('log() appends multiple lines', () {
      service.log('INFO', 'Line 1');
      service.log('WARN', 'Line 2');
      final content = logFile.readAsStringSync();
      expect(content, contains('[INFO] Line 1'));
      expect(content, contains('[WARN] Line 2'));
    });

    test('logError() writes error with stack trace', () {
      final stack = StackTrace.current;
      service.logError('Something failed', stack);
      final content = logFile.readAsStringSync();
      expect(content, contains('[ERROR] Something failed'));
      expect(content, contains('crash_log_service_test.dart'));
    });

    test('logError() writes error without stack trace', () {
      service.logError('No stack error', null);
      final content = logFile.readAsStringSync();
      expect(content, contains('[ERROR] No stack error'));
    });

    test('getLogContent() returns written content', () {
      service.log('DEBUG', 'Test content');
      final content = service.getLogContent();
      expect(content, contains('Test content'));
    });

    test('getLogFile() returns null when log is empty', () {
      if (logFile.existsSync()) {
        logFile.writeAsStringSync('');
      }
      expect(service.getLogFile(), isNull);
    });

    test('getLogFile() returns File when log has content', () {
      service.log('INFO', 'Some data');
      final file = service.getLogFile();
      expect(file, isNotNull);
      expect(file!.path, logFile.path);
    });

    test('clearLog() empties the file', () {
      service.log('INFO', 'Data to clear');
      expect(logFile.readAsStringSync(), isNotEmpty);
      service.clearLog();
      expect(logFile.readAsStringSync(), isEmpty);
    });

    test('clearLog() followed by getLogFile() returns null', () {
      service.log('INFO', 'Data');
      service.clearLog();
      expect(service.getLogFile(), isNull);
    });

    test('truncation kicks in above 500KB', () {
      final bigLine = 'X' * 1024;
      for (int i = 0; i < 520; i++) {
        service.log('INFO', bigLine);
      }
      final length = logFile.lengthSync();
      expect(length, lessThan(500 * 1024));
    });

    test('truncation adds marker', () {
      final bigLine = 'X' * 1024;
      for (int i = 0; i < 520; i++) {
        service.log('INFO', bigLine);
      }
      final content = logFile.readAsStringSync();
      expect(content, startsWith('[...log truncated...]'));
    });

    test('truncation does not leave partial lines', () {
      final bigLine = 'X' * 1024;
      for (int i = 0; i < 520; i++) {
        service.log('INFO', bigLine);
      }
      final content = logFile.readAsStringSync();
      final lines = content.split('\n').where((l) => l.isNotEmpty).toList();
      for (int i = 1; i < lines.length; i++) {
        expect(lines[i], startsWith('['));
      }
    });
  });
}
