import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/console_focusable.dart';
import '../../l10n/app_localizations.dart';
import '../../models/config/source.dart';
import '../../providers/app_providers.dart';
import '../../widgets/console_hud.dart';

/// Adds or edits one connection route on a source.
///
/// A route is just an address: the same RomM server has one on the LAN and one
/// on the internet. Credentials live on the [Source], not here — both routes
/// reach the same server with the same account, so asking for the password
/// again per route would be wrong.
///
/// Returns the edited [SourceEndpoint] via `Navigator.pop`, or null on cancel.
class EndpointEditScreen extends ConsumerStatefulWidget {
  const EndpointEditScreen({
    super.key,
    required this.sourceType,
    required this.existingEndpoints,
    this.initial,
  });

  final SourceType sourceType;

  /// Used to reject a second route to an address the source already has —
  /// duplicates would make which one is "live" arbitrary.
  final List<SourceEndpoint> existingEndpoints;

  /// null when adding.
  final SourceEndpoint? initial;

  @override
  ConsumerState<EndpointEditScreen> createState() => _EndpointEditScreenState();
}

class _EndpointEditScreenState extends ConsumerState<EndpointEditScreen> {
  final FocusNode _screenFocus = FocusNode(debugLabel: 'ep_edit_screen');
  final FocusNode _saveFocus = FocusNode(debugLabel: 'ep_edit_save');

  late final _label = TextEditingController(text: widget.initial?.label ?? '');
  late final _url = TextEditingController(text: widget.initial?.url ?? '');
  late final _host = TextEditingController(text: widget.initial?.host ?? '');
  late final _port =
      TextEditingController(text: widget.initial?.port?.toString() ?? '');
  late final _share = TextEditingController(text: widget.initial?.share ?? '');

  List<_Field> _fields = const [];
  String? _error;
  bool _built = false;

