import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/responsive/responsive.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/console_focusable.dart';
import '../../../models/config/provider_config.dart';
import '../onboarding_controller.dart';
import 'chat_bubble.dart';
import 'configured_servers_summary.dart';
import 'connection_test_indicator.dart';

class RemoteConnectView extends ConsumerStatefulWidget {
  final VoidCallback onComplete;
  const RemoteConnectView({super.key, required this.onComplete});

  @override
  ConsumerState<RemoteConnectView> createState() => _RemoteConnectViewState();
}

class _RemoteConnectViewState extends ConsumerState<RemoteConnectView> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};
  final Map<String, FocusNode> _consoleFocusNodes = {};

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
      _consoleFocusNodes[key] = FocusNode(debugLabel: 'remote_console_$key');
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingControllerProvider);
    final rs = context.rs;
    final controller = ref.read(onboardingControllerProvider.notifier);
    final remoteState = state.remoteSetupState;
    if (remoteState == null) return const SizedBox.shrink();

    final chatMessage = remoteState.isTestingConnection
        ? "Connecting to your server..."
        : remoteState.connectionError != null
            ? "Couldn't reach your server. Check the details and try again."
            : remoteState.scanError != null
                ? "Connected to your server, but couldn't scan the folders. "
                    "Check the path and try again."
                : "Pick your server type and enter the connection details. "
                    "The path should point to the folder containing your console subfolders.";

    return FocusScope(
      child: Column(
        key: const ValueKey('remoteConnect'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ChatBubble(
            key: ValueKey('bubble_remoteConnect_${remoteState.isTestingConnection}'
                '_${remoteState.connectionTestSuccess}'
                '_${remoteState.connectionError ?? ''}'),
            message: chatMessage,
            accentColor: remoteState.connectionError != null
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
                      if (state.configuredRemoteServers.isNotEmpty)
                        ConfiguredServersSummary(
                            servers: state.configuredRemoteServers),
                      // Provider type chips
                      _buildTypeSelector(rs, remoteState, controller),
                      SizedBox(height: rs.spacing.md),
                      // Dynamic fields based on type
                      ..._buildFieldsForType(rs, remoteState, controller),
                      SizedBox(height: rs.spacing.md),
                      ConnectionTestIndicator(
                        isTesting: remoteState.isTestingConnection,
                        isSuccess: remoteState.connectionTestSuccess,
                        error: remoteState.connectionError,
                      ),
                      if (remoteState.scanError != null) ...[
                        SizedBox(height: rs.spacing.sm),
                        Row(
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                color: Colors.orange.shade300, size: 16),
                            SizedBox(width: rs.spacing.xs),
                            Expanded(
                              child: Text(
                                remoteState.scanError!,
                                style: TextStyle(
                                  color: Colors.orange.shade300,
                                  fontSize: rs.isSmall ? 10 : 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
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

  Widget _buildTypeSelector(
    Responsive rs,
    RemoteSetupState remoteState,
    OnboardingController controller,
  ) {
    final chipFontSize = rs.isSmall ? 11.0 : 13.0;
    final types = [ProviderType.ftp, ProviderType.smb, ProviderType.web];

    return Wrap(
      spacing: rs.spacing.sm,
      children: types.map((type) {
        final selected = remoteState.providerType == type;
        final label = switch (type) {
          ProviderType.ftp => 'FTP',
          ProviderType.smb => 'SMB',
          ProviderType.web => 'Web (HTTP)',
          ProviderType.romm => 'RomM',
        };
        return ConsoleFocusable(
          autofocus: selected && !_controllers.containsKey('host'),
          focusScale: 1.0,
          borderRadius: rs.radius.round,
          onSelect: () {
            controller.setRemoteProviderType(type);
            // Clear text controllers when switching type
            for (final c in _controllers.values) {
              c.clear();
            }
          },
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: rs.spacing.md,
              vertical: rs.spacing.sm,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? Colors.teal.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(rs.radius.round),
              border: Border.all(
                color: selected
                    ? Colors.teal.withValues(alpha: 0.7)
                    : Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white54,
                fontSize: chipFontSize,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  List<Widget> _buildFieldsForType(
    Responsive rs,
    RemoteSetupState remoteState,
    OnboardingController controller,
  ) {
    switch (remoteState.providerType) {
      case ProviderType.ftp:
        return [
          _buildTextField(rs, 'host', 'Host', '192.168.1.100', remoteState.host, controller),
          SizedBox(height: rs.spacing.sm),
          _buildTextField(rs, 'port', 'Port', '21', remoteState.port, controller, numeric: true),
          SizedBox(height: rs.spacing.sm),
          _buildTextField(rs, 'path', 'ROM Path', '/roms', remoteState.path, controller),
          SizedBox(height: rs.spacing.sm),
          _buildTextField(rs, 'user', 'Username', '(optional)', remoteState.user, controller),
          SizedBox(height: rs.spacing.sm),
          _buildTextField(rs, 'pass', 'Password', '(optional)', remoteState.pass, controller, obscure: true),
        ];
      case ProviderType.smb:
        return [
          _buildTextField(rs, 'host', 'Host', '192.168.1.100', remoteState.host, controller),
          SizedBox(height: rs.spacing.sm),
          _buildTextField(rs, 'port', 'Port', '445', remoteState.port, controller, numeric: true),
          SizedBox(height: rs.spacing.sm),
          _buildTextField(rs, 'share', 'Share', 'roms', remoteState.share, controller),
          SizedBox(height: rs.spacing.sm),
          _buildTextField(rs, 'path', 'Path', '/ (root of share)', remoteState.path, controller),
          SizedBox(height: rs.spacing.sm),
          _buildTextField(rs, 'user', 'Username', '(optional)', remoteState.user, controller),
          SizedBox(height: rs.spacing.sm),
          _buildTextField(rs, 'pass', 'Password', '(optional)', remoteState.pass, controller, obscure: true),
          SizedBox(height: rs.spacing.sm),
          _buildTextField(rs, 'domain', 'Domain', '(optional)', remoteState.domain, controller),
        ];
      case ProviderType.web:
        return [
          _buildTextField(rs, 'url', 'URL', 'https://myserver.com/roms', remoteState.url, controller),
          SizedBox(height: rs.spacing.sm),
          _buildTextField(rs, 'path', 'Path', '(optional subdirectory)', remoteState.path, controller),
          SizedBox(height: rs.spacing.sm),
          _buildTextField(rs, 'user', 'Username', '(optional)', remoteState.user, controller),
          SizedBox(height: rs.spacing.sm),
          _buildTextField(rs, 'pass', 'Password', '(optional)', remoteState.pass, controller, obscure: true),
        ];
      case ProviderType.romm:
        return []; // Not used
    }
  }

  Widget _buildTextField(
    Responsive rs,
    String key,
    String label,
    String hint,
    String currentValue,
    OnboardingController controller, {
    bool obscure = false,
    bool numeric = false,
  }) {
    final fontSize = rs.isSmall ? 12.0 : 14.0;
    final labelFontSize = rs.isSmall ? 10.0 : 12.0;
    final fieldController = _getController(key, currentValue);
    final textFocusNode = _getFocusNode(key);
    final consoleFocusNode = _getConsoleFocusNode(key);

    return ConsoleFocusable(
      key: ValueKey('remote_field_$key'),
      focusNode: consoleFocusNode,
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
                keyboardType: numeric ? TextInputType.number : null,
                inputFormatters: numeric
                    ? [FilteringTextInputFormatter.digitsOnly]
                    : null,
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
                    controller.updateRemoteField(key, value),
                onSubmitted: (_) => consoleFocusNode.requestFocus(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
