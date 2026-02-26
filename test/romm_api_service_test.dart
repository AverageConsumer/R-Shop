import 'dart:collection';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retro_eshop/models/config/provider_config.dart';
import 'package:retro_eshop/services/romm_api_service.dart';

// ─── Test doubles ────────────────────────────────────────

class _RecordedRequest {
  final String url;
  final Map<String, dynamic>? queryParameters;
  final Map<String, dynamic>? headers;

  _RecordedRequest({
    required this.url,
    this.queryParameters,
    this.headers,
  });
}

class _FakeResponse {
  final dynamic data;
  final int statusCode;
  final bool isError;

  _FakeResponse(this.data, {this.statusCode = 200, this.isError = false});
}

class _FakeDio implements Dio {
  final List<_RecordedRequest> requests = [];
  final Queue<_FakeResponse> responses = Queue();

  void enqueue(dynamic data, {int statusCode = 200}) {
    responses.add(_FakeResponse(data, statusCode: statusCode));
  }

  void enqueueError(int statusCode, {String? message}) {
    responses.add(_FakeResponse(null, statusCode: statusCode, isError: true));
  }

  void enqueueConnectionError({String? message}) {
    responses.add(_FakeResponse(
      message ?? 'Connection failed',
      statusCode: 0,
      isError: true,
    ));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not faked');

  @override
  Future<Response<T>> get<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    requests.add(_RecordedRequest(
      url: path,
      queryParameters: queryParameters,
      headers: options?.headers?.cast<String, dynamic>(),
    ));

    if (responses.isEmpty) {
      throw StateError('No more queued responses in _FakeDio');
    }

    final fake = responses.removeFirst();

    if (fake.isError) {
      if (fake.statusCode == 0) {
        throw DioException(
          requestOptions: RequestOptions(path: path),
          message: fake.data as String?,
          type: DioExceptionType.connectionError,
        );
      }
      throw DioException(
        requestOptions: RequestOptions(path: path),
        response: Response(
          requestOptions: RequestOptions(path: path),
          statusCode: fake.statusCode,
        ),
        type: DioExceptionType.badResponse,
      );
    }

    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: fake.data as T?,
      statusCode: fake.statusCode,
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────

Map<String, dynamic> _platformJson({
  required int id,
  String? slug,
  String? fsSlug,
  String? name,
  int? igdbId,
  int? romCount,
}) =>
    {
      'id': id,
      if (slug != null) 'slug': slug,
      if (fsSlug != null) 'fs_slug': fsSlug,
      if (name != null) 'name': name,
      if (igdbId != null) 'igdb_id': igdbId,
      if (romCount != null) 'rom_count': romCount,
    };

Map<String, dynamic> _romJson({
  required int id,
  String? name,
  String? fileName,
  String? fsName,
  int? platformId,
  String? urlCover,
  String? pathCoverSmall,
  String? pathCoverLarge,
  List<dynamic>? mergedScreenshots,
}) =>
    {
      'id': id,
      if (name != null) 'name': name,
      if (fileName != null) 'file_name': fileName,
      if (fsName != null) 'fs_name': fsName,
      if (platformId != null) 'platform_id': platformId,
      if (urlCover != null) 'url_cover': urlCover,
      if (pathCoverSmall != null) 'path_cover_small': pathCoverSmall,
      if (pathCoverLarge != null) 'path_cover_large': pathCoverLarge,
      if (mergedScreenshots != null) 'merged_screenshots': mergedScreenshots,
    };

// ─── Tests ───────────────────────────────────────────────

void main() {
  late _FakeDio fakeDio;
  late RommApiService service;

  setUp(() {
    fakeDio = _FakeDio();
    service = RommApiService(dio: fakeDio);
  });

  // ═══════════════════════════════════════════════════════
  group('RommPlatform.fromJson', () {
    test('parses complete JSON', () {
      final p = RommPlatform.fromJson({
        'id': 1,
        'slug': 'snes',
        'fs_slug': 'snes',
        'name': 'Super Nintendo',
        'igdb_id': 19,
        'rom_count': 42,
      });

      expect(p.id, 1);
      expect(p.slug, 'snes');
      expect(p.fsSlug, 'snes');
      expect(p.name, 'Super Nintendo');
      expect(p.igdbId, 19);
      expect(p.romCount, 42);
    });

    test('defaults for missing optional fields', () {
      final p = RommPlatform.fromJson({'id': 5, 'fs_slug': 'gba'});

      expect(p.slug, '');
      expect(p.name, '');
      expect(p.romCount, 0);
    });

    test('handles null igdbId', () {
      final p = RommPlatform.fromJson({
        'id': 2,
        'fs_slug': 'nes',
        'igdb_id': null,
      });

      expect(p.igdbId, isNull);
    });

    test('handles minimal JSON (only required fields)', () {
      final p = RommPlatform.fromJson({'id': 99, 'fs_slug': 'n64'});

      expect(p.id, 99);
      expect(p.fsSlug, 'n64');
      expect(p.slug, '');
      expect(p.name, '');
      expect(p.igdbId, isNull);
      expect(p.romCount, 0);
    });
  });

  // ═══════════════════════════════════════════════════════
  group('RommRom.fromJson', () {
    test('parses complete JSON', () {
      final r = RommRom.fromJson({
        'id': 10,
        'name': 'Super Mario World',
        'file_name': 'smw.sfc',
        'platform_id': 1,
        'url_cover': 'https://cdn.example.com/smw.jpg',
        'path_cover_small': '/covers/small/smw.jpg',
        'path_cover_large': '/covers/large/smw.jpg',
        'merged_screenshots': ['https://cdn.example.com/ss1.jpg'],
      });

      expect(r.id, 10);
      expect(r.name, 'Super Mario World');
      expect(r.fileName, 'smw.sfc');
      expect(r.platformId, 1);
      expect(r.urlCover, 'https://cdn.example.com/smw.jpg');
      expect(r.pathCoverSmall, '/covers/small/smw.jpg');
      expect(r.pathCoverLarge, '/covers/large/smw.jpg');
      expect(r.mergedScreenshots, ['https://cdn.example.com/ss1.jpg']);
    });

    test('falls back to fs_name when file_name missing', () {
      final r = RommRom.fromJson({
        'id': 11,
        'name': 'Zelda',
        'fs_name': 'zelda.sfc',
        'platform_id': 1,
      });

      expect(r.fileName, 'zelda.sfc');
    });

    test('handles null cover fields', () {
      final r = RommRom.fromJson({
        'id': 12,
        'name': 'Game',
        'file_name': 'game.rom',
        'platform_id': 1,
      });

      expect(r.urlCover, isNull);
      expect(r.pathCoverSmall, isNull);
      expect(r.pathCoverLarge, isNull);
    });

    test('filters non-string values from merged_screenshots', () {
      final r = RommRom.fromJson({
        'id': 13,
        'name': 'Game',
        'file_name': 'game.rom',
        'platform_id': 1,
        'merged_screenshots': ['valid.jpg', 42, null, true, 'also_valid.jpg'],
      });

      expect(r.mergedScreenshots, ['valid.jpg', 'also_valid.jpg']);
    });

    test('handles missing merged_screenshots key', () {
      final r = RommRom.fromJson({
        'id': 14,
        'name': 'Game',
        'file_name': 'game.rom',
        'platform_id': 1,
      });

      expect(r.mergedScreenshots, isEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════
  group('fetchPlatforms', () {
    test('returns platforms from array response', () async {
      fakeDio.enqueue([
        _platformJson(id: 1, slug: 'snes', fsSlug: 'snes', name: 'SNES', romCount: 10),
        _platformJson(id: 2, slug: 'gba', fsSlug: 'gba', name: 'GBA', romCount: 5),
      ]);

      final platforms = await service.fetchPlatforms('https://romm.local');

      expect(platforms, hasLength(2));
      expect(platforms[0].slug, 'snes');
      expect(platforms[1].slug, 'gba');
      expect(fakeDio.requests.single.url, 'https://romm.local/api/platforms');
    });

    test('returns platforms from {items: [...]} format', () async {
      fakeDio.enqueue({
        'items': [
          _platformJson(id: 1, slug: 'nes', fsSlug: 'nes', name: 'NES'),
        ],
      });

      final platforms = await service.fetchPlatforms('https://romm.local');

      expect(platforms, hasLength(1));
      expect(platforms[0].slug, 'nes');
    });

    test('returns platforms from {results: [...]} format', () async {
      fakeDio.enqueue({
        'results': [
          _platformJson(id: 1, slug: 'n64', fsSlug: 'n64', name: 'N64'),
        ],
      });

      final platforms = await service.fetchPlatforms('https://romm.local');

      expect(platforms, hasLength(1));
      expect(platforms[0].slug, 'n64');
    });

    test('returns empty list for unexpected data format', () async {
      fakeDio.enqueue('unexpected string');

      final platforms = await service.fetchPlatforms('https://romm.local');

      expect(platforms, isEmpty);
    });

    test('sends auth headers (API key)', () async {
      fakeDio.enqueue([]);
      final auth = AuthConfig(apiKey: 'my-secret-key');

      await service.fetchPlatforms('https://romm.local', auth: auth);

      expect(
        fakeDio.requests.single.headers?['Authorization'],
        'Bearer my-secret-key',
      );
    });
  });

  // ═══════════════════════════════════════════════════════
  group('fetchRoms — pagination', () {
    test('returns ROMs from single page (<500 items)', () async {
      fakeDio.enqueue([
        _romJson(id: 1, name: 'Game 1', fileName: 'g1.rom', platformId: 5),
        _romJson(id: 2, name: 'Game 2', fileName: 'g2.rom', platformId: 5),
      ]);

      final roms = await service.fetchRoms('https://romm.local', 5);

      expect(roms, hasLength(2));
      expect(roms[0].name, 'Game 1');
      expect(roms[1].name, 'Game 2');
      expect(fakeDio.requests, hasLength(1));
    });

    test('paginates across multiple pages', () async {
      // Page 1: exactly 500 items → triggers next page
      final page1 = List.generate(
        500,
        (i) => _romJson(id: i, name: 'Game $i', fileName: 'g$i.rom', platformId: 3),
      );
      // Page 2: 100 items → stops
      final page2 = List.generate(
        100,
        (i) => _romJson(id: 500 + i, name: 'Game ${500 + i}', fileName: 'g${500 + i}.rom', platformId: 3),
      );

      fakeDio.enqueue(page1);
      fakeDio.enqueue(page2);

      final roms = await service.fetchRoms('https://romm.local', 3);

      expect(roms, hasLength(600));
      expect(fakeDio.requests, hasLength(2));

      // Verify offset parameters
      expect(fakeDio.requests[0].queryParameters?['offset'], 0);
      expect(fakeDio.requests[1].queryParameters?['offset'], 500);
    });

    test('stops at partial page (<500 items)', () async {
      final page = List.generate(
        250,
        (i) => _romJson(id: i, name: 'Game $i', fileName: 'g$i.rom', platformId: 1),
      );
      fakeDio.enqueue(page);

      final roms = await service.fetchRoms('https://romm.local', 1);

      expect(roms, hasLength(250));
      expect(fakeDio.requests, hasLength(1));
    });

    test('stops at safety guard (>20000 items)', () async {
      // Enqueue 41 pages of exactly 500 items each (= 20500 total)
      // Should stop after offset exceeds 20000
      for (var i = 0; i <= 40; i++) {
        final page = List.generate(
          500,
          (j) => _romJson(
            id: i * 500 + j,
            name: 'Game ${i * 500 + j}',
            fileName: 'g${i * 500 + j}.rom',
            platformId: 1,
          ),
        );
        fakeDio.enqueue(page);
      }

      final roms = await service.fetchRoms('https://romm.local', 1);

      // offset goes 0, 500, 1000, ..., 20000 → 41 pages fetched
      // but at offset 20000 the loop checks offset > 20000 AFTER incrementing,
      // so 41 pages = 20500 items
      expect(roms, hasLength(20500));
      // Should NOT fetch page 42
      expect(fakeDio.requests.length, 41);
    });

    test('handles {items: [...]} response format', () async {
      fakeDio.enqueue({
        'items': [
          _romJson(id: 1, name: 'Game', fileName: 'g.rom', platformId: 1),
        ],
      });

      final roms = await service.fetchRoms('https://romm.local', 1);

      expect(roms, hasLength(1));
    });

    test('returns empty list for unexpected data', () async {
      fakeDio.enqueue('not a list or map');

      final roms = await service.fetchRoms('https://romm.local', 1);

      expect(roms, isEmpty);
    });

    test('sends correct query parameters', () async {
      fakeDio.enqueue([]);

      await service.fetchRoms('https://romm.local', 42);

      final params = fakeDio.requests.single.queryParameters!;
      expect(params['platform_ids'], [42]);
      expect(params['limit'], 500);
      expect(params['offset'], 0);
    });
  });

  // ═══════════════════════════════════════════════════════
  group('testConnection', () {
    test('returns ok() on success', () async {
      fakeDio.enqueue([]);

      final result = await service.testConnection('https://romm.local');

      expect(result.success, isTrue);
      expect(result.error, isNull);
    });

    test('maps 401 → auth error message', () async {
      fakeDio.enqueueError(401);

      final result = await service.testConnection('https://romm.local');

      expect(result.success, isFalse);
      expect(result.error, contains('Authentication failed'));
    });

    test('maps 403 → access denied message', () async {
      fakeDio.enqueueError(403);

      final result = await service.testConnection('https://romm.local');

      expect(result.success, isFalse);
      expect(result.error, contains('Access denied'));
    });

    test('maps 429 → rate limited message', () async {
      fakeDio.enqueueError(429);

      final result = await service.testConnection('https://romm.local');

      expect(result.success, isFalse);
      expect(result.error, contains('Rate limited'));
    });

    test('maps 5xx → server error message', () async {
      fakeDio.enqueueError(503);

      final result = await service.testConnection('https://romm.local');

      expect(result.success, isFalse);
      expect(result.error, contains('Server error'));
      expect(result.error, contains('503'));
    });

    test('maps connection error (no statusCode) → error message', () async {
      fakeDio.enqueueConnectionError(message: 'Connection refused');

      final result = await service.testConnection('https://romm.local');

      expect(result.success, isFalse);
      expect(result.error, contains('Connection'));
    });
  });

  // ═══════════════════════════════════════════════════════
  group('buildRomDownloadUrl', () {
    test('constructs correct URL with encoded filename', () {
      final rom = RommRom(
        id: 42,
        name: 'Super Mario World',
        fileName: 'smw.sfc',
        platformId: 1,
      );

      final url = service.buildRomDownloadUrl('https://romm.local', rom);

      expect(url, 'https://romm.local/api/roms/42/content/smw.sfc');
    });

    test('handles special characters in filename', () {
      final rom = RommRom(
        id: 7,
        name: 'Game',
        fileName: 'My Game (USA) [!].zip',
        platformId: 1,
      );

      final url = service.buildRomDownloadUrl('https://romm.local', rom);

      expect(url, contains(Uri.encodeComponent('My Game (USA) [!].zip')));
      expect(url, startsWith('https://romm.local/api/roms/7/content/'));
    });

    test('normalizes trailing slashes in baseUrl', () {
      final rom = RommRom(
        id: 1,
        name: 'Game',
        fileName: 'game.rom',
        platformId: 1,
      );

      final url = service.buildRomDownloadUrl('https://romm.local///', rom);

      expect(url, startsWith('https://romm.local/api/'));
      expect(url, isNot(contains('///api')));
    });
  });

  // ═══════════════════════════════════════════════════════
  group('buildCoverUrl', () {
    test('returns external CDN URL as-is', () {
      final rom = RommRom(
        id: 1,
        name: 'Game',
        fileName: 'game.rom',
        platformId: 1,
        urlCover: 'https://cdn.igdb.com/cover.jpg',
      );

      expect(
        service.buildCoverUrl('https://romm.local', rom),
        'https://cdn.igdb.com/cover.jpg',
      );
    });

    test('prepends baseUrl to relative urlCover', () {
      final rom = RommRom(
        id: 1,
        name: 'Game',
        fileName: 'game.rom',
        platformId: 1,
        urlCover: '/api/covers/1.jpg',
      );

      expect(
        service.buildCoverUrl('https://romm.local', rom),
        'https://romm.local/api/covers/1.jpg',
      );
    });

    test('falls back to pathCoverSmall', () {
      final rom = RommRom(
        id: 1,
        name: 'Game',
        fileName: 'game.rom',
        platformId: 1,
        pathCoverSmall: '/covers/small/1.jpg',
      );

      expect(
        service.buildCoverUrl('https://romm.local', rom),
        'https://romm.local/covers/small/1.jpg',
      );
    });

    test('falls back to pathCoverLarge', () {
      final rom = RommRom(
        id: 1,
        name: 'Game',
        fileName: 'game.rom',
        platformId: 1,
        pathCoverLarge: '/covers/large/1.jpg',
      );

      expect(
        service.buildCoverUrl('https://romm.local', rom),
        'https://romm.local/covers/large/1.jpg',
      );
    });

    test('falls back to first screenshot', () {
      final rom = RommRom(
        id: 1,
        name: 'Game',
        fileName: 'game.rom',
        platformId: 1,
        mergedScreenshots: ['https://cdn.example.com/ss1.jpg'],
      );

      expect(
        service.buildCoverUrl('https://romm.local', rom),
        'https://cdn.example.com/ss1.jpg',
      );
    });

    test('returns null when no cover data available', () {
      final rom = RommRom(
        id: 1,
        name: 'Game',
        fileName: 'game.rom',
        platformId: 1,
      );

      expect(service.buildCoverUrl('https://romm.local', rom), isNull);
    });
  });

  // ═══════════════════════════════════════════════════════
  group('_buildAuthOptions (tested via fetchPlatforms headers)', () {
    test('API key → Bearer header', () async {
      fakeDio.enqueue([]);

      await service.fetchPlatforms(
        'https://romm.local',
        auth: const AuthConfig(apiKey: 'test-key-123'),
      );

      expect(
        fakeDio.requests.single.headers?['Authorization'],
        'Bearer test-key-123',
      );
    });

    test('User/pass → Basic auth header', () async {
      fakeDio.enqueue([]);

      await service.fetchPlatforms(
        'https://romm.local',
        auth: const AuthConfig(user: 'admin', pass: 's3cret'),
      );

      final expected = 'Basic ${base64Encode(utf8.encode('admin:s3cret'))}';
      expect(
        fakeDio.requests.single.headers?['Authorization'],
        expected,
      );
    });

    test('API key takes priority over user/pass', () async {
      fakeDio.enqueue([]);

      await service.fetchPlatforms(
        'https://romm.local',
        auth: const AuthConfig(
          apiKey: 'my-key',
          user: 'admin',
          pass: 'pass',
        ),
      );

      expect(
        fakeDio.requests.single.headers?['Authorization'],
        'Bearer my-key',
      );
    });

    test('no auth → no Authorization header', () async {
      fakeDio.enqueue([]);

      await service.fetchPlatforms('https://romm.local');

      expect(fakeDio.requests.single.headers, isNull);
    });
  });

  // ═══════════════════════════════════════════════════════
  group('_normalizeBaseUrl (tested via buildRomDownloadUrl)', () {
    test('strips single trailing slash', () {
      final rom = RommRom(
        id: 1,
        name: 'G',
        fileName: 'g.rom',
        platformId: 1,
      );

      final url = service.buildRomDownloadUrl('https://romm.local/', rom);
      expect(url, startsWith('https://romm.local/api/'));
    });

    test('strips multiple trailing slashes', () {
      final rom = RommRom(
        id: 1,
        name: 'G',
        fileName: 'g.rom',
        platformId: 1,
      );

      final url = service.buildRomDownloadUrl('https://romm.local///', rom);
      expect(url, startsWith('https://romm.local/api/'));
    });
  });
}
