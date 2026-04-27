import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/console_focusable.dart';
import '../../l10n/app_localizations.dart';
import '../../services/romm_pairing_service.dart';
import '../../widgets/console_hud.dart';

/// Confirmation screen shown after a successful pairing-code exchange.
class PairingResultScreen extends StatefulWidget {
  const PairingResultScreen({super.key, required this.result});

  final RommPairResult result;

  @override
  State<PairingResultScreen> createState() => _PairingResultScreenState();
}

class _PairingResultScreenState extends State<PairingResultScreen> {
  final FocusNode _screenFocus = FocusNode();
  final FocusNode _confirmFocus = FocusNode();
  final FocusNode _cancelFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _confirmFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _screenFocus.dispose();
    _confirmFocus.dispose();
    _cancelFocus.dispose();
    super.dispose();
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown) {
      if (_confirmFocus.hasFocus) {
        _cancelFocus.requestFocus();
      } else {
        _confirmFocus.requestFocus();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  String _expiryLabel() {
    final l = L.of(context);
    final exp = widget.result.expiresAt;
    if (exp == null) return l.pairing_neverExpires;
    final delta = exp.difference(DateTime.now());
    if (delta.isNegative) return l.pairing_alreadyExpired;
    if (delta.inDays >= 2) return 'Expires in ${delta.inDays} days';
    if (delta.inHours >= 2) return 'Expires in ${delta.inHours} hours';
    return 'Expires in ${delta.inMinutes} minutes';
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final result = widget.result;
    final scopes = result.scopes;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Stack(
        children: [
          Focus(
            focusNode: _screenFocus,
            onKeyEvent: _onKeyEvent,
            child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          children: [
                            const Icon(Icons.check_circle,
                                color: Colors.greenAccent, size: 24),
                            const SizedBox(width: 10),
                            Text(
                              l.pairing_successTitle,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Info + Permissions side by side
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Left: connection details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _row(l.pairing_server,
                                        _hostOf(result.serverUrl)),
                                    _row(l.pairing_token, result.name),
                                    _row(l.pairing_userId,
                                        result.userId.toString()),
                                    _row(l.pairing_expiry, _expiryLabel()),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 24),
                              // Right: permissions
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      l.pairing_permissions,
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 10,
                                        letterSpacing: 1.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 4,
                                      runSpacing: 4,
                                      children: [
                                        for (final scope in scopes)
                                          _scopeBadge(scope),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Buttons
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: ConsoleFocusable(
                                  focusNode: _cancelFocus,
                                  focusScale: 1.0,
                                  onSelect: () =>
                                      Navigator.of(context).pop(false),
                                  child: _button(l.common_cancel, Colors.grey),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ConsoleFocusable(
                                  focusNode: _confirmFocus,
                                  focusScale: 1.0,
                                  onSelect: () =>
                                      Navigator.of(context).pop(true),
                                  child: _button(
                                      l.pairing_addServer, AppTheme.primaryColor),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 48),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          ConsoleHud(
            a: HudAction(l.pairing_addServer, onTap: () => Navigator.of(context).pop(true)),
            b: HudAction(l.common_cancel,
                onTap: () => Navigator.of(context).pop(false)),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 11,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _scopeBadge(String scope) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        scope,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 9,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  Widget _button(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 2),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
        ),
      ),
    );
  }

  String _hostOf(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    return '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
  }
}

/// Push the [PairingResultScreen] and return whether the user confirmed.
Future<bool> showPairingResultScreen(
  BuildContext context,
  RommPairResult result,
) async {
  final accepted = await Navigator.of(context).push<bool>(
    PageRouteBuilder(
      pageBuilder: (_, __, ___) => PairingResultScreen(result: result),
    ),
  );
  return accepted ?? false;
}
