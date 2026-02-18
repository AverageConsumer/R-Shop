import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/config/provider_config.dart';
import 'source_provider.dart';

class RommPlatform {
  final int id;
  final String slug;
  final String fsSlug;
  final String name;
  final int? igdbId;
  final int romCount;

  const RommPlatform({
    required this.id,
    required this.slug,
    required this.fsSlug,
    required this.name,
    this.igdbId,
    required this.romCount,
  });

  factory RommPlatform.fromJson(Map<String, dynamic> json) {
    return RommPlatform(
      id: json['id'] as int,
      slug: json['slug'] as String? ?? '',
      fsSlug: json['fs_slug'] as String? ?? '',
      name: json['name'] as String? ?? '',
      igdbId: json['igdb_id'] as int?,
      romCount: json['rom_count'] as int? ?? 0,
    );
  }
}

class RommRom {
  final int id;
  final String name;
  final String fileName;
  final int platformId;
  final String? urlCover;

  const RommRom({
    required this.id,
    required this.name,
    required this.fileName,
    required this.platformId,
    this.urlCover,
  });

  factory RommRom.fromJson(Map<String, dynamic> json) {
    return RommRom(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      fileName: json['file_name'] as String? ?? json['fs_name'] as String? ?? '',
      platformId: json['platform_id'] as int? ?? 0,
      urlCover: json['url_cover'] as String?,
    );
  }
}

class RommApiService {
  final Dio _dio;

  RommApiService({Dio? dio}) : _dio = dio ?? Dio();

  Options? _buildAuthOptions(AuthConfig? auth) {
    if (auth == null) return null;

    final headers = <String, String>{};

    if (auth.apiKey != null && auth.apiKey!.isNotEmpty) {
      headers['Authorization'] = 'Bearer ${auth.apiKey}';
    } else if (auth.user != null && auth.user!.isNotEmpty) {
      final credentials = base64Encode(
        utf8.encode('${auth.user}:${auth.pass ?? ''}'),
      );
      headers['Authorization'] = 'Basic $credentials';
    }

    if (headers.isEmpty) return null;
    return Options(headers: headers);
  }

  String _normalizeBaseUrl(String url) {
    var base = url.trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    return base;
  }

  Future<List<RommPlatform>> fetchPlatforms(
    String baseUrl, {
    AuthConfig? auth,
  }) async {
    final url = '${_normalizeBaseUrl(baseUrl)}/api/platforms';
    final response = await _dio.get<dynamic>(
      url,
      options: _buildAuthOptions(auth),
    );

    final data = response.data;
    final List<dynamic> list;
    if (data is List) {
      list = data;
    } else if (data is Map) {
      list = (data['items'] ?? data['results']) as List<dynamic>? ?? [];
    } else {
      list = [];
    }

    return list
        .map((e) => RommPlatform.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<RommRom>> fetchRoms(
    String baseUrl,
    int platformId, {
    AuthConfig? auth,
  }) async {
    final url = '${_normalizeBaseUrl(baseUrl)}/api/roms';
    const pageSize = 500;
    final allRoms = <RommRom>[];
    var offset = 0;

    while (true) {
      final response = await _dio.get<dynamic>(
        url,
        queryParameters: {
          'platform_ids': [platformId],
          'limit': pageSize,
          'offset': offset,
        },
        options: _buildAuthOptions(auth),
      );

      final data = response.data;
      final List<dynamic> list;
      if (data is List) {
        list = data;
      } else if (data is Map) {
        list = (data['items'] ?? data['results']) as List<dynamic>? ?? [];
      } else {
        break;
      }

      allRoms.addAll(
        list.map((e) => RommRom.fromJson(e as Map<String, dynamic>)),
      );

      if (list.length < pageSize) break;
      offset += pageSize;
    }

    return allRoms;
  }

  Future<SourceConnectionResult> testConnection(
    String baseUrl, {
    AuthConfig? auth,
  }) async {
    try {
      final url = '${_normalizeBaseUrl(baseUrl)}/api/platforms';
      await _dio.get<dynamic>(
        url,
        options: _buildAuthOptions(auth),
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

  String buildRomDownloadUrl(String baseUrl, RommRom rom) {
    final base = _normalizeBaseUrl(baseUrl);
    final encodedFileName = Uri.encodeComponent(rom.fileName);
    return '$base/api/roms/${rom.id}/content/$encodedFileName';
  }

  String? buildCoverUrl(String baseUrl, RommRom rom) {
    if (rom.urlCover == null || rom.urlCover!.isEmpty) return null;
    final base = _normalizeBaseUrl(baseUrl);
    final cover = rom.urlCover!;
    if (cover.startsWith('http')) return cover;
    return '$base$cover';
  }
}
