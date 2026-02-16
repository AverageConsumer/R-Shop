import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../services/image_cache_service.dart';

class DynamicBackground extends StatelessWidget {
  final ValueNotifier<String?> backgroundNotifier;
  final Color accentColor;

  const DynamicBackground({
    super.key,
    required this.backgroundNotifier,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ValueListenableBuilder<String?>(
        valueListenable: backgroundNotifier,
        builder: (context, backgroundImageUrl, child) {
          if (backgroundImageUrl != null && backgroundImageUrl.isNotEmpty) {
            return Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: backgroundImageUrl,
                  key: ValueKey(backgroundImageUrl),
                  cacheManager: GameCoverCacheManager.instance,
                  fit: BoxFit.cover,
                  memCacheWidth: 128,
                  fadeInDuration: Duration.zero,
                  fadeOutDuration: Duration.zero,
                  placeholder: (_, __) => _buildStaticGradient(),
                  errorWidget: (_, __, ___) => _buildStaticGradient(),
                ),
                BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                  child: Container(color: Colors.transparent),
                ),
              ],
            );
          }
          return _buildStaticGradient();
        },
      ),
    );
  }

  Widget _buildStaticGradient() {
    return Container(
      key: const ValueKey('static_gradient'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor.withValues(alpha: 0.3),
            accentColor.withValues(alpha: 0.1),
            const Color(0xFF0A0A0A),
            Colors.black,
          ],
          stops: const [0.0, 0.2, 0.5, 1.0],
        ),
      ),
    );
  }
}
