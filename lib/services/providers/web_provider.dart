import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart';

import '../../models/config/provider_config.dart';
import '../../utils/network_constants.dart';
import '../../models/config/system_config.dart';
import '../../models/game_item.dart';
import '../../models/system_model.dart';
import '../download_handle.dart';
import '../source_provider.dart';

class WebProvider implements SourceProvider {
  @override
  final ProviderConfig config;

  final Dio _dio;

  static const int _maxScanDepth = 3;
  static const Duration _scanTimeout = Duration(minutes: 5);

  WebProvider(this.config, {Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: NetworkTimeouts.apiConnect,
              receiveTimeout: NetworkTimeouts.apiReceive,
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
    final rootUrl = configPath != null ? '$_baseUrl${_trimSlashes(configPath)}/' : _baseUrl;

    final games = <GameItem>[];
    final folderFiles = <String, List<({String name, String url})>>{};
    final folderNames = <String, String>{};
    final visited = <String>{};

    await _scanDirectory(rootUrl, 0, games, folderFiles, folderNames, visited)
        .timeout(_scanTimeout, onTimeout: () {
      debugPrint('WebProvider: scan timed out after $_scanTimeout');
    });

    // Promote folders: single-file → flat GameItem, multi-file → folder GameItem
    for (final entry in folderFiles.entries) {
      final files = entry.value;
      if (files.length == 1) {
        final file = files.first;
        games.add(GameItem(
          filename: file.name,
          displayName: GameItem.cleanDisplayName(file.name),
          url: file.url,
          providerConfig: config,
        ));
      } else {
        final folderName = folderNames[entry.key]!;
        games.add(GameItem(
          filename: folderName,
          displayName: GameItem.cleanDisplayName(folderName),
          url: entry.key,
          providerConfig: config,
          isFolder: true,
        ));
      }
    }

    return games;
  }

  Future<void> _scanDirectory(
    String dirUrl,
    int depth,
    List<GameItem> games,
    Map<String, List<({String name, String url})>> folderFiles,
    Map<String, String> folderNames,
    Set<String> visited,
  ) async {
    final normalizedUrl = dirUrl.endsWith('/') ? dirUrl : '$dirUrl/';
    if (visited.contains(normalizedUrl)) return;
    visited.add(normalizedUrl);

    final Response<String> response;
    try {
      response = await _dio.get<String>(normalizedUrl, options: _authOptions);
    } catch (e) {
      debugPrint('WebProvider: failed to fetch $normalizedUrl: $e');
      return;
    }

    final document = parse(response.data ?? '');
    final links = document.querySelectorAll('a');
    final subdirs = <String>[];

    for (final link in links) {
      final href = link.attributes['href'];
      if (href == null) continue;
      if (href.length > 1024) continue;

      final text = link.text.trim();
      if (text == 'Parent Directory' ||
          text == '..' ||
          text.startsWith('/') ||
          href == '/') {
        continue;
      }

      // Skip absolute URLs, absolute paths, and path traversal attempts
      if (href.startsWith('http://') ||
          href.startsWith('https://') ||
          href.startsWith('/') ||
          href.contains('../')) {
        continue;
      }

      if (_containsControlChars(href)) continue;

      final hrefLower = href.toLowerCase();

      // Directory link (ends with /)
      if (href.endsWith('/') && depth < _maxScanDepth) {
        final decoded = Uri.decodeFull(href);
        if (decoded.length <= 512 && !decoded.startsWith('.')) {
          subdirs.add(href);
        }
        continue;
      }

      if (SystemModel.isGameFile(hrefLower)) {
        final decodedFilename = Uri.decodeFull(href);
        if (decodedFilename.length > 512) continue;
        final fileUrl = '$normalizedUrl$href';

        if (depth == 0) {
          games.add(GameItem(
            filename: decodedFilename,
            displayName: GameItem.cleanDisplayName(decodedFilename),
            url: fileUrl,
            providerConfig: config,
          ));
        } else {
          // Nested file → track per parent folder for promotion
          folderNames.putIfAbsent(normalizedUrl, () => _folderNameFromUrl(normalizedUrl));
          folderFiles.putIfAbsent(normalizedUrl, () => [])
              .add((name: decodedFilename, url: fileUrl));
        }
      }
    }

    // Recurse into subdirectories
    for (final subHref in subdirs) {
      final subUrl = '$normalizedUrl$subHref';
      try {
        await _scanDirectory(subUrl, depth + 1, games, folderFiles, folderNames, visited);
      } catch (e) {
        debugPrint('WebProvider: failed to scan subdirectory $subUrl: $e');
      }
    }
  }

  /// Extracts a folder display name from a directory URL.
  static String _folderNameFromUrl(String url) {
    var trimmed = url;
    while (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    final lastSlash = trimmed.lastIndexOf('/');
    if (lastSlash >= 0) {
      return Uri.decodeFull(trimmed.substring(lastSlash + 1));
    }
    return Uri.decodeFull(trimmed);
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
