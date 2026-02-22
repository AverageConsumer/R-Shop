import 'package:flutter/material.dart';

class SelectionAwareItem extends StatefulWidget {
  final ValueNotifier<int> selectedIndexNotifier;
  final int index;
  final Widget Function(bool isSelected) builder;

  const SelectionAwareItem({
    super.key,
    required this.selectedIndexNotifier,
    required this.index,
    required this.builder,
  });

  @override
  State<SelectionAwareItem> createState() => _SelectionAwareItemState();
}

class _SelectionAwareItemState extends State<SelectionAwareItem> {
  late bool _isSelected;

  @override
  void initState() {
    super.initState();
    _isSelected = widget.selectedIndexNotifier.value == widget.index;
    widget.selectedIndexNotifier.addListener(_onSelectionChanged);
  }

  @override
  void didUpdateWidget(SelectionAwareItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndexNotifier != widget.selectedIndexNotifier) {
      oldWidget.selectedIndexNotifier.removeListener(_onSelectionChanged);
      widget.selectedIndexNotifier.addListener(_onSelectionChanged);
    }
    final nowSelected = widget.selectedIndexNotifier.value == widget.index;
    if (nowSelected != _isSelected) {
      _isSelected = nowSelected;
      // No setState — parent rebuild is already running
    }
  }

  void _onSelectionChanged() {
    final nowSelected = widget.selectedIndexNotifier.value == widget.index;
    if (nowSelected != _isSelected) {
      setState(() => _isSelected = nowSelected);
    }
  }

  @override
  void dispose() {
    widget.selectedIndexNotifier.removeListener(_onSelectionChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(_isSelected);
}
