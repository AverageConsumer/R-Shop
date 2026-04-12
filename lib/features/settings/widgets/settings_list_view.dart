import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/input/input.dart';
import '../../../core/responsive/responsive.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/console_focusable.dart';
import '../../../providers/app_providers.dart';
import '../models/settings_entry.dart';
import 'settings_switch.dart';
import 'volume_slider.dart';

class SettingsListView extends ConsumerWidget {
  final FocusNode firstFocusNode;
  final List<SettingsSection> sections;

  const SettingsListView({
    super.key,
    required this.firstFocusNode,
    required this.sections,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rs = context.rs;
    final items = <Widget>[];
    var isFirstFocusable = true;

    for (final section in sections) {
      for (int i = 0; i < section.entries.length; i++) {
        final entry = section.entries[i];
        final isFirstInSection = i == 0;
        final focusNode = isFirstFocusable
            ? (entry.focusNode ?? firstFocusNode)
            : entry.focusNode;
        if (isFirstFocusable) isFirstFocusable = false;

        if (items.isNotEmpty) {
          SizedBox(height: isFirstInSection ? rs.spacing.lg : rs.spacing.sm);
        }

        items.add(Padding(
          padding: EdgeInsets.only(
            top: items.isEmpty
                ? 0
                : isFirstInSection
                    ? rs.spacing.lg
                    : rs.spacing.sm,
          ),
          child: _SettingsEntryTile(
            entry: entry,
            focusNode: focusNode,
            sectionHeader: isFirstInSection ? section.title : null,
          ),
        ));
      }
    }

    return FocusTraversalGroup(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: EdgeInsets.symmetric(
              horizontal: rs.spacing.lg,
              vertical: rs.spacing.md,
            ),
            children: items,
          ),
        ),
      ),
    );
  }
}

/// Unified tile that renders any [SettingsEntry] type.
/// When [sectionHeader] is set, the header is rendered as part of this
/// widget so `Scrollable.ensureVisible` includes it when focused.
class _SettingsEntryTile extends ConsumerStatefulWidget {
  final SettingsEntry entry;
  final FocusNode? focusNode;
  final String? sectionHeader;

  const _SettingsEntryTile({
    required this.entry,
    this.focusNode,
    this.sectionHeader,
  });

  @override
  ConsumerState<_SettingsEntryTile> createState() => _SettingsEntryTileState();
}

class _SettingsEntryTileState extends ConsumerState<_SettingsEntryTile> {
  late FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(_SettingsEntryTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      _focusNode.removeListener(_onFocusChange);
      if (oldWidget.focusNode == null) _focusNode.dispose();
      _focusNode = widget.focusNode ?? FocusNode();
      _focusNode.addListener(_onFocusChange);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    if (widget.focusNode == null) _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    final hasFocus = _focusNode.hasFocus;
    if (hasFocus != _isFocused) {
      setState(() => _isFocused = hasFocus);
      // When this tile has a section header, scroll the ENTIRE tile
      // (header + item) into view — not just the focusable child.
      // ConsoleFocusable/ListItem calls ensureVisible on its own context
      // in a postFrameCallback, so we schedule ours one frame later to
      // override with the larger scroll extent that includes the header.
      if (hasFocus && widget.sectionHeader != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Scrollable.ensureVisible(
                context,
                duration: const Duration(milliseconds: 200),
              );
            }
          });
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final tile = entry.type == SettingsEntryType.nav
        ? _buildNavTile(entry)
        : entry.type == SettingsEntryType.custom
            ? _buildCustomTile(entry)
            : _buildStandardTile(entry);

    final wrapped = _wrapWithNavigate(entry, tile);

    if (widget.sectionHeader == null) return wrapped;

