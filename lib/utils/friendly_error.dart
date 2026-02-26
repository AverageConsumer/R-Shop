String getUserFriendlyError(dynamic e) {
  final errorString = e.toString().toLowerCase();

  if (errorString.contains('socketexception') ||
      errorString.contains('connection')) {
    return 'Connection error - Check your internet connection.';
  }
  if (errorString.contains('timeout')) {
    return 'Timeout - Server responding too slowly.';
  }
  if (errorString.contains('handshake') ||
      errorString.contains('ssl') ||
      errorString.contains('certificate')) {
    return 'SSL error - Secure connection failed.';
  }
  if (errorString.contains('status 404')) {
    return 'File not found (404) - Server does not have this file.';
  }
  if (errorString.contains('status 403')) {
    return 'Access denied (403) - Check your permissions.';
  }
  if (errorString.contains('status 503')) {
    return 'Server overloaded (503) - Try again in a few minutes.';
  }
  if (errorString.contains('status 50')) {
    return 'Server error - Try again later.';
  }

  return 'An unexpected error occurred. Please try again.';
}
