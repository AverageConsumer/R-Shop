import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/console_focusable.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/config/source.dart';
import '../../../widgets/console_hud.dart';
import '../../../models/system_model.dart';
import '../../../providers/app_providers.dart';
import '../../../services/romm_api_service.dart';
import '../../../services/romm_pairing_service.dart';
import '../../../services/romm_platform_matcher.dart';

/// Username/password (or API key) login form for **pre-4.8 RomM servers**
/// that don't support the QR Client-Token flow yet.
///
/// Lives in the welcome chooser path as a sub-tap-target on the QR tile.
/// On success the screen returns the hydrated [Source] (with platforms
/// already discovered) so the caller can hand it off to
/// `OnboardingController.completeFromRommPairing` exactly like the QR path.
///
/// While the user types a URL the screen probes `/api/heartbeat` in the
/// background; if the server reports >= 4.8 we surface a hint nudging the
/// user back to QR ("easier than typing creds") without blocking the form.
class RommLegacyLoginScreen extends ConsumerStatefulWidget {
  const RommLegacyLoginScreen({super.key});

  @override
  ConsumerState<RommLegacyLoginScreen> createState() =>
      _RommLegacyLoginScreenState();
}

class _RommLegacyLoginScreenState
    extends ConsumerState<RommLegacyLoginScreen> {
  final _nameCtl = TextEditingController();
  final _urlCtl = TextEditingController();
  final _userCtl = TextEditingController();
  final _passCtl = TextEditingController();

  late List<_Field> _fields;
  final _backFocus = FocusNode(debugLabel: 'romm_legacy_back');
  final _saveFocus = FocusNode(debugLabel: 'romm_legacy_save');
  final _screenFocus = FocusNode(debugLabel: 'romm_legacy_screen');

  bool _busy = false;
  String? _error;
  String? _probedVersion;
  bool _probeSupportsTokens = false;
  Timer? _probeDebounce;
  bool _fieldsInitialized = false;

  @override
  void initState() {
    super.initState();
    _fields = [];
    _urlCtl.addListener(_scheduleProbe);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_fieldsInitialized) {
      _fieldsInitialized = true;
      final l = L.of(context);
      _nameCtl.text = l.rommLogin_nameDefault;
      _fields = [
        _Field(l.rommLogin_name, _nameCtl, hint: l.rommLogin_nameDefault),
        _Field(l.rommLogin_serverUrl, _urlCtl,
            hint: 'http://192.168.1.10:8080', monospace: true),
        _Field(l.rommLogin_username, _userCtl, hint: l.rommLogin_usernameHint),
        _Field(l.rommLogin_password, _passCtl, hint: l.rommLogin_passwordHint, obscure: true),
      ];
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fields.first.consoleFocus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _probeDebounce?.cancel();
    _urlCtl.removeListener(_scheduleProbe);
    _nameCtl.dispose();
    _urlCtl.dispose();
    _userCtl.dispose();
    _passCtl.dispose();
    for (final f in _fields) {
      f.consoleFocus.dispose();
      f.textFocus.dispose();
    }
    _backFocus.dispose();
    _saveFocus.dispose();
    _screenFocus.dispose();
    super.dispose();
  }

  void _scheduleProbe() {
    _probeDebounce?.cancel();
    final url = _urlCtl.text.trim();
    if (url.length < 7 || !url.startsWith(RegExp(r'https?://'))) {
      if (_probedVersion != null) {
        setState(() {
          _probedVersion = null;
          _probeSupportsTokens = false;
        });
      }
      return;
    }
    _probeDebounce = Timer(const Duration(milliseconds: 600), () async {
      final version = await RommPairingService().probeServer(url);
      if (!mounted) return;
      setState(() {
        _probedVersion = version;
        _probeSupportsTokens = supportsClientTokens(version);
      });
    });
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
      [_backFocus, ..._fields.map((f) => f.consoleFocus), _saveFocus];

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
    if (_backFocus.hasFocus) {
      Navigator.of(context).maybePop();
      return;
    }
    for (final f in _fields) {
      if (f.consoleFocus.hasFocus) {
        f.textFocus.requestFocus();
        return;
      }
    }
    if (_saveFocus.hasFocus && !_busy) _save();
  }

  String? _validate() {
    final l = L.of(context);
    if (_nameCtl.text.trim().isEmpty) return l.rommLogin_nameRequired;
    final url = _urlCtl.text.trim();
    if (url.isEmpty) return l.rommLogin_serverUrlRequired;
    if (!url.startsWith(RegExp(r'https?://'))) {
      return 'URL must start with http:// or https://';
    }
    if (_userCtl.text.trim().isEmpty && _passCtl.text.isEmpty) {
      return l.rommLogin_credentialsRequired;
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

    final url = _urlCtl.text.trim();
    final user = _userCtl.text.trim();
    final pass = _passCtl.text;

    try {
      final api = RommApiService();
      // Build a probe source so fetchPlatforms uses the same auth path
      final probeSource = buildLegacyRommSource(
        name: _nameCtl.text.trim(),
        serverUrl: url,
        user: user,
        pass: pass,
      );
      final platforms =
          await api.fetchPlatforms(url, auth: probeSource.auth);
      final allSystemIds = SystemModel.supportedSystems.map((s) => s.id);
      final knownPlatforms =
          RommPlatformMatcher.buildKnownPlatforms(allSystemIds, platforms);

      final hydrated = buildLegacyRommSource(
        name: _nameCtl.text.trim(),
        serverUrl: url,
        user: user,
        pass: pass,
        knownPlatforms: knownPlatforms,
      );

      if (!mounted) return;
      Navigator.of(context).pop<Source?>(hydrated);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Login failed: $e';
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
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
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
                          L.of(context).rommLogin_title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(left: 48),
                      child: Text(
                        'Use this for RomM servers older than 4.8 — the ones '
                        'without QR pairing.',
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final f in _fields) ...[
                              _textBox(f),
                              const SizedBox(height: 12),
                            ],
                    if (_probedVersion != null) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: _probeSupportsTokens
                              ? Colors.amber.withValues(alpha: 0.12)
                              : Colors.green.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _probeSupportsTokens
                                ? Colors.amber.withValues(alpha: 0.5)
                                : Colors.green.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _probeSupportsTokens
                                  ? Icons.qr_code_2
                                  : Icons.check_circle_outline,
                              color: _probeSupportsTokens
                                  ? Colors.amber
                                  : Colors.greenAccent,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _probeSupportsTokens
                                    ? 'RomM $_probedVersion supports QR — '
                                        'tap B and use the QR option for an easier setup.'
                                    : 'RomM $_probedVersion reachable',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(_error!,
                          style: const TextStyle(
                              color: Colors.redAccent, fontSize: 13)),
                    ],
                    const SizedBox(height: 16),
                    ConsoleFocusable(
                      focusNode: _saveFocus,
                      focusScale: 1.0,
                      onSelect: _busy ? null : _save,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.18),
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
        child: Text(text,
            style: const TextStyle(
                color: Colors.grey, fontSize: 11, letterSpacing: 1.2)),
      );

  Widget _textBox(_Field f) {
    return ConsoleFocusable(
      focusNode: f.consoleFocus,
      focusScale: 1.0,
      onSelect: () => f.textFocus.requestFocus(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _label(f.label),
          ListenableBuilder(
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
        ],
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
  })  : consoleFocus = FocusNode(debugLabel: 'romm_legacy_${label}_wrap'),
        textFocus = FocusNode(
            skipTraversal: true, debugLabel: 'romm_legacy_${label}_text');

  final String label;
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final bool monospace;
  final FocusNode consoleFocus;
  final FocusNode textFocus;
}
