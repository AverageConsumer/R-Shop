import 'package:flutter/material.dart';

import '../core/responsive/responsive.dart';

/// Canonical "this collection has nothing to show" placeholder. Lift the
/// pattern out of every screen so the icon size, copy hierarchy, and CTA
/// affordance feel the same across Library, Sources, GameList filter
/// results, etc.
///
/// The optional `action` widget is rendered below the subtitle; callers
/// wrap their own ConsoleFocusable around it when the action should be
/// reachable by gamepad.
class EmptyStateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const EmptyStateView({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: rs.spacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: rs.isSmall ? 56 : 72,
                color: Colors.white24,
              ),
              SizedBox(height: rs.spacing.lg),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: rs.isSmall ? 16 : 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle != null) ...[
                SizedBox(height: rs.spacing.sm),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: rs.isSmall ? 11 : 13,
                    height: 1.4,
                  ),
                ),
              ],
              if (action != null) ...[
                SizedBox(height: rs.spacing.lg),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// "Something failed" placeholder. Same composition as EmptyStateView but
/// the icon defaults to an error glyph and the action slot is wired to a
/// Retry callback so callers don't have to reinvent the button.
class ErrorStateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final VoidCallback? onRetry;
  final String retryLabel;
  final Color? accentColor;

  const ErrorStateView({
    super.key,
    this.icon = Icons.error_outline,
    required this.title,
    this.message,
    this.onRetry,
    this.retryLabel = 'Retry',
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final accent = accentColor ?? Theme.of(context).colorScheme.primary;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: rs.spacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: rs.isSmall ? 48 : 64,
                color: Colors.redAccent.withValues(alpha: 0.8),
              ),
              SizedBox(height: rs.spacing.md),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: rs.isSmall ? 14 : 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (message != null) ...[
                SizedBox(height: rs.spacing.sm),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: rs.isSmall ? 10 : 12,
                    height: 1.4,
                  ),
                ),
              ],
              if (onRetry != null) ...[
                SizedBox(height: rs.spacing.md),
                ElevatedButton(
                  onPressed: onRetry,
                  style: ElevatedButton.styleFrom(backgroundColor: accent),
                  child: Text(retryLabel),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
