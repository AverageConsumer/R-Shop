import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:html/parser.dart';

import '../../models/config/provider_config.dart';
import '../../models/config/system_config.dart';
import '../../models/game_item.dart';
import '../download_handle.dart';
import '../source_provider.dart';

class WebProvider implements SourceProvider {
  @override
  final ProviderConfig config;

  final Dio _dio;

  WebProvider(this.config, {Dio? dio}) : _dio = dio ?? Dio();

  String get _baseUrl {
    final url = config.url!;
    return url.endsWith('/') ? url : '$url/';
  }

  @override
  Future<List<GameItem>> fetchGames(SystemConfig system) async {
    final url = config.path != null ? '$_baseUrl${_trimSlashes(config.path!)}/' : _baseUrl;

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
      return SourceConnectionResult.failed(
        e.response?.statusCode != null
            ? 'HTTP ${e.response!.statusCode}'
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

      final text = link.text.trim();
      if (text == 'Parent Directory' ||
          text == '..' ||
          text.startsWith('/') ||
          href == '/') {
        continue;
      }

      final hrefLower = href.toLowerCase();
      if (_isGameFile(hrefLower)) {
        final decodedFilename = Uri.decodeFull(href);
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

  static bool _isGameFile(String name) {
    return _gameExtensions.any((ext) => name.endsWith(ext));
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

  static const _gameExtensions = [
    '.zip', '.7z', '.rar',
    '.nes', '.sfc', '.z64', '.n64', '.v64',
    '.gb', '.gbc', '.gba', '.nds', '.3ds', '.cia',
    '.iso', '.cso', '.chd', '.pbp', '.cue', '.rvz',
    '.sms', '.md', '.gen', '.gg',
  ];
}

class HeaderValue {
  static String basicAuth(String user, String pass) {
    return 'Basic ${base64Encode(utf8.encode('$user:$pass'))}';
  }
}
