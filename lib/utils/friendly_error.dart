import 'package:dio/dio.dart';

String getUserFriendlyError(dynamic e, {bool returnRawOnNoMatch = false}) {
  // Structured DioException handling — more reliable than string matching.
  if (e is DioException) {
    return _handleDioError(e, returnRawOnNoMatch: returnRawOnNoMatch);
  }

  return _fromString(
    e.toString(),
    returnRawOnNoMatch: returnRawOnNoMatch,
  );
}

String _handleDioError(
  DioException e, {
  bool returnRawOnNoMatch = false,
}) {
  final code = e.response?.statusCode;
  if (code != null) {
    if (code == 401) return 'Authentication failed — check credentials';
    if (code == 403) return 'Access denied — check permissions';
    if (code == 404) return 'Resource not found — check URL';
    if (code == 429) {
      return 'Rate limited — please wait a moment and try again';
    }
    if (code == 503) {
      return 'Server overloaded (503) — try again in a few minutes';
    }
    if (code >= 500) return 'Server error — try again later';
  }

  if (e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.receiveTimeout ||
      e.type == DioExceptionType.sendTimeout) {
    return 'Connection timed out';
  }

  if (e.type == DioExceptionType.connectionError) {
    return 'Connection error — check your network connection';
  }

  // Fall through to string matching for other DioException cases.
  return _fromString(
    e.toString(),
    returnRawOnNoMatch: returnRawOnNoMatch,
  );
}

String _fromString(String raw, {bool returnRawOnNoMatch = false}) {
  final errorString = raw.toLowerCase();

  // Protocol-specific (before generic "connection" match)
  if (errorString.contains('smb')) {
    return 'SMB connection failed — check share settings';
  }
  if (errorString.contains('ftp')) {
    return 'FTP connection failed — check host/credentials';
  }

  // Timeout before connection (since "connectionTimeout" contains both).
  if (errorString.contains('timeout')) {
    return 'Connection timed out';
  }
  if (errorString.contains('socketexception') ||
      errorString.contains('connection')) {
    return 'Connection error — check your network connection';
  }
  if (errorString.contains('handshake') ||
      errorString.contains('ssl') ||
      errorString.contains('certificate')) {
    return 'SSL/TLS error — check server certificate';
  }
  if (errorString.contains('401') || errorString.contains('unauthorized')) {
    return 'Authentication failed — check credentials';
  }
  if (errorString.contains('status 404') ||
      errorString.contains('404') && errorString.contains('not found')) {
    return 'Resource not found — check URL';
  }
  if (errorString.contains('status 403') ||
      errorString.contains('403') && errorString.contains('forbidden')) {
    return 'Access denied — check permissions';
  }
  if (errorString.contains('429') || errorString.contains('rate limit')) {
    return 'Rate limited — please wait a moment and try again';
  }
  if (errorString.contains('status 503')) {
    return 'Server overloaded (503) — try again in a few minutes';
  }
  if (errorString.contains('status 50') || errorString.contains('500')) {
    return 'Server error — try again later';
  }

  if (returnRawOnNoMatch) {
    if (raw.length > 100) return '${raw.substring(0, 100)}…';
    return raw;
  }

  return 'An unexpected error occurred. Please try again.';
}
