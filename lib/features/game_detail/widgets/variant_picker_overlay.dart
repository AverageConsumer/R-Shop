import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/input/overlay_scope.dart';
import '../../../core/responsive/responsive.dart';
import '../../../models/game_item.dart';
import '../../../models/system_model.dart';
import '../../../providers/app_providers.dart';
import '../../../utils/game_metadata.dart';
import '../../../widgets/console_hud.dart';
import 'version_card.dart';

class VariantPickerOverlay extends ConsumerStatefulWidget {
  final List<GameItem> variants;
  final SystemModel system;
  final Map<int, bool> installedStatus;
  final Future<bool> Function(int index) onDownload;
  final void Function(int index) onDelete;
  final VoidCallback onClose;

  const VariantPickerOverlay({
    super.key,
    required this.variants,
    required this.system,
    required this.installedStatus,
    required this.onDownload,
    required this.onDelete,
    required this.onClose,
  });

  @override
  ConsumerState<VariantPickerOverlay> createState() =>
      _VariantPickerOverlayState();
}

class _VariantPickerOverlayState extends ConsumerState<VariantPickerOverlay>
    with SingleTickerProviderStateMixin {
  int _focusedIndex = 0;
  final FocusNode _focusNode = FocusNode(debugLabel: 'VariantPicker');
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  final Map<int, GlobalKey> _cardKeys = {};

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
    _animController.forward();
    _ensureKeys();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _ensureKeys() {
    for (int i = 0; i < widget.variants.length; i++) {
      _cardKeys.putIfAbsent(i, () => GlobalKey());
    }
  }

  void _scrollToIndex(int index, {bool goingDown = true}) {
    final key = _cardKeys[index];
    if (key == null) return;
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      alignmentPolicy: goingDown
          ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
          : ScrollPositionAlignmentPolicy.keepVisibleAtStart,
    );
  }

  void _handleSelect(int index) {
    final isInstalled = widget.installedStatus[index] ?? false;
    if (isInstalled) {
      ref.read(feedbackServiceProvider).warning();
      widget.onDelete(index);
    } else {
      ref.read(feedbackServiceProvider).confirm();
      widget.onDownload(index);
    }
  }

  void _close() {
    _animController.reverse().then((_) {
      if (mounted) widget.onClose();
    });
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.gameButtonB ||
        key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.backspace) {
      ref.read(feedbackServiceProvider).cancel();
      _close();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.gameButtonA ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.space) {
      _handleSelect(_focusedIndex);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowUp) {
      if (_focusedIndex > 0) {
        setState(() => _focusedIndex--);
        ref.read(feedbackServiceProvider).tick();
        _scrollToIndex(_focusedIndex, goingDown: false);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      if (_focusedIndex < widget.variants.length - 1) {
        setState(() => _focusedIndex++);
        ref.read(feedbackServiceProvider).tick();
        _scrollToIndex(_focusedIndex);
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;

    return OverlayFocusScope(
      priority: OverlayPriority.dialog,
      isVisible: true,
      onClose: widget.onClose,
      child: Focus(
        focusNode: _focusNode,
        onKeyEvent: _handleKeyEvent,
        autofocus: true,
        child: Stack(
          children: [
            // Backdrop
            GestureDetector(
              onTap: _close,
              child: FadeTransition(
                opacity: _fadeAnim,
                child: Container(color: Colors.black.withValues(alpha: 0.6)),
              ),
            ),
            // Content
            Center(
              child: SlideTransition(
                position: _slideAnim,
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: Material(
                    type: MaterialType.transparency,
                    child: Container(
                      width: rs.isPortrait
                          ? rs.screenWidth * 0.88
                          : rs.screenWidth * 0.45,
                      constraints: BoxConstraints(
                        maxHeight: rs.screenHeight * 0.7,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF161616),
                        borderRadius: BorderRadius.circular(rs.radius.lg),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.7),
                            blurRadius: 32,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(rs),
                          Flexible(child: _buildList(rs)),
                          _buildHud(rs),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Responsive rs) {
    final labelFontSize = rs.isSmall ? 11.0 : 13.0;
    final countFontSize = rs.isSmall ? 9.0 : 11.0;
    final subtitleFontSize = rs.isSmall ? 10.0 : 12.0;
    final gameTitle = GameMetadata.cleanTitle(widget.variants.first.filename);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        rs.spacing.md,
        rs.spacing.md,
        rs.spacing.md,
        rs.spacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'VERSIONS',
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: labelFontSize,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              SizedBox(width: rs.spacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: widget.system.accentColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(rs.radius.sm),
                ),
                child: Text(
                  '${widget.variants.length}',
                  style: TextStyle(
                    color: widget.system.accentColor,
                    fontSize: countFontSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: rs.spacing.xs),
          Text(
            gameTitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: subtitleFontSize,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildList(Responsive rs) {
    _ensureKeys();

    return ListView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.symmetric(horizontal: rs.spacing.sm),
      itemCount: widget.variants.length,
      itemBuilder: (context, index) {
        final isInstalled = widget.installedStatus[index] ?? false;
        final isFocused = _focusedIndex == index;

        return Padding(
          key: _cardKeys[index],
          padding: EdgeInsets.only(
            bottom:
                index < widget.variants.length - 1 ? rs.spacing.sm : 0,
          ),
          child: GestureDetector(
            onTap: () {
              setState(() => _focusedIndex = index);
              _handleSelect(index);
            },
            child: MouseRegion(
              onEnter: (_) => setState(() => _focusedIndex = index),
              child: AnimatedScale(
                scale: isFocused ? 1.02 : 1.0,
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOutCubic,
                child: SingleVersionDisplay(
                  variant: widget.variants[index],
                  system: widget.system,
                  isInstalled: isInstalled,
                  isSelected: isFocused,
                  isFocused: isFocused,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHud(Responsive rs) {
    final isInstalled = widget.installedStatus[_focusedIndex] ?? false;

    return Padding(
      padding: EdgeInsets.all(rs.spacing.sm),
      child: ConsoleHud(
        embedded: true,
        dpad: (label: '', action: 'Navigate'),
        a: HudAction(isInstalled ? 'Delete' : 'Download'),
        b: HudAction('Close'),
      ),
    );
  }
}
