import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/responsive/responsive.dart';
import '../../../core/widgets/console_focusable.dart';
import '../onboarding_controller.dart';
import 'chat_bubble.dart';
import 'romm_action_button.dart';

class RaSetupStep extends ConsumerWidget {
  final VoidCallback onComplete;

  const RaSetupStep({super.key, required this.onComplete});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingControllerProvider);
    final ra = state.raSetupState;
    if (ra == null) return const SizedBox.shrink();

    if (!ra.wantsSetup) {
      return _RaAskView(onComplete: onComplete);
    }
    return _RaConnectView(onComplete: onComplete);
  }
}

class _RaAskView extends ConsumerWidget {
  final VoidCallback onComplete;
  const _RaAskView({required this.onComplete});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(onboardingControllerProvider.notifier);
    final rs = context.rs;
    final labelFontSize = rs.isSmall ? 10.0 : 12.0;
    final iconSize = rs.isSmall ? 14.0 : 18.0;

    return FocusScope(
      child: Column(
          key: const ValueKey('raAsk'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ChatBubble(
              message:
                  "Do you have a RetroAchievements account? I can show achievement info for your games and track your progress!",
              onComplete: onComplete,
            ),
            SizedBox(height: rs.spacing.lg),
            Padding(
              padding: EdgeInsets.only(left: rs.isSmall ? 40 : 60),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(bottom: rs.spacing.sm),
                    child: Row(
                      children: [
                        Icon(Icons.emoji_events_rounded,
                            color: const Color(0xFFFFD54F), size: iconSize),
                        SizedBox(width: rs.spacing.sm),
                        Text(
                          'RETROACHIEVEMENTS',
                          style: TextStyle(
                            color: const Color(0xFFFFD54F),
                            fontSize: labelFontSize,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FocusTraversalGroup(
                    child: Row(
                      children: [
                        Expanded(
                          child: RommActionButton(
                            label: 'Yes, connect my account',
                            icon: Icons.emoji_events_rounded,
                            color: const Color(0xFFFFD54F),
                            autofocus: true,
                            onTap: () => controller.raSetupAnswer(true),
                          ),
                        ),
                        SizedBox(width: rs.spacing.md),
                        Expanded(
                          child: RommActionButton(
                            label: 'No, skip',
                            icon: Icons.skip_next_rounded,
                            color: Colors.grey,
                            onTap: () => controller.raSetupAnswer(false),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: rs.spacing.md),
                  Text(
                    'You can always set this up later in Settings.',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: rs.isSmall ? 10.0 : 12.0,
                    ),
                  ),
                ],
              ),
            ),
          ],
      ),
    );
  }
}

class _RaConnectView extends ConsumerStatefulWidget {
  final VoidCallback onComplete;
  const _RaConnectView({required this.onComplete});

  @override
  ConsumerState<_RaConnectView> createState() => _RaConnectViewState();
}

class _RaConnectViewState extends ConsumerState<_RaConnectView> {
  final _usernameController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _usernameFocus = FocusNode(skipTraversal: true);
  final _apiKeyFocus = FocusNode(skipTraversal: true);
  final _usernameConsoleFocus = FocusNode(debugLabel: 'ra_console_username');
  final _apiKeyConsoleFocus = FocusNode(debugLabel: 'ra_console_apiKey');

  @override
  void initState() {
    super.initState();
    final ra = ref.read(onboardingControllerProvider).raSetupState;
    if (ra != null) {
      _usernameController.text = ra.username;
      _apiKeyController.text = ra.apiKey;
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _apiKeyController.dispose();
    _usernameFocus.dispose();
    _apiKeyFocus.dispose();
    _usernameConsoleFocus.dispose();
    _apiKeyConsoleFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingControllerProvider);
    final ra = state.raSetupState;
    if (ra == null) return const SizedBox.shrink();

    final controller = ref.read(onboardingControllerProvider.notifier);
    final rs = context.rs;
    final labelFontSize = rs.isSmall ? 10.0 : 12.0;
    final fieldFontSize = rs.isSmall ? 12.0 : 14.0;
    final hintFontSize = rs.isSmall ? 10.0 : 12.0;
    final iconSize = rs.isSmall ? 14.0 : 18.0;

    return Column(
        key: const ValueKey('raConnect'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ChatBubble(
            message:
                "Enter your RetroAchievements username and API key. You can find your API key at retroachievements.org under Settings.",
            onComplete: widget.onComplete,
          ),
          SizedBox(height: rs.spacing.lg),
          Padding(
            padding: EdgeInsets.only(left: rs.isSmall ? 40 : 60),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(bottom: rs.spacing.sm),
                  child: Row(
                    children: [
                      Icon(Icons.emoji_events_rounded,
                          color: const Color(0xFFFFD54F), size: iconSize),
                      SizedBox(width: rs.spacing.sm),
                      Text(
                        'RETROACHIEVEMENTS',
                        style: TextStyle(
                          color: const Color(0xFFFFD54F),
                          fontSize: labelFontSize,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: rs.spacing.sm),
                FocusTraversalGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Username field
                      ConsoleFocusable(
                        focusNode: _usernameConsoleFocus,
                        autofocus: true,
                        focusScale: 1.0,
                        borderRadius: 12,
                        onSelect: () => _usernameFocus.requestFocus(),
                        child: CallbackShortcuts(
                          bindings: {
                            const SingleActivator(LogicalKeyboardKey.escape, includeRepeats: false): () =>
                                _usernameConsoleFocus.requestFocus(),
                            const SingleActivator(LogicalKeyboardKey.gameButtonB, includeRepeats: false): () =>
                                _usernameConsoleFocus.requestFocus(),
                            const SingleActivator(LogicalKeyboardKey.goBack, includeRepeats: false): () =>
                                _usernameConsoleFocus.requestFocus(),
                          },
                          child: TextField(
                            controller: _usernameController,
                            focusNode: _usernameFocus,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: fieldFontSize,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Username',
                              labelStyle: TextStyle(
                                color: Colors.white54,
                                fontSize: fieldFontSize,
                              ),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.05),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.1),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.1),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFFFFD54F),
                                ),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: rs.spacing.md,
                                vertical: rs.spacing.sm,
                              ),
                            ),
                            onChanged: (v) =>
                                controller.updateRaField('username', v),
                            onSubmitted: (_) =>
                                _usernameConsoleFocus.requestFocus(),
                          ),
                        ),
                      ),
                      SizedBox(height: rs.spacing.md),
                      // API Key field
                      ConsoleFocusable(
                        focusNode: _apiKeyConsoleFocus,
                        focusScale: 1.0,
                        borderRadius: 12,
                        onSelect: () => _apiKeyFocus.requestFocus(),
                        child: CallbackShortcuts(
                          bindings: {
                            const SingleActivator(LogicalKeyboardKey.escape, includeRepeats: false): () =>
                                _apiKeyConsoleFocus.requestFocus(),
                            const SingleActivator(LogicalKeyboardKey.gameButtonB, includeRepeats: false): () =>
                                _apiKeyConsoleFocus.requestFocus(),
                            const SingleActivator(LogicalKeyboardKey.goBack, includeRepeats: false): () =>
                                _apiKeyConsoleFocus.requestFocus(),
                          },
                          child: TextField(
                            controller: _apiKeyController,
                            focusNode: _apiKeyFocus,
                            obscureText: true,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: fieldFontSize,
                            ),
                            decoration: InputDecoration(
                              labelText: 'API Key',
                              labelStyle: TextStyle(
                                color: Colors.white54,
                                fontSize: fieldFontSize,
                              ),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.05),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.1),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.1),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFFFFD54F),
                                ),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: rs.spacing.md,
                                vertical: rs.spacing.sm,
                              ),
                            ),
                            onChanged: (v) =>
                                controller.updateRaField('apiKey', v),
                            onSubmitted: (_) =>
                                _apiKeyConsoleFocus.requestFocus(),
                          ),
                        ),
                      ),
                      SizedBox(height: rs.spacing.md),
                      // Connection status
                      _buildConnectionStatus(ra, rs),
                      SizedBox(height: rs.spacing.sm),
                      Text(
                        'Get your API key at retroachievements.org/controlpanel.php',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: hintFontSize,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
    );
  }

  Widget _buildConnectionStatus(RaSetupState ra, Responsive rs) {
    if (ra.isTestingConnection) {
      return Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: const Color(0xFFFFD54F).withValues(alpha: 0.7),
            ),
          ),
          SizedBox(width: rs.spacing.sm),
          Text(
            'Testing connection...',
            style: TextStyle(
              color: Colors.white54,
              fontSize: rs.isSmall ? 10.0 : 12.0,
            ),
          ),
        ],
      );
    }
    if (ra.connectionSuccess) {
      return Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.greenAccent, size: 16),
          SizedBox(width: rs.spacing.sm),
          Text(
            'Connected!',
            style: TextStyle(
              color: Colors.greenAccent,
              fontSize: rs.isSmall ? 10.0 : 12.0,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }
    if (ra.connectionError != null) {
      return Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 16),
          SizedBox(width: rs.spacing.sm),
          Flexible(
            child: Text(
              ra.connectionError!,
              style: TextStyle(
                color: Colors.redAccent,
                fontSize: rs.isSmall ? 10.0 : 12.0,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}
