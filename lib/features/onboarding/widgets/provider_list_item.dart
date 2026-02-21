import 'package:flutter/material.dart';
import '../../../core/responsive/responsive.dart';
import '../../../core/widgets/console_focusable.dart';
import '../../../models/config/provider_config.dart';

class ProviderListItem extends StatelessWidget {
  final ProviderConfig provider;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  const ProviderListItem({
    super.key,
    required this.provider,
    required this.index,
    required this.onEdit,
    required this.onDelete,
    this.onMoveUp,
    this.onMoveDown,
  });

  IconData get _typeIcon {
    switch (provider.type) {
      case ProviderType.web:
        return Icons.language;
      case ProviderType.ftp:
        return Icons.dns;
      case ProviderType.smb:
        return Icons.folder_shared;
      case ProviderType.romm:
        return Icons.storage;
    }
  }

  String get _displayText {
    switch (provider.type) {
      case ProviderType.web:
        return provider.url ?? 'Web source';
      case ProviderType.ftp:
        return '${provider.host ?? ''}:${provider.port ?? 21}${provider.path ?? ''}';
      case ProviderType.smb:
        return '${provider.host ?? ''}/${provider.share ?? ''}${provider.path ?? ''}';
      case ProviderType.romm:
        return provider.url ?? 'RomM source';
    }
  }

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final fontSize = rs.isSmall ? 12.0 : 14.0;
    final iconSize = rs.isSmall ? 16.0 : 20.0;

    return ConsoleFocusableListItem(
      onSelect: onEdit,
      borderRadius: rs.radius.sm,
      margin: EdgeInsets.only(bottom: rs.spacing.sm),
      padding: EdgeInsets.symmetric(
        horizontal: rs.spacing.md,
        vertical: rs.spacing.md,
      ),
      backgroundColor: Colors.white.withValues(alpha: 0.05),
      child: Row(
        children: [
          Icon(_typeIcon, color: Colors.redAccent, size: iconSize),
          SizedBox(width: rs.spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  provider.type.name.toUpperCase(),
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: fontSize - 2,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  _displayText,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: fontSize,
                    fontFamily: 'monospace',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (onMoveUp != null)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onMoveUp,
              child: SizedBox(
                width: 48,
                height: 48,
                child: Center(
                  child: Icon(Icons.arrow_upward, color: Colors.white38, size: iconSize),
                ),
              ),
            ),
          if (onMoveDown != null)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onMoveDown,
              child: SizedBox(
                width: 48,
                height: 48,
                child: Center(
                  child: Icon(Icons.arrow_downward, color: Colors.white38, size: iconSize),
                ),
              ),
            ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onEdit,
            child: SizedBox(
              width: 48,
              height: 48,
              child: Center(
                child: Icon(Icons.edit, color: Colors.white38, size: iconSize),
              ),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onDelete,
            child: SizedBox(
              width: 48,
              height: 48,
              child: Center(
                child: Icon(Icons.delete_outline, color: Colors.white38, size: iconSize),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
