import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/responsive/responsive.dart';
import '../core/theme/app_theme.dart';
import 'glass_overlay.dart';

class ExitConfirmationOverlay extends StatefulWidget {
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const ExitConfirmationOverlay({
    super.key,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<ExitConfirmationOverlay> createState() => _ExitConfirmationOverlayState();
}

class _ExitConfirmationOverlayState extends State<ExitConfirmationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  int _selectedIndex = 0; // 0 = Stay (Default), 1 = Exit

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

    _controller.forward();
    
    // Ensure focus is requested after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        FocusScope.of(context).requestFocus(_focusNode);
      }
    });
  }

  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
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
    _controller.reverse().then((_) => widget.onCancel());
  }

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => _handleNavigate(true),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _handleNavigate(false),
        const SingleActivator(LogicalKeyboardKey.enter): _handleConfirm, // A / Enter
        const SingleActivator(LogicalKeyboardKey.gameButtonA): _handleConfirm,
        const SingleActivator(LogicalKeyboardKey.escape): _close, // B / Esc
        const SingleActivator(LogicalKeyboardKey.gameButtonB): _close,
        const SingleActivator(LogicalKeyboardKey.goBack): _close,
      },
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        child: GlassOverlay(
          blur: 15,
          opacity: 0.7,
          tint: Colors.black,
          child: Center(
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  width: rs.isSmall ? 320 : 450,
                  padding: EdgeInsets.all(rs.spacing.xl),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(rs.radius.lg),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.power_settings_new_rounded,
                        size: rs.isSmall ? 48 : 64,
                        color: AppTheme.primaryColor,
                      ),
                      SizedBox(height: rs.spacing.lg),
                      Text(
                        'EXIT APPLICATION',
                        style: AppTheme.headlineMedium.copyWith(
                          fontSize: rs.isSmall ? 24 : 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                      SizedBox(height: rs.spacing.sm),
                      Text(
                        'Are you sure you want to quit?',
                        style: AppTheme.bodyLarge.copyWith(
                          color: Colors.white60,
                        ),
                      ),
                      SizedBox(height: rs.spacing.xl),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildButton(
                            label: 'STAY',
                            isSelected: _selectedIndex == 0,
                            isPrimary: true,
                            onTap: () {
                               if (_selectedIndex != 0) {
                                  setState(() => _selectedIndex = 0);
                               } else {
                                  _close();
                               }
                            },
                          ),
                          SizedBox(width: rs.spacing.lg),
                          _buildButton(
                            label: 'EXIT',
                            isSelected: _selectedIndex == 1,
                            isPrimary: false, 
                            onTap: () {
                                if (_selectedIndex != 1) {
                                  setState(() => _selectedIndex = 1);
                                } else {
                                  widget.onConfirm();
                                }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButton({
    required String label,
    required bool isSelected,
    required bool isPrimary,
    required VoidCallback onTap,
  }) {
    final color = isPrimary ? AppTheme.primaryColor : Colors.redAccent;
    
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : Colors.white24,
              width: 2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.4),
                      blurRadius: 15,
                      spreadRadius: 2,
                    )
                  ]
                : [],
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}
