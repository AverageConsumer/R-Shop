import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/console_focusable.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/app_providers.dart';
import '../../services/romm_pairing_service.dart';
import 'pairing_result_screen.dart';

/// Manual pairing fallback for users who can't or don't want to use the QR
/// scanner. Two fields: server URL + 8-character pairing code.
///
/// Live feedback: as soon as the URL field loses focus or the user pauses
/// typing, the screen calls [RommPairingService.probeServer] and shows a
/// green check + RomM version, or a red error.
class ManualPairingScreen extends ConsumerStatefulWidget {
  const ManualPairingScreen({super.key});

  @override
  ConsumerState<ManualPairingScreen> createState() =>
      _ManualPairingScreenState();
}

class _ManualPairingScreenState extends ConsumerState<ManualPairingScreen> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  // Wrapper focus nodes (controller navigates between these).
  final FocusNode _urlConsoleFocus = FocusNode(debugLabel: 'mp_url_wrap');
  final FocusNode _codeConsoleFocus = FocusNode(debugLabel: 'mp_code_wrap');
  final FocusNode _submitFocus = FocusNode(debugLabel: 'mp_submit');
  final FocusNode _backFocus = FocusNode(debugLabel: 'mp_back');
  // Text-edit focus nodes — skipTraversal so the controller can never
  // land here via arrow keys; the user has to press A on the wrapper
  // first to start editing, and B to leave editing again.
  final FocusNode _urlTextFocus =
      FocusNode(skipTraversal: true, debugLabel: 'mp_url_text');
  final FocusNode _codeTextFocus =
      FocusNode(skipTraversal: true, debugLabel: 'mp_code_text');
  // Top-level focus that catches every key on this screen so [B] always
  // exits and the screen owns its own ↑/↓ traversal between wrappers.
  final FocusNode _screenFocus = FocusNode(debugLabel: 'mp_screen');

  Timer? _probeDebounce;
  String? _probeVersion;
  bool _probing = false;
  String? _probeError;

  bool _busy = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _urlController.addListener(_onUrlChanged);
    // Land on the URL wrapper after first frame so the user can hit
    // [A] to start typing or ↓ to skip straight to the code field.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _urlConsoleFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _probeDebounce?.cancel();
    _urlController.removeListener(_onUrlChanged);
    _urlController.dispose();
    _codeController.dispose();
    _urlConsoleFocus.dispose();
    _urlTextFocus.dispose();
    _codeConsoleFocus.dispose();
    _codeTextFocus.dispose();
    _submitFocus.dispose();
    _backFocus.dispose();
    _screenFocus.dispose();
    super.dispose();
  }

  /// Ordered list of wrapper focus nodes. ↑/↓ walk through this list.
  List<FocusNode> get _navOrder =>
      [_urlConsoleFocus, _codeConsoleFocus, _submitFocus];

  /// True when one of the text fields is currently in edit mode (soft
  /// keyboard up). [B] in this state should exit editing instead of
  /// popping the screen.
  bool get _isEditing => _urlTextFocus.hasFocus || _codeTextFocus.hasFocus;

  KeyEventResult _handleScreenKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;

    // [B] / Escape: leave editing first, only then close the screen.
    if (key == LogicalKeyboardKey.gameButtonB ||
        key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack) {
      if (_isEditing) {
        if (_urlTextFocus.hasFocus) {
          _urlConsoleFocus.requestFocus();
        } else {
          _codeConsoleFocus.requestFocus();
        }
        return KeyEventResult.handled;
      }
      Navigator.of(context).maybePop();
      return KeyEventResult.handled;
    }

    // While editing, let arrow keys / A / Enter behave normally inside
    // the TextField (cursor movement, line break, etc.).
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

  void _moveFocus(int delta) {
    final order = _navOrder;
    final currentIndex = order.indexWhere((n) => n.hasFocus);
    final start = currentIndex < 0 ? (delta > 0 ? -1 : order.length) : currentIndex;
    final next = (start + delta).clamp(0, order.length - 1);
    if (next == currentIndex) return; // edge — no move
    final target = order[next];
    if (target.canRequestFocus) {
      target.requestFocus();
      ref.read(feedbackServiceProvider).tick();
    }
  }

  void _activateFocused() {
    if (_urlConsoleFocus.hasFocus) {
      _urlTextFocus.requestFocus();
    } else if (_codeConsoleFocus.hasFocus) {
      _codeTextFocus.requestFocus();
    } else if (_submitFocus.hasFocus) {
      if (!_busy) _submit();
    } else if (_backFocus.hasFocus) {
      Navigator.of(context).maybePop();
    }
  }

  void _onUrlChanged() {
    _probeDebounce?.cancel();
    setState(() {
      _probeVersion = null;
      _probeError = null;
    });
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    _probeDebounce = Timer(const Duration(milliseconds: 600), _probe);
  }

  Future<void> _probe() async {
    final url = _urlController.text.trim();
    if (url.isEmpty || !url.startsWith(RegExp(r'https?://'))) {
      setState(() => _probeError = 'URL must start with http:// or https://');
      return;
    }
    setState(() {
      _probing = true;
      _probeError = null;
      _probeVersion = null;
    });
    final svc = ref.read(rommPairingServiceProvider);
    final version = await svc.probeServer(url);
    if (!mounted) return;
    setState(() {
      _probing = false;
      _probeVersion = version;
      _probeError = version == null
          ? L.of(context).pairing_serverNotReachable
          : null;
    });
  }

  Future<void> _submit() async {
    final url = _urlController.text.trim();
    final code = _codeController.text.trim().toUpperCase();
    if (url.isEmpty || code.isEmpty) {
      setState(() => _submitError = L.of(context).pairing_serverUrlRequired);
      return;
    }
    setState(() {
      _busy = true;
      _submitError = null;
    });
    final svc = ref.read(rommPairingServiceProvider);
    try {
      final result = await svc.exchangeCode(serverUrl: url, code: code);
      if (!mounted) return;
      final accepted = await showPairingResultScreen(context, result);
      if (!mounted) return;
      Navigator.of(context).pop<RommPairResult?>(accepted ? result : null);
    } on RommPairCodeExpiredException catch (e) {
      setState(() => _submitError = e.message);
    } on RommPairServerUnreachableException catch (e) {
      setState(() => _submitError = e.message);
    } on RommPairingException catch (e) {
      setState(() => _submitError = e.message);
    } catch (e) {
      setState(() => _submitError = 'Unexpected error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
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
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ConsoleFocusable(
                          focusNode: _backFocus,
                          onSelect: () => Navigator.of(context).maybePop(),
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(Icons.arrow_back, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          L.of(context).pairing_manualTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${L.of(context).pairing_manualInstructions}'
                      'Profile → API Tokens → Pair Device.',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                    ),
                    const SizedBox(height: 24),
                    _label(L.of(context).pairing_serverUrl),
                    _textField(
                      controller: _urlController,
                      consoleFocus: _urlConsoleFocus,
                      textFocus: _urlTextFocus,
                      hint: 'https://romm.example.com',
                      monospace: true,
                    ),
                    const SizedBox(height: 6),
                    _probeStatus(),
                    const SizedBox(height: 16),
                    _label(L.of(context).pairing_pairingCode),
                    _textField(
                      controller: _codeController,
                      consoleFocus: _codeConsoleFocus,
                      textFocus: _codeTextFocus,
                      hint: L.of(context).pairing_pairingCodeHint,
                      monospace: true,
                      uppercase: true,
                    ),
                    if (_submitError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _submitError!,
                        style: const TextStyle(
                            color: Colors.redAccent, fontSize: 13),
                      ),
                    ],
                    const SizedBox(height: 24),
                    ConsoleFocusable(
                      focusNode: _submitFocus,
                      onSelect: _busy ? null : _submit,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.primaryColor,
                            width: 2,
                          ),
                        ),
                        child: _busy
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.primaryColor,
                                ),
                              )
                            : Text(
                                L.of(context).common_connect,
                                style: const TextStyle(
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
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 11,
            letterSpacing: 1.2,
          ),
        ),
      );

  Widget _textField({
    required TextEditingController controller,
    required FocusNode consoleFocus,
    required FocusNode textFocus,
    required String hint,
    bool monospace = false,
    bool uppercase = false,
  }) {
    return ConsoleFocusable(
      focusNode: consoleFocus,
      focusScale: 1.0,
      // A on the wrapper enters edit mode. The screen-level handler
      // also routes A here, but keep onSelect set so touch taps work
      // identically to controller A presses.
      onSelect: () => textFocus.requestFocus(),
      child: ListenableBuilder(
        listenable: textFocus,
        builder: (context, _) {
          final hasFocus = textFocus.hasFocus;
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
              controller: controller,
              focusNode: textFocus,
              textCapitalization: uppercase
                  ? TextCapitalization.characters
                  : TextCapitalization.none,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontFamily: monospace ? 'monospace' : null,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 14,
                  fontFamily: monospace ? 'monospace' : null,
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

  Widget _probeStatus() {
    if (_probing) {
      return Row(
        children: [
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text(L.of(context).pairing_probingServer,
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      );
    }
    if (_probeVersion != null) {
      return Row(
        children: [
          const Icon(Icons.check_circle,
              color: Colors.greenAccent, size: 14),
          const SizedBox(width: 6),
          Text(
            'RomM $_probeVersion reachable',
            style: const TextStyle(
                color: Colors.greenAccent, fontSize: 12),
          ),
        ],
      );
    }
    if (_probeError != null) {
      return Row(
        children: [
          const Icon(Icons.error_outline,
              color: Colors.redAccent, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _probeError!,
              style: const TextStyle(
                  color: Colors.redAccent, fontSize: 12),
            ),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}
