import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/console_focusable.dart';
import '../../models/config/provider_config.dart';
import '../../models/config/source.dart';
import '../../providers/app_providers.dart';
import '../../services/network_discovery_service.dart';

/// Form to add a manual (non-RomM) [Source]: SMB, FTP, or Web.
///
/// Manual sources don't auto-discover platforms — the user maps them per
/// system later via the source action overlay. This screen only collects
/// connection details + optional auth and creates the bare Source. The
/// mapping editor lives elsewhere so the two concerns stay separate and
/// can be reused (e.g. when re-pairing an existing manual source).
///
/// Controller layout: a single scrollable column of focusable rows. The
/// screen-level Focus owns ↑/↓ traversal and routes B to either exit
/// the active text field or pop the screen, mirroring [ManualPairingScreen].
class ManualSourceAddScreen extends ConsumerStatefulWidget {
  const ManualSourceAddScreen({super.key, required this.type});

  final SourceType type;

  @override
  ConsumerState<ManualSourceAddScreen> createState() =>
      _ManualSourceAddScreenState();
}

class _ManualSourceAddScreenState
    extends ConsumerState<ManualSourceAddScreen> {
  // --- Form controllers (subset depends on type) ---
  final _nameCtl = TextEditingController();
  final _urlCtl = TextEditingController();
  final _hostCtl = TextEditingController();
  final _portCtl = TextEditingController();
  final _shareCtl = TextEditingController();
  final _userCtl = TextEditingController();
  final _passCtl = TextEditingController();

  // --- Wrapper focus nodes (controller traverses these) ---
  late final List<_Field> _fields;
  final _saveFocus = FocusNode(debugLabel: 'manual_add_save');
  final _screenFocus = FocusNode(debugLabel: 'manual_add_screen');

  bool _busy = false;
  String? _error;

  final List<DiscoveredHost> _discovered = [];
  bool _discovering = true;
  StreamSubscription<DiscoveredHost>? _discoverySub;

  @override
  void initState() {
    super.initState();
    // Default ports keep parity with the legacy onboarding flow.
    if (widget.type == SourceType.smb) _portCtl.text = '445';
    if (widget.type == SourceType.ftp) _portCtl.text = '21';
    _fields = _buildFieldList();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fields.first.consoleFocus.requestFocus();
    });
    _startDiscovery();
  }

  void _startDiscovery() {
    if (widget.type == SourceType.web) {
      setState(() => _discovering = false);
      return;
    }
    final stream = NetworkDiscoveryService().discover(
      timeout: const Duration(seconds: 4),
    );
    _discoverySub = stream.listen(
      (host) {
        if (host.kind != DiscoveredKind.smb) return;
        if (!mounted) return;
        setState(() => _discovered.add(host));
      },
      onDone: () {
        if (mounted) setState(() => _discovering = false);
      },
      onError: (e) {
        if (mounted) setState(() => _discovering = false);
      },
      cancelOnError: false,
    );
  }

  void _applyDiscovered(DiscoveredHost host) {
    setState(() {
      _hostCtl.text = host.address;
      if (widget.type == SourceType.smb) _portCtl.text = '445';
      if (widget.type == SourceType.ftp) _portCtl.text = '21';
      if (_nameCtl.text.trim().isEmpty || _nameCtl.text == _defaultName()) {
        _nameCtl.text = host.name.isNotEmpty ? host.name : host.address;
      }
    });
    ref.read(feedbackServiceProvider).tick();
  }

  List<_Field> _buildFieldList() {
    final t = widget.type;
    return [
      _Field('Name', _nameCtl, hint: _defaultName()),
      if (t == SourceType.web)
        _Field('URL', _urlCtl, hint: 'https://example.com/roms', monospace: true),
      if (t == SourceType.smb || t == SourceType.ftp) ...[
        _Field('Host', _hostCtl, hint: 'nas.local or 192.168.1.10', monospace: true),
        _Field('Port', _portCtl, hint: t == SourceType.smb ? '445' : '21',
            keyboardType: TextInputType.number),
      ],
      if (t == SourceType.smb)
        _Field('Share', _shareCtl, hint: 'roms', monospace: true),
      _Field('Username (optional)', _userCtl, hint: 'leave blank for guest'),
      _Field('Password (optional)', _passCtl,
          hint: '••••••••', obscure: true),
    ];
  }

  String _defaultName() {
    switch (widget.type) {
      case SourceType.smb:
        return 'My NAS';
      case SourceType.ftp:
        return 'My FTP';
      case SourceType.web:
        return 'Web Mirror';
      default:
        return 'Source';
    }
  }

  @override
  void dispose() {
    _discoverySub?.cancel();
    _nameCtl.dispose();
    _urlCtl.dispose();
    _hostCtl.dispose();
    _portCtl.dispose();
    _shareCtl.dispose();
    _userCtl.dispose();
    _passCtl.dispose();
    for (final f in _fields) {
      f.consoleFocus.dispose();
      f.textFocus.dispose();
    }
    _saveFocus.dispose();
    _screenFocus.dispose();
    super.dispose();
  }

  bool get _isEditing => _fields.any((f) => f.textFocus.hasFocus);

  KeyEventResult _handleScreenKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.gameButtonB ||
        key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack) {
      if (_isEditing) {
        for (final f in _fields) {
          if (f.textFocus.hasFocus) {
            f.consoleFocus.requestFocus();
            return KeyEventResult.handled;
          }
        }
      }
      Navigator.of(context).maybePop();
      return KeyEventResult.handled;
    }

    if (_isEditing) return KeyEventResult.ignored;

    if (key == LogicalKeyboardKey.arrowDown) {
      _moveFocus(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _moveFocus(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.gameButtonA ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.select) {
      _activateFocused();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  List<FocusNode> get _navOrder =>
      [..._fields.map((f) => f.consoleFocus), _saveFocus];

  void _moveFocus(int delta) {
    final order = _navOrder;
    final cur = order.indexWhere((n) => n.hasFocus);
    final start = cur < 0 ? (delta > 0 ? -1 : order.length) : cur;
    final next = (start + delta).clamp(0, order.length - 1);
    if (next == cur) return;
    final target = order[next];
    if (target.canRequestFocus) {
      target.requestFocus();
      ref.read(feedbackServiceProvider).tick();
    }
  }

  void _activateFocused() {
    for (final f in _fields) {
      if (f.consoleFocus.hasFocus) {
        f.textFocus.requestFocus();
        return;
      }
    }
    if (_saveFocus.hasFocus && !_busy) _save();
  }

  String? _validate() {
    final name = _nameCtl.text.trim();
    if (name.isEmpty) return 'Name is required';
    switch (widget.type) {
      case SourceType.web:
        final url = _urlCtl.text.trim();
        if (url.isEmpty) return 'URL is required';
        if (!url.startsWith(RegExp(r'https?://'))) {
          return 'URL must start with http:// or https://';
        }
        break;
      case SourceType.smb:
        if (_hostCtl.text.trim().isEmpty) return 'Host is required';
        if (_shareCtl.text.trim().isEmpty) return 'Share is required';
        break;
      case SourceType.ftp:
        if (_hostCtl.text.trim().isEmpty) return 'Host is required';
        break;
      default:
        break;
    }
    return null;
  }

  Future<void> _save() async {
    final err = _validate();
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });

    final user = _userCtl.text.trim();
    final pass = _passCtl.text;
    AuthConfig? auth;
    if (user.isNotEmpty || pass.isNotEmpty) {
      auth = AuthConfig(
        user: user.isEmpty ? null : user,
        pass: pass.isEmpty ? null : pass,
      );
    }

    final id = 'src-${widget.type.name}-'
        '${DateTime.now().millisecondsSinceEpoch}';
    final source = Source(
      id: id,
      name: _nameCtl.text.trim(),
      type: widget.type,
      url: widget.type == SourceType.web ? _urlCtl.text.trim() : null,
      host: (widget.type == SourceType.smb || widget.type == SourceType.ftp)
          ? _hostCtl.text.trim()
          : null,
      port: (widget.type == SourceType.smb || widget.type == SourceType.ftp)
          ? int.tryParse(_portCtl.text.trim())
          : null,
      share: widget.type == SourceType.smb ? _shareCtl.text.trim() : null,
      auth: auth,
      autoMap: false,
      priority: 5,
      enabled: true,
      knownPlatforms: const {},
    );

    try {
      await ref
          .read(sourcesProvider.notifier)
          .addSourceWithMappings(source, const {});
      if (!mounted) return;
      Navigator.of(context).pop<Source?>(source);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Failed to save: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Focus(
          focusNode: _screenFocus,
          autofocus: true,
          onKeyEvent: _handleScreenKey,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add ${_typeLabel(widget.type)} source',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Connection only — map systems to remote folders '
                      'after saving from the source actions menu.',
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 12),
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.type != SourceType.web)
                              _buildDiscoverySection(),
                            for (final f in _fields) ...[
                              _label(f.label),
                              _textBox(f),
                              const SizedBox(height: 12),
                            ],
                            if (_error != null) ...[
                              const SizedBox(height: 4),
                              Text(_error!,
                                  style: const TextStyle(
                                      color: Colors.redAccent, fontSize: 13)),
                            ],
                            const SizedBox(height: 16),
                            ConsoleFocusable(
                              focusNode: _saveFocus,
                              onSelect: _busy ? null : _save,
                              child: Container(
                                width: double.infinity,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor
                                      .withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: AppTheme.primaryColor, width: 2),
                                ),
                                child: _busy
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppTheme.primaryColor,
                                        ),
                                      )
                                    : const Text(
                                        'Save source',
                                        style: TextStyle(
                                          color: AppTheme.primaryColor,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 1,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _typeLabel(SourceType t) {
    switch (t) {
      case SourceType.smb:
        return 'SMB';
      case SourceType.ftp:
        return 'FTP';
      case SourceType.web:
        return 'Web';
      default:
        return t.name.toUpperCase();
    }
  }

  Widget _buildDiscoverySection() {
    if (_discovered.isEmpty && !_discovering) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (_discovering)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primaryColor,
                    ),
                  )
                else
                  const Icon(Icons.lan_outlined,
                      size: 14, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  _discovering
                      ? 'Searching network…'
                      : 'Found on your network',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            if (_discovered.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final host in _discovered)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: ConsoleFocusable(
                    focusScale: 1.0,
                    onSelect: () => _applyDiscovered(host),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF252525),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.folder_shared,
                              size: 16, color: Colors.white54),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(host.name,
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 13)),
                                Text(
                                  '${host.address}:${host.port}',
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward,
                              size: 14, color: Colors.white38),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                color: Colors.grey, fontSize: 11, letterSpacing: 1.2)),
      );

  Widget _textBox(_Field f) {
    return ConsoleFocusable(
      focusNode: f.consoleFocus,
      focusScale: 1.0,
      onSelect: () => f.textFocus.requestFocus(),
      child: ListenableBuilder(
        listenable: f.textFocus,
        builder: (context, _) {
          final hasFocus = f.textFocus.hasFocus;
          return Container(
            decoration: BoxDecoration(
              color: const Color(0xFF252525),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: hasFocus
                    ? AppTheme.primaryColor
                    : AppTheme.primaryColor.withValues(alpha: 0.4),
                width: 2,
              ),
            ),
            child: TextField(
              controller: f.controller,
              focusNode: f.textFocus,
              obscureText: f.obscure,
              keyboardType: f.keyboardType,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontFamily: f.monospace ? 'monospace' : null,
              ),
              decoration: InputDecoration(
                hintText: f.hint,
                hintStyle: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 14,
                  fontFamily: f.monospace ? 'monospace' : null,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 14),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Field {
  _Field(
    this.label,
    this.controller, {
    this.hint = '',
    this.obscure = false,
    this.monospace = false,
    this.keyboardType,
  })  : consoleFocus = FocusNode(debugLabel: 'mas_${label}_wrap'),
        textFocus = FocusNode(
            skipTraversal: true, debugLabel: 'mas_${label}_text');

  final String label;
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final bool monospace;
  final TextInputType? keyboardType;
  final FocusNode consoleFocus;
  final FocusNode textFocus;
}
