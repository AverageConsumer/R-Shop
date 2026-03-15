import 'package:flutter/material.dart';

import '../../../core/responsive/responsive.dart';
import 'download_action_button.dart';

/// Action section split into two independently focusable parts:
/// 1. [ActionButtonsRow.primaryOnly] — Download / Manage / Delete button
/// 2. [ActionButtonsRow.iconsOnly] — Favorite / Share / Shelf icon buttons
///
/// Icon button navigation indices: 0 = favorite, 1 = share, 2 = collection
class ActionButtonsRow extends StatelessWidget {
  // Primary-only fields
  final DownloadButtonState? downloadButtonState;
  final int? variantCount;
  final VoidCallback? onPrimaryAction;
  final String? hintText;

  // Icons-only fields
  final bool? isFavorite;
  final int? focusedButtonIndex;
  final VoidCallback? onFavorite;
  final VoidCallback? onShare;
  final VoidCallback? onCollection;

  final Color accentColor;
  final _Mode _mode;

  /// Total navigable items in the icon buttons section.
  static const int itemCount = 3;

  /// Renders only the primary action button (Download/Delete/Manage).
  const ActionButtonsRow.primaryOnly({
    super.key,
    required this.accentColor,
    required this.downloadButtonState,
    this.variantCount,
    required this.onPrimaryAction,
    required this.hintText,
  })  : _mode = _Mode.primary,
        isFavorite = null,
        focusedButtonIndex = null,
        onFavorite = null,
        onShare = null,
        onCollection = null;

  /// Renders only the icon action buttons (Favorite/Share/Shelf).
  const ActionButtonsRow.iconsOnly({
    super.key,
    required this.accentColor,
    required this.isFavorite,
    required this.focusedButtonIndex,
    required this.onFavorite,
    required this.onShare,
    required this.onCollection,
  })  : _mode = _Mode.icons,
        downloadButtonState = null,
        variantCount = null,
        onPrimaryAction = null,
        hintText = null;

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;

    return switch (_mode) {
      _Mode.primary => _buildPrimary(rs),
      _Mode.icons => _buildIcons(rs),
    };
  }

  Widget _buildPrimary(Responsive rs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PrimaryActionButton(
          state: downloadButtonState!,
          accentColor: accentColor,
          variantCount: variantCount,
          isFocused: true,
          onTap: onPrimaryAction,
        ),
        if (hintText != null && hintText!.isNotEmpty) ...[
          SizedBox(height: rs.spacing.xs),
          Text(
            hintText!,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.25),
              fontSize: rs.isSmall ? 9 : 10,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildIcons(Responsive rs) {
    return Row(
      children: [
        Expanded(
          child: _IconActionButton(
            icon: isFavorite!
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            label: 'Favorite',
            color: isFavorite! ? Colors.redAccent : Colors.white54,
            isFocused: focusedButtonIndex == 0,
            accentColor: accentColor,
            onTap: onFavorite!,
          ),
        ),
        SizedBox(width: rs.spacing.xs),
        Expanded(
          child: _IconActionButton(
            icon: Icons.share_rounded,
            label: 'Share',
            color: Colors.white54,
            isFocused: focusedButtonIndex == 1,
            accentColor: accentColor,
            onTap: onShare!,
          ),
        ),
        SizedBox(width: rs.spacing.xs),
        Expanded(
          child: _IconActionButton(
            icon: Icons.shelves,
            label: 'Shelf',
            color: Colors.white54,
            isFocused: focusedButtonIndex == 2,
            accentColor: accentColor,
            onTap: onCollection!,
          ),
        ),
      ],
    );
  }
}

enum _Mode { primary, icons }

class _PrimaryActionButton extends StatelessWidget {
  final DownloadButtonState state;
  final Color accentColor;
  final int? variantCount;
  final bool isFocused;
  final VoidCallback? onTap;

  const _PrimaryActionButton({
    required this.state,
    required this.accentColor,
    this.variantCount,
    required this.isFocused,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final isMulti = variantCount != null && variantCount! > 1;

    final Color bgColor;
    final Color borderColor;
    final Color textColor;
    final IconData icon;
    final String label;

    switch (state) {
      case DownloadButtonState.download:
        bgColor = accentColor.withValues(alpha: isFocused ? 0.25 : 0.15);
        borderColor = accentColor.withValues(alpha: isFocused ? 0.7 : 0.4);
        textColor = accentColor;
        icon = Icons.download_rounded;
        label = isMulti ? 'MANAGE FILES' : 'DOWNLOAD';
      case DownloadButtonState.adding:
        bgColor = accentColor.withValues(alpha: 0.1);
        borderColor = accentColor.withValues(alpha: 0.3);
        textColor = accentColor.withValues(alpha: 0.7);
        icon = Icons.download_rounded;
        label = 'ADDING...';
      case DownloadButtonState.delete:
        bgColor = Colors.red.withValues(alpha: isFocused ? 0.18 : 0.1);
        borderColor = Colors.red.withValues(alpha: isFocused ? 0.5 : 0.3);
        textColor = Colors.redAccent;
        icon = Icons.delete_outline_rounded;
        label = 'DELETE';
      case DownloadButtonState.installed:
        bgColor = accentColor.withValues(alpha: isFocused ? 0.2 : 0.1);
        borderColor = accentColor.withValues(alpha: isFocused ? 0.6 : 0.3);
        textColor = accentColor;
        icon = Icons.folder_open_rounded;
        label = 'MANAGE FILES';
      case DownloadButtonState.unavailable:
        bgColor = Colors.white.withValues(alpha: 0.04);
        borderColor = Colors.white.withValues(alpha: 0.08);
        textColor = Colors.white.withValues(alpha: 0.3);
        icon = Icons.block_rounded;
        label = 'UNAVAILABLE';
    }

    final isDisabled = state == DownloadButtonState.adding ||
        state == DownloadButtonState.unavailable;

    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(
          horizontal: rs.isSmall ? 14 : 18,
          vertical: rs.isSmall ? 10 : 12,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(rs.radius.md),
          border: Border.all(color: borderColor, width: isFocused ? 2 : 1.5),
          boxShadow: isFocused
              ? [
                  BoxShadow(
                    color: (state == DownloadButtonState.delete
                            ? Colors.red
                            : accentColor)
                        .withValues(alpha: 0.25),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (state == DownloadButtonState.adding)
              SizedBox(
                width: rs.isSmall ? 14 : 16,
                height: rs.isSmall ? 14 : 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: textColor,
                ),
              )
            else
              Icon(icon, color: textColor, size: rs.isSmall ? 16 : 18),
            SizedBox(width: rs.spacing.sm),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontSize: rs.isSmall ? 12 : 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            if (isMulti &&
                state == DownloadButtonState.download) ...[
              SizedBox(width: rs.spacing.sm),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$variantCount',
                  style: TextStyle(
                    color: accentColor,
                    fontSize: rs.isSmall ? 9 : 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _IconActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isFocused;
  final Color accentColor;
  final VoidCallback onTap;

  const _IconActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.isFocused,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(
          horizontal: rs.isSmall ? 10 : 14,
          vertical: rs.isSmall ? 8 : 10,
        ),
        decoration: BoxDecoration(
          color: isFocused
              ? accentColor.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(rs.radius.md),
          border: Border.all(
            color: isFocused
                ? accentColor.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: rs.isSmall ? 18 : 22),
            SizedBox(height: rs.spacing.xs),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: isFocused ? 0.9 : 0.5),
                fontSize: rs.isSmall ? 8 : 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
