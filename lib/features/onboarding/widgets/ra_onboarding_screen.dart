import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/console_focusable.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/system_model.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/ra_providers.dart';
import '../../../widgets/console_hud.dart';

/// Lightweight RetroAchievements setup screen used by both onboarding and
/// settings. Matches the visual style of [RommLegacyLoginScreen] — dark
/// background, ConsoleFocusable fields, D-pad navigation. On successful
/// connection test the credentials are saved immediately.
///
/// When [popOnSuccess] is true (default, used by onboarding), the screen
/// auto-pops after a brief success indicator. When false (settings), it
/// stays open so the user can also trigger a manual sync.
class RaOnboardingScreen extends ConsumerStatefulWidget {
  const RaOnboardingScreen({super.key, this.popOnSuccess = true});

  final bool popOnSuccess;

  @override
  ConsumerState<RaOnboardingScreen> createState() =>
      _RaOnboardingScreenState();
}

class _RaOnboardingScreenState extends ConsumerState<RaOnboardingScreen> {
  final _userCtl = TextEditingController();
  final _keyCtl = TextEditingController();

  late List<_Field> _fields;
  final _connectFocus = FocusNode(debugLabel: 'ra_ob_connect');
  final _syncFocus = FocusNode(debugLabel: 'ra_ob_sync');
  final _disconnectFocus = FocusNode(debugLabel: 'ra_ob_disconnect');
  final _screenFocus = FocusNode(debugLabel: 'ra_ob_screen');

