import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retro_eshop/models/config/provider_config.dart';
import 'package:retro_eshop/models/config/system_config.dart';
import 'package:retro_eshop/models/game_item.dart';
import 'package:retro_eshop/services/download_handle.dart';
import 'package:retro_eshop/services/providers/web_provider.dart';

/// Fake Dio adapter for testing WebProvider without real HTTP.
class _FakeHttpAdapter implements HttpClientAdapter {
  final Map<String, ResponseBody Function(RequestOptions)> _handlers = {};

  void onGet(String urlPattern, {required int statusCode, required String body, Map<String, List<String>>? headers}) {
    _handlers[urlPattern] = (options) {
      return ResponseBody.fromString(
        body,
        statusCode,
        headers: headers ?? {'content-type': ['text/html']},
      );
    };
  }

  void onHead(String urlPattern, {int statusCode = 200}) {
    _handlers['HEAD:$urlPattern'] = (options) {
      return ResponseBody.fromString('', statusCode);
    };
  }

  void onHeadError(String urlPattern, DioException Function(RequestOptions) factory) {
    _handlers['HEAD:$urlPattern'] = (options) {
      throw factory(options);
    };
  }

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    final key = options.method == 'HEAD' ? 'HEAD:${options.uri}' : options.uri.toString();
    // Try exact match first, then pattern match
    final handler = _handlers[key] ??
        _handlers.entries
            .where((e) => key.contains(e.key) || options.uri.toString().contains(e.key))
            .map((e) => e.value)
            .firstOrNull;
    if (handler != null) return handler(options);
    return ResponseBody.fromString('Not Found', 404);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  const systemConfig = SystemConfig(
    id: 'gba',
    name: 'Game Boy Advance',
    targetFolder: '/sdcard/Roms/GBA',
    providers: [],
  );

