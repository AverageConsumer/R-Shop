import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/console_focusable.dart';
import '../../l10n/app_localizations.dart';
import '../../models/config/source.dart';
import '../../providers/app_providers.dart';
import '../../providers/game_providers.dart';
import '../../services/http_endpoint_failover.dart';

/// Edits connection routes of one source; never adds or selects sources.
class SourceEndpointsScreen extends ConsumerStatefulWidget {
  const SourceEndpointsScreen({super.key, required this.source});
  final Source source;

  @override
  ConsumerState<SourceEndpointsScreen> createState() =>
      _SourceEndpointsScreenState();
}

class _SourceEndpointsScreenState extends ConsumerState<SourceEndpointsScreen> {
  late final _urls =
      TextEditingController(text: widget.source.fallbackUrls.join('\n'));
  final _field = FocusNode();
  final _text = FocusNode();
  final _save = FocusNode();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _urls.dispose();
    _field.dispose();
    _text.dispose();
    _save.dispose();
    super.dispose();
  }

  Future<void> _persist() async {
    if (_busy) return;
    final l = L.of(context);
    final List<String> urls;
    try {
      urls = HttpEndpointRoutes(
              widget.source.url ?? '',
              _urls.text
                  .split('\n')
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .toList())
          .bases
          .skip(1)
          .toList();
    } on FormatException {
      setState(() => _error = l.sources_endpointInvalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(sourcesProvider.notifier)
          .setFallbackUrls(widget.source.id, urls);
      ref
        ..invalidate(bootstrappedConfigProvider)
        ..invalidate(gamesProvider);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = l.sources_endpointSaveFailed;
        });
      }
    }
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.gameButtonB ||
        key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack) {
      if (_text.hasFocus) {
        _field.requestFocus();
      } else if (!_busy) {
        Navigator.of(context).maybePop();
      }
      return KeyEventResult.handled;
    }
    if (_text.hasFocus) return KeyEventResult.ignored;
    if (key == LogicalKeyboardKey.gameButtonA ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.select) {
      if (_save.hasFocus) {
        _persist();
      } else {
        _text.requestFocus();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _save.requestFocus();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _field.requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.sources_endpoints)),
      body: Focus(
        onKeyEvent: _handleKey,
        child: Center(
            child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(padding: const EdgeInsets.all(24), children: [
            Text(widget.source.name,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(l.sources_endpointHint),
            const SizedBox(height: 20),
            Text(l.sources_primaryAddress),
            SelectableText(widget.source.url ?? ''),
            const SizedBox(height: 20),
            ConsoleFocusable(
              autofocus: true,
              focusNode: _field,
              onSelect: _text.requestFocus,
              child: TextField(
                controller: _urls,
                focusNode: _text,
                enabled: !_busy,
                minLines: 3,
                maxLines: 6,
                keyboardType: TextInputType.multiline,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                    labelText: l.sources_alternativeAddresses,
                    border: const OutlineInputBorder()),
              ),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ElevatedButton(
                focusNode: _save,
                onPressed: _busy ? null : _persist,
                child: Text(l.common_save)),
          ]),
        )),
      ),
    );
  }
}
