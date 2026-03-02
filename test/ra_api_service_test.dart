import 'dart:collection';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retro_eshop/services/ra_api_service.dart';

// ─── Test doubles ────────────────────────────────────────

class _RecordedRequest {
  final String url;
  final Map<String, dynamic>? queryParameters;

  _RecordedRequest({required this.url, this.queryParameters});
}

class _FakeResponse {
  final dynamic data;
  final int statusCode;
  final bool isError;
  final DioExceptionType? errorType;

  _FakeResponse(
    this.data, {
    this.statusCode = 200,
    this.isError = false,
    this.errorType,
  });
}

class _FakeDio implements Dio {
  final List<_RecordedRequest> requests = [];
  final Queue<_FakeResponse> responses = Queue();

  void enqueue(dynamic data, {int statusCode = 200}) {
    responses.add(_FakeResponse(data, statusCode: statusCode));
  }

  void enqueueError(int statusCode) {
    responses.add(_FakeResponse(null, statusCode: statusCode, isError: true));
  }

  void enqueueConnectionError({String? message}) {
    responses.add(_FakeResponse(
      message ?? 'Connection failed',
      statusCode: 0,
      isError: true,
    ));
  }

  void enqueueTimeout() {
    responses.add(_FakeResponse(
      null,
      statusCode: 0,
      isError: true,
      errorType: DioExceptionType.connectionTimeout,
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
          type: fake.errorType ?? DioExceptionType.connectionError,
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

// ─── JSON helpers ────────────────────────────────────────

Map<String, dynamic> _gameJson({
  required int id,
  String title = 'Test Game',
  int consoleId = 1,
  int numAchievements = 10,
  int points = 100,
  String? imageIcon,
  List<String>? hashes,
}) =>
    {
      'ID': id,
      'Title': title,
      'ConsoleID': consoleId,
      'NumAchievements': numAchievements,
      'Points': points,
      if (imageIcon != null) 'ImageIcon': imageIcon,
      if (hashes != null) 'Hashes': hashes,
    };

Map<String, dynamic> _hashEntryJson({
  String md5 = 'abc123',
  String? name,
  List<String>? labels,
}) =>
    {
      'MD5': md5,
      if (name != null) 'Name': name,
      if (labels != null) 'Labels': labels,
    };

Map<String, dynamic> _achievementJson({
  required int id,
  String title = 'Beat Level 1',
  int points = 5,
  int displayOrder = 0,
  String? dateEarned,
}) =>
    {
      'ID': id,
      'Title': title,
      'Points': points,
      'DisplayOrder': displayOrder,
      if (dateEarned != null) 'DateEarned': dateEarned,
    };

// ─── Tests ───────────────────────────────────────────────

void main() {
  late _FakeDio fakeDio;
  late RetroAchievementsService service;

  setUp(() {
    fakeDio = _FakeDio();
    service = RetroAchievementsService(dio: fakeDio);
  });

  // ── fetchGameList ───────────────────────────────────────

  group('fetchGameList', () {
    test('parses game list response', () async {
      fakeDio.enqueue([
        _gameJson(id: 1, title: 'Super Mario World', consoleId: 3),
        _gameJson(id: 2, title: 'Zelda', consoleId: 3, points: 500),
      ]);

      final games =
          await service.fetchGameList(3, apiKey: 'key123');

      expect(games, hasLength(2));
      expect(games[0].raGameId, 1);
      expect(games[0].title, 'Super Mario World');
      expect(games[0].consoleId, 3);
      expect(games[1].points, 500);
    });

    test('sends correct query parameters', () async {
      fakeDio.enqueue([]);

      await service.fetchGameList(7, apiKey: 'mykey',
          hasAchievementsOnly: false);

      expect(fakeDio.requests.single.queryParameters, {
        'y': 'mykey',
        'i': 7,
        'f': 0,
        'h': 1,
      });
    });

    test('returns empty list for non-list response', () async {
      fakeDio.enqueue({'error': 'not a list'});

      final games = await service.fetchGameList(1, apiKey: 'k');

      expect(games, isEmpty);
    });

    test('caps results at pagination limit', () async {
      final bigList = List.generate(
        25000,
        (i) => _gameJson(id: i, consoleId: 1),
      );
      fakeDio.enqueue(bigList);

      final games = await service.fetchGameList(1, apiKey: 'k');

      expect(games, hasLength(20000));
    });

    test('throws user-friendly error on 401', () async {
      fakeDio.enqueueError(401);

      expect(
        () => service.fetchGameList(1, apiKey: 'bad'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Invalid API key'),
        )),
      );
    });

    test('throws user-friendly error on 403', () async {
      fakeDio.enqueueError(403);

      expect(
        () => service.fetchGameList(1, apiKey: 'revoked'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Access denied'),
        )),
      );
    });

    test('throws user-friendly error on 500', () async {
      fakeDio.enqueueError(500);

      expect(
        () => service.fetchGameList(1, apiKey: 'k'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Server error'),
        )),
      );
    });

    test('throws user-friendly error on connection error', () async {
      fakeDio.enqueueConnectionError();

      expect(
        () => service.fetchGameList(1, apiKey: 'k'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Connection error'),
        )),
      );
    });

    test('throws user-friendly error on timeout', () async {
      fakeDio.enqueueTimeout();

      expect(
        () => service.fetchGameList(1, apiKey: 'k'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('timed out'),
        )),
      );
    });
  });

  // ── fetchGameHashes ─────────────────────────────────────

  group('fetchGameHashes', () {
    test('parses hash entries from Results array', () async {
      fakeDio.enqueue({
        'Results': [
          _hashEntryJson(md5: 'aaa111', name: 'ROM v1.0'),
          _hashEntryJson(md5: 'bbb222', labels: ['nointro']),
        ],
      });

      final hashes = await service.fetchGameHashes(42, apiKey: 'k');

      expect(hashes, hasLength(2));
      expect(hashes[0].md5, 'aaa111');
      expect(hashes[0].name, 'ROM v1.0');
      expect(hashes[1].labels, ['nointro']);
    });

    test('returns empty list when Results is missing', () async {
      fakeDio.enqueue({'Something': 'else'});

      final hashes = await service.fetchGameHashes(1, apiKey: 'k');

      expect(hashes, isEmpty);
    });

    test('returns empty list for non-map response', () async {
      fakeDio.enqueue('not a map');

      final hashes = await service.fetchGameHashes(1, apiKey: 'k');

      expect(hashes, isEmpty);
    });

    test('sends correct endpoint and parameters', () async {
      fakeDio.enqueue({'Results': []});

      await service.fetchGameHashes(99, apiKey: 'testkey');

      final req = fakeDio.requests.single;
      expect(req.url, contains('API_GetGameHashes.php'));
      expect(req.queryParameters!['i'], 99);
      expect(req.queryParameters!['y'], 'testkey');
    });
  });

  // ── fetchAchievements ───────────────────────────────────

  group('fetchAchievements', () {
    test('parses achievements from map-keyed response', () async {
      fakeDio.enqueue({
        'Title': 'Super Mario World',
        'ImageIcon': '/Images/icon.png',
        'Achievements': {
          '100': _achievementJson(id: 100, points: 10, displayOrder: 2),
          '101': _achievementJson(id: 101, points: 25, displayOrder: 1),
        },
      });

      final progress = await service.fetchAchievements(5, apiKey: 'k');

      expect(progress.raGameId, 5);
      expect(progress.title, 'Super Mario World');
      expect(progress.imageIcon, '/Images/icon.png');
      expect(progress.achievements, hasLength(2));
      // Sorted by displayOrder
      expect(progress.achievements[0].id, 101);
      expect(progress.achievements[1].id, 100);
      expect(progress.points, 35); // 10 + 25
    });

    test('parses achievements from list response', () async {
      fakeDio.enqueue({
        'Title': 'Zelda',
        'Achievements': [
          _achievementJson(id: 1, points: 5),
          _achievementJson(id: 2, points: 10),
        ],
      });

      final progress = await service.fetchAchievements(3, apiKey: 'k');

      expect(progress.achievements, hasLength(2));
      expect(progress.points, 15);
    });

    test('returns empty progress for non-map response', () async {
      fakeDio.enqueue('not a map');

      final progress = await service.fetchAchievements(1, apiKey: 'k');

      expect(progress.raGameId, 1);
      expect(progress.title, '');
      expect(progress.achievements, isEmpty);
    });

    test('handles null achievements field', () async {
      fakeDio.enqueue({
        'Title': 'Game',
        'Achievements': null,
      });

      final progress = await service.fetchAchievements(1, apiKey: 'k');

      expect(progress.achievements, isEmpty);
      expect(progress.points, 0);
    });

    test('handles missing title gracefully', () async {
      fakeDio.enqueue({
        'Achievements': {},
      });

      final progress = await service.fetchAchievements(1, apiKey: 'k');

      expect(progress.title, '');
    });
  });

  // ── fetchUserProgress ───────────────────────────────────

  group('fetchUserProgress', () {
    test('parses user progress with earned achievements', () async {
      fakeDio.enqueue({
        'Title': 'Mega Man X',
        'ImageIcon': '/Images/mm.png',
        'Achievements': {
          '1': _achievementJson(
            id: 1,
            points: 10,
            dateEarned: '2024-01-15 12:00:00',
          ),
          '2': _achievementJson(id: 2, points: 20),
        },
      });

      final progress = await service.fetchUserProgress(
        7,
        username: 'player1',
        apiKey: 'k',
      );

      expect(progress.raGameId, 7);
      expect(progress.title, 'Mega Man X');
      expect(progress.achievements, hasLength(2));
      expect(progress.earnedCount, 1);
      expect(progress.earnedPoints, 10);
    });

    test('sends correct endpoint and parameters', () async {
      fakeDio.enqueue({
        'Title': 'Test',
        'Achievements': {},
      });

      await service.fetchUserProgress(42,
          username: 'user1', apiKey: 'key1');

      final req = fakeDio.requests.single;
      expect(req.url, contains('API_GetGameInfoAndUserProgress.php'));
      expect(req.queryParameters!['u'], 'user1');
      expect(req.queryParameters!['g'], 42);
    });
  });

  // ── lookupGameByHash ────────────────────────────────────

  group('lookupGameByHash', () {
    test('returns game ID when found', () async {
      fakeDio.enqueue({'GameID': 42});

      final result =
          await service.lookupGameByHash('abc123md5', apiKey: 'k');

      expect(result, 42);
    });

    test('returns null when game ID is 0', () async {
      fakeDio.enqueue({'GameID': 0});

      final result =
          await service.lookupGameByHash('unknown', apiKey: 'k');

      expect(result, isNull);
    });

    test('returns null for non-map response', () async {
      fakeDio.enqueue('plain text');

      final result =
          await service.lookupGameByHash('hash', apiKey: 'k');

      expect(result, isNull);
    });

    test('returns null on connection error instead of throwing', () async {
      fakeDio.enqueueConnectionError();

      final result =
          await service.lookupGameByHash('hash', apiKey: 'k');

      expect(result, isNull);
    });

    test('sends correct endpoint and parameters', () async {
      fakeDio.enqueue({'GameID': 1});

      await service.lookupGameByHash('deadbeef', apiKey: 'mykey');

      final req = fakeDio.requests.single;
      expect(req.url, contains('dorequest.php'));
      expect(req.queryParameters!['r'], 'gameid');
      expect(req.queryParameters!['m'], 'deadbeef');
    });
  });

  // ── testConnection ──────────────────────────────────────

  group('testConnection', () {
    test('returns ok when API returns non-empty list', () async {
      fakeDio.enqueue([
        {'ID': 1, 'Name': 'SNES'},
      ]);

      final result = await service.testConnection(
        username: 'user',
        apiKey: 'key',
      );

      expect(result.success, isTrue);
      expect(result.error, isNull);
    });

    test('returns failed for empty list', () async {
      fakeDio.enqueue([]);

      final result = await service.testConnection(
        username: 'user',
        apiKey: 'key',
      );

      expect(result.success, isFalse);
      expect(result.error, contains('Unexpected'));
    });

    test('returns failed for empty username', () async {
      final result = await service.testConnection(
        username: '',
        apiKey: 'key',
      );

      expect(result.success, isFalse);
      expect(result.error, contains('required'));
      expect(fakeDio.requests, isEmpty);
    });

    test('returns failed for empty api key', () async {
      final result = await service.testConnection(
        username: 'user',
        apiKey: '',
      );

      expect(result.success, isFalse);
      expect(result.error, contains('required'));
    });

    test('returns failed with user-friendly error on 401', () async {
      fakeDio.enqueueError(401);

      final result = await service.testConnection(
        username: 'user',
        apiKey: 'bad',
      );

      expect(result.success, isFalse);
      expect(result.error, contains('Invalid API key'));
    });

    test('returns failed on connection error', () async {
      fakeDio.enqueueConnectionError();

      final result = await service.testConnection(
        username: 'user',
        apiKey: 'key',
      );

      expect(result.success, isFalse);
      expect(result.error, contains('Connection error'));
    });
  });

  // ── static helpers ──────────────────────────────────────

  group('static helpers', () {
    test('badgeUrl returns correct URL', () {
      expect(
        RetroAchievementsService.badgeUrl('12345'),
        'https://media.retroachievements.org/Badge/12345.png',
      );
    });

    test('badgeLockedUrl returns locked badge URL', () {
      expect(
        RetroAchievementsService.badgeLockedUrl('12345'),
        'https://media.retroachievements.org/Badge/12345_lock.png',
      );
    });

    test('gameIconUrl returns correct URL', () {
      expect(
        RetroAchievementsService.gameIconUrl('/Images/042069.png'),
        'https://retroachievements.org/Images/042069.png',
      );
    });
  });

  // ── rate limiter (429 handling) ─────────────────────────

  group('rate limiter', () {
    test('serializes requests (second call waits for first)', () async {
      fakeDio.enqueue([_gameJson(id: 1, consoleId: 1)]);
      fakeDio.enqueue([_gameJson(id: 2, consoleId: 1)]);

      final results = await Future.wait([
        service.fetchGameList(1, apiKey: 'k'),
        service.fetchGameList(1, apiKey: 'k'),
      ]);

      expect(results[0], hasLength(1));
      expect(results[1], hasLength(1));
      expect(fakeDio.requests, hasLength(2));
    });

    test('errors produce single request only', () async {
      fakeDio.enqueueError(500);

      await expectLater(
        () => service.fetchGameList(1, apiKey: 'k'),
        throwsA(isA<Exception>()),
      );
      expect(fakeDio.requests, hasLength(1));
    });
  });
}
