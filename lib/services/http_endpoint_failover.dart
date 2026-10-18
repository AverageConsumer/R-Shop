import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Alternative addresses of ONE server. Does not select or filter sources.
class HttpEndpointRoutes {
  HttpEndpointRoutes(String primary, List<String> fallbacks)
      : bases = [primary, ...fallbacks].map(normalize).toSet().toList();

  final List<String> bases;

  static String normalize(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const FormatException(
          'Expected an HTTP(S) base URL without credentials, query or fragment');
    }
    return uri.toString().replaceFirst(RegExp(r'/+$'), '');
  }

  /// Rewrites only explicitly configured origins and path prefixes. Never
  /// forwards credentials to URLs merely containing a server's hostname.
  String? rebase(String url, String target) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    // Longest path first when two routes happen to share an origin.
    final candidates = [...bases]..sort((a, b) => b.length.compareTo(a.length));
    for (final base in candidates) {
      final from = Uri.parse(base);
      if (uri.scheme != from.scheme ||
          uri.host != from.host ||
          uri.port != from.port) {
        continue;
      }
      final prefix = from.path.replaceFirst(RegExp(r'/+$'), '');
      if (uri.path != prefix && !uri.path.startsWith('$prefix/')) continue;
      final suffix = uri.path.substring(prefix.length);
      return '$target$suffix${uri.hasQuery ? '?${uri.query}' : ''}'
          '${uri.hasFragment ? '#${uri.fragment}' : ''}';
    }
    return null;
  }

  List<String> urlsFor(String url) => {
        for (final base in bases)
          if (rebase(url, base) case final String rewritten) rewritten,
      }.toList();
}

/// Retries read-only HTTP requests against the configured addresses. A route
/// becomes preferred only after a real HTTP success, for this client lifetime
/// (e.g. one paginated sync). A new sync tries LAN first again.
class HttpEndpointFailover implements HttpClientAdapter {
  HttpEndpointFailover(this.delegate, this.routes, {this.rejectHtml = false});

  final HttpClientAdapter delegate;
  final HttpEndpointRoutes routes;
  final bool rejectHtml;
  String? _preferred;
  String get preferredBase => _preferred ?? routes.bases.first;
  static const connectTimeout = Duration(seconds: 3);

  static bool retryable(DioException error) => switch (error.type) {
        DioExceptionType.connectionError ||
        DioExceptionType.connectionTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.sendTimeout =>
          true,
        _ => false,
      };

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final original = options.uri.toString();
    if (!['GET', 'HEAD'].contains(options.method) ||
        requestStream != null ||
        routes.rebase(original, routes.bases.first) == null) {
      return delegate.fetch(options, requestStream, cancelFuture);
    }
    final bases =
        [_preferred, ...routes.bases].whereType<String>().toSet().toList();
    for (var i = 0; i < bases.length; i++) {
      if (options.cancelToken?.cancelError case final DioException error) {
        throw error;
      }
      final request = options.copyWith(
        baseUrl: '',
        path: routes.rebase(original, bases[i]),
        queryParameters: {},
        connectTimeout: options.connectTimeout != null &&
                options.connectTimeout! < connectTimeout
            ? options.connectTimeout
            : connectTimeout,
      );
      try {
        final response = await delegate.fetch(request, null, cancelFuture);
        final invalidHtml = rejectHtml &&
            response.statusCode >= 200 &&
            response.statusCode < 300 &&
            (response.headers[Headers.contentTypeHeader]
                    ?.any((v) => v.contains('text/html')) ??
                false);
        if (invalidHtml ||
            (response.statusCode >= 500 &&
                response.statusCode <= 599 &&
                i < bases.length - 1)) {
          await response.stream.listen(null).cancel();
          if (i == bases.length - 1) {
            throw DioException(
                requestOptions: request,
                error: const FormatException(
                    'Expected a RomM JSON response, received HTML'));
          }
          continue;
        }
        if (response.statusCode >= 200 && response.statusCode < 300) {
          _preferred = bases[i];
        }
        // Authentication, permission, rate-limit and missing-file responses are
        // meaningful results, not evidence that a different address is needed.
        return response;
      } on DioException catch (e) {
        if (!retryable(e) || i == bases.length - 1) rethrow;
      }
    }
    throw StateError('No HTTP endpoints configured');
  }

  @override
  void close({bool force = false}) => delegate.close(force: force);
}

void installEndpointFailover(Dio dio, String? primary, List<String> fallbacks,
    {bool rejectHtml = false}) {
  if (primary == null || fallbacks.isEmpty) return;
  dio.httpClientAdapter = HttpEndpointFailover(
      dio.httpClientAdapter, HttpEndpointRoutes(primary, fallbacks),
      rejectHtml: rejectHtml);
}