  group('WebProvider', () {
    late _FakeHttpAdapter adapter;
    late Dio dio;

    setUp(() {
      adapter = _FakeHttpAdapter();
      dio = Dio()..httpClientAdapter = adapter;
    });

    group('fetchGames', () {
      test('parses Apache-style directory listing', () async {
        const config = ProviderConfig(
          type: ProviderType.web,
          priority: 1,
          url: 'https://roms.example.com/gba',
        );
        final provider = WebProvider(config, dio: dio);

        adapter.onGet('https://roms.example.com/gba/', statusCode: 200, body: '''
<html><body>
<a href="/">Parent Directory</a>
<a href="Pokemon%20Emerald.gba">Pokemon Emerald.gba</a>
<a href="Metroid%20Fusion.gba">Metroid Fusion.gba</a>
<a href="readme.txt">readme.txt</a>
</body></html>
''');

        final games = await provider.fetchGames(systemConfig);
        expect(games.length, 2);
        expect(games[0].filename, 'Pokemon Emerald.gba');
        expect(games[0].url, 'https://roms.example.com/gba/Pokemon%20Emerald.gba');
        expect(games[1].filename, 'Metroid Fusion.gba');
      });

      test('skips parent directory links', () async {
        const config = ProviderConfig(type: ProviderType.web, priority: 1, url: 'https://example.com');
        final provider = WebProvider(config, dio: dio);

        adapter.onGet('https://example.com/', statusCode: 200, body: '''
<html><body>
<a href="/">Home</a>
<a href="..">..</a>
<a href="Parent Directory">Parent Directory</a>
<a href="game.gba">game.gba</a>
</body></html>
''');

        final games = await provider.fetchGames(systemConfig);
        expect(games.length, 1);
        expect(games[0].filename, 'game.gba');
      });

      test('skips path traversal attempts', () async {
        const config = ProviderConfig(type: ProviderType.web, priority: 1, url: 'https://example.com');
        final provider = WebProvider(config, dio: dio);

        adapter.onGet('https://example.com/', statusCode: 200, body: '''
<html><body>
<a href="../../../etc/passwd">passwd</a>
<a href="https://evil.com/game.gba">external game.gba</a>
<a href="http://evil.com/game.gba">another external</a>
<a href="legit.gba">legit.gba</a>
</body></html>
''');

        final games = await provider.fetchGames(systemConfig);
        expect(games.length, 1);
        expect(games[0].filename, 'legit.gba');
      });

      test('skips oversized hrefs', () async {
        const config = ProviderConfig(type: ProviderType.web, priority: 1, url: 'https://example.com');
        final provider = WebProvider(config, dio: dio);

        final longHref = 'a' * 1025;
        adapter.onGet('https://example.com/', statusCode: 200, body: '''
<html><body>
<a href="$longHref.gba">long name</a>
<a href="short.gba">short.gba</a>
</body></html>
''');

        final games = await provider.fetchGames(systemConfig);
        expect(games.length, 1);
        expect(games[0].filename, 'short.gba');
      });

      test('skips hrefs with control characters', () async {
        const config = ProviderConfig(type: ProviderType.web, priority: 1, url: 'https://example.com');
        final provider = WebProvider(config, dio: dio);

        adapter.onGet('https://example.com/', statusCode: 200, body: '''
<html><body>
<a href="game\x00.gba">game</a>
<a href="legit.gba">legit.gba</a>
</body></html>
''');

        final games = await provider.fetchGames(systemConfig);
        expect(games.length, 1);
      });

      test('uses subpath from config.path', () async {
        const config = ProviderConfig(type: ProviderType.web, priority: 1, url: 'https://example.com', path: '/roms/gba');
        final provider = WebProvider(config, dio: dio);

        adapter.onGet('https://example.com/roms/gba/', statusCode: 200, body: '''
<html><body>
<a href="game.gba">game.gba</a>
</body></html>
''');

        final games = await provider.fetchGames(systemConfig);
        expect(games.length, 1);
      });

      test('returns empty list for empty directory', () async {
        const config = ProviderConfig(type: ProviderType.web, priority: 1, url: 'https://example.com');
        final provider = WebProvider(config, dio: dio);

        adapter.onGet('https://example.com/', statusCode: 200, body: '<html><body></body></html>');

        final games = await provider.fetchGames(systemConfig);
        expect(games, isEmpty);
      });
    });

    group('resolveDownload', () {
      test('returns HttpDownloadHandle with correct URL', () async {
        const config = ProviderConfig(type: ProviderType.web, priority: 1, url: 'https://example.com');
        final provider = WebProvider(config, dio: dio);

        const game = GameItem(filename: 'game.gba', displayName: 'Game', url: 'https://example.com/game.gba');
        final handle = await provider.resolveDownload(game);
        expect(handle, isA<HttpDownloadHandle>());
        expect((handle as HttpDownloadHandle).url, 'https://example.com/game.gba');
      });

      test('includes auth headers when configured', () async {
        const config = ProviderConfig(
          type: ProviderType.web,
          priority: 1,
          url: 'https://example.com',
          auth: AuthConfig(user: 'admin', pass: 'secret'),
        );
        final provider = WebProvider(config, dio: dio);

        const game = GameItem(filename: 'game.gba', displayName: 'Game', url: 'https://example.com/game.gba');
        final handle = await provider.resolveDownload(game) as HttpDownloadHandle;
        expect(handle.headers, isNotNull);
        expect(handle.headers!['Authorization'], contains('Basic'));
      });

      test('no auth headers without credentials', () async {
        const config = ProviderConfig(type: ProviderType.web, priority: 1, url: 'https://example.com');
        final provider = WebProvider(config, dio: dio);

        const game = GameItem(filename: 'game.gba', displayName: 'Game', url: 'https://example.com/game.gba');
        final handle = await provider.resolveDownload(game) as HttpDownloadHandle;
        expect(handle.headers, isNull);
      });
    });

    group('testConnection', () {
      test('returns ok on success', () async {
        const config = ProviderConfig(type: ProviderType.web, priority: 1, url: 'https://example.com');
        final provider = WebProvider(config, dio: dio);

        adapter.onHead('https://example.com/', statusCode: 200);

        final result = await provider.testConnection();
        expect(result.success, true);
      });
    });

    group('displayLabel', () {
      test('shows WEB: url', () {
        const config = ProviderConfig(type: ProviderType.web, priority: 1, url: 'https://roms.example.com');
        final provider = WebProvider(config, dio: dio);
        expect(provider.displayLabel, 'WEB: https://roms.example.com');
      });
    });
  });

  group('HeaderValue', () {
    test('basicAuth produces valid base64', () {
      final value = HeaderValue.basicAuth('user', 'pass');
      expect(value, startsWith('Basic '));
      final decoded = utf8.decode(base64Decode(value.substring(6)));
      expect(decoded, 'user:pass');
    });
  });
}
