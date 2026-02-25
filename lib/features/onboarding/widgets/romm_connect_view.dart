import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/responsive/responsive.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/console_focusable.dart';
import '../../../providers/app_providers.dart';
import '../onboarding_controller.dart';
import 'chat_bubble.dart';
import 'connection_test_indicator.dart';

class RommConnectView extends ConsumerStatefulWidget {
  final VoidCallback onComplete;
  const RommConnectView({super.key, required this.onComplete});

  @override
  ConsumerState<RommConnectView> createState() => _RommConnectViewState();
}

class _RommConnectViewState extends ConsumerState<RommConnectView> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};
  final Map<String, FocusNode> _consoleFocusNodes = {};
  bool _didAutoFill = false;

  TextEditingController _getController(String key, String initialValue) {
    if (!_controllers.containsKey(key)) {
      _controllers[key] = TextEditingController(text: initialValue);
    }
    return _controllers[key]!;
  }

  FocusNode _getFocusNode(String key) {
    if (!_focusNodes.containsKey(key)) {
      _focusNodes[key] = FocusNode(skipTraversal: true);
    }
    return _focusNodes[key]!;
  }

  FocusNode _getConsoleFocusNode(String key) {
    if (!_consoleFocusNodes.containsKey(key)) {
      _consoleFocusNodes[key] = FocusNode(debugLabel: 'romm_console_$key');
    }
    return _consoleFocusNodes[key]!;
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final f in _focusNodes.values) {
      f.dispose();
    }
    for (final f in _consoleFocusNodes.values) {
      f.dispose();
    }
    super.dispose();
  }

  void _autoFillFromStorage() {
    if (_didAutoFill) return;
    _didAutoFill = true;

    final storage = ref.read(storageServiceProvider);
    final globalUrl = storage.getRommUrl();
    if (globalUrl != null && globalUrl.isNotEmpty) {
      _getController('url', '').text = globalUrl;
      ref
          .read(onboardingControllerProvider.notifier)
          .updateRommSetupField('url', globalUrl);
    }

    final authJson = storage.getRommAuth();
    if (authJson != null) {
      try {
        final map = jsonDecode(authJson) as Map<String, dynamic>;
        if (map['api_key'] != null) {
          final v = map['api_key'] as String;
          _getController('apiKey', '').text = v;
          ref
              .read(onboardingControllerProvider.notifier)
              .updateRommSetupField('apiKey', v);
        }
        if (map['user'] != null) {
          final v = map['user'] as String;
          _getController('user', '').text = v;
          ref
              .read(onboardingControllerProvider.notifier)
              .updateRommSetupField('user', v);
        }
        if (map['pass'] != null) {
          final v = map['pass'] as String;
          _getController('pass', '').text = v;
          ref
              .read(onboardingControllerProvider.notifier)
              .updateRommSetupField('pass', v);
        }
      } catch (e) {
        debugPrint('RommSetupStep: auth autofill failed: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingControllerProvider);
    final rs = context.rs;
    final controller = ref.read(onboardingControllerProvider.notifier);
    final rommSetup = state.rommSetupState;
    if (rommSetup == null) return const SizedBox.shrink();

    // Auto-fill from global storage on first build if fields are empty
    if (!_didAutoFill && rommSetup.url.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _autoFillFromStorage();
      });
    }

    return FocusScope(
      child: Column(
        key: const ValueKey('rommConnect'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ChatBubble(
            key: ValueKey('bubble_rommConnect_${state.isTestingConnection}'
                '_${state.connectionTestSuccess}'
                '_${state.connectionTestError ?? ''}'),
            message: state.isTestingConnection
                ? "Hang on, connecting to your RomM server..."
                : state.connectionTestError != null
                    ? "Couldn't reach your server. Check the URL and credentials."
                    : "Enter your RomM server details and I'll discover your consoles.",
            accentColor: state.connectionTestError != null
                ? Colors.redAccent
                : null,
            onComplete: widget.onComplete,
          ),
          SizedBox(height: rs.spacing.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                left: rs.isSmall ? 40 : 60,
                bottom: 64,
              ),
              child: FocusTraversalGroup(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTextField(rs, 'url', 'URL',
                          'https://romm.example.com', rommSetup.url, controller),
                      SizedBox(height: rs.spacing.sm),
                      _buildTextField(rs, 'apiKey', 'API Key', '(optional)',
                          rommSetup.apiKey, controller),
                      SizedBox(height: rs.spacing.sm),
                      _buildTextField(rs, 'user', 'Username', '(optional)',
                          rommSetup.user, controller),
                      SizedBox(height: rs.spacing.sm),
                      _buildTextField(rs, 'pass', 'Password', '(optional)',
                          rommSetup.pass, controller,
                          obscure: true),
                      SizedBox(height: rs.spacing.md),
                      ConnectionTestIndicator(
                        isTesting: state.isTestingConnection,
                        isSuccess: state.connectionTestSuccess,
                        error: state.connectionTestError,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    Responsive rs,
    String key,
    String label,
    String hint,
    String currentValue,
    OnboardingController controller, {
    bool obscure = false,
  }) {
    final fontSize = rs.isSmall ? 12.0 : 14.0;
    final labelFontSize = rs.isSmall ? 10.0 : 12.0;
    final fieldController = _getController(key, currentValue);
    final textFocusNode = _getFocusNode(key);
    final consoleFocusNode = _getConsoleFocusNode(key);

    return ConsoleFocusable(
      key: ValueKey('romm_field_$key'),
      focusNode: consoleFocusNode,
      autofocus: key == 'url',
      focusScale: 1.0,
      borderRadius: rs.radius.sm,
      onSelect: () => textFocusNode.requestFocus(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: labelFontSize,
              letterSpacing: 1,
            ),
          ),
          SizedBox(height: rs.spacing.xs),
          ListenableBuilder(
            listenable: textFocusNode,
            builder: (context, child) {
              final hasFocus = textFocusNode.hasFocus;
              return Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF252525),
                  borderRadius: BorderRadius.circular(rs.radius.sm),
                  border: Border.all(
                    color: hasFocus
                        ? AppTheme.primaryColor
                        : AppTheme.primaryColor.withValues(alpha: 0.4),
                    width: 2,
                  ),
                  boxShadow: hasFocus
                      ? [
                          BoxShadow(
                            color: AppTheme.primaryColor.withValues(alpha: 0.3),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: child,
              );
            },
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.escape, includeRepeats: false): () =>
                    consoleFocusNode.requestFocus(),
                const SingleActivator(LogicalKeyboardKey.gameButtonB, includeRepeats: false): () =>
                    consoleFocusNode.requestFocus(),
                const SingleActivator(LogicalKeyboardKey.goBack, includeRepeats: false): () =>
                    consoleFocusNode.requestFocus(),
              },
              child: TextField(
                controller: fieldController,
                focusNode: textFocusNode,
                obscureText: obscure,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: fontSize,
                  fontFamily: 'monospace',
                ),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: fontSize,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: rs.spacing.md,
                    vertical: rs.spacing.md,
                  ),
                ),
                onChanged: (value) =>
                    controller.updateRommSetupField(key, value),
                onSubmitted: (_) => consoleFocusNode.requestFocus(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
