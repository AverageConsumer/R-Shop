import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';

void showConsoleNotification(
  BuildContext context, {
  required String message,
  bool isError = true,
}) {
  final color = isError ? Colors.redAccent : const Color(0xFF4CAF50);
  final icon = isError ? Icons.error_outline : Icons.check_circle_outline;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontFamily: 'Inter',
              ),
            ),
          ),
        ],
      ),
      backgroundColor: const Color(0xFF1A1A1A),
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: color.withValues(alpha: 0.6)),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      duration: const Duration(seconds: 3),
    ),
  );
}

/// Shows an error notification with haptic + audio feedback.
void showErrorNotification(
  BuildContext context,
  WidgetRef ref, {
  required String message,
}) {
  ref.read(feedbackServiceProvider).error();
  showConsoleNotification(context, message: message);
}

/// Shows a success notification with confirm feedback.
void showSuccessNotification(
  BuildContext context,
  WidgetRef ref, {
  required String message,
}) {
  ref.read(feedbackServiceProvider).confirm();
  showConsoleNotification(context, message: message, isError: false);
}
