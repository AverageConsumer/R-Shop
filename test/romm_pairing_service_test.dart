import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retro_eshop/models/config/source.dart';
import 'package:retro_eshop/services/romm_pairing_service.dart';

/// Lightweight Dio adapter that returns pre-canned responses keyed by
/// `<METHOD> <uri>`.
class _FakeAdapter implements HttpClientAdapter {
  final Map<String, _Response> _routes = {};
  final List<RequestOptions> requests = [];
  Object? throwOn;

  void on({
    required String method,
    required String url,
    required int status,
    Map<String, dynamic>? body,
  }) {
    _routes['$method $url'] = _Response(status, body ?? const {});
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (throwOn != null) {
      final t = throwOn;
      throwOn = null;
      if (t is DioException) throw t;
    }
    final key = '${options.method} ${options.uri}';
    final route = _routes[key];
    if (route == null) {
      return ResponseBody.fromString(
        '{"detail":"unmocked $key"}',
        404,
        headers: {
          'content-type': ['application/json'],
        },
      );
    }
    return ResponseBody.fromString(
      jsonEncode(route.body),
      route.status,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Response {
  _Response(this.status, this.body);
  final int status;
  final Map<String, dynamic> body;
}

RommPairingService _makeService(_FakeAdapter adapter) {
  final dio = Dio()..httpClientAdapter = adapter;
  return RommPairingService(dio: dio);
}

void main() {
  group('normalizeCode', () {
    test('canonical 8-char code stays as XXXX-XXXX', () {
      expect(RommPairingService.normalizeCode('B7K9-3MX2'), 'B7K9-3MX2');
    });

    test('lowercase is uppercased', () {
      expect(RommPairingService.normalizeCode('b7k9-3mx2'), 'B7K9-3MX2');
    });

    test('missing dash is reinserted', () {
      expect(RommPairingService.normalizeCode('B7K93MX2'), 'B7K9-3MX2');
    });

    test('whitespace is stripped', () {
      expect(RommPairingService.normalizeCode('  B7K9 - 3MX2 '), 'B7K9-3MX2');
    });

    test('multiple dashes collapse', () {
      expect(RommPairingService.normalizeCode('B7-K9-3-MX2'), 'B7K9-3MX2');
    });

    test('non-8-char input returns uppercase stripped form', () {
      expect(RommPairingService.normalizeCode('abc'), 'ABC');
      expect(RommPairingService.normalizeCode('toolong-1234'), 'TOOLONG1234');
    });
  });

  group('parseQrPayload', () {
    final svc = RommPairingService();

    test('parses http URL with code', () {
      final result = svc.parseQrPayload('http://localhost:8090/pair?code=B7K9-3MX2');
      expect(result.serverUrl, 'http://localhost:8090');
      expect(result.code, 'B7K9-3MX2');
    });

    test('parses https URL with code', () {
      final result = svc.parseQrPayload('https://romm.example.com/pair?code=ABCD-1234');
      expect(result.serverUrl, 'https://romm.example.com');
      expect(result.code, 'ABCD-1234');
    });

    test('trims whitespace', () {
      final result =
          svc.parseQrPayload('  https://r.io/pair?code=AAAA-BBBB  ');
      expect(result.serverUrl, 'https://r.io');
      expect(result.code, 'AAAA-BBBB');
    });

    test('rejects non-pair URL', () {
      expect(
        () => svc.parseQrPayload('https://romm.example.com/'),
        throwsA(isA<RommPairInvalidQrException>()),
      );
    });

    test('rejects ftp scheme', () {
      expect(
        () => svc.parseQrPayload('ftp://server/pair?code=XX-YY'),
        throwsA(isA<RommPairInvalidQrException>()),
      );
    });

    test('rejects plain code without URL', () {
      expect(
        () => svc.parseQrPayload('B7K9-3MX2'),
        throwsA(isA<RommPairInvalidQrException>()),
      );
    });

    test('rejects empty payload', () {
      expect(
        () => svc.parseQrPayload(''),
        throwsA(isA<RommPairInvalidQrException>()),
      );
    });
  });

  group('exchangeCode', () {
    test('returns parsed RommPairResult on 200', () async {
      final adapter = _FakeAdapter()
        ..on(
          method: 'POST',
          url: 'http://localhost:8090/api/client-tokens/exchange',
          status: 200,
          body: {
            'raw_token': 'eyJraWQiOiJhYmM',
            'id': 7,
            'name': 'rshop-test',
            'scopes': ['roms.read', 'platforms.read'],
            'user_id': 1,
            'expires_at': '2026-05-09T12:34:56',
            'created_at': '2026-04-09T12:00:00',
            'last_used_at': null,
          },
        );
      final svc = _makeService(adapter);

      final result = await svc.exchangeCode(
        serverUrl: 'http://localhost:8090',
        code: 'B7K9-3MX2',
      );

      expect(result.token, 'eyJraWQiOiJhYmM');
      expect(result.tokenId, 7);
      expect(result.name, 'rshop-test');
      expect(result.scopes, ['roms.read', 'platforms.read']);
      expect(result.userId, 1);
      expect(result.expiresAt, DateTime.parse('2026-05-09T12:34:56'));
      expect(result.serverUrl, 'http://localhost:8090');
    });

    test('accepts legacy `token` field as fallback', () async {
      final adapter = _FakeAdapter()
        ..on(
          method: 'POST',
          url: 'http://localhost:8090/api/client-tokens/exchange',
          status: 200,
          body: {
            'token': 'legacy-token',
            'id': 1,
            'name': 'legacy',
            'scopes': <String>[],
            'user_id': 1,
          },
        );
      final svc = _makeService(adapter);
      final result = await svc.exchangeCode(
        serverUrl: 'http://localhost:8090',
        code: 'AAAA-BBBB',
      );
      expect(result.token, 'legacy-token');
    });

    test('normalises code before sending to server', () async {
      final adapter = _FakeAdapter()
        ..on(
          method: 'POST',
          url: 'http://localhost:8090/api/client-tokens/exchange',
          status: 200,
          body: {
            'raw_token': 't',
            'id': 1,
            'name': 'n',
            'scopes': <String>[],
            'user_id': 1,
          },
        );
      final svc = _makeService(adapter);
      await svc.exchangeCode(
        serverUrl: 'http://localhost:8090',
        code: '  b7k93mx2 ',
      );
      final sent = adapter.requests.first.data as Map;
      expect(sent['code'], 'B7K9-3MX2');
    });

    test('handles null expiry (never expires)', () async {
      final adapter = _FakeAdapter()
        ..on(
          method: 'POST',
          url: 'http://localhost:8090/api/client-tokens/exchange',
          status: 200,
          body: {
            'raw_token': 'tok',
            'id': 1,
            'name': 'forever',
            'scopes': ['roms.read'],
            'user_id': 1,
            'expires_at': null,
          },
        );
      final svc = _makeService(adapter);

      final result = await svc.exchangeCode(
        serverUrl: 'http://localhost:8090',
        code: 'XX-YY',
      );
      expect(result.expiresAt, isNull);
    });

    test('strips trailing slashes from serverUrl', () async {
      final adapter = _FakeAdapter()
        ..on(
          method: 'POST',
          url: 'http://localhost:8090/api/client-tokens/exchange',
          status: 200,
          body: {
            'raw_token': 't',
            'id': 1,
            'name': 'n',
            'scopes': <String>[],
            'user_id': 1,
          },
        );
      final svc = _makeService(adapter);

      await svc.exchangeCode(
        serverUrl: 'http://localhost:8090///',
        code: 'X-Y',
      );

      expect(adapter.requests.first.uri.toString(),
          'http://localhost:8090/api/client-tokens/exchange');
    });

    test('throws RommPairCodeExpiredException on 400 with expired detail',
        () async {
      final adapter = _FakeAdapter()
        ..on(
          method: 'POST',
          url: 'http://localhost:8090/api/client-tokens/exchange',
          status: 400,
          body: {'detail': 'Invalid or expired pairing code'},
        );
      final svc = _makeService(adapter);

      expect(
        () => svc.exchangeCode(
          serverUrl: 'http://localhost:8090',
          code: 'EXPI-RED1',
        ),
        throwsA(isA<RommPairCodeExpiredException>()),
      );
    });

    test('throws RommPairCodeExpiredException on 404', () async {
      final adapter = _FakeAdapter()
        ..on(
          method: 'POST',
          url: 'http://localhost:8090/api/client-tokens/exchange',
          status: 404,
          body: {'detail': 'Not Found'},
        );
      final svc = _makeService(adapter);

      expect(
        () => svc.exchangeCode(
          serverUrl: 'http://localhost:8090',
          code: 'NOPE-1234',
        ),
        throwsA(isA<RommPairCodeExpiredException>()),
      );
    });

    test('throws RommPairServerUnreachableException on connection error',
        () async {
      final adapter = _FakeAdapter()
        ..throwOn = DioException(
          requestOptions: RequestOptions(path: '/'),
          type: DioExceptionType.connectionError,
          message: 'host down',
        );
      final svc = _makeService(adapter);

      expect(
        () => svc.exchangeCode(
          serverUrl: 'http://10.0.0.99:8090',
          code: 'X-Y',
        ),
        throwsA(isA<RommPairServerUnreachableException>()),
      );
    });

    test('exchanges via pairFromQr in one call', () async {
      final adapter = _FakeAdapter()
        ..on(
          method: 'POST',
          url: 'http://localhost:8090/api/client-tokens/exchange',
          status: 200,
          body: {
            'raw_token': 'qr-tok',
            'id': 42,
            'name': 'from-qr',
            'scopes': ['roms.read'],
            'user_id': 1,
          },
        );
      final svc = _makeService(adapter);

      final result =
          await svc.pairFromQr('http://localhost:8090/pair?code=B7K9-3MX2');

      expect(result.token, 'qr-tok');
      expect(result.tokenId, 42);
    });
  });

  group('probeServer', () {
    test('returns version on 200 heartbeat', () async {
      final adapter = _FakeAdapter()
        ..on(
          method: 'GET',
          url: 'http://localhost:8090/api/heartbeat',
          status: 200,
          body: {
            'SYSTEM': {'VERSION': '4.8.1'},
          },
        );
      final svc = _makeService(adapter);

      final version = await svc.probeServer('http://localhost:8090');
      expect(version, '4.8.1');
    });

    test('returns null on 404', () async {
      final adapter = _FakeAdapter()
        ..on(
          method: 'GET',
          url: 'http://localhost:8090/api/heartbeat',
          status: 404,
          body: {},
        );
      final svc = _makeService(adapter);

      final version = await svc.probeServer('http://localhost:8090');
      expect(version, isNull);
    });

    test('returns null on connection error', () async {
      final adapter = _FakeAdapter()
        ..throwOn = DioException(
          requestOptions: RequestOptions(path: '/'),
          type: DioExceptionType.connectionError,
        );
      final svc = _makeService(adapter);

      final version = await svc.probeServer('http://10.0.0.99:8090');
      expect(version, isNull);
    });
  });

  group('buildSourceFromPairResult', () {
    RommPairResult result({
      String name = 'My RomM',
      List<String> scopes = const ['roms.read', 'roms.write'],
      DateTime? expiresAt,
    }) {
      return RommPairResult(
        serverUrl: 'http://192.168.1.50:8090',
        token: 'eyJ.test.token',
        tokenId: 7,
        name: name,
        scopes: scopes,
        userId: 1,
        expiresAt: expiresAt,
      );
    }

    test('produces an enabled RomM source with auth and empty platforms', () {
      final src = buildSourceFromPairResult(result());
      expect(src.type, SourceType.romm);
      expect(src.url, 'http://192.168.1.50:8090');
      expect(src.autoMap, isTrue);
      expect(src.enabled, isTrue);
      expect(src.knownPlatforms, isEmpty);
      expect(src.auth?.clientToken, 'eyJ.test.token');
      expect(src.auth?.clientTokenId, 7);
    });

    test('marks read-only tokens as borrowed', () {
      final src =
          buildSourceFromPairResult(result(scopes: const ['roms.read']));
      expect(src.borrowed, isTrue);
    });

    test('does not mark read+write tokens as borrowed', () {
      final src = buildSourceFromPairResult(
          result());
      expect(src.borrowed, isFalse);
    });

    test('explicit borrowed flag overrides the heuristic', () {
      final src = buildSourceFromPairResult(
        result(),
        borrowed: true,
      );
      expect(src.borrowed, isTrue);
    });

    test('mirrors expiresAt onto the source', () {
      final exp = DateTime.utc(2026, 5, 9, 12);
      final src = buildSourceFromPairResult(result(expiresAt: exp));
      expect(src.tokenExpiresAt, exp);
      expect(src.auth?.clientTokenExpiresAt, exp);
    });

    test('falls back to host label when token name is empty', () {
      final src = buildSourceFromPairResult(result(name: ''));
      expect(src.name, '192.168.1.50');
    });
  });

  group('supportsClientTokens', () {
    test('returns true for 4.8.x and newer', () {
      expect(supportsClientTokens('4.8.0'), isTrue);
      expect(supportsClientTokens('4.8.1'), isTrue);
      expect(supportsClientTokens('4.9.0'), isTrue);
      expect(supportsClientTokens('5.0.0'), isTrue);
      expect(supportsClientTokens('4.10.2'), isTrue);
    });

    test('returns false for older versions', () {
      expect(supportsClientTokens('4.7.5'), isFalse);
      expect(supportsClientTokens('3.5.0'), isFalse);
      expect(supportsClientTokens('1.0.0'), isFalse);
    });

    test('handles pre-release suffixes', () {
      expect(supportsClientTokens('4.8.0-rc1'), isTrue);
      expect(supportsClientTokens('4.7.0-beta'), isFalse);
    });

    test('returns false for unparseable input', () {
      expect(supportsClientTokens(null), isFalse);
      expect(supportsClientTokens(''), isFalse);
      expect(supportsClientTokens('garbage'), isFalse);
    });
  });

  group('buildLegacyRommSource', () {
    test('builds a romm source with user/pass auth', () {
      final src = buildLegacyRommSource(
        name: 'Home RomM',
        serverUrl: 'http://192.168.1.10:8080',
        user: 'admin',
        pass: 'secret',
      );
      expect(src.type, SourceType.romm);
      expect(src.url, 'http://192.168.1.10:8080');
      expect(src.auth?.user, 'admin');
      expect(src.auth?.pass, 'secret');
      expect(src.auth?.clientToken, isNull);
      expect(src.autoMap, isTrue);
      expect(src.borrowed, isFalse);
    });

    test('omits empty credentials', () {
      final src = buildLegacyRommSource(
        name: 'x',
        serverUrl: 'http://h',
        user: '',
        pass: '',
        apiKey: 'k',
      );
      expect(src.auth?.user, isNull);
      expect(src.auth?.pass, isNull);
      expect(src.auth?.apiKey, 'k');
    });

    test('falls back to host label when name is empty', () {
      final src = buildLegacyRommSource(
        name: '',
        serverUrl: 'http://nas.local:8080',
      );
      expect(src.name, 'nas.local');
    });
  });
}
