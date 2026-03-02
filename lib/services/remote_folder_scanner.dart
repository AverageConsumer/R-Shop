import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:ftpconnect/ftpconnect.dart';
import 'package:html/parser.dart';

import '../models/config/provider_config.dart';
import '../utils/network_constants.dart';
import 'native_smb_service.dart';

class RemoteFolderEntry {
  final String name;

  const RemoteFolderEntry({required this.name});
}

/// Lightweight service that lists only top-level directories from a remote
/// provider. Unlike the full providers which recurse 3 levels deep to find
/// game files, this only needs directory names at depth 0 for auto-discovery.
class RemoteFolderScanner {
  RemoteFolderScanner._();

  static Future<List<RemoteFolderEntry>> scanTopLevel(
    ProviderConfig config, {
    NativeSmbService? smbService,
    Dio? dio,
  }) async {
    switch (config.type) {
      case ProviderType.smb:
        return _scanSmb(config, smbService ?? NativeSmbService());
      case ProviderType.ftp:
        return _scanFtp(config);
      case ProviderType.web:
        return _scanWeb(config, dio);
      case ProviderType.romm:
        throw StateError('RemoteFolderScanner does not support RomM');
    }
  }

  static Future<List<RemoteFolderEntry>> _scanSmb(
    ProviderConfig config,
    NativeSmbService smbService,
  ) async {
    final entries = await smbService.listFiles(
      host: config.host ?? '',
      port: config.port ?? 445,
      share: config.share ?? '',
      path: config.path ?? '',
      user: config.auth?.user ?? 'guest',
      pass: config.auth?.pass ?? '',
      domain: config.auth?.domain ?? '',
      maxDepth: 0,
    ).timeout(NetworkTimeouts.smbConnect);

    return entries
        .where((e) => e.isDirectory)
        .map((e) => RemoteFolderEntry(name: e.name))
        .toList();
  }

  static Future<List<RemoteFolderEntry>> _scanFtp(ProviderConfig config) async {
    final host = config.host;
    if (host == null || host.isEmpty) {
      throw StateError('FTP provider requires a host');
    }

    final ftp = FTPConnect(
      host,
      port: config.port ?? 21,
      user: config.auth?.user ?? 'anonymous',
      pass: config.auth?.pass ?? '',
      timeout: 30,
    );

    await ftp.connect().timeout(NetworkTimeouts.ftpConnect);
    try {
      final remotePath = config.path ?? '/';
      await ftp.changeDirectory(remotePath);
      final listing = await ftp.listDirectoryContent()
          .timeout(NetworkTimeouts.ftpList);

      return listing
          .where((e) =>
              e.type == FTPEntryType.dir &&
              e.name != '.' &&
              e.name != '..' &&
              !e.name.contains('..'))
          .map((e) => RemoteFolderEntry(name: e.name))
          .toList();
    } finally {
      try {
        await ftp.disconnect();
      } catch (e) {
        debugPrint('RemoteFolderScanner: FTP disconnect error: $e');
      }
    }
  }

  static Future<List<RemoteFolderEntry>> _scanWeb(
    ProviderConfig config,
    Dio? dio,
  ) async {
    final baseUrl = config.url;
    if (baseUrl == null || baseUrl.isEmpty) {
      throw StateError('Web provider requires a URL');
    }

    final effectiveDio = dio ??
        Dio(BaseOptions(
          connectTimeout: NetworkTimeouts.apiConnect,
          receiveTimeout: NetworkTimeouts.apiReceive,
        ));

    final configPath = config.path;
    String rootUrl;
    if (configPath != null && configPath.isNotEmpty) {
      final base = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
      final trimmed = _trimSlashes(configPath);
      rootUrl = '$base$trimmed/';
    } else {
      rootUrl = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    }

    Options? authOptions;
    final auth = config.auth;
    if (auth != null && auth.user != null && auth.user!.isNotEmpty) {
      final encoded = base64Encode(utf8.encode('${auth.user}:${auth.pass ?? ''}'));
      authOptions = Options(headers: {'Authorization': 'Basic $encoded'});
    }

    final response = await effectiveDio.get<String>(rootUrl, options: authOptions);
    final document = parse(response.data ?? '');
    final links = document.querySelectorAll('a');
    final dirs = <RemoteFolderEntry>[];

    for (final link in links) {
      final href = link.attributes['href'];
      if (href == null || href.length > 1024) continue;

      final text = link.text.trim();
      if (text == 'Parent Directory' || text == '..' || href == '/') continue;

      // Only directories (hrefs ending with /)
      if (!href.endsWith('/')) continue;

      // Skip absolute URLs and paths
      if (href.startsWith('http://') || href.startsWith('https://')) continue;
      if (href.startsWith('/')) continue;

      // Skip traversal attempts
      final decoded = Uri.decodeFull(href);
      if (decoded.contains('..')) continue;

      // Extract clean directory name
      final name = decoded.endsWith('/')
          ? decoded.substring(0, decoded.length - 1)
          : decoded;
      if (name.isEmpty) continue;

      dirs.add(RemoteFolderEntry(name: name));
    }

    return dirs;
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
