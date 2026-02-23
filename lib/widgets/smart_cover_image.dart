import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../services/image_cache_service.dart';
import '../services/thumbnail_service.dart';

Uint8List? _reencodeAsJpeg(Uint8List input) {
  try {
    final decoded = img.decodeImage(input);
    if (decoded == null) return null;
    return Uint8List.fromList(img.encodeJpg(decoded, quality: 90));
  } catch (e) {
    debugPrint('SmartCoverImage: JPEG re-encode failed: $e');
    return null;
  }
}

class SmartCoverImage extends StatefulWidget {
  final List<String> urls;
  final String? cachedUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final void Function(String)? onUrlFound;
  final bool hasThumbnail;
  final void Function(String url)? onThumbnailNeeded;
  final int? memCacheWidth;
  final ValueNotifier<bool>? scrollSuppression;

  const SmartCoverImage({
    super.key,
    required this.urls,
    this.cachedUrl,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.placeholder,
    this.errorWidget,
    this.onUrlFound,
    this.hasThumbnail = false,
    this.onThumbnailNeeded,
    this.memCacheWidth,
    this.scrollSuppression,
  });

  @override
  State<SmartCoverImage> createState() => _SmartCoverImageState();
}

class _SmartCoverImageState extends State<SmartCoverImage> {
  int _currentIndex = 0;
  bool _allFailed = false;
  bool _loadedSuccessfully = false;
  bool _usedCache = false;
  bool _thumbnailRequested = false;
  bool _validatingCache = false;
  int _retryCount = 0;
  Timer? _retryTimer;
  Uint8List? _dartDecodedBytes;
  bool _dartDecodeInProgress = false;
  bool _suppressed = false;
  VoidCallback? _suppressionListener;
  File? _resolvedThumbnail;

  @override
  void initState() {
    super.initState();
    _usedCache = widget.cachedUrl != null &&
        widget.cachedUrl!.isNotEmpty &&
        !FailedUrlsCache.instance.hasFailed(widget.cachedUrl!);
    if (_usedCache) _preValidateCachedUrl();
    _skipFailedUrls();
    _resolveThumbnail();
    _setupSuppressionListener();
  }

  void _resolveThumbnail() {
    _resolvedThumbnail = null;
    if (!widget.hasThumbnail || widget.cachedUrl == null) return;
    final thumbPath = ThumbnailService.thumbnailPath(widget.cachedUrl!);
    if (thumbPath == null) return;
    final thumbFile = File(thumbPath);
    if (thumbFile.existsSync() && isValidImageFile(thumbFile)) {
      _resolvedThumbnail = thumbFile;
    } else if (thumbFile.existsSync()) {
      // Bad thumbnail — delete so it gets regenerated
      thumbFile.deleteSync();
    }
  }

  void _setupSuppressionListener() {
    if (widget.scrollSuppression != null) {
      _suppressed = widget.scrollSuppression!.value;
      _suppressionListener = () {
        final nowSuppressed = widget.scrollSuppression!.value;
        if (nowSuppressed != _suppressed) {
          _suppressed = nowSuppressed;
          if (!nowSuppressed && !_loadedSuccessfully && _resolvedThumbnail == null && mounted) {
            setState(() {}); // Unsuppress → trigger load
          }
        }
      };
      widget.scrollSuppression!.addListener(_suppressionListener!);
    }
  }

  void _teardownSuppressionListener() {
    if (_suppressionListener != null && widget.scrollSuppression != null) {
      widget.scrollSuppression!.removeListener(_suppressionListener!);
      _suppressionListener = null;
    }
  }

  @override
  void dispose() {
    _teardownSuppressionListener();
    _cancelPendingLoad();
    _retryTimer?.cancel();
    _dartDecodedBytes = null;
    super.dispose();
  }

  @override
  void didUpdateWidget(SmartCoverImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final urlsChanged = !listEquals(oldWidget.urls, widget.urls);
    final cachedUrlChanged = oldWidget.cachedUrl != widget.cachedUrl;

    if (urlsChanged) {
      // Cancel pending load for old widget's URL before resetting
      _cancelPendingLoad(old: oldWidget);
      // Different game — full reset
      _retryTimer?.cancel();
      _currentIndex = 0;
      _allFailed = false;
      _loadedSuccessfully = false;
      _thumbnailRequested = false;
      _retryCount = 0;
      _dartDecodedBytes = null;
      _dartDecodeInProgress = false;
      _usedCache = widget.cachedUrl != null &&
          widget.cachedUrl!.isNotEmpty &&
          !FailedUrlsCache.instance.hasFailed(widget.cachedUrl!);
      _skipFailedUrls();
      _resolveThumbnail();
    } else if (cachedUrlChanged) {
      // Same image, just persisted (null→url) — only update cache flag
      _usedCache = widget.cachedUrl != null &&
          widget.cachedUrl!.isNotEmpty &&
          !FailedUrlsCache.instance.hasFailed(widget.cachedUrl!);
    }

    // Thumbnail was generated (hasThumbnail false→true)
    if (!oldWidget.hasThumbnail && widget.hasThumbnail) {
      _resolveThumbnail();
    }
  }

