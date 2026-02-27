import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Local crash log service that persists error logs to disk.
/// Ring buffer keeps the file under ~500KB by truncating oldest entries.
/// All log messages are scrubbed for credentials before writing.
class CrashLogService {
  static const int _maxBytes = 500 * 1024; // 500KB
  static const String _logFileName = 'rshop_crash.log';

  /// Patterns that may contain sensitive credentials in log messages.
  static final _credentialPatterns = [
    // Key=value patterns (password=xxx, apiKey=xxx, etc.)
    RegExp(r'(pass(?:word)?|api[_-]?key|secret|token|authorization|credential)s?\s*[=:]\s*\S+', caseSensitive: false),
    // HTTP Basic Auth header values
    RegExp(r'Basic\s+[A-Za-z0-9+/=]{4,}'),
    // Bearer tokens
    RegExp(r'Bearer\s+\S+', caseSensitive: false),
  ];

  static const String _redacted = '[REDACTED]';

  /// Scrubs potential credentials from a log message.
  static String scrubCredentials(String message) {
    var result = message;
    for (final pattern in _credentialPatterns) {
      result = result.replaceAll(pattern, _redacted);
    }
    return result;
  }

  File? _logFile;
  bool _initialized = false;

  /// Initialize the service. Must be called before any logging.
  Future<void> init() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final logDir = Directory('${cacheDir.path}/crash_logs');
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }
      _logFile = File('${logDir.path}/$_logFileName');
      _initialized = true;
    } catch (e) {
      debugPrint('CrashLogService: init failed: $e');
    }
  }

  /// Append a timestamped log line. Credentials are scrubbed before writing.
  void log(String level, String message) {
    if (!_initialized || _logFile == null) return;
    try {
      final scrubbed = scrubCredentials(message);
      final timestamp = DateTime.now().toIso8601String();
      final line = '[$timestamp] [$level] $scrubbed\n';
      _logFile!.writeAsStringSync(line, mode: FileMode.append, flush: true);
      _truncateIfNeeded();
    } catch (e) {
      debugPrint('CrashLogService: write failed: $e');
    }
  }

  /// Log an error with optional stack trace.
  void logError(dynamic error, StackTrace? stack) {
    final buffer = StringBuffer()
      ..writeln(error.toString());
    if (stack != null) {
      buffer.writeln(stack.toString());
    }
    log('ERROR', buffer.toString().trimRight());
  }

  /// Get the log file reference for sharing.
  File? getLogFile() {
    if (!_initialized || _logFile == null) return null;
    if (!_logFile!.existsSync()) return null;
    if (_logFile!.lengthSync() == 0) return null;
    return _logFile;
  }

  /// Read the full log content.
  String getLogContent() {
    if (!_initialized || _logFile == null) return '';
    try {
      if (!_logFile!.existsSync()) return '';
      return _logFile!.readAsStringSync();
    } catch (e) {
      debugPrint('CrashLogService: read failed: $e');
      return '';
    }
  }

  /// Clear the log file.
  void clearLog() {
    if (!_initialized || _logFile == null) return;
    try {
      if (_logFile!.existsSync()) {
        _logFile!.writeAsStringSync('');
      }
    } catch (e) {
      debugPrint('CrashLogService: clear failed: $e');
    }
  }

  /// Truncate oldest entries if file exceeds max size.
  void _truncateIfNeeded() {
    try {
      if (!_logFile!.existsSync()) return;
      final length = _logFile!.lengthSync();
      if (length <= _maxBytes) return;

      final content = _logFile!.readAsStringSync();
      // Keep the last ~400KB (leave headroom)
      final keepFrom = content.length - (400 * 1024);
      if (keepFrom <= 0) return;

      // Find the next newline after the cut point to avoid partial lines
      final newlineIndex = content.indexOf('\n', keepFrom);
      if (newlineIndex == -1) return;

      final truncated = '[...log truncated...]\n${content.substring(newlineIndex + 1)}';
      _logFile!.writeAsStringSync(truncated);
    } catch (e) {
      debugPrint('CrashLogService: truncate failed: $e');
    }
  }
}
