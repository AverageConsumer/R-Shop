import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/config/provider_config.dart';
import '../utils/network_constants.dart';
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
  final String? pathCoverSmall;
  final String? pathCoverLarge;
  final List<String> mergedScreenshots;
  final String? summary;
  final String? genres;
  final String? developer;
  final int? firstReleaseDate;
  final String? gameModes;
  final double? averageRating;

  const RommRom({
    required this.id,
    required this.name,
    required this.fileName,
    required this.platformId,
    this.urlCover,
    this.pathCoverSmall,
    this.pathCoverLarge,
    this.mergedScreenshots = const [],
    this.summary,
    this.genres,
    this.developer,
    this.firstReleaseDate,
    this.gameModes,
    this.averageRating,
  });

  factory RommRom.fromJson(Map<String, dynamic> json) {
    final screenshots = json['merged_screenshots'];

    // Parse metadata defensively — malformed fields must not break game listing
    String? parsedGenres;
    String? parsedDeveloper;
    String? parsedGameModes;
    try {
      parsedGenres = _joinListField(json['genres']);
      parsedDeveloper = _extractFirstName(json['companies']);
      parsedGameModes = _joinListField(json['game_modes']);
    } catch (e) {
      debugPrint('RommApiService: metadata parsing skipped: $e');
    }

    return RommRom(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      fileName: json['file_name'] as String? ?? json['fs_name'] as String? ?? '',
      platformId: json['platform_id'] as int? ?? 0,
      urlCover: json['url_cover'] as String?,
      pathCoverSmall: json['path_cover_small'] as String?,
      pathCoverLarge: json['path_cover_large'] as String?,
      mergedScreenshots: screenshots is List
          ? screenshots.whereType<String>().toList()
          : const [],
      summary: json['summary'] as String?,
      genres: parsedGenres,
      developer: parsedDeveloper,
      firstReleaseDate: json['first_release_date'] as int?,
      gameModes: parsedGameModes,
      averageRating: (json['average_rating'] as num?)?.toDouble(),
    );
  }

  /// Joins a list field that may be `List<String>` or `List<Map>` with a `name` key.
  static String? _joinListField(dynamic field) {
    if (field is! List || field.isEmpty) return null;
    final names = field
        .map((e) => e is Map ? e['name']?.toString() : e?.toString())
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .toList();
    return names.isEmpty ? null : names.join(', ');
  }

  /// Extracts the first company name from a list of company objects or strings.
  static String? _extractFirstName(dynamic field) {
    if (field is! List || field.isEmpty) return null;
    final first = field.first;
    if (first is Map) return first['name']?.toString();
    return first?.toString();
  }
}

class RommApiService {
  static const _maxPaginationItems = 20000;
  final Dio _dio;

  RommApiService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: NetworkTimeouts.apiConnect,
              receiveTimeout: NetworkTimeouts.apiReceive,
            ));

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
        .whereType<Map<String, dynamic>>()
        .map((e) => RommPlatform.fromJson(e))
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
        list
            .whereType<Map<String, dynamic>>()
            .map((e) => RommRom.fromJson(e)),
      );

      if (list.length < pageSize) break;
      offset += pageSize;
      if (offset > _maxPaginationItems) break; // Safety guard
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
      final statusCode = e.response?.statusCode;
      final String message;
      if (statusCode == 401) {
        message = 'Authentication failed — check your credentials';
      } else if (statusCode == 403) {
        message = 'Access denied — insufficient permissions';
      } else if (statusCode == 429) {
        message = 'Rate limited — try again later';
      } else if (statusCode != null && statusCode >= 500) {
        message = 'Server error (HTTP $statusCode)';
      } else if (statusCode != null) {
        message = 'HTTP $statusCode';
      } else {
        message = e.message ?? 'Connection failed';
      }
      return SourceConnectionResult.failed(message);
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
    final base = _normalizeBaseUrl(baseUrl);

    // 1. External CDN URL (fastest)
    final cover = rom.urlCover;
    if (cover != null && cover.isNotEmpty) {
      if (cover.startsWith('http')) return cover;
      return '$base$cover';
    }

    // 2. Local cover from RomM instance
    final small = rom.pathCoverSmall;
    if (small != null && small.isNotEmpty) return '$base$small';

    final large = rom.pathCoverLarge;
    if (large != null && large.isNotEmpty) return '$base$large';

    // 3. First screenshot as fallback cover
    if (rom.mergedScreenshots.isNotEmpty) {
      final screenshot = rom.mergedScreenshots.first;
      if (screenshot.startsWith('http')) return screenshot;
      return '$base$screenshot';
    }

    return null;
  }
}
