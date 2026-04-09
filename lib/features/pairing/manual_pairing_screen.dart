import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/console_focusable.dart';
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
  final FocusNode _urlConsoleFocus = FocusNode();
  final FocusNode _urlTextFocus = FocusNode();
  final FocusNode _codeConsoleFocus = FocusNode();
  final FocusNode _codeTextFocus = FocusNode();
  final FocusNode _submitFocus = FocusNode();
  final FocusNode _backFocus = FocusNode();

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
    super.dispose();
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
          ? 'Server not reachable or not a RomM instance'
          : null;
    });
  }

  Future<void> _submit() async {
    final url = _urlController.text.trim();
    final code = _codeController.text.trim().toUpperCase();
    if (url.isEmpty || code.isEmpty) {
      setState(() => _submitError = 'Server URL and code are required');
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
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.gameButtonB): () =>
                Navigator.of(context).maybePop(),
            const SingleActivator(LogicalKeyboardKey.escape): () =>
                Navigator.of(context).maybePop(),
          },
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
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
                        const Text(
                          'Manual pairing',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Generate the code in your RomM web UI under '
                      'Profile → API Tokens → Pair Device.',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                    ),
                    const SizedBox(height: 24),
                    _label('Server URL'),
                    _textField(
                      controller: _urlController,
                      consoleFocus: _urlConsoleFocus,
                      textFocus: _urlTextFocus,
                      hint: 'https://romm.example.com',
                      autofocus: true,
                      monospace: true,
                    ),
                    const SizedBox(height: 6),
                    _probeStatus(),
                    const SizedBox(height: 16),
                    _label('Pairing code'),
                    _textField(
                      controller: _codeController,
                      consoleFocus: _codeConsoleFocus,
                      textFocus: _codeTextFocus,
                      hint: 'ABCD-1234',
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
                            : const Text(
                                'Connect',
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
    bool autofocus = false,
    bool monospace = false,
    bool uppercase = false,
  }) {
    return ConsoleFocusable(
      focusNode: consoleFocus,
      autofocus: autofocus,
      focusScale: 1.0,
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
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.escape): () =>
                    consoleFocus.requestFocus(),
                const SingleActivator(LogicalKeyboardKey.gameButtonB): () =>
                    consoleFocus.requestFocus(),
              },
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
            ),
          );
        },
      ),
    );
  }

  Widget _probeStatus() {
    if (_probing) {
      return Row(
        children: const [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 8),
          Text('Probing server…',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
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
    return const SizedBox(height: 16);
  }
}
