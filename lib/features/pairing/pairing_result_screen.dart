import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/console_focusable.dart';
import '../../services/romm_pairing_service.dart';

/// Confirmation screen shown after a successful pairing-code exchange.
///
/// Surfaces the most relevant fields from [RommPairResult] (server, name,
/// scopes, expiry) and asks the user to either accept and store the token
/// or cancel and discard it. Used by both [QrPairingScreen] and
/// [ManualPairingScreen].
class PairingResultScreen extends StatefulWidget {
  const PairingResultScreen({super.key, required this.result});

  final RommPairResult result;

  @override
  State<PairingResultScreen> createState() => _PairingResultScreenState();
}

class _PairingResultScreenState extends State<PairingResultScreen> {
  final FocusNode _confirmFocus = FocusNode();
  final FocusNode _cancelFocus = FocusNode();

  @override
  void dispose() {
    _confirmFocus.dispose();
    _cancelFocus.dispose();
    super.dispose();
  }

  String? _expiryLabel() {
    final exp = widget.result.expiresAt;
    if (exp == null) return 'Never expires';
    final now = DateTime.now();
    final delta = exp.difference(now);
    if (delta.isNegative) return 'Already expired';
    if (delta.inDays >= 2) return 'Expires in ${delta.inDays} days';
    if (delta.inHours >= 2) return 'Expires in ${delta.inHours} hours';
    return 'Expires in ${delta.inMinutes} minutes';
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.greenAccent, size: 28),
                      SizedBox(width: 12),
                      Text(
                        'Pairing successful',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _row('Server', _hostOf(result.serverUrl)),
                  _row('Token name', result.name),
                  _row('User ID', result.userId.toString()),
                  _row('Expiry', _expiryLabel() ?? '—'),
                  const SizedBox(height: 12),
                  const Text(
                    'Permissions',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final scope in result.scopes)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: AppTheme.primaryColor.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            scope,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: ConsoleFocusable(
                          focusNode: _cancelFocus,
                          onSelect: () => Navigator.of(context).pop(false),
                          child: _button('Cancel', Colors.grey),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ConsoleFocusable(
                          focusNode: _confirmFocus,
                          autofocus: true,
                          onSelect: () => Navigator.of(context).pop(true),
                          child: _button('Add server', AppTheme.primaryColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '[A] Add   [B] Cancel',
                    style: TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
                letterSpacing: 1,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
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
      opaque: true,
      pageBuilder: (_, __, ___) => CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.gameButtonB):
              () => Navigator.of(context).pop(false),
          const SingleActivator(LogicalKeyboardKey.escape):
              () => Navigator.of(context).pop(false),
        },
        child: PairingResultScreen(result: result),
      ),
    ),
  );
  return accepted ?? false;
}
