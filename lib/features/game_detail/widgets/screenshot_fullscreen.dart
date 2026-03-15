import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/input/input.dart';
import '../../../core/responsive/responsive.dart';

/// Fullscreen screenshot viewer overlay.
/// L/R to browse, B to close, shows image counter.
class ScreenshotFullscreen extends ConsumerStatefulWidget {
  final List<String> screenshots;
  final int initialIndex;
  final Color accentColor;
  final VoidCallback onClose;

  const ScreenshotFullscreen({
    super.key,
    required this.screenshots,
    required this.initialIndex,
    required this.accentColor,
    required this.onClose,
  });

  @override
  ConsumerState<ScreenshotFullscreen> createState() =>
      _ScreenshotFullscreenState();
}

class _ScreenshotFullscreenState extends ConsumerState<ScreenshotFullscreen> {
  late int _currentIndex;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.screenshots.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    if (index < 0 || index >= widget.screenshots.length) return;
    setState(() => _currentIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;

    return OverlayFocusScope(
      priority: OverlayPriority.fullScreen,
      isVisible: true,
      onClose: widget.onClose,
      child: Shortcuts(
        shortcuts: <ShortcutActivator, Intent>{
          const SingleActivator(LogicalKeyboardKey.arrowLeft): const NavigateIntent(GridDirection.left),
          const SingleActivator(LogicalKeyboardKey.arrowRight): const NavigateIntent(GridDirection.right),
          // L1/R1 shoulder buttons
          const SingleActivator(LogicalKeyboardKey.gameButtonLeft1): const NavigateIntent(GridDirection.left),
          const SingleActivator(LogicalKeyboardKey.gameButtonRight1): const NavigateIntent(GridDirection.right),
          const SingleActivator(LogicalKeyboardKey.pageUp): const NavigateIntent(GridDirection.left),
          const SingleActivator(LogicalKeyboardKey.pageDown): const NavigateIntent(GridDirection.right),
          const SingleActivator(LogicalKeyboardKey.escape): const BackIntent(),
          const SingleActivator(LogicalKeyboardKey.gameButtonB): const BackIntent(),
        },
        child: Actions(
          actions: {
            NavigateIntent: CallbackAction<NavigateIntent>(
              onInvoke: (intent) {
                if (intent.direction == GridDirection.left) {
                  _goTo(_currentIndex - 1);
                } else if (intent.direction == GridDirection.right) {
                  _goTo(_currentIndex + 1);
                }
                return null;
              },
            ),
            BackIntent: CallbackAction<BackIntent>(
              onInvoke: (_) {
                widget.onClose();
                return null;
              },
            ),
          },
          child: Focus(
            autofocus: true,
            child: GestureDetector(
              onTap: widget.onClose,
              child: Container(
                color: Colors.black.withValues(alpha: 0.92),
                child: Stack(
                  children: [
                    // PageView for swipe/key navigation
                    PageView.builder(
                      controller: _pageController,
                      itemCount: widget.screenshots.length,
                      onPageChanged: (index) {
                        setState(() => _currentIndex = index);
                      },
                      itemBuilder: (context, index) {
                        return Center(
                          child: GestureDetector(
                            onTap: () {}, // Absorb tap on image
                            child: Padding(
                              padding: EdgeInsets.all(rs.spacing.lg),
                              child: Image.network(
                                widget.screenshots[index],
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Icon(
                                  Icons.broken_image_outlined,
                                  color: Colors.white.withValues(alpha: 0.3),
                                  size: 48,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    // Counter indicator
                    Positioned(
                      bottom: rs.spacing.xl + MediaQuery.of(context).padding.bottom,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: rs.spacing.md,
                            vertical: rs.spacing.sm,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(rs.radius.md),
                            border: Border.all(
                              color: widget.accentColor.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            '${_currentIndex + 1} / ${widget.screenshots.length}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: rs.isSmall ? 12 : 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Close button
                    Positioned(
                      top: MediaQuery.of(context).padding.top + rs.spacing.sm,
                      right: rs.spacing.md,
                      child: GestureDetector(
                        onTap: widget.onClose,
                        child: Container(
                          padding: EdgeInsets.all(rs.spacing.sm),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close,
                            color: Colors.white.withValues(alpha: 0.7),
                            size: rs.isSmall ? 18 : 22,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
