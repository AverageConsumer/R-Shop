String getUserFriendlyError(dynamic e, {bool returnRawOnNoMatch = false}) {
  final raw = e.toString();
  final errorString = raw.toLowerCase();

  // Protocol-specific (before generic "connection" match)
  if (errorString.contains('smb')) {
    return 'SMB connection failed — check share settings';
  }
  if (errorString.contains('ftp')) {
    return 'FTP connection failed — check host/credentials';
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
  if (errorString.contains('timeout')) {
    return 'Connection timed out';
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
  if (errorString.contains('status 503')) {
    return 'Server overloaded (503) — try again in a few minutes';
  }
  if (errorString.contains('status 50')) {
    return 'Server error — try again later';
  }

  if (returnRawOnNoMatch) {
    if (raw.length > 100) return '${raw.substring(0, 100)}…';
    return raw;
  }

  return 'An unexpected error occurred. Please try again.';
}
