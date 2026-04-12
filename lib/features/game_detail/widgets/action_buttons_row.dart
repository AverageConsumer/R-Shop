import 'package:flutter/material.dart';

import '../../../core/responsive/responsive.dart';
import '../../../core/util/color_contrast.dart';
import '../../../l10n/app_localizations.dart';
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
  final bool? isShareEnabled;
  final int? focusedButtonIndex;
  final VoidCallback? onFavorite;
  final VoidCallback? onShare;
  final VoidCallback? onCollection;

  final Color accentColor;
  final _Mode _mode;

  /// Total navigable items in the icon buttons section.
  static const int itemCount = 3;

  // Primary-only: whether the section is focused
  final bool isSectionFocused;

  /// Download progress (0.0–1.0) when [downloadButtonState] is [DownloadButtonState.downloading].
  final double downloadProgress;

  /// Renders only the primary action button (Download/Delete/Manage).
  const ActionButtonsRow.primaryOnly({
    super.key,
    required this.accentColor,
    required this.downloadButtonState,
    this.variantCount,
    required this.onPrimaryAction,
    required this.hintText,
    this.isSectionFocused = false,
    this.downloadProgress = 0.0,
  })  : _mode = _Mode.primary,
        isFavorite = null,
        isShareEnabled = null,
        isCollectionEnabled = null,
        focusedButtonIndex = null,
        onFavorite = null,
        onShare = null,
        onCollection = null;

  /// Whether the collection/shelf button is enabled.
  final bool? isCollectionEnabled;

  /// Renders only the icon action buttons (Favorite/Share/Shelf).
  const ActionButtonsRow.iconsOnly({
    super.key,
    required this.accentColor,
    required this.isFavorite,
    this.isShareEnabled = true,
    this.isCollectionEnabled = true,
    required this.focusedButtonIndex,
    this.isSectionFocused = false,
    required this.onFavorite,
    required this.onShare,
    required this.onCollection,
  })  : _mode = _Mode.icons,
        downloadButtonState = null,
        variantCount = null,
        onPrimaryAction = null,
        hintText = null,
        downloadProgress = 0.0;

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
          isFocused: isSectionFocused,
          onTap: onPrimaryAction,
          progress: downloadProgress,
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
    final shareEnabled = isShareEnabled ?? true;
    final collectionEnabled = isCollectionEnabled ?? true;

    return Row(
      children: [
        // Favorite — always enabled
        Expanded(
          child: _IconActionButton(
            icon: isFavorite!
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            color: isFavorite! ? Colors.redAccent : Colors.white54,
            isFocused: isSectionFocused && focusedButtonIndex == 0,
            accentColor: accentColor,
            onTap: onFavorite!,
          ),
        ),
        SizedBox(width: rs.spacing.xs),
        // Share — disabled when game not installed
        Expanded(
          child: _IconActionButton(
            icon: Icons.share_rounded,
            color: shareEnabled ? Colors.white54 : Colors.white12,
            isFocused: shareEnabled && isSectionFocused && focusedButtonIndex == 1,
            accentColor: accentColor,
            enabled: shareEnabled,
            onTap: onShare!,
          ),
        ),
        SizedBox(width: rs.spacing.xs),
        // Collection — disabled when no shelves exist
        Expanded(
          child: _IconActionButton(
            icon: Icons.shelves,
            color: collectionEnabled ? Colors.white54 : Colors.white12,
            isFocused: collectionEnabled && isSectionFocused && focusedButtonIndex == 2,
            accentColor: accentColor,
            enabled: collectionEnabled,
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
  final double progress;

  const _PrimaryActionButton({
    required this.state,
    required this.accentColor,
    this.variantCount,
    required this.isFocused,
    this.onTap,
    this.progress = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final l = L.of(context);
    final isMulti = variantCount != null && variantCount! > 1;

    final Color bgColor;
    final Color borderColor;
    final Color textColor;
    final IconData icon;
    final String label;
    final bool showProgressFill;

    switch (state) {
      case DownloadButtonState.download:
        bgColor = accentColor.withValues(alpha: isFocused ? 0.25 : 0.15);
        borderColor = accentColor.withValues(alpha: isFocused ? 0.7 : 0.4);
        textColor = accentColor.forText;
        icon = Icons.download_rounded;
        label = isMulti ? l.gameDetail_manageFiles : l.gameDetail_download;
        showProgressFill = false;
      case DownloadButtonState.adding:
        bgColor = accentColor.withValues(alpha: 0.1);
        borderColor = accentColor.withValues(alpha: 0.3);
        textColor = accentColor.forText;
        icon = Icons.download_rounded;
        label = l.gameDetail_adding;
        showProgressFill = false;
      case DownloadButtonState.queued:
        bgColor = accentColor.withValues(alpha: 0.08);
        borderColor = accentColor.withValues(alpha: 0.4);
        textColor = accentColor.forText;
        icon = Icons.schedule_rounded;
        label = l.gameDetail_queued;
        showProgressFill = false;
      case DownloadButtonState.downloading:
        bgColor = accentColor.withValues(alpha: 0.06);
        borderColor = accentColor.withValues(alpha: 0.5);
        textColor = Colors.white;
        icon = Icons.downloading_rounded;
        label = '${(progress * 100).toStringAsFixed(0)}%';
        showProgressFill = true;
      case DownloadButtonState.extracting:
        bgColor = Colors.amber.withValues(alpha: 0.08);
        borderColor = Colors.amber.withValues(alpha: 0.4);
        textColor = Colors.amber;
        icon = Icons.unarchive_rounded;
        label = l.gameDetail_extracting;
        showProgressFill = false;
      case DownloadButtonState.delete:
        bgColor = Colors.red.withValues(alpha: isFocused ? 0.18 : 0.1);
        borderColor = Colors.red.withValues(alpha: isFocused ? 0.5 : 0.3);
        textColor = Colors.redAccent;
        icon = Icons.delete_outline_rounded;
        label = l.gameDetail_delete;
        showProgressFill = false;
      case DownloadButtonState.installed:
        bgColor = accentColor.withValues(alpha: isFocused ? 0.2 : 0.1);
        borderColor = accentColor.withValues(alpha: isFocused ? 0.6 : 0.3);
        textColor = accentColor.forText;
        icon = Icons.folder_open_rounded;
        label = l.gameDetail_manageFiles;
        showProgressFill = false;
      case DownloadButtonState.unavailable:
        bgColor = Colors.white.withValues(alpha: 0.04);
        borderColor = Colors.white.withValues(alpha: 0.08);
        textColor = Colors.white.withValues(alpha: 0.3);
        icon = Icons.block_rounded;
        label = l.gameDetail_unavailable;
        showProgressFill = false;
    }

    final isDisabled = state == DownloadButtonState.adding ||
        state == DownloadButtonState.unavailable ||
        state == DownloadButtonState.queued ||
        state == DownloadButtonState.downloading ||
        state == DownloadButtonState.extracting;

    final radius = BorderRadius.circular(rs.radius.md);

    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: radius,
          border: Border.all(
            color: isFocused ? Colors.white.withValues(alpha: 0.9) : borderColor,
            width: isFocused ? 2 : 1.5,
          ),
          boxShadow: isFocused
              ? [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.3),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                  BoxShadow(
                    color: (state == DownloadButtonState.delete
                            ? Colors.red
                            : accentColor)
                        .withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: IntrinsicHeight(
          child: Stack(
            children: [
              // Progress fill — slides left to right behind the content
              if (showProgressFill)
                Positioned.fill(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: progress.clamp(0.0, 1.0)),
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeInOut,
                    builder: (context, value, _) {
                      return FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: value,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                accentColor.withValues(alpha: 0.3),
                                accentColor.withValues(alpha: 0.15),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              // Button content — full width so button size stays stable
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: rs.isSmall ? 14 : 18,
                  vertical: rs.isSmall ? 10 : 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
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
                    Text(
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
                            color: accentColor.forText,
                            fontSize: rs.isSmall ? 9 : 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool isFocused;
  final Color accentColor;
  final bool enabled;
  final VoidCallback onTap;

  const _IconActionButton({
    required this.icon,
    required this.color,
    required this.isFocused,
    required this.accentColor,
    this.enabled = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;

    final effectiveFocused = isFocused && enabled;

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: enabled ? 1.0 : 0.4,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(
            horizontal: rs.isSmall ? 10 : 14,
            vertical: rs.isSmall ? 8 : 10,
          ),
          decoration: BoxDecoration(
            color: effectiveFocused
                ? accentColor.withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(rs.radius.md),
            border: Border.all(
              color: effectiveFocused
                  ? Colors.white.withValues(alpha: 0.7)
                  : Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
            boxShadow: effectiveFocused
                ? [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.2),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
          child: Icon(icon, color: color, size: rs.isSmall ? 18 : 22),
        ),
      ),
    );
  }
}
