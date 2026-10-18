import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retro_eshop/services/http_endpoint_failover.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);
  final Future<ResponseBody> Function(RequestOptions) respond;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? stream,
      Future<void>? cancelFuture) async {
    requests.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  const lan = 'http://lan.test/romm';
  const wan = 'https://wan.test/library';
  final routes = HttpEndpointRoutes(lan, [wan]);
  ResponseBody ok() => ResponseBody.fromString('[]', 200, headers: {
        Headers.contentTypeHeader: ['application/json']
      });

  test(
      'rewrites only configured origins and path boundaries, preserving encoding/query',
      () {
    expect(routes.rebase('$lan/api/a%2Fb%20c?x=%2B&x=two', wan),
        '$wan/api/a%2Fb%20c?x=%2B&x=two');
    expect(routes.rebase('http://lan.test/romm-other/api', wan), isNull);
    expect(routes.rebase('http://lan.test.evil/romm/api', wan), isNull);
    expect(routes.rebase('http://elsewhere.test/romm/api', wan), isNull);
    expect(routes.rebase('http://lan.test:123/romm/api', wan), isNull);
    expect(routes.rebase('$wan/api/roms', lan), '$lan/api/roms');
  });

  test('normalizes and deduplicates configured addresses', () {
    expect(HttpEndpointRoutes('$lan/', [wan, '$wan/', lan]).bases, [lan, wan]);
    for (final bad in [
      'file:///roms',
      'https://user:pass@host',
      '$wan?q=1',
      '$wan#fragment',
      'not-a-url'
    ]) {
      expect(() => HttpEndpointRoutes(lan, [bad]), throwsFormatException);
    }
  });

  test(
      'retries real network failure with auth, pagination and cancellation token intact',
      () async {
    final token = CancelToken();
    final adapter = _Adapter((request) async {
      if (request.uri.host == 'lan.test') {
        throw DioException.connectionError(
            requestOptions: request, reason: 'offline');
      }
      if (request.uri.queryParameters['offset'] == '500') {
        expect(request.headers['Authorization'], 'Bearer token');
        expect(request.uri.queryParametersAll, {
          'platform_ids': ['1', '2'],
          'offset': ['500']
        });
        expect(request.cancelToken, same(token));
      }
      return ok();
    });
    final dio = Dio()
      ..httpClientAdapter = HttpEndpointFailover(adapter, routes);
    addTearDown(dio.close);
    await dio.get('$lan/api/roms',
        queryParameters: {
          'platform_ids': ['1', '2'],
          'offset': 500
        },
        options: Options(
            listFormat: ListFormat.multi,
            headers: {'Authorization': 'Bearer token'}),
        cancelToken: token);
    expect(adapter.requests.map((r) => r.uri.host), ['lan.test', 'wan.test']);
    await dio.get('$lan/api/roms?offset=1000');
    expect(adapter.requests.last.uri.host, 'wan.test');
    expect(adapter.requests, hasLength(3));
  });

  for (final status in [401, 403, 404, 429]) {
    test('does not mask HTTP $status by switching addresses', () async {
      final adapter =
          _Adapter((r) async => ResponseBody.fromString('error', status));
      final dio = Dio()
        ..httpClientAdapter = HttpEndpointFailover(adapter, routes);
      addTearDown(dio.close);
      await expectLater(
          dio.get('$lan/api/platforms'), throwsA(isA<DioException>()));
      expect(adapter.requests, hasLength(1));
    });
  }

  test('server errors try each endpoint once and propagate final failure',
      () async {
    final adapter =
        _Adapter((r) async => ResponseBody.fromString('unavailable', 503));
    final dio = Dio()
      ..httpClientAdapter = HttpEndpointFailover(adapter, routes);
    addTearDown(dio.close);
    await expectLater(
        dio.get('$lan/api/platforms'), throwsA(isA<DioException>()));
    expect(adapter.requests, hasLength(2));
  });

  test('cancellation never starts another endpoint', () async {
    final token = CancelToken();
    final adapter = _Adapter((r) async {
      token.cancel();
      throw DioException.connectionError(requestOptions: r, reason: 'offline');
    });
    final dio = Dio()
      ..httpClientAdapter = HttpEndpointFailover(adapter, routes);
    addTearDown(dio.close);
    await expectLater(
        dio.get('$lan/api/platforms', cancelToken: token),
        throwsA(isA<DioException>()
            .having((e) => e.type, 'type', DioExceptionType.cancel)));
    expect(adapter.requests, hasLength(1));
  });

  test('certificate errors never fall back or downgrade', () async {
    final adapter = _Adapter((r) async => throw DioException(
        requestOptions: r, type: DioExceptionType.badCertificate));
    final dio = Dio()
      ..httpClientAdapter = HttpEndpointFailover(adapter, routes);
    addTearDown(dio.close);
    await expectLater(
        dio.get('$lan/api/platforms'), throwsA(isA<DioException>()));
    expect(adapter.requests, hasLength(1));
  });

  test('does not retry mutations or unrelated CDN URLs', () async {
    final adapter = _Adapter((r) async => throw DioException.connectionError(
        requestOptions: r, reason: 'offline'));
    final dio = Dio()
      ..httpClientAdapter = HttpEndpointFailover(adapter, routes);
    addTearDown(dio.close);
    await expectLater(dio.post('$lan/api/mutate', data: 'body'),
        throwsA(isA<DioException>()));
    await expectLater(
        dio.get('https://cdn.test/cover.png'), throwsA(isA<DioException>()));
    expect(adapter.requests, hasLength(2));
  });

  test('RomM HTML login page is not considered a successful endpoint',
      () async {
    final adapter = _Adapter((r) async => r.uri.host == 'lan.test'
        ? ResponseBody.fromString('<html>Login</html>', 200, headers: {
            Headers.contentTypeHeader: ['text/html']
          })
        : ok());
    final dio = Dio()
      ..httpClientAdapter =
          HttpEndpointFailover(adapter, routes, rejectHtml: true);
    addTearDown(dio.close);
    expect((await dio.get('$lan/api/platforms')).data, isEmpty);
    expect(adapter.requests, hasLength(2));
  });
}