  void _cancelPendingLoad({SmartCoverImage? old}) {
    if (_loadedSuccessfully) return;
    final w = old ?? widget;
    final url = _usedCache
        ? w.cachedUrl
        : (_currentIndex < w.urls.length ? w.urls[_currentIndex] : null);
    if (url != null) {
      RateLimitedFileService.cancelPending(url);
    }
  }

  Future<void> _preValidateCachedUrl() async {
    _validatingCache = true;
    try {
      final info = await GameCoverCacheManager.instance
          .getFileFromCache(widget.cachedUrl!);
      if (info != null && !isValidImageFile(info.file)) {
        await GameCoverCacheManager.instance.removeFile(widget.cachedUrl!);
        FailedUrlsCache.instance.markFailed(widget.cachedUrl!);
        if (mounted) {
          setState(() {
            _usedCache = false;
            _validatingCache = false;
            if (widget.urls.isEmpty) {
              _allFailed = true;
            } else {
              _skipFailedUrls();
            }
          });
          return;
        }
      }
    } catch (e) {
      debugPrint('SmartCoverImage: cache validation failed: $e');
    }
    if (mounted) setState(() => _validatingCache = false);
  }

  void _skipFailedUrls() {
    while (_currentIndex < widget.urls.length &&
        FailedUrlsCache.instance.hasFailed(widget.urls[_currentIndex])) {
      _currentIndex++;
    }
    if (_currentIndex >= widget.urls.length) {
      _allFailed = true;
    }
  }

  bool get _needsSuccessCallback {
    if (!_loadedSuccessfully) return true;
    return !widget.hasThumbnail &&
        !_thumbnailRequested &&
        widget.onThumbnailNeeded != null;
  }

  void _onSuccess(String url) {
    if (!_loadedSuccessfully) {
      _loadedSuccessfully = true;
      if (!_usedCache) {
        widget.onUrlFound?.call(url);
      }
    }
    if (!widget.hasThumbnail && !_thumbnailRequested) {
      _thumbnailRequested = true;
      widget.onThumbnailNeeded?.call(url);
    }
  }

