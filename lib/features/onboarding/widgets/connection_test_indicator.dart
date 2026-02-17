import 'package:flutter/material.dart';
import '../../../core/responsive/responsive.dart';

class ConnectionTestIndicator extends StatelessWidget {
  final bool isTesting;
  final bool isSuccess;
  final String? error;

  const ConnectionTestIndicator({
    super.key,
    required this.isTesting,
    required this.isSuccess,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final iconSize = rs.isSmall ? 12.0 : 16.0;
    final fontSize = rs.isSmall ? 10.0 : 12.0;

    if (isTesting) {
      return Row(
        children: [
          SizedBox(
            width: iconSize,
            height: iconSize,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.redAccent.withValues(alpha: 0.7),
            ),
          ),
          SizedBox(width: rs.spacing.sm),
          Text(
            'Testing connection...',
            style: TextStyle(color: Colors.grey.shade400, fontSize: fontSize),
          ),
        ],
      );
    }

    if (isSuccess) {
      return Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: iconSize),
          SizedBox(width: rs.spacing.sm),
          Text(
            'Connection successful!',
            style: TextStyle(color: Colors.green.shade300, fontSize: fontSize),
          ),
        ],
      );
    }

    if (error != null) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: Colors.redAccent, size: iconSize),
          SizedBox(width: rs.spacing.sm),
          Expanded(
            child: Text(
              error!,
              style: TextStyle(color: Colors.redAccent.shade100, fontSize: fontSize),
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }
}
