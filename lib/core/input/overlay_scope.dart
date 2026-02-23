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
  late final OverlayPriorityManager _priorityManager;
  int? _claimToken;

  @override
  void initState() {
    super.initState();
    _priorityManager = ref.read(overlayPriorityProvider.notifier);
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
    final token = _claimToken;
    if (token != null) {
      _claimToken = null;
      final manager = _priorityManager;
      final priority = widget.priority;
      Future(() {
        if (!manager.release(token)) {
          manager.releaseByPriority(priority);
        }
      });
    }
    _scopeNode.dispose();
    super.dispose();
  }

  void _claimPriority() {
    _claimToken ??= _priorityManager.claim(widget.priority);
    _scopeNode.requestFocus();
  }

  void _releasePriority() {
    final token = _claimToken;
    if (token == null) return;
    _claimToken = null;
    if (!_priorityManager.release(token)) {
      _priorityManager.releaseByPriority(widget.priority);
    }
    restoreMainFocus(ref);
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
  late final OverlayPriorityManager _priorityManager;
  int? _claimToken;

  @override
  void initState() {
    super.initState();
    _priorityManager = ref.read(overlayPriorityProvider.notifier);
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
    final token = _claimToken;
    if (token != null) {
      _claimToken = null;
      final manager = _priorityManager;
      Future(() {
        if (!manager.release(token)) {
          manager.releaseByPriority(OverlayPriority.dialog);
        }
      });
    }
    _scopeNode.dispose();
    _rootFocusNode.dispose();
    super.dispose();
  }

  void _claimPriority() {
    _claimToken ??= _priorityManager.claim(OverlayPriority.dialog);
    _rootFocusNode.requestFocus();
  }

  void _releasePriority() {
    final token = _claimToken;
    if (token == null) return;
    _claimToken = null;
    if (!_priorityManager.release(token)) {
      _priorityManager.releaseByPriority(OverlayPriority.dialog);
    }
    restoreMainFocus(ref);
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
  late final OverlayPriorityManager _priorityManager;
  int? _claimToken;

  @override
  void initState() {
    super.initState();
    _priorityManager = ref.read(overlayPriorityProvider.notifier);
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
    final token = _claimToken;
    if (token != null) {
      _claimToken = null;
      final manager = _priorityManager;
      Future(() {
        if (!manager.release(token)) {
          manager.releaseByPriority(OverlayPriority.search);
        }
      });
    }
    _scopeNode.dispose();
    super.dispose();
  }

  void _claimPriority() {
    _claimToken ??= _priorityManager.claim(OverlayPriority.search);
    if (widget.textFieldFocusNode != null) {
      widget.textFieldFocusNode!.requestFocus();
    } else {
      _scopeNode.requestFocus();
    }
  }

  void _releasePriority() {
    final token = _claimToken;
    if (token == null) return;
    _claimToken = null;
    if (!_priorityManager.release(token)) {
      _priorityManager.releaseByPriority(OverlayPriority.search);
    }
    restoreMainFocus(ref);
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
