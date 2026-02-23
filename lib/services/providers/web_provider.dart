import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:html/parser.dart';

import '../../models/config/provider_config.dart';
import '../../models/config/system_config.dart';
import '../../models/game_item.dart';
import '../../models/system_model.dart';
import '../download_handle.dart';
import '../source_provider.dart';

class WebProvider implements SourceProvider {
  @override
  final ProviderConfig config;

  final Dio _dio;

  WebProvider(this.config, {Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
            ));

  String get _baseUrl {
    final url = config.url;
    if (url == null || url.isEmpty) {
      throw StateError('Web provider requires a URL');
    }
    return url.endsWith('/') ? url : '$url/';
  }

  @override
  Future<List<GameItem>> fetchGames(SystemConfig system) async {
    final configPath = config.path;
    final url = configPath != null ? '$_baseUrl${_trimSlashes(configPath)}/' : _baseUrl;

    final response = await _dio.get<String>(
      url,
      options: _authOptions,
    );

    return _parseDirectoryListing(response.data ?? '', url);
  }

  @override
  Future<DownloadHandle> resolveDownload(GameItem game) async {
    return HttpDownloadHandle(
      url: game.url,
      headers: _authHeaders.isNotEmpty ? _authHeaders : null,
    );
  }

  @override
  Future<SourceConnectionResult> testConnection() async {
    try {
      await _dio.head<void>(
        _baseUrl,
        options: _authOptions,
      );
      return const SourceConnectionResult.ok();
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      return SourceConnectionResult.failed(
        statusCode != null
            ? 'HTTP $statusCode'
            : e.message ?? 'Connection failed',
      );
    } catch (e) {
      return SourceConnectionResult.failed(e.toString());
    }
  }

  @override
  String get displayLabel => 'WEB: ${config.url}';

  Map<String, String> get _authHeaders {
    final auth = config.auth;
    if (auth == null || auth.user == null) return {};
    return {
      'Authorization': HeaderValue.basicAuth(auth.user!, auth.pass ?? ''),
    };
  }

  Options? get _authOptions {
    final headers = _authHeaders;
    if (headers.isEmpty) return null;
    return Options(headers: headers);
  }

  List<GameItem> _parseDirectoryListing(String html, String baseUrl) {
    final document = parse(html);
    final links = document.querySelectorAll('a');
    final games = <GameItem>[];

    for (final link in links) {
      final href = link.attributes['href'];
      if (href == null) continue;

      // Length validation: skip oversized hrefs (crafted URLs)
      if (href.length > 1024) continue;

      final text = link.text.trim();
      if (text == 'Parent Directory' ||
          text == '..' ||
          text.startsWith('/') ||
          href == '/') {
        continue;
      }

      // Skip absolute URLs and path traversal attempts
      if (href.startsWith('http://') ||
          href.startsWith('https://') ||
          href.contains('../')) {
        continue;
      }

      // Skip hrefs with control characters
      if (_containsControlChars(href)) continue;

      final hrefLower = href.toLowerCase();
      if (SystemModel.isGameFile(hrefLower)) {
        final decodedFilename = Uri.decodeFull(href);
        // Skip filenames that are too long after decoding
        if (decodedFilename.length > 512) continue;
        games.add(GameItem(
          filename: decodedFilename,
          displayName: GameItem.cleanDisplayName(decodedFilename),
          url: '$baseUrl$href',
          providerConfig: config,
        ));
      }
    }

    return games;
  }

  static bool _containsControlChars(String s) {
    for (var i = 0; i < s.length; i++) {
      final c = s.codeUnitAt(i);
      if (c < 0x20 && c != 0x09) return true; // allow tab, reject other control chars
    }
    return false;
  }

  static String _trimSlashes(String path) {
    var result = path;
    while (result.startsWith('/')) {
      result = result.substring(1);
    }
    while (result.endsWith('/')) {
      result = result.substring(0, result.length - 1);
    }
    return result;
  }

}

class HeaderValue {
  static String basicAuth(String user, String pass) {
    return 'Basic ${base64Encode(utf8.encode('$user:$pass'))}';
  }
}
