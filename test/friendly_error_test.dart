import 'package:flutter_test/flutter_test.dart';
import 'package:retro_eshop/utils/friendly_error.dart';

void main() {
  group('getUserFriendlyError', () {
    test('SocketException returns connection error', () {
      expect(
        getUserFriendlyError(Exception('SocketException: Connection refused')),
        'Connection error — check your network connection',
      );
    });

    test('"connection" keyword returns connection error', () {
      expect(
        getUserFriendlyError('Connection reset by peer'),
        'Connection error — check your network connection',
      );
    });

    test('timeout returns timeout message', () {
      expect(
        getUserFriendlyError(Exception('Request timeout after 30s')),
        'Connection timed out',
      );
    });

    test('handshake error returns SSL message', () {
      expect(
        getUserFriendlyError('HandshakeException: TLS failed'),
        'SSL/TLS error — check server certificate',
      );
    });

    test('SSL error returns SSL message', () {
      expect(
        getUserFriendlyError('SSL handshake failed'),
        'SSL/TLS error — check server certificate',
      );
    });

    test('certificate error returns SSL message', () {
      expect(
        getUserFriendlyError('Bad certificate'),
        'SSL/TLS error — check server certificate',
      );
    });

    test('status 404 returns not found', () {
      expect(
        getUserFriendlyError('HTTP status 404'),
        'Resource not found — check URL',
      );
    });

    test('status 403 returns access denied', () {
      expect(
        getUserFriendlyError('HTTP status 403'),
        'Access denied — check permissions',
      );
    });

    test('status 503 returns server overloaded', () {
      expect(
        getUserFriendlyError('HTTP status 503'),
        'Server overloaded (503) — try again in a few minutes',
      );
    });

    test('status 500 returns server error', () {
      expect(
        getUserFriendlyError('HTTP status 500'),
        'Server error — try again later',
      );
    });

    test('status 502 returns server error', () {
      expect(
        getUserFriendlyError('HTTP status 502'),
        'Server error — try again later',
      );
    });

    test('unknown error returns generic message', () {
      expect(
        getUserFriendlyError('Something completely unknown happened'),
        'An unexpected error occurred. Please try again.',
      );
    });

    test('case-insensitive matching works', () {
      expect(
        getUserFriendlyError('SOCKETEXCEPTION: failed'),
        'Connection error — check your network connection',
      );
    });

    test('first match wins — connection before timeout', () {
      expect(
        getUserFriendlyError('SocketException: connection timeout'),
        'Connection error — check your network connection',
      );
    });

    // New: SMB/FTP patterns
    test('SMB error returns SMB message', () {
      expect(
        getUserFriendlyError('SMB connection failed: bad share'),
        'SMB connection failed — check share settings',
      );
    });

    test('FTP error returns FTP message', () {
      expect(
        getUserFriendlyError('FTP auth failed for host'),
        'FTP connection failed — check host/credentials',
      );
    });

    test('SMB matches before generic connection', () {
      // "SMB connection error" should match SMB, not generic connection
      expect(
        getUserFriendlyError('SMB connection error'),
        'SMB connection failed — check share settings',
      );
    });

    test('401 returns auth failed', () {
      expect(
        getUserFriendlyError('HTTP 401 Unauthorized'),
        'Authentication failed — check credentials',
      );
    });

    test('404 Not Found (non-status format) returns not found', () {
      expect(
        getUserFriendlyError('HTTP 404 Not Found'),
        'Resource not found — check URL',
      );
    });

    // returnRawOnNoMatch
    test('returnRawOnNoMatch returns raw error on no match', () {
      expect(
        getUserFriendlyError('Some weird error', returnRawOnNoMatch: true),
        'Some weird error',
      );
    });

    test('returnRawOnNoMatch truncates long messages at 100 chars', () {
      final longMsg = 'A' * 200;
      final result = getUserFriendlyError(longMsg, returnRawOnNoMatch: true);
      expect(result.length, 101); // 100 chars + ellipsis
      expect(result, endsWith('…'));
    });

    test('returnRawOnNoMatch still matches known patterns', () {
      expect(
        getUserFriendlyError('SocketException: fail', returnRawOnNoMatch: true),
        'Connection error — check your network connection',
      );
    });
  });
}
