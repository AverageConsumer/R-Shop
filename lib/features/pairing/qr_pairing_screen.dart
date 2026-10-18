import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/console_focusable.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/app_providers.dart';
import '../../services/romm_pairing_service.dart';
import 'manual_pairing_screen.dart';
import 'pairing_result_screen.dart';

/// QR-code based pairing flow.
///
/// Live camera preview from `mobile_scanner`. When a code is detected we
/// stop the camera, exchange the code for a token, and push the
/// [PairingResultScreen]. On success this screen pops with the
/// [RommPairResult]; on cancel/error it stays open so the user can retry.
class QrPairingScreen extends ConsumerStatefulWidget {
  const QrPairingScreen({super.key});

  @override
  ConsumerState<QrPairingScreen> createState() => _QrPairingScreenState();
}

class _QrPairingScreenState extends ConsumerState<QrPairingScreen> {
  late final MobileScannerController _controller;
  bool _processing = false;
  String? _error;
  final FocusNode _backFocus = FocusNode();
  final FocusNode _manualFocus = FocusNode();
  final FocusNode _screenFocus = FocusNode(debugLabel: 'qr_pair_screen');

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      formats: const [BarcodeFormat.qrCode],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _backFocus.dispose();
    _manualFocus.dispose();
    _screenFocus.dispose();
    super.dispose();
  }

  /// Top-level key handler so [B]/Escape always closes the scanner and
  /// [A]/Enter always opens manual entry, regardless of which inner
  /// widget happens to have focus. The QR screen has no real "primary
  /// action" target since the camera does the work, so it makes more
  /// sense to bind A globally to the only manual-action escape hatch
  /// than to require the user to tab onto a button first.
  KeyEventResult _handleScreenKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.gameButtonB ||
        key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack) {
      Navigator.of(context).maybePop();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.gameButtonA ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.select) {
      _openManual();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null || code.isEmpty) return;
    setState(() {
      _processing = true;
      _error = null;
    });
    await _controller.stop();
    await _handlePayload(code);
  }

  Future<void> _handlePayload(String payload) async {
    final l = L.of(context);
    final svc = ref.read(rommPairingServiceProvider);
    try {
      final result = await svc.pairFromQr(payload);
      if (!mounted) return;
      final accepted = await showPairingResultScreen(context, result);
      if (!mounted) return;
      if (accepted) {
        Navigator.of(context).pop<RommPairResult?>(result);
        return;
      }
      // user cancelled — resume scanning
      setState(() => _processing = false);
      await _controller.start();
    } on RommPairInvalidQrException {
      _showError(l.pairing_invalidQr);
    } on RommPairCodeExpiredException catch (e) {
      _showError(e.message);
    } on RommPairServerUnreachableException catch (e) {
      _showError(e.message);
    } on RommPairingException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Unexpected error: $e');
    }
  }

  Future<void> _showError(String message) async {
    if (!mounted) return;
    setState(() {
      _error = message;
      _processing = false;
    });
    await _controller.start();
  }

  Future<void> _openManual() async {
    await _controller.stop();
    if (!mounted) return;
    final result = await Navigator.of(context).push<RommPairResult?>(
      MaterialPageRoute(builder: (_) => const ManualPairingScreen()),
    );
    if (!mounted) return;
    if (result != null) {
      Navigator.of(context).pop<RommPairResult?>(result);
      return;
    }
    await _controller.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Focus(
          focusNode: _screenFocus,
          autofocus: true,
          onKeyEvent: _handleScreenKey,
          child: Stack(
            children: [
              // Camera preview (or solid black on devices without one).
              // We deliberately do NOT use mobile_scanner's errorBuilder:
              // its default UI conflicts with our reticle/bottom hint and
              // the bottom "Enter code manually" button is the obvious
              // fallback that works on every device anyway.
              Positioned.fill(
                child: MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                  errorBuilder: (_, __, ___) =>
                      const ColoredBox(color: Colors.black),
                ),
              ),
              // Top bar
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.85),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  child: Row(
                    children: [
                      ConsoleFocusable(
                        focusNode: _backFocus,
                        onSelect: () => Navigator.of(context).maybePop(),
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(Icons.arrow_back,
                              color: Colors.white, size: 26),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        L.of(context).pairing_scanQrTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Reticle
              Center(
                child: IgnorePointer(
                  child: Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppTheme.primaryColor.withValues(alpha: 0.85),
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              // Bottom hint + manual entry
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.9),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
                  child: Column(
                    children: [
                      if (_error != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.redAccent),
                          ),
                          child: Text(
                            _error!,
                            style: const TextStyle(
                                color: Colors.redAccent, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Text(
                        L.of(context).pairing_scanQrHint,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      ConsoleFocusable(
                        focusNode: _manualFocus,
                        onSelect: _openManual,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.6),
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            L.of(context).pairing_enterManually,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13),
                          ),
                        ),
                      ),
                      if (_processing)
                        const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: CircularProgressIndicator(
                            color: AppTheme.primaryColor,
                            strokeWidth: 2,
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
    );
  }
}

