import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../services/image_cache_service.dart';

class SmartCoverImage extends StatefulWidget {
  final List<String> urls;
  final String? cachedUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final void Function(String)? onUrlFound;

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
  });

  @override
  State<SmartCoverImage> createState() => _SmartCoverImageState();
}

class _SmartCoverImageState extends State<SmartCoverImage> {
  int _currentIndex = 0;
  bool _allFailed = false;
  bool _loadedSuccessfully = false;
  bool _usedCache = false;
  int _retryCount = 0;
  Timer? _retryTimer;

  @override
  void initState() {
    super.initState();
    _usedCache = widget.cachedUrl != null &&
        widget.cachedUrl!.isNotEmpty &&
        !FailedUrlsCache.instance.hasFailed(widget.cachedUrl!);
    _skipFailedUrls();
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(SmartCoverImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.urls != widget.urls ||
        oldWidget.cachedUrl != widget.cachedUrl) {
      _retryTimer?.cancel();
      _currentIndex = 0;
      _allFailed = false;
      _loadedSuccessfully = false;
      _retryCount = 0;
      _usedCache = widget.cachedUrl != null &&
          widget.cachedUrl!.isNotEmpty &&
          !FailedUrlsCache.instance.hasFailed(widget.cachedUrl!);
      _skipFailedUrls();
    }
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

  void _onSuccess(String url) {
    if (!_loadedSuccessfully && !_usedCache) {
      _loadedSuccessfully = true;
      widget.onUrlFound?.call(url);
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
    } else if (is404) {
      FailedUrlsCache.instance.markFailed(url);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_currentIndex < widget.urls.length - 1) {
        setState(() {
          _currentIndex++;
          _retryCount = 0;
          _skipFailedUrls();
        });
      } else {
        setState(() {
          _allFailed = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_usedCache) {
      return CachedNetworkImage(
        imageUrl: widget.cachedUrl!,
        cacheManager: GameCoverCacheManager.instance,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        memCacheWidth: 300,
        fadeInDuration: const Duration(milliseconds: 150),
        fadeOutDuration: Duration.zero,
        placeholder: (context, url) =>
            widget.placeholder ?? _buildDefaultPlaceholder(),
        errorWidget: (context, url, error) {

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
          return widget.placeholder ?? _buildDefaultPlaceholder();
        },
        imageBuilder: (context, imageProvider) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _onSuccess(widget.cachedUrl!);
          });
          return Image(
            image: imageProvider,
            fit: widget.fit,
            width: widget.width,
            height: widget.height,
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
      memCacheWidth: 300,
      fadeInDuration: const Duration(milliseconds: 150),
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
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _onSuccess(url);
        });
        return Image(
          image: imageProvider,
          fit: widget.fit,
          width: widget.width,
          height: widget.height,
        );
      },
    );
  }

  Widget _buildDefaultPlaceholder() {
    return Container(
      color: const Color(0xFF2A2A2A),
      child: const Center(
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.redAccent,
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultError() {
    return Container(
      color: const Color(0xFF2A2A2A),
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