    // Section header is part of this widget so ensureVisible includes it.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _SectionHeader(label: widget.sectionHeader!),
        const SizedBox(height: 8),
        wrapped,
      ],
    );
  }

  Widget _buildNavTile(SettingsEntry entry) {
    return ConsoleFocusable(
      focusNode: _focusNode,
      onSelect: entry.onTap,
      borderRadius: 12,
      focusScale: 1.0,
      focusBorderColor: AppTheme.primaryColor,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1C),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
              ),
              child:
                  Icon(entry.icon, color: AppTheme.primaryColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    entry.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.subtitle,
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white30),
          ],
        ),
      ),
    );
  }

  Widget _buildStandardTile(SettingsEntry entry) {
    return ConsoleFocusableListItem(
      focusNode: _focusNode,
      onSelect: entry.onTap ?? () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title.toUpperCase(),
                    style: AppTheme.titleMedium.copyWith(
                      color: _isFocused ? Colors.white : Colors.white70,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.subtitle,
                    style: AppTheme.bodySmall.copyWith(
                      color: _isFocused ? Colors.white70 : Colors.white38,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            _buildTrailing(entry),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomTile(SettingsEntry entry) {
    if (entry.custom != null) {
      return entry.custom!;
    }
    return ConsoleFocusableListItem(
      focusNode: _focusNode,
      onSelect: entry.onTap ?? () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Text(entry.title, style: const TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildTrailing(SettingsEntry entry) {
    return switch (entry.type) {
      SettingsEntryType.toggle =>
        SettingsSwitch(value: entry.toggleValue ?? false),
      SettingsEntryType.cycle => _buildCycleBadge(entry.displayValue ?? ''),
      SettingsEntryType.slider => VolumeSlider(
          volume: entry.sliderValue ?? 0,
          isSelected: _isFocused,
          onChanged: entry.onSliderChanged ?? (_) {},
        ),
      SettingsEntryType.spinner => _buildSpinner(entry),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _buildCycleBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.4),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.primaryColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildSpinner(SettingsEntry entry) {
    final value = entry.spinnerValue ?? 0;
    final min = entry.spinnerMin ?? 0;
    final max = entry.spinnerMax ?? 10;
    final onChange = entry.onSpinnerChanged;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => onChange?.call(-1),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(Icons.chevron_left,
                color: value > min
                    ? (_isFocused ? Colors.white : Colors.white70)
                    : Colors.white24,
                size: 24),
          ),
        ),
        SizedBox(
          width: 24,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _isFocused ? Colors.white : Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        GestureDetector(
          onTap: () => onChange?.call(1),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(Icons.chevron_right,
                color: value < max
                    ? (_isFocused ? Colors.white : Colors.white70)
                    : Colors.white24,
                size: 24),
          ),
        ),
      ],
    );
  }

  /// Wraps toggle/cycle/slider/spinner items with NavigateIntent actions
  /// so D-pad L/R works automatically.
  Widget _wrapWithNavigate(SettingsEntry entry, Widget child) {
    switch (entry.type) {
      case SettingsEntryType.toggle:
        return Actions(
          actions: {
            NavigateIntent: NavigateAction(ref, onNavigate: (intent) {
              if (intent.direction == GridDirection.left ||
                  intent.direction == GridDirection.right) {
                entry.onTap?.call();
                return true;
              }
              return false;
            }),
          },
          child: child,
        );
      case SettingsEntryType.cycle:
        return Actions(
          actions: {
            NavigateIntent: NavigateAction(ref, onNavigate: (intent) {
              if (intent.direction == GridDirection.left ||
                  intent.direction == GridDirection.right) {
                entry.onTap?.call();
                return true;
              }
              return false;
            }),
          },
          child: child,
        );
      case SettingsEntryType.slider:
        return Actions(
          actions: {
            NavigateIntent: NavigateAction(ref, onNavigate: (intent) {
              if (intent.direction == GridDirection.left) {
                entry.onSliderChanged
                    ?.call((entry.sliderValue ?? 0) - 0.05);
                ref.read(feedbackServiceProvider).tick();
                return true;
              } else if (intent.direction == GridDirection.right) {
                entry.onSliderChanged
                    ?.call((entry.sliderValue ?? 0) + 0.05);
                ref.read(feedbackServiceProvider).tick();
                return true;
              }
              return false;
            }),
          },
          child: child,
        );
      case SettingsEntryType.spinner:
        return Actions(
          actions: {
            NavigateIntent: NavigateAction(ref, onNavigate: (intent) {
              if (intent.direction == GridDirection.left) {
                entry.onSpinnerChanged?.call(-1);
                ref.read(feedbackServiceProvider).tick();
                return true;
              } else if (intent.direction == GridDirection.right) {
                entry.onSpinnerChanged?.call(1);
                ref.read(feedbackServiceProvider).tick();
                return true;
              }
              return false;
            }),
          },
          child: child,
        );
      default:
        return child;
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 12, bottom: 0),
      decoration: const BoxDecoration(
        border: Border(
          left: BorderSide(color: AppTheme.primaryColor, width: 3),
        ),
      ),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 2,
        ),
      ),
    );
  }
}
