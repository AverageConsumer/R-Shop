import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'input_providers.dart';

class OverlayFocusScope extends ConsumerStatefulWidget {
  final Widget child;
  final OverlayPriority priority;
  final bool isVisible;
  final VoidCallback? onClose;
  final bool trapFocus;

  const OverlayFocusScope({
    super.key,
    required this.child,
    required this.priority,
    required this.isVisible,
    this.onClose,
    this.trapFocus = true,
  });

  @override
  ConsumerState<OverlayFocusScope> createState() => _OverlayFocusScopeState();
}

class _OverlayFocusScopeState extends ConsumerState<OverlayFocusScope> {
  final FocusScopeNode _scopeNode = FocusScopeNode(debugLabel: 'OverlayScope');
  late final StateController<OverlayPriority> _priorityController;
  bool _hasClaimed = false;

  @override
  void initState() {
    super.initState();
    _priorityController = ref.read(overlayPriorityProvider.notifier);
    if (widget.isVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _claimPriority();
        }
      });
    }
  }

  @override
  void didUpdateWidget(OverlayFocusScope oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isVisible && !oldWidget.isVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _claimPriority();
      });
    } else if (!widget.isVisible && oldWidget.isVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _releasePriority();
      });
    }
  }

  @override
  void dispose() {
    if (_hasClaimed) {
      _hasClaimed = false;
      final controller = _priorityController;
      final priority = widget.priority;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          if (controller.state == priority) {
            controller.state = OverlayPriority.none;
          }
        } catch (_) {}
      });
    }
    _scopeNode.dispose();
    super.dispose();
  }

  void _claimPriority() {
    final currentPriority = _priorityController.state;
    if (widget.priority.level > currentPriority.level) {
      _priorityController.state = widget.priority;
    }
    _hasClaimed = true;
    _scopeNode.requestFocus();
  }

  void _releasePriority() {
    _hasClaimed = false;
    final currentPriority = _priorityController.state;
    if (currentPriority == widget.priority) {
      _priorityController.state = OverlayPriority.none;
      restoreMainFocus(ref);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) {
      return const SizedBox.shrink();
    }

    return FocusScope(
      node: _scopeNode,
      autofocus: true,
      child: widget.child,
    );
  }
}

class DialogFocusScope extends ConsumerStatefulWidget {
  final Widget child;
  final bool isVisible;
  final VoidCallback? onClose;

  const DialogFocusScope({
    super.key,
    required this.child,
    required this.isVisible,
    this.onClose,
  });

  @override
  ConsumerState<DialogFocusScope> createState() => _DialogFocusScopeState();
}

class _DialogFocusScopeState extends ConsumerState<DialogFocusScope> {
  final FocusScopeNode _scopeNode = FocusScopeNode(debugLabel: 'DialogScope');
  final FocusNode _rootFocusNode = FocusNode(debugLabel: 'DialogRoot');
  late final StateController<OverlayPriority> _priorityController;
  bool _hasClaimed = false;

  @override
  void initState() {
    super.initState();
    _priorityController = ref.read(overlayPriorityProvider.notifier);
    if (widget.isVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _claimPriority();
        }
      });
    }
  }

  @override
  void didUpdateWidget(DialogFocusScope oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isVisible && !oldWidget.isVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _claimPriority();
        }
      });
    } else if (!widget.isVisible && oldWidget.isVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _releasePriority();
      });
    }
  }

  @override
  void dispose() {
    if (_hasClaimed) {
      _hasClaimed = false;
      final controller = _priorityController;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          if (controller.state == OverlayPriority.dialog) {
            controller.state = OverlayPriority.none;
          }
        } catch (_) {}
      });
    }
    _scopeNode.dispose();
    _rootFocusNode.dispose();
    super.dispose();
  }

  void _claimPriority() {
    final currentPriority = _priorityController.state;
    if (OverlayPriority.dialog.level > currentPriority.level) {
      _priorityController.state = OverlayPriority.dialog;
    }
    _hasClaimed = true;
    _rootFocusNode.requestFocus();
  }

  void _releasePriority() {
    _hasClaimed = false;
    final currentPriority = _priorityController.state;
    if (currentPriority == OverlayPriority.dialog) {
      _priorityController.state = OverlayPriority.none;
      restoreMainFocus(ref);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) {
      return const SizedBox.shrink();
    }

    return FocusScope(
      node: _scopeNode,
      autofocus: true,
      child: Focus(
        focusNode: _rootFocusNode,
        autofocus: true,
        child: widget.child,
      ),
    );
  }
}

class SearchFocusScope extends ConsumerStatefulWidget {
  final Widget child;
  final bool isVisible;
  final VoidCallback? onClose;
  final FocusNode? textFieldFocusNode;

  const SearchFocusScope({
    super.key,
    required this.child,
    required this.isVisible,
    this.onClose,
    this.textFieldFocusNode,
  });

  @override
  ConsumerState<SearchFocusScope> createState() => _SearchFocusScopeState();
}

class _SearchFocusScopeState extends ConsumerState<SearchFocusScope> {
  final FocusScopeNode _scopeNode = FocusScopeNode(debugLabel: 'SearchScope');
  late final StateController<OverlayPriority> _priorityController;
  bool _hasClaimed = false;

  @override
  void initState() {
    super.initState();
    _priorityController = ref.read(overlayPriorityProvider.notifier);
    if (widget.isVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _claimPriority();
        }
      });
    }
  }

  @override
  void didUpdateWidget(SearchFocusScope oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isVisible && !oldWidget.isVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _claimPriority();
        }
      });
    } else if (!widget.isVisible && oldWidget.isVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _releasePriority();
      });
    }
  }

  @override
  void dispose() {
    if (_hasClaimed) {
      _hasClaimed = false;
      final controller = _priorityController;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          if (controller.state == OverlayPriority.search) {
            controller.state = OverlayPriority.none;
          }
        } catch (_) {}
      });
    }
    _scopeNode.dispose();
    super.dispose();
  }

  void _claimPriority() {
    final currentPriority = _priorityController.state;
    if (OverlayPriority.search.level > currentPriority.level) {
      _priorityController.state = OverlayPriority.search;
    }
    _hasClaimed = true;
    if (widget.textFieldFocusNode != null) {
      widget.textFieldFocusNode!.requestFocus();
    } else {
      _scopeNode.requestFocus();
    }
  }

  void _releasePriority() {
    _hasClaimed = false;
    final currentPriority = _priorityController.state;
    if (currentPriority == OverlayPriority.search) {
      _priorityController.state = OverlayPriority.none;
      restoreMainFocus(ref);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) {
      return const SizedBox.shrink();
    }

    return FocusScope(
      node: _scopeNode,
      autofocus: true,
      child: widget.child,
    );
  }
}
