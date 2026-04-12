import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/input/input_providers.dart';
import '../core/responsive/responsive.dart';
import '../l10n/app_localizations.dart';
import 'console_hud.dart';
import 'glass_overlay.dart';

class ExitConfirmationOverlay extends ConsumerStatefulWidget {
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  /// Optional overrides for reuse as generic confirmation dialog.
  final String? title;
  final String? message;
  final IconData icon;
  final String? confirmLabel;
  final String? cancelLabel;

  const ExitConfirmationOverlay({
    super.key,
    required this.onConfirm,
    required this.onCancel,
    this.title,
    this.message,
    this.icon = Icons.power_settings_new_rounded,
    this.confirmLabel,
    this.cancelLabel,
  });

  @override
  ConsumerState<ExitConfirmationOverlay> createState() =>
      _ExitConfirmationOverlayState();
}

class _ExitConfirmationOverlayState
    extends ConsumerState<ExitConfirmationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  int _selectedIndex = 0; // 0 = Cancel (default safe choice), 1 = Confirm
  OverlayPriorityManager? _overlayManager;
  int? _claimToken;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );
    _focusNode = FocusNode();
    _controller.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _overlayManager = ref.read(overlayPriorityProvider.notifier);
        _claimToken = _overlayManager!.claim(OverlayPriority.dialog);
        FocusScope.of(context).requestFocus(_focusNode);
      }
    });
  }

  @override
  void dispose() {
    final token = _claimToken;
    if (token != null) {
      _claimToken = null;
      final manager = _overlayManager;
      if (manager != null) {
        Future(() => manager.release(token));
      }
    }
    _focusNode.dispose();
    _controller.stop();
    _controller.dispose();
    super.dispose();
  }

  void _handleNavigate(bool right) {
    if (right && _selectedIndex == 0) {
      setState(() => _selectedIndex = 1);
    } else if (!right && _selectedIndex == 1) {
      setState(() => _selectedIndex = 0);
    }
  }

  void _handleConfirm() {
    if (_selectedIndex == 1) {
      widget.onConfirm();
    } else {
      _close();
    }
  }

  void _close() {
    _controller.reverse().then((_) {
      final token = _claimToken;
      if (token != null) {
        _claimToken = null;
        _overlayManager?.release(token);
      }
      if (!mounted) return;
      restoreMainFocus(ref);
      widget.onCancel();
    });
  }

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final l = L.of(context);

    final title = widget.title ?? l.exit_title;
    final message = widget.message ?? l.exit_message;
    final confirmLabel = widget.confirmLabel ?? l.exit_confirmButton;
    final cancelLabel = widget.cancelLabel ?? l.exit_cancelButton;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowRight,
            includeRepeats: false): () => _handleNavigate(true),
        const SingleActivator(LogicalKeyboardKey.arrowLeft,
            includeRepeats: false): () => _handleNavigate(false),
        const SingleActivator(LogicalKeyboardKey.enter,
            includeRepeats: false): _handleConfirm,
        const SingleActivator(LogicalKeyboardKey.gameButtonA,
            includeRepeats: false): _handleConfirm,
        const SingleActivator(LogicalKeyboardKey.escape,
            includeRepeats: false): _close,
        const SingleActivator(LogicalKeyboardKey.gameButtonB,
            includeRepeats: false): _close,
        const SingleActivator(LogicalKeyboardKey.goBack,
            includeRepeats: false): _close,
      },
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        child: GlassOverlay(
          blur: 15,
          opacity: 0.7,
          tint: Colors.black,
          child: Stack(
            children: [
              Center(
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Container(
                      width: (rs.isSmall ? 300.0 : 420.0)
                          .clamp(0, rs.screenWidth * 0.85),
                      padding: EdgeInsets.all(rs.isSmall ? 24 : 32),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141414),
                        borderRadius: BorderRadius.circular(rs.radius.lg),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.6),
                            blurRadius: 40,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Icon
                          Container(
                            width: rs.isSmall ? 56 : 68,
                            height: rs.isSmall ? 56 : 68,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.04),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                            child: Icon(
                              widget.icon,
                              size: rs.isSmall ? 28 : 34,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                          SizedBox(height: rs.isSmall ? 16 : 20),
                          // Title
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: rs.isSmall ? 18 : 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: rs.spacing.sm),
                          // Message
                          Text(
                            message,
                            style: TextStyle(
                              fontSize: rs.isSmall ? 13 : 15,
                              color: Colors.white.withValues(alpha: 0.5),
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: rs.isSmall ? 20 : 28),
                          // Buttons
                          Row(
                            children: [
                              Expanded(
                                child: _DialogButton(
                                  label: cancelLabel,
                                  isSelected: _selectedIndex == 0,
                                  isDestructive: false,
                                  isSmall: rs.isSmall,
                                  onTap: () {
                                    if (_selectedIndex != 0) {
                                      setState(() => _selectedIndex = 0);
                                    } else {
                                      _close();
                                    }
                                  },
                                ),
                              ),
                              SizedBox(width: rs.isSmall ? 10 : 14),
                              Expanded(
                                child: _DialogButton(
                                  label: confirmLabel,
                                  isSelected: _selectedIndex == 1,
                                  isDestructive: true,
                                  isSmall: rs.isSmall,
                                  onTap: () {
                                    if (_selectedIndex != 1) {
                                      setState(() => _selectedIndex = 1);
                                    } else {
                                      widget.onConfirm();
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // HUD
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: ConsoleHud(
                      a: HudAction(l.common_select, onTap: _handleConfirm),
                      b: HudAction(l.common_close, onTap: _close),
                      embedded: true,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isDestructive;
  final bool isSmall;
  final VoidCallback onTap;

  const _DialogButton({
    required this.label,
    required this.isSelected,
    required this.isDestructive,
    required this.isSmall,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? Colors.redAccent : Colors.white;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(vertical: isSmall ? 12 : 14),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDestructive
                  ? Colors.redAccent.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.08))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? (isDestructive
                    ? Colors.redAccent.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.3))
                : Colors.white.withValues(alpha: 0.08),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: (isDestructive ? Colors.redAccent : Colors.white)
                        .withValues(alpha: 0.15),
                    blurRadius: 12,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? color : Colors.white.withValues(alpha: 0.4),
            fontSize: isSmall ? 13 : 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}