  bool get _isUrlType =>
      widget.sourceType == SourceType.romm ||
      widget.sourceType == SourceType.web;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Field labels are localised, so they cannot be built in initState.
    if (_built) return;
    _built = true;
    final l = L.of(context);
    _fields = [
      _Field(l.manualSource_name, _label, hint: '區網 / 遠端'),
      if (_isUrlType)
        _Field(l.manualSource_url, _url,
            hint: 'http://192.168.1.50:8090', monospace: true)
      else ...[
        _Field(l.manualSource_host, _host,
            hint: l.manualSource_hostHint, monospace: true),
        _Field(l.manualSource_port, _port,
            keyboardType: TextInputType.number, monospace: true),
        if (widget.sourceType == SourceType.smb)
          _Field(l.manualSource_share, _share,
              hint: l.manualSource_shareHint, monospace: true),
      ],
    ];
  }

  @override
  void dispose() {
    for (final f in _fields) {
      f.dispose();
    }
    _screenFocus.dispose();
    _saveFocus.dispose();
    _label.dispose();
    _url.dispose();
    _host.dispose();
    _port.dispose();
    _share.dispose();
    super.dispose();
  }

  bool get _isEditing => _fields.any((f) => f.textFocus.hasFocus);

  List<FocusNode> get _navOrder =>
      [..._fields.map((f) => f.consoleFocus), _saveFocus];

  KeyEventResult _handleScreenKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.gameButtonB ||
        key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack) {
      // While typing, B leaves the keyboard rather than the screen — losing a
      // half-typed address to a stray B press would be infuriating.
      if (_isEditing) {
        for (final f in _fields) {
          if (f.textFocus.hasFocus) {
            f.consoleFocus.requestFocus();
            return KeyEventResult.handled;
          }
        }
      }
      _cancel();
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
    return KeyEventResult.ignored;
  }

  void _moveFocus(int delta) {
    final order = _navOrder;
    final current = order.indexWhere((n) => n.hasFocus);
    final next = current < 0 ? 0 : (current + delta) % order.length;
    order[(next + order.length) % order.length].requestFocus();
    ref.read(feedbackServiceProvider).tick();
  }

  SourceEndpoint? _build(L l) {
    final label = _label.text.trim();
    if (_isUrlType) {
      final url = _url.text.trim();
      if (url.isEmpty) {
        setState(() => _error = l.manualSource_hostRequired);
        return null;
      }
      return SourceEndpoint(
        id: widget.initial?.id ?? _newId(),
        label: label,
        url: url,
      );
    }
    final host = _host.text.trim();
    if (host.isEmpty) {
      setState(() => _error = l.manualSource_hostRequired);
      return null;
    }
    if (widget.sourceType == SourceType.smb && _share.text.trim().isEmpty) {
      setState(() => _error = l.manualSource_shareRequired);
      return null;
    }
    return SourceEndpoint(
      id: widget.initial?.id ?? _newId(),
      label: label,
      host: host,
      port: int.tryParse(_port.text.trim()),
      share: widget.sourceType == SourceType.smb ? _share.text.trim() : null,
    );
  }

  /// Ids only need to be unique within one source, and routes are added by
  /// hand one at a time, so a timestamp is enough — no uuid dependency.
  String _newId() => 'ep-${DateTime.now().millisecondsSinceEpoch}';

  void _save() {
    final l = L.of(context);
    final built = _build(l);
    if (built == null) {
      ref.read(feedbackServiceProvider).cancel();
      return;
    }

    final clash = widget.existingEndpoints
        .where((e) => e.id != built.id)
        .any((e) => e.sameAddressAs(built));
    if (clash) {
      setState(() => _error = l.sources_routeDuplicate);
      ref.read(feedbackServiceProvider).cancel();
      return;
    }

    // An unlabelled route still needs something readable in the switcher.
    final finished =
        built.label.isEmpty ? built.copyWith(label: built.addressLabel) : built;

    ref.read(feedbackServiceProvider).confirm();
    Navigator.of(context).pop<SourceEndpoint?>(finished);
  }

  void _cancel() {
    ref.read(feedbackServiceProvider).cancel();
    Navigator.of(context).pop<SourceEndpoint?>(null);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final title =
        widget.initial == null ? l.sources_addRoute : l.sources_editRoute;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Focus(
          focusNode: _screenFocus,
          autofocus: true,
          onKeyEvent: _handleScreenKey,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    for (int i = 0; i < _fields.length; i++) ...[
                      if (i > 0) const SizedBox(height: 14),
                      _FieldEditor(field: _fields[i], autofocus: i == 0),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: const TextStyle(
                          color: Color(0xFFE57373),
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    ConsoleFocusable(
                      focusNode: _saveFocus,
                      onSelect: _save,
                      borderRadius: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          l.common_save,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
              ConsoleHud(
                a: HudAction(l.common_save, onTap: _save),
                b: HudAction(l.common_back, onTap: _cancel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field {
  _Field(
    this.label,
    this.controller, {
    this.hint = '',
    this.monospace = false,
    this.keyboardType,
  })  : consoleFocus = FocusNode(debugLabel: 'ep_${label}_wrap'),
        textFocus =
            FocusNode(skipTraversal: true, debugLabel: 'ep_${label}_text');

  final String label;
  final TextEditingController controller;
  final String hint;
  final bool monospace;
  final TextInputType? keyboardType;
  final FocusNode consoleFocus;
  final FocusNode textFocus;

  void dispose() {
    consoleFocus.dispose();
    textFocus.dispose();
  }
}

/// Wraps the text field in a [ConsoleFocusable] so the D-pad traverses fields
/// and [A] drops into the keyboard — the same two-node arrangement the manual
/// source form uses. The inner node has `skipTraversal` so the D-pad never
/// lands on it directly.
class _FieldEditor extends StatelessWidget {
  const _FieldEditor({required this.field, this.autofocus = false});

  final _Field field;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return ConsoleFocusable(
      focusNode: field.consoleFocus,
      autofocus: autofocus,
      onSelect: () => field.textFocus.requestFocus(),
      borderRadius: 8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              field.label,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          ListenableBuilder(
            listenable: field.textFocus,
            builder: (context, _) {
              final hasFocus = field.textFocus.hasFocus;
              return Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF252525),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: hasFocus
                        ? Colors.white
                        : AppTheme.primaryColor.withValues(alpha: 0.4),
                    width: 2,
                  ),
                ),
                child: TextField(
                  controller: field.controller,
                  focusNode: field.textFocus,
                  keyboardType: field.keyboardType,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontFamily: field.monospace ? 'monospace' : null,
                  ),
                  decoration: InputDecoration(
                    hintText: field.hint,
                    hintStyle: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 14,
                      fontFamily: field.monospace ? 'monospace' : null,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
