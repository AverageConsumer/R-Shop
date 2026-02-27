import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/ra_models.dart';
import '../utils/network_constants.dart';
import 'source_provider.dart';

class RetroAchievementsService {
  static const _baseUrl = 'https://retroachievements.org/API/';
  static const _connectUrl = 'https://retroachievements.org/dorequest.php';
  static const _maxPaginationItems = 20000;
  final Dio _dio;
  final _rateLimiter = _RateLimiter();

  RetroAchievementsService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: NetworkTimeouts.apiConnect,
              receiveTimeout: const Duration(seconds: 60),
            ));

  // ---------------------------------------------------------------------------
  // API endpoints
  // ---------------------------------------------------------------------------

  /// Fetches all games with achievement support for a system.
  /// Set [hasAchievementsOnly] to true to filter to games with achievements.
  Future<List<RaGame>> fetchGameList(
    int consoleId, {
    required String apiKey,
    bool hasAchievementsOnly = true,
  }) async {
    return _rateLimiter.throttle(() async {
      try {
        final response = await _dio.get<dynamic>(
          '${_baseUrl}API_GetGameList.php',
          queryParameters: {
            'y': apiKey,
            'i': consoleId,
            'f': hasAchievementsOnly ? 1 : 0,
            'h': 1,
          },
        );

        final data = response.data;
        if (data is! List) return [];

        if (data.length > _maxPaginationItems) {
          debugPrint(
            'RetroAchievements: console $consoleId returned ${data.length} games '
            '(capped at $_maxPaginationItems)',
          );
        }

        return data
            .take(_maxPaginationItems)
            .whereType<Map<String, dynamic>>()
            .map(RaGame.fromJson)
            .toList();
      } on DioException catch (e) {
        throw Exception(_getUserFriendlyError(e));
      }
    });
  }

  /// Fetches hash details (including No-Intro ROM filenames) for a game.
  Future<List<RaHashEntry>> fetchGameHashes(
    int gameId, {
    required String apiKey,
  }) async {
    return _rateLimiter.throttle(() async {
      try {
        final response = await _dio.get<dynamic>(
          '${_baseUrl}API_GetGameHashes.php',
          queryParameters: {
            'y': apiKey,
            'i': gameId,
          },
        );

        final data = response.data;
        if (data is! Map<String, dynamic>) return [];

        final results = data['Results'];
        if (results is! List) return [];

        return results
            .whereType<Map<String, dynamic>>()
            .map(RaHashEntry.fromJson)
            .toList();
      } on DioException catch (e) {
        throw Exception(_getUserFriendlyError(e));
      }
    });
  }

  /// Fetches detailed achievement list for a game.
  Future<RaGameProgress> fetchAchievements(
    int gameId, {
    required String apiKey,
  }) async {
    return _rateLimiter.throttle(() async {
      try {
        final response = await _dio.get<dynamic>(
          '${_baseUrl}API_GetGameExtended.php',
          queryParameters: {
            'y': apiKey,
            'i': gameId,
          },
        );

        final data = response.data;
        if (data is! Map<String, dynamic>) {
          return RaGameProgress(raGameId: gameId, title: '');
        }

        final achievements = _parseAchievements(data['Achievements']);
        return RaGameProgress(
          raGameId: gameId,
          title: data['Title'] as String? ?? '',
          imageIcon: data['ImageIcon'] as String?,
          numAchievements: data['NumDistinctPlayers'] != null
              ? achievements.length
              : data['NumAchievements'] as int? ?? achievements.length,
          points: achievements.fold(0, (sum, a) => sum + a.points),
          achievements: achievements,
        );
      } on DioException catch (e) {
        throw Exception(_getUserFriendlyError(e));
      }
    });
  }

  /// Fetches user's progress on a specific game (earned/missing achievements).
  Future<RaGameProgress> fetchUserProgress(
    int gameId, {
    required String username,
    required String apiKey,
  }) async {
    return _rateLimiter.throttle(() async {
      try {
        final response = await _dio.get<dynamic>(
          '${_baseUrl}API_GetGameInfoAndUserProgress.php',
          queryParameters: {
            'y': apiKey,
            'u': username,
            'g': gameId,
          },
        );

        final data = response.data;
        if (data is! Map<String, dynamic>) {
          return RaGameProgress(raGameId: gameId, title: '');
        }

        final achievements = _parseAchievements(data['Achievements']);
        return RaGameProgress(
          raGameId: gameId,
          title: data['Title'] as String? ?? '',
          imageIcon: data['ImageIcon'] as String?,
          numAchievements: achievements.length,
          points: achievements.fold(0, (sum, a) => sum + a.points),
          achievements: achievements,
        );
      } on DioException catch (e) {
        throw Exception(_getUserFriendlyError(e));
      }
    });
  }

  /// Looks up a game ID by ROM hash (MD5).
  /// Returns null if the hash is not recognized.
  Future<int?> lookupGameByHash(
    String md5Hash, {
    required String apiKey,
  }) async {
    return _rateLimiter.throttle(() async {
      try {
        final response = await _dio.get<dynamic>(
          _connectUrl,
          queryParameters: {
            'r': 'gameid',
            'm': md5Hash,
          },
        );

        final data = response.data;
        if (data is Map<String, dynamic>) {
          final gameId = data['GameID'];
          if (gameId is int && gameId > 0) return gameId;
        }
        return null;
      } on DioException catch (e) {
        debugPrint('RetroAchievements: hash lookup failed: ${e.message}');
        return null;
      }
    });
  }

  /// Tests the connection with the provided credentials.
  Future<SourceConnectionResult> testConnection({
    required String username,
    required String apiKey,
  }) async {
    if (username.isEmpty || apiKey.isEmpty) {
      return SourceConnectionResult.failed(
        'Username and API Key are required',
      );
    }

    return _rateLimiter.throttle(() async {
      try {
        final response = await _dio.get<dynamic>(
          '${_baseUrl}API_GetConsoleIDs.php',
          queryParameters: {
            'y': apiKey,
            'a': 1,
            'g': 1,
          },
        );

        final data = response.data;
        if (data is List && data.isNotEmpty) {
          return SourceConnectionResult.ok();
        }
        return SourceConnectionResult.failed('Unexpected response from server');
      } on DioException catch (e) {
        return SourceConnectionResult.failed(_getUserFriendlyError(e));
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Static helpers
  // ---------------------------------------------------------------------------

  /// Builds the URL for an achievement badge image.
  static String badgeUrl(String badgeName) =>
      'https://media.retroachievements.org/Badge/$badgeName.png';

  /// Builds the URL for an achievement badge image (locked state).
  static String badgeLockedUrl(String badgeName) =>
      'https://media.retroachievements.org/Badge/${badgeName}_lock.png';

  /// Builds the URL for a game icon.
  static String gameIconUrl(String imageIcon) =>
      'https://retroachievements.org$imageIcon';

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  List<RaAchievement> _parseAchievements(dynamic raw) {
    if (raw == null) return [];

    // Achievements can be a Map<String, dynamic> keyed by ID or a List
    Iterable<Map<String, dynamic>> entries;
    if (raw is Map<String, dynamic>) {
      entries = raw.values.whereType<Map<String, dynamic>>();
    } else if (raw is List) {
      entries = raw.whereType<Map<String, dynamic>>();
    } else {
      return [];
    }

    final achievements = entries.map(RaAchievement.fromJson).toList();
    achievements.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    return achievements;
  }

  String _getUserFriendlyError(DioException e) {
    if (e.response != null) {
      final code = e.response!.statusCode ?? 0;
      switch (code) {
        case 401:
          return 'Invalid API key — check your RetroAchievements credentials';
        case 403:
          return 'Access denied — your API key may be expired or revoked';
        case 429:
          return 'Rate limited — please wait a moment and try again';
        case >= 500:
          return 'RetroAchievements server error ($code) — try again later';
      }
    }

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Connection timed out — check your internet connection';
    }

    if (e.type == DioExceptionType.connectionError) {
      return 'Could not reach retroachievements.org — check your connection';
    }

    return 'Connection failed: ${e.message ?? 'unknown error'}';
  }
}

// -----------------------------------------------------------------------------
// Rate limiter — serializes RA API requests with ~2 req/s throttle
// -----------------------------------------------------------------------------

/// Completer-chain mutex (same pattern as ConfigStorageService._AsyncLock).
class _AsyncLock {
  Future<void>? _last;

  Future<T> run<T>(Future<T> Function() action) async {
    final prev = _last;
    final completer = Completer<void>();
    _last = completer.future;
    if (prev != null) await prev;
    try {
      return await action();
    } finally {
      completer.complete();
    }
  }
}

class _RateLimiter {
  static const _minInterval = Duration(milliseconds: 500);
  static const _backoffBase = Duration(seconds: 2);
  static const _maxBackoff = Duration(seconds: 30);

  DateTime _lastRequest = DateTime(0);
  int _consecutiveRateLimits = 0;
  final _lock = _AsyncLock();

  /// Serializes [action] with a minimum interval between requests.
  /// On 429, backs off exponentially and retries once.
  Future<T> throttle<T>(Future<T> Function() action) async {
    return _lock.run(() async {
      await _waitForSlot();
      _lastRequest = DateTime.now();
      try {
        final result = await action();
        _consecutiveRateLimits = 0;
        return result;
      } on DioException catch (e) {
        if (e.response?.statusCode == 429) {
          _consecutiveRateLimits++;
          final backoff = _calculateBackoff();
          debugPrint(
            'RetroAchievements: rate limited, backing off ${backoff.inSeconds}s',
          );
          await Future<void>.delayed(backoff);
          _lastRequest = DateTime.now();
          final result = await action();
          _consecutiveRateLimits = 0;
          return result;
        }
        rethrow;
      }
    });
  }

  Future<void> _waitForSlot() async {
    final elapsed = DateTime.now().difference(_lastRequest);
    final interval =
        _consecutiveRateLimits > 0 ? _calculateBackoff() : _minInterval;
    if (elapsed < interval) {
      await Future<void>.delayed(interval - elapsed);
    }
  }

  Duration _calculateBackoff() {
    final multiplier = 1 << _consecutiveRateLimits.clamp(0, 5);
    final backoff = _backoffBase * multiplier;
    return backoff > _maxBackoff ? _maxBackoff : backoff;
  }
}
