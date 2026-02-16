import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/console_focusable.dart';

class SettingsItem extends StatefulWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;
  final Widget Function(bool isFocused)? trailingBuilder;
  final VoidCallback? onTap;
  final bool isDestructive;
  final FocusNode? focusNode;

  const SettingsItem({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.trailingBuilder,
    this.onTap,
    this.isDestructive = false,
    this.focusNode,
  }) : assert(trailing == null || trailingBuilder == null, 'Cannot provide both trailing and trailingBuilder');

  @override
  State<SettingsItem> createState() => _SettingsItemState();
}

class _SettingsItemState extends State<SettingsItem> {
  late FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus != _isFocused) {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConsoleFocusableListItem(
      focusNode: _focusNode,
      onSelect: widget.onTap ?? () {},
      backgroundColor: widget.isDestructive ? Colors.redAccent.withOpacity(0.1) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title.toUpperCase(),
                    style: AppTheme.titleMedium.copyWith(
                      color: widget.isDestructive
                          ? Colors.redAccent
                          : (_isFocused ? Colors.white : Colors.white70),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.subtitle,
                    style: AppTheme.bodySmall.copyWith(
                      color: widget.isDestructive
                          ? Colors.redAccent.withOpacity(0.7)
                          : (_isFocused ? Colors.white70 : Colors.white38),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            if (widget.trailingBuilder != null)
              widget.trailingBuilder!(_isFocused)
            else if (widget.trailing != null)
              widget.trailing!,
          ],
        ),
      ),
    );
  }
}
