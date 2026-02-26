import 'package:flutter_test/flutter_test.dart';
import 'package:retro_eshop/utils/friendly_error.dart';

void main() {
  group('getUserFriendlyError', () {
    test('SocketException returns connection error', () {
      expect(
        getUserFriendlyError(Exception('SocketException: Connection refused')),
        'Connection error - Check your internet connection.',
      );
    });

    test('"connection" keyword returns connection error', () {
      expect(
        getUserFriendlyError('Connection reset by peer'),
        'Connection error - Check your internet connection.',
      );
    });

    test('timeout returns timeout message', () {
      expect(
        getUserFriendlyError(Exception('Request timeout after 30s')),
        'Timeout - Server responding too slowly.',
      );
    });

    test('handshake error returns SSL message', () {
      expect(
        getUserFriendlyError('HandshakeException: TLS failed'),
        'SSL error - Secure connection failed.',
      );
    });

    test('SSL error returns SSL message', () {
      expect(
        getUserFriendlyError('SSL handshake failed'),
        'SSL error - Secure connection failed.',
      );
    });

    test('certificate error returns SSL message', () {
      expect(
        getUserFriendlyError('Bad certificate'),
        'SSL error - Secure connection failed.',
      );
    });

    test('status 404 returns file not found', () {
      expect(
        getUserFriendlyError('HTTP status 404'),
        'File not found (404) - Server does not have this file.',
      );
    });

    test('status 403 returns access denied', () {
      expect(
        getUserFriendlyError('HTTP status 403'),
        'Access denied (403) - Check your permissions.',
      );
    });

    test('status 503 returns server overloaded', () {
      expect(
        getUserFriendlyError('HTTP status 503'),
        'Server overloaded (503) - Try again in a few minutes.',
      );
    });

    test('status 500 returns server error', () {
      expect(
        getUserFriendlyError('HTTP status 500'),
        'Server error - Try again later.',
      );
    });

    test('status 502 returns server error', () {
      expect(
        getUserFriendlyError('HTTP status 502'),
        'Server error - Try again later.',
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
        'Connection error - Check your internet connection.',
      );
    });

    test('first match wins — connection before timeout', () {
      // "connection" matches before "timeout"
      expect(
        getUserFriendlyError('SocketException: connection timeout'),
        'Connection error - Check your internet connection.',
      );
    });
  });
}