  void _advanceToNextUrl() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_currentIndex < widget.urls.length - 1) {
        setState(() {
          _currentIndex++;
          _retryCount = 0;
          _skipFailedUrls();
        });
      } else {
        setState(() => _allFailed = true);
      }
    });
  }

  Future<void> _attemptDartDecode(String url, {required VoidCallback onFail}) async {
    if (_dartDecodeInProgress) return;
    _dartDecodeInProgress = true;
    try {
      final info = await GameCoverCacheManager.instance.getFileFromCache(url);
      if (info == null || !mounted) { onFail(); return; }

      final sourceBytes = await info.file.readAsBytes();
      final jpegBytes = await compute(_reencodeAsJpeg, sourceBytes);
      if (!mounted) return;

      if (jpegBytes == null) {
        await GameCoverCacheManager.instance.removeFile(url);
        FailedUrlsCache.instance.markFailed(url);
        onFail();
        return;
      }

      // Replace cache file with valid JPEG
      await GameCoverCacheManager.instance.removeFile(url);
      await GameCoverCacheManager.instance.putFile(url, jpegBytes, fileExtension: 'jpg');

      if (mounted) {
        setState(() => _dartDecodedBytes = jpegBytes);
        _onSuccess(url);
      }
    } catch (e) {
      debugPrint('SmartCoverImage: dart decode failed for $url: $e');
      if (mounted) {
        GameCoverCacheManager.instance.removeFile(url);
        onFail();
      }
    } finally {
      _dartDecodeInProgress = false;
    }
  }

  void _onError(String url, dynamic error) {
    if (!mounted) return;

    final errorMsg = error.toString();
    final isRateLimited =
        errorMsg.contains('429') || errorMsg.contains('Rate limited');
    final is404 = errorMsg.contains('404');

    if (isRateLimited) {
      _retryCount++;
      if (_retryCount <= 3) {
        final delay = Duration(seconds: _retryCount * 2);
        _retryTimer = Timer(delay, () {
          if (mounted) setState(() {});
        });
        return;
      }
      GameCoverCacheManager.instance.removeFile(url);
      _advanceToNextUrl();
      return;
    }

    if (is404) {
      GameCoverCacheManager.instance.removeFile(url);
      FailedUrlsCache.instance.markFailed(url);
      _advanceToNextUrl();
      return;
    }

    // Decode error — attempt Dart fallback (do NOT evict file yet)
    _attemptDartDecode(url, onFail: _advanceToNextUrl);
  }

  @override
  Widget build(BuildContext context) {
    // Tier 1: Local JPEG thumbnail (cached in state — no sync I/O)
    if (_resolvedThumbnail != null) {
      return Image(
        image: FileImage(_resolvedThumbnail!),
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) {
          _resolvedThumbnail = null;
          return _buildNetworkFallback();
        },
      );
    }

    return _buildNetworkFallback();
  }

  // Tier 2: Network fetch via CachedNetworkImage (current pipeline)
  Widget _buildNetworkFallback() {
    if (_dartDecodedBytes != null) {
      return Image.memory(
        _dartDecodedBytes!,
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _dartDecodedBytes = null);
          });
          return widget.errorWidget ?? _buildDefaultError();
        },
      );
    }

    if (_validatingCache) {
      return widget.placeholder ?? _buildDefaultPlaceholder();
    }

    if (_suppressed && !_loadedSuccessfully && !_allFailed) {
      return widget.placeholder ?? _buildDefaultPlaceholder();
    }

    if (_usedCache) {
      return CachedNetworkImage(
        imageUrl: widget.cachedUrl!,
        cacheManager: GameCoverCacheManager.instance,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        memCacheWidth: widget.memCacheWidth,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        placeholder: (context, url) =>
            widget.placeholder ?? _buildDefaultPlaceholder(),
        errorWidget: (context, url, error) {
          final errorMsg = error.toString();
          final is404 = errorMsg.contains('404');
          final isRateLimited =
              errorMsg.contains('429') || errorMsg.contains('Rate limited');

          if (is404 || isRateLimited) {
            FailedUrlsCache.instance.markFailed(url);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _usedCache = false;
                  _allFailed = widget.urls.isEmpty;
                  if (!_allFailed) _skipFailedUrls();
                });
              }
            });
          } else {
            _attemptDartDecode(url, onFail: () {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    _usedCache = false;
                    _allFailed = widget.urls.isEmpty;
                    if (!_allFailed) _skipFailedUrls();
                  });
                }
              });
            });
          }
          return widget.placeholder ?? _buildDefaultPlaceholder();
        },
        imageBuilder: (context, imageProvider) {
          if (_needsSuccessCallback) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _onSuccess(widget.cachedUrl!);
            });
          }
          return Image(
            image: imageProvider,
            fit: widget.fit,
            width: widget.width,
            height: widget.height,
            gaplessPlayback: true,
          );
        },
      );
    }

    if (widget.urls.isEmpty || _allFailed) {
      return widget.errorWidget ?? _buildDefaultError();
    }

    final url = widget.urls[_currentIndex];

    if (FailedUrlsCache.instance.hasFailed(url)) {
      return widget.errorWidget ?? _buildDefaultError();
    }

    return CachedNetworkImage(
      imageUrl: url,
      cacheManager: GameCoverCacheManager.instance,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      memCacheWidth: widget.memCacheWidth,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholder: (context, url) =>
          widget.placeholder ?? _buildDefaultPlaceholder(),
      errorWidget: (context, url, error) {
        _onError(url, error);
        if (_currentIndex < widget.urls.length - 1) {
          return widget.placeholder ?? _buildDefaultPlaceholder();
        }
        return widget.errorWidget ?? _buildDefaultError();
      },
      imageBuilder: (context, imageProvider) {
        if (_needsSuccessCallback) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _onSuccess(url);
          });
        }
        return Image(
          image: imageProvider,
          fit: widget.fit,
          width: widget.width,
          height: widget.height,
          gaplessPlayback: true,
        );
      },
    );
  }

  Widget _buildDefaultPlaceholder() {
    return const _StaticPlaceholder();
  }

  Widget _buildDefaultError() {
    return Container(
      color: const Color(0xFF1E1E1E),
      child: const Center(
        child: Icon(
          Icons.broken_image,
          color: Colors.grey,
          size: 32,
        ),
      ),
    );
  }
}

class _StaticPlaceholder extends StatelessWidget {
  const _StaticPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(color: const Color(0xFF1E1E1E));
  }
}
