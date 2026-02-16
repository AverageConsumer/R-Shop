import 'dart:async';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class FailedUrlsCache {
  static final FailedUrlsCache _instance = FailedUrlsCache._internal();
  static FailedUrlsCache get instance => _instance;
  FailedUrlsCache._internal();

  final Set<String> _failedUrls = {};

  bool hasFailed(String url) => _failedUrls.contains(url);

  void markFailed(String url) {
    _failedUrls.add(url);
  }

  void clear() {
    _failedUrls.clear();
  }
}

class GameCoverCacheManager {
  static const key = 'gameCoverCache';

  static CacheManager? _instance;

  static CacheManager get instance {
    _instance ??= CacheManager(
      Config(
        key,
        stalePeriod: const Duration(days: 30),
        maxNrOfCacheObjects: 5000,
        repo: JsonCacheInfoRepository(databaseName: key),
        fileService: RateLimitedFileService(),
      ),
    );
    return _instance!;
  }
}



class RateLimitedFileService extends FileService {
  final HttpFileService _httpFileService = HttpFileService();
  static const int _maxConcurrent = 6;
  static const Duration _requestDelay = Duration(milliseconds: 50);
  static final Set<String> _rateLimitedHosts = {};
  static int _activeRequests = 0;
  static final List<Completer<void>> _queue = [];

  @override
  Future<FileServiceResponse> get(String url,
      {Map<String, String>? headers}) async {
    if (_activeRequests >= _maxConcurrent) {
      final completer = Completer<void>();
      _queue.add(completer);
      await completer.future;
    }

    _activeRequests++;

    try {
      final uri = Uri.parse(url);
      final isRateLimited = _rateLimitedHosts.contains(uri.host);

      if (isRateLimited) {
        await Future.delayed(const Duration(seconds: 2));
      } else {
        await Future.delayed(_requestDelay);
      }

      final response = await _httpFileService.get(url, headers: headers);

      if (response.statusCode == 429) {
        _rateLimitedHosts.add(uri.host);
        throw HttpExceptionWithStatus(
          429,
          'Rate limited',
          uri: uri,
        );
      }

      _rateLimitedHosts.remove(uri.host);
      return response;
    } finally {
      _activeRequests--;
      if (_queue.isNotEmpty) {
        _queue.removeAt(0).complete();
      }
    }
  }
}
