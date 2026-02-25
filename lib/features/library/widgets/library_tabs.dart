import 'package:flutter/material.dart';
import '../../../core/responsive/responsive.dart';

class LibraryTab {
  final String label;
  final int count;
  final bool isCustomShelf;

  const LibraryTab({
    required this.label,
    required this.count,
    this.isCustomShelf = false,
  });
}

class LibraryTabs extends StatefulWidget {
  final int selectedTab;
  final List<LibraryTab> tabs;
  final Color accentColor;
  final ValueChanged<int>? onTap;

  const LibraryTabs({
    super.key,
    required this.selectedTab,
    required this.tabs,
    this.accentColor = Colors.cyanAccent,
    this.onTap,
  });

  @override
  State<LibraryTabs> createState() => _LibraryTabsState();
}

class _LibraryTabsState extends State<LibraryTabs> {
  final ScrollController _scrollController = ScrollController();
  final List<GlobalKey> _tabKeys = [];

  @override
  void initState() {
    super.initState();
    _ensureKeys();
  }

  @override
  void didUpdateWidget(LibraryTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    _ensureKeys();
    if (oldWidget.selectedTab != widget.selectedTab) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToActive();
      });
    }
  }

  void _ensureKeys() {
    while (_tabKeys.length < widget.tabs.length) {
      _tabKeys.add(GlobalKey());
    }
    if (_tabKeys.length > widget.tabs.length) {
      _tabKeys.removeRange(widget.tabs.length, _tabKeys.length);
    }
  }

  void _scrollToActive() {
    if (widget.selectedTab < 0 || widget.selectedTab >= _tabKeys.length) return;
    final key = _tabKeys[widget.selectedTab];
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.5,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final fontSize = rs.isSmall ? 10.0 : 12.0;
    final countFontSize = rs.isSmall ? 8.0 : 10.0;
    final hPadding = rs.isSmall ? 10.0 : 14.0;
    final vPadding = rs.isSmall ? 4.0 : 6.0;

    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(widget.tabs.length, (i) {
          final tab = widget.tabs[i];
          final isActive = i == widget.selectedTab;

          return Padding(
            key: _tabKeys[i],
            padding:
                EdgeInsets.only(right: i < widget.tabs.length - 1 ? 2.0 : 0.0),
            child: GestureDetector(
              onTap: widget.onTap != null ? () => widget.onTap!(i) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: EdgeInsets.symmetric(
                  horizontal: hPadding,
                  vertical: vPadding,
                ),
                decoration: BoxDecoration(
                  color: isActive
                      ? widget.accentColor.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isActive
                        ? widget.accentColor.withValues(alpha: 0.5)
                        : Colors.white.withValues(alpha: 0.08),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (tab.isCustomShelf)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(
                          Icons.collections_bookmark_rounded,
                          size: fontSize,
                          color: isActive
                              ? widget.accentColor
                              : Colors.grey[500],
                        ),
                      ),
                    Text(
                      tab.label.toUpperCase(),
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight:
                            isActive ? FontWeight.w700 : FontWeight.w500,
                        color: isActive
                            ? widget.accentColor
                            : Colors.grey[500],
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? widget.accentColor.withValues(alpha: 0.3)
                            : Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${tab.count}',
                        style: TextStyle(
                          fontSize: countFontSize,
                          fontWeight: FontWeight.w600,
                          color: isActive
                              ? widget.accentColor
                              : Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
