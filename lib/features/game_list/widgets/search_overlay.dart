import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/responsive/responsive.dart';
import '../../../models/system_model.dart';

class SearchOverlay extends StatelessWidget {
  final SystemModel system;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final bool isSearching;
  final bool isSearchFocused;
  final String searchQuery;
  final void Function(String) onSearchChanged;
  final VoidCallback onClose;
  final VoidCallback onUnfocus;
  final VoidCallback onSubmitted;

  const SearchOverlay({
    super.key,
    required this.system,
    required this.searchController,
    required this.searchFocusNode,
    required this.isSearching,
    required this.isSearchFocused,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onClose,
    required this.onUnfocus,
    required this.onSubmitted,
  });

  bool get _showBlur => isSearchFocused;

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final topPadding = rs.safeAreaTop + (rs.isSmall ? 10.0 : 16.0);
    final horizontalPadding = rs.isSmall ? rs.spacing.md : rs.spacing.lg;
    final bottomPadding = rs.isSmall ? 10.0 : 16.0;
    final textFieldFontSize = rs.isSmall ? 15.0 : 18.0;
    final borderRadius = rs.isSmall ? 22.0 : 30.0;
    final iconSize = rs.isSmall ? 20.0 : 24.0;
    final contentPadding = rs.isSmall ? 12.0 : 16.0;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          if (_showBlur)
            GestureDetector(
              onTap: onSubmitted,
              child: Container(
                color: Colors.black.withValues(alpha: 0.7),
              ),
            ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.only(
                top: topPadding,
                left: horizontalPadding,
                right: horizontalPadding,
                bottom: bottomPadding,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                boxShadow: [
                  BoxShadow(
                    color: system.accentColor.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: -5,
                  ),
                ],
              ),
              child: CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.escape): () {
                    if (searchFocusNode.hasFocus) {
                      onUnfocus();
                    } else {
                      onClose();
                    }
                  },
                  const SingleActivator(LogicalKeyboardKey.gameButtonB): () {
                    if (searchFocusNode.hasFocus) {
                      onUnfocus();
                    } else {
                      onClose();
                    }
                  },
                  const SingleActivator(LogicalKeyboardKey.goBack): () {
                    if (searchFocusNode.hasFocus) {
                      onUnfocus();
                    } else {
                      onClose();
                    }
                  },
                  const SingleActivator(LogicalKeyboardKey.arrowDown): () {
                    if (searchFocusNode.hasFocus) {
                      onUnfocus();
                    }
                  },
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF252525),
                    borderRadius: BorderRadius.circular(borderRadius),
                    border: Border.all(
                      color: isSearchFocused
                          ? system.accentColor
                          : system.accentColor.withValues(alpha: 0.4),
                      width: 2,
                    ),
                    boxShadow: isSearchFocused
                        ? [
                            BoxShadow(
                              color: system.accentColor.withValues(alpha: 0.4),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: TextField(
                    controller: searchController,
                    focusNode: searchFocusNode,
                    autofocus: false,
                    autocorrect: false,
                    textInputAction: TextInputAction.search,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: textFieldFontSize,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search ${system.name}...',
                      hintStyle: TextStyle(
                        color: Colors.grey[500],
                        fontSize: textFieldFontSize,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: system.accentColor,
                        size: iconSize,
                      ),
                      suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.grey),
                              onPressed: () {
                                searchController.clear();
                                onSearchChanged('');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: contentPadding,
                        vertical: contentPadding,
                      ),
                    ),
                    onChanged: onSearchChanged,
                    onSubmitted: (_) => onSubmitted(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
