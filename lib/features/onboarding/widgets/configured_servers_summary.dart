import 'package:flutter/material.dart';
import '../../../core/responsive/responsive.dart';
import '../../../models/config/provider_config.dart';
import '../onboarding_state.dart';

/// Compact, non-interactive summary showing already-configured remote servers
/// as inline chips in a single Wrap row.
class ConfiguredServersSummary extends StatelessWidget {
  final List<ConfiguredServerSummary> servers;

  const ConfiguredServersSummary({super.key, required this.servers});

  @override
  Widget build(BuildContext context) {
    if (servers.isEmpty) return const SizedBox.shrink();

    final rs = context.rs;
    final fontSize = rs.isSmall ? 9.0 : 11.0;

    return Padding(
      padding: EdgeInsets.only(bottom: rs.spacing.md),
      child: Wrap(
        spacing: rs.spacing.sm,
        runSpacing: rs.spacing.xs,
        children: [
          for (final server in servers)
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: rs.spacing.sm,
                vertical: rs.spacing.xs,
              ),
              decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(rs.radius.round),
                border: Border.all(
                  color: Colors.teal.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_rounded,
                      color: Colors.teal.shade400, size: 12),
                  SizedBox(width: rs.spacing.xs),
                  Icon(_iconForType(server.type),
                      color: Colors.white38, size: 12),
                  SizedBox(width: 4),
                  Text(
                    server.hostLabel.isNotEmpty
                        ? server.hostLabel
                        : server.detailLabel,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: fontSize,
                      fontFamily: 'monospace',
                    ),
                  ),
                  SizedBox(width: rs.spacing.xs),
                  Text(
                    '(${server.systemCount})',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: fontSize,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static IconData _iconForType(ProviderType type) {
    switch (type) {
      case ProviderType.ftp:
        return Icons.dns;
      case ProviderType.smb:
        return Icons.folder_shared;
      case ProviderType.web:
        return Icons.language;
      case ProviderType.romm:
        return Icons.storage;
    }
  }
}
