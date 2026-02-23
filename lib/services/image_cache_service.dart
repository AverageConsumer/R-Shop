import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Checks file magic bytes for PNG/JPEG/GIF/WebP headers.
/// Returns false for HTML error pages, truncated downloads, or unknown formats.
bool isValidImageFile(File file) {
  try {
    final raf = file.openSync();
    try {
      if (raf.lengthSync() < 12) return false;
      final bytes = raf.readSync(12);
      // PNG: 89 50 4E 47
      if (bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4E &&
          bytes[3] == 0x47) {
        return true;
      }
      // JPEG: FF D8 FF
      if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
        return true;
      }
      // GIF: 47 49 46
      if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) {
        return true;
      }
      // WebP: RIFF....WEBP
      if (bytes[0] == 0x52 &&
          bytes[1] == 0x49 &&
          bytes[2] == 0x46 &&
          bytes[3] == 0x46 &&
          bytes[8] == 0x57 &&
          bytes[9] == 0x45 &&
          bytes[10] == 0x42 &&
          bytes[11] == 0x50) {
        return true;
      }
      return false;
    } finally {
      raf.closeSync();
    }
  } catch (e) {
    debugPrint('isValidImageFile: header check failed: $e');
    return false;
  }
}

class FailedUrlsCache {
  static final FailedUrlsCache _instance = FailedUrlsCache._internal();
  static FailedUrlsCache get instance => _instance;
  FailedUrlsCache._internal();

  static const Duration _ttl = Duration(minutes: 5);
  final Map<String, DateTime> _failedUrls = {};

  bool hasFailed(String url) {
    final failedAt = _failedUrls[url];
    if (failedAt == null) return false;
    if (DateTime.now().difference(failedAt) > _ttl) {
      _failedUrls.remove(url);
      return false;
    }
    return true;
  }

  void markFailed(String url) {
    _failedUrls[url] = DateTime.now();
    // Proactively prune expired entries when cache grows large
    if (_failedUrls.length > 500) {
      _pruneExpired();
    }
  }

  void _pruneExpired() {
    final now = DateTime.now();
    _failedUrls.removeWhere((_, failedAt) => now.difference(failedAt) > _ttl);
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



class _QueueEntry {
  final Completer<void> completer;
  final String url;
  bool cancelled = false;
  _QueueEntry(this.completer, this.url);
}

/// Rate-limited HTTP file service for cache downloads.
///
/// NOTE: The static mutable fields (_activeRequests, _queue, _rateLimitedHosts)
/// are safe because Dart's event loop is single-threaded — async code only
/// interleaves at `await` points. Do NOT access these from a separate Isolate.
class RateLimitedFileService extends FileService {
  final HttpFileService _httpFileService = HttpFileService();
  static const int _maxConcurrent = 6;
  static const int _maxQueueSize = 200;
  static const Duration _requestDelay = Duration(milliseconds: 50);
  static const Duration _rateLimitTtl = Duration(minutes: 10);
  static final Map<String, DateTime> _rateLimitedHosts = {};
  static int _activeRequests = 0;
  static final List<_QueueEntry> _queue = [];

  static bool _isHostRateLimited(String host) {
    final limitedAt = _rateLimitedHosts[host];
    if (limitedAt == null) return false;
    if (DateTime.now().difference(limitedAt) > _rateLimitTtl) {
      _rateLimitedHosts.remove(host);
      return false;
    }
    return true;
  }

  @override
  int get concurrentFetches => 50;

  static void cancelPending(String url) {
    for (final entry in _queue) {
      if (entry.url == url && !entry.cancelled) {
        entry.cancelled = true;
        if (!entry.completer.isCompleted) {
          entry.completer.complete();
        }
      }
    }
  }

  @override
  Future<FileServiceResponse> get(String url,
      {Map<String, String>? headers}) async {
    if (_activeRequests >= _maxConcurrent) {
      // Evict oldest entries when queue is full
      while (_queue.length >= _maxQueueSize) {
        final oldest = _queue.removeAt(0);
        if (!oldest.cancelled && !oldest.completer.isCompleted) {
          oldest.cancelled = true;
          oldest.completer.complete();
        }
      }

      final entry = _QueueEntry(Completer<void>(), url);
      _queue.add(entry);
      await entry.completer.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          entry.cancelled = true;
        },
      );
      if (entry.cancelled) {
        throw HttpExceptionWithStatus(499, 'Cancelled', uri: Uri.parse(url));
      }
    }

    _activeRequests++;

    try {
      final uri = Uri.parse(url);
      final isRateLimited = _isHostRateLimited(uri.host);

      if (isRateLimited) {
        await Future.delayed(const Duration(seconds: 2));
      } else {
        await Future.delayed(_requestDelay);
      }

      final response = await _httpFileService.get(url, headers: headers);

      if (response.statusCode == 429) {
        _rateLimitedHosts[uri.host] = DateTime.now();
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
      _releaseNext();
    }
  }

  static void _releaseNext() {
    while (_queue.isNotEmpty) {
      final next = _queue.removeLast();
      if (next.cancelled) continue;
      if (!next.completer.isCompleted) {
        next.completer.complete();
      }
      return;
    }
  }
}