  bool _busy = false;
  bool? _success;
  String? _error;
  bool _isConfigured = false;
  bool _fieldsInitialized = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill if already configured
    final storage = ref.read(storageServiceProvider);
    _userCtl.text = storage.getRaUsername() ?? '';
    _keyCtl.text = storage.getRaApiKey() ?? '';
    _isConfigured = storage.isRaConfigured;
    _fields = [];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_fieldsInitialized) {
      _fieldsInitialized = true;
      final l = L.of(context);
      _fields = [
        _Field(l.ra_usernameLabel, _userCtl, hint: l.ra_usernameHint),
        _Field(l.ra_apiKeyLabel, _keyCtl, hint: l.ra_apiKeyHint,
            monospace: true),
      ];
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fields.first.consoleFocus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _userCtl.dispose();
    _keyCtl.dispose();
    for (final f in _fields) {
      f.consoleFocus.dispose();
      f.textFocus.dispose();
    }
    _connectFocus.dispose();
    _syncFocus.dispose();
    _disconnectFocus.dispose();
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

  List<FocusNode> get _navOrder => [
        ..._fields.map((f) => f.consoleFocus),
        _connectFocus,
        if (_isConfigured) _syncFocus,
        if (_isConfigured) _disconnectFocus,
      ];

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
    if (_connectFocus.hasFocus && !_busy) _connect();
    if (_syncFocus.hasFocus) _syncNow();
    if (_disconnectFocus.hasFocus) _disconnect();
  }

  void _syncNow() {
    final syncService = ref.read(raSyncServiceProvider.notifier);
    final raSystems = SystemModel.supportedSystems
        .where((s) => s.hasRetroAchievements)
        .toList();
    syncService.syncAll(raSystems, force: true);
    ref.read(feedbackServiceProvider).tick();
  }

  void _disconnect() {
    final storage = ref.read(storageServiceProvider);
    storage.setRaUsername('');
    storage.setRaApiKey('');
    storage.setRaEnabled(false);
    setState(() {
      _userCtl.clear();
      _keyCtl.clear();
      _isConfigured = false;
      _success = null;
      _error = null;
    });
    ref.read(feedbackServiceProvider).tick();
  }

  String? _validate() {
    final l = L.of(context);
    if (_userCtl.text.trim().isEmpty) return l.ra_usernameRequired;
    if (_keyCtl.text.trim().isEmpty) return l.ra_apiKeyRequired;
    return null;
  }

  Future<void> _connect() async {
    final err = _validate();
    if (err != null) {
      setState(() {
        _error = err;
        _success = null;
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });

    final username = _userCtl.text.trim();
    final apiKey = _keyCtl.text.trim();

    try {
      final result = await ref.read(raApiServiceProvider).testConnection(
            username: username,
            apiKey: apiKey,
          );

      if (!mounted) return;

      if (result.success) {
        final storage = ref.read(storageServiceProvider);
        await storage.setRaUsername(username);
        await storage.setRaApiKey(apiKey);
        await storage.setRaEnabled(true);

        setState(() {
          _busy = false;
          _success = true;
          _isConfigured = true;
        });

        if (widget.popOnSuccess) {
          // Brief pause to show success, then pop
          await Future<void>.delayed(const Duration(milliseconds: 800));
          if (!mounted) return;
          Navigator.of(context).pop();
        }
      } else {
        setState(() {
          _busy = false;
          _success = false;
          _error = result.error ?? L.of(context).ra_connectionFailed;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _success = false;
        _error = '${L.of(context).ra_connectionFailed}: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Stack(
        children: [
          SafeArea(
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
                          l.ra_title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${l.ra_subtitle}'
                          'Get your API key at retroachievements.org/controlpanel.php',
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 12),
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
                                if (_success != null) ...[
                                  const SizedBox(height: 4),
                                  _resultBanner(),
                                ],
                                if (_error != null && _success == null) ...[
                                  const SizedBox(height: 4),
                                  Text(_error!,
                                      style: const TextStyle(
                                          color: Colors.redAccent,
                                          fontSize: 13)),
                                ],
                                const SizedBox(height: 16),
                                _actionButton(
                                  focusNode: _connectFocus,
                                  label:
                                      _busy ? l.providerForm_testingConnection : 'Test & connect',
                                  icon: Icons.wifi_tethering,
                                  busy: _busy,
                                  onSelect: _busy ? null : _connect,
                                  primary: true,
                                ),
                                if (_isConfigured) ...[
                                  const SizedBox(height: 12),
                                  _buildSyncButton(),
                                  const SizedBox(height: 12),
                                  _actionButton(
                                    focusNode: _disconnectFocus,
                                    label: l.ra_disconnect,
                                    icon: Icons.link_off,
                                    onSelect: _disconnect,
                                    destructive: true,
                                  ),
                                ],
                                // Extra bottom padding so content doesn't
                                // hide behind the HUD.
                                const SizedBox(height: 56),
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
          ConsoleHud(
            b: HudAction(l.common_back, onTap: () => Navigator.maybePop(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncButton() {
    final syncState = ref.watch(raSyncServiceProvider);
    final isSyncing = syncState.isSyncing;
    final label = isSyncing
        ? 'Syncing ${syncState.currentSystem ?? ''}… '
            '(${syncState.completedSystems}/${syncState.totalSystems})'
        : L.of(context).ra_syncNow;

    return _actionButton(
      focusNode: _syncFocus,
      label: label,
      icon: Icons.sync,
      busy: isSyncing,
      onSelect: isSyncing ? null : _syncNow,
    );
  }

  Widget _actionButton({
    required FocusNode focusNode,
    required String label,
    required IconData icon,
    required VoidCallback? onSelect,
    bool busy = false,
    bool primary = false,
    bool destructive = false,
  }) {
    final color = destructive
        ? Colors.redAccent
        : primary
            ? AppTheme.primaryColor
            : Colors.white70;

    return ListenableBuilder(
      listenable: focusNode,
      builder: (context, _) {
        final isFocused = focusNode.hasFocus;
        final effectiveColor = isFocused ? Colors.white : color;
        final bgColor = isFocused
            ? color.withValues(alpha: 0.3)
            : color.withValues(alpha: 0.12);

        return ConsoleFocusable(
          focusNode: focusNode,
          focusScale: 1.02,
          focusBorderColor: Colors.white,
          borderRadius: 10,
          onSelect: onSelect,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: busy
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child:
                        CircularProgressIndicator(strokeWidth: 2, color: effectiveColor),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 16, color: effectiveColor),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: TextStyle(
                          color: effectiveColor,
                          fontSize: 15,
                          fontWeight: isFocused ? FontWeight.w700 : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _resultBanner() {
    final ok = _success == true;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: ok
            ? Colors.green.withValues(alpha: 0.10)
            : Colors.redAccent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: ok
              ? Colors.green.withValues(alpha: 0.4)
              : Colors.redAccent.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle_outline : Icons.error_outline,
            color: ok ? Colors.greenAccent : Colors.redAccent,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              ok
                  ? 'Connected — achievements will show on your games'
                  : _error ?? L.of(context).ra_connectionFailed,
              style: TextStyle(
                color: ok ? Colors.white70 : Colors.redAccent,
                fontSize: 12,
              ),
            ),
          ),
        ],
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
                        ? Colors.white
                        : AppTheme.primaryColor.withValues(alpha: 0.4),
                    width: 2,
                  ),
                ),
                child: TextField(
                  controller: f.controller,
                  focusNode: f.textFocus,
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
    this.monospace = false,
  })  : consoleFocus = FocusNode(debugLabel: 'ra_ob_${label}_wrap'),
        textFocus = FocusNode(
            skipTraversal: true, debugLabel: 'ra_ob_${label}_text');

  final String label;
  final TextEditingController controller;
  final String hint;
  final bool monospace;
  final FocusNode consoleFocus;
  final FocusNode textFocus;
}
