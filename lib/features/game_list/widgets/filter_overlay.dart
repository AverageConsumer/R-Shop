import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/responsive/responsive.dart';
import '../logic/filter_state.dart';

enum _FilterItemType { header, option }
enum _FilterCategory { region, language }

class _FilterItem {
  final _FilterItemType type;
  final _FilterCategory category;
  final FilterOption? option;
  final String label;

  const _FilterItem({
    required this.type,
    required this.category,
    this.option,
    required this.label,
  });
}

class FilterOverlay extends StatefulWidget {
  final Color accentColor;
  final List<FilterOption> availableRegions;
  final List<FilterOption> availableLanguages;
  final Set<String> selectedRegions;
  final Set<String> selectedLanguages;
  final void Function(String region) onToggleRegion;
  final void Function(String language) onToggleLanguage;
  final VoidCallback onClearAll;
  final VoidCallback onClose;

  const FilterOverlay({
    super.key,
    required this.accentColor,
    required this.availableRegions,
    required this.availableLanguages,
    required this.selectedRegions,
    required this.selectedLanguages,
    required this.onToggleRegion,
    required this.onToggleLanguage,
    required this.onClearAll,
    required this.onClose,
  });

  @override
  State<FilterOverlay> createState() => _FilterOverlayState();
}

class _FilterOverlayState extends State<FilterOverlay>
    with SingleTickerProviderStateMixin {
  final FocusNode _focusNode = FocusNode(debugLabel: 'FilterOverlay');
  final ScrollController _scrollController = ScrollController();
  late AnimationController _animController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  int _focusedIndex = 0;
  late List<_FilterItem> _items;
  late List<int> _selectableIndices;
  int _regionSectionStart = -1;
  int _languageSectionStart = -1;

  @override
  void initState() {
    super.initState();
    _buildItems();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(-1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _animController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void didUpdateWidget(FilterOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _buildItems();
  }

  @override
  void dispose() {
    _animController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _buildItems() {
    _items = [];
    _selectableIndices = [];

    if (widget.availableRegions.isNotEmpty) {
      _regionSectionStart = _items.length;
      _items.add(const _FilterItem(
        type: _FilterItemType.header,
        category: _FilterCategory.region,
        label: 'REGIONS',
      ));
      for (final option in widget.availableRegions) {
        _selectableIndices.add(_items.length);
        _items.add(_FilterItem(
          type: _FilterItemType.option,
          category: _FilterCategory.region,
          option: option,
          label: option.label,
        ));
      }
    }

    if (widget.availableLanguages.isNotEmpty) {
      _languageSectionStart = _items.length;
      _items.add(const _FilterItem(
        type: _FilterItemType.header,
        category: _FilterCategory.language,
        label: 'LANGUAGES',
      ));
      for (final option in widget.availableLanguages) {
        _selectableIndices.add(_items.length);
        _items.add(_FilterItem(
          type: _FilterItemType.option,
          category: _FilterCategory.language,
          option: option,
          label: option.label,
        ));
      }
    }

    // Ensure focused index is valid
    if (_selectableIndices.isNotEmpty) {
      if (!_selectableIndices.contains(_focusedIndex)) {
        _focusedIndex = _selectableIndices.first;
      }
    }
  }

  void _moveFocus(int delta) {
    if (_selectableIndices.isEmpty) return;
    final currentPos = _selectableIndices.indexOf(_focusedIndex);
    if (currentPos < 0) {
      setState(() => _focusedIndex = _selectableIndices.first);
      return;
    }
    final newPos = (currentPos + delta).clamp(0, _selectableIndices.length - 1);
    if (newPos != currentPos) {
      setState(() => _focusedIndex = _selectableIndices[newPos]);
      _ensureVisible(_focusedIndex);
    }
  }

  void _jumpToSection(_FilterCategory category) {
    final targetStart = category == _FilterCategory.region
        ? _regionSectionStart
        : _languageSectionStart;
    if (targetStart < 0) return;

    // Find first selectable index after the section header
    final firstSelectable = _selectableIndices.firstWhere(
      (i) => i > targetStart,
      orElse: () => _focusedIndex,
    );
    setState(() => _focusedIndex = firstSelectable);
    _ensureVisible(_focusedIndex);
  }

  void _toggleCurrent() {
    if (!_selectableIndices.contains(_focusedIndex)) return;
    final item = _items[_focusedIndex];
    if (item.option == null) return;

    if (item.category == _FilterCategory.region) {
      widget.onToggleRegion(item.option!.id);
    } else {
      widget.onToggleLanguage(item.option!.id);
    }
  }

  void _ensureVisible(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      const itemHeight = 44.0;
      final offset = index * itemHeight;
      final viewport = _scrollController.position;
      if (offset < viewport.pixels) {
        _scrollController.animateTo(
          offset,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      } else if (offset + itemHeight > viewport.pixels + viewport.viewportDimension) {
        _scrollController.animateTo(
          offset + itemHeight - viewport.viewportDimension,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });
  }

  bool _isSelected(_FilterItem item) {
    if (item.option == null) return false;
    if (item.category == _FilterCategory.region) {
      return widget.selectedRegions.contains(item.option!.id);
    }
    return widget.selectedLanguages.contains(item.option!.id);
  }

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final totalActive = widget.selectedRegions.length + widget.selectedLanguages.length;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            // Semi-transparent backdrop
            GestureDetector(
              onTap: widget.onClose,
              child: Container(
                color: Colors.black.withValues(alpha: 0.5),
              ),
            ),
            // Side panel
            Positioned(
              top: 0,
              bottom: 0,
              left: 0,
              width: rs.isPortrait
                  ? rs.screenWidth
                  : rs.screenWidth * 0.38,
              child: SlideTransition(
                position: _slideAnimation,
                child: CallbackShortcuts(
                  bindings: {
                    const SingleActivator(LogicalKeyboardKey.arrowUp):
                        () => _moveFocus(-1),
                    const SingleActivator(LogicalKeyboardKey.arrowDown):
                        () => _moveFocus(1),
                    const SingleActivator(LogicalKeyboardKey.enter):
                        _toggleCurrent,
                    const SingleActivator(LogicalKeyboardKey.space):
                        _toggleCurrent,
                    const SingleActivator(LogicalKeyboardKey.gameButtonA):
                        _toggleCurrent,
                    const SingleActivator(LogicalKeyboardKey.escape):
                        widget.onClose,
                    const SingleActivator(LogicalKeyboardKey.gameButtonB):
                        widget.onClose,
                    const SingleActivator(LogicalKeyboardKey.goBack):
                        widget.onClose,
                    const SingleActivator(LogicalKeyboardKey.gameButtonX):
                        widget.onClearAll,
                    const SingleActivator(LogicalKeyboardKey.gameButtonLeft1):
                        () => _jumpToSection(_FilterCategory.region),
                    const SingleActivator(LogicalKeyboardKey.gameButtonRight1):
                        () => _jumpToSection(_FilterCategory.language),
                    const SingleActivator(LogicalKeyboardKey.pageUp):
                        () => _jumpToSection(_FilterCategory.region),
                    const SingleActivator(LogicalKeyboardKey.pageDown):
                        () => _jumpToSection(_FilterCategory.language),
                  },
                  child: Focus(
                    focusNode: _focusNode,
                    autofocus: true,
                    child: _buildPanel(rs, totalActive),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPanel(Responsive rs, int totalActive) {
    final padding = rs.isSmall ? rs.spacing.md : rs.spacing.lg;
    final headerFontSize = rs.isSmall ? 16.0 : 20.0;
    final badgeFontSize = rs.isSmall ? 11.0 : 13.0;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xF0141414),
        border: Border(
          right: BorderSide(
            color: widget.accentColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 30,
            offset: const Offset(10, 0),
          ),
        ],
      ),
      child: SafeArea(
        left: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title bar
            Padding(
              padding: EdgeInsets.fromLTRB(padding, padding, padding, rs.spacing.sm),
              child: Row(
                children: [
                  Text(
                    'FILTER',
                    style: TextStyle(
                      fontSize: headerFontSize,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 3,
                    ),
                  ),
                  const Spacer(),
                  if (totalActive > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: widget.accentColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: widget.accentColor.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        '$totalActive active',
                        style: TextStyle(
                          fontSize: badgeFontSize,
                          fontWeight: FontWeight.w600,
                          color: widget.accentColor,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Divider(
              color: Colors.white.withValues(alpha: 0.08),
              height: 1,
            ),
            // Scrollable list
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: EdgeInsets.symmetric(vertical: rs.spacing.sm),
                itemCount: _items.length,
                itemExtent: 44,
                itemBuilder: (context, index) {
                  final item = _items[index];
                  if (item.type == _FilterItemType.header) {
                    return _buildHeader(rs, item);
                  }
                  return _buildOption(
                    rs,
                    item,
                    isFocused: index == _focusedIndex,
                    isSelected: _isSelected(item),
                    index: index,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Responsive rs, _FilterItem item) {
    final fontSize = rs.isSmall ? 10.0 : 11.0;
    final padding = rs.isSmall ? rs.spacing.md : rs.spacing.lg;

    return Padding(
      padding: EdgeInsets.fromLTRB(padding, 12, padding, 4),
      child: Text(
        item.label,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: Colors.grey[500],
          letterSpacing: 2,
        ),
      ),
    );
  }

  Widget _buildOption(
    Responsive rs,
    _FilterItem item, {
    required bool isFocused,
    required bool isSelected,
    required int index,
  }) {
    final option = item.option!;
    final fontSize = rs.isSmall ? 13.0 : 15.0;
    final countFontSize = rs.isSmall ? 11.0 : 12.0;
    final horizontalPadding = rs.isSmall ? rs.spacing.md : rs.spacing.lg;

    return GestureDetector(
      onTap: () {
        setState(() => _focusedIndex = index);
        _toggleCurrent();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: EdgeInsets.symmetric(
          horizontal: horizontalPadding - 4,
          vertical: 1,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? widget.accentColor.withValues(alpha: isFocused ? 0.18 : 0.08)
              : isFocused
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(rs.radius.md),
          border: isFocused
              ? Border.all(
                  color: widget.accentColor.withValues(alpha: 0.7),
                  width: 1.5,
                )
              : Border.all(color: Colors.transparent, width: 1.5),
          boxShadow: isFocused
              ? [
                  BoxShadow(
                    color: widget.accentColor.withValues(alpha: 0.15),
                    blurRadius: 8,
                    spreadRadius: -2,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // Checkbox indicator
            SizedBox(
              width: 20,
              child: isSelected
                  ? Icon(
                      Icons.check_circle,
                      size: 16,
                      color: widget.accentColor,
                    )
                  : Icon(
                      Icons.circle_outlined,
                      size: 16,
                      color: isFocused
                          ? Colors.grey[400]
                          : Colors.grey[600],
                    ),
            ),
            const SizedBox(width: 8),
            // Flag
            Text(
              option.flag,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(width: 8),
            // Label
            Expanded(
              child: Text(
                option.label,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected
                      ? Colors.white
                      : isFocused
                          ? Colors.white.withValues(alpha: 0.9)
                          : Colors.grey[400],
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Count badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${option.count}',
                style: TextStyle(
                  fontSize: countFontSize,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[500],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
