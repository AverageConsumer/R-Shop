import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/input/input.dart';
import '../../core/responsive/responsive.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/screen_layout.dart';
import '../../models/config/provider_config.dart';
import '../../providers/app_providers.dart';
import '../../services/romm_api_service.dart';
import 'widgets/settings_item.dart';

class RommConfigScreen extends ConsumerStatefulWidget {
  const RommConfigScreen({super.key});
  @override
  ConsumerState<RommConfigScreen> createState() => _RommConfigScreenState();
}

class _RommConfigScreenState extends ConsumerState<RommConfigScreen>
    with ConsoleScreenMixin {
  final _urlController = TextEditingController();
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  final _apiKeyController = TextEditingController();

  final FocusNode _urlFocusNode = FocusNode(skipTraversal: true);
  final FocusNode _urlConsoleFocusNode = FocusNode(debugLabel: 'romm_url');

  bool _isTesting = false;
  bool? _testSuccess;
  String? _testError;

  @override
  String get routeId => 'romm_config';

  @override
  Map<Type, Action<Intent>> get screenActions => {
        BackIntent: CallbackAction<BackIntent>(onInvoke: (_) {
          _goBack();
          return null;
        }),
      };

  @override
  void initState() {
    super.initState();
    final storage = ref.read(storageServiceProvider);
    _urlController.text = storage.getRommUrl() ?? '';

    final authJson = storage.getRommAuth();
    if (authJson != null) {
      try {
        final map = jsonDecode(authJson) as Map<String, dynamic>;
        final auth = AuthConfig.fromJson(map);
        _userController.text = auth.user ?? '';
        _passController.text = auth.pass ?? '';
        _apiKeyController.text = auth.apiKey ?? '';
      } catch (_) {}
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(mainFocusRequestProvider.notifier).state = screenFocusNode;
      _urlConsoleFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    _userController.dispose();
    _passController.dispose();
    _apiKeyController.dispose();
    _urlFocusNode.dispose();
    _urlConsoleFocusNode.dispose();
    super.dispose();
  }

  void _goBack() {
    Navigator.pop(context);
  }

  Future<void> _testConnection() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _isTesting = true;
      _testSuccess = null;
      _testError = null;
    });

    final auth = _buildAuth();
    final result = await RommApiService().testConnection(url, auth: auth);

    if (!mounted) return;
    setState(() {
      _isTesting = false;
      _testSuccess = result.success;
      _testError = result.success ? null : result.error;
    });
  }

  AuthConfig? _buildAuth() {
    final user = _userController.text.trim();
    final pass = _passController.text.trim();
    final apiKey = _apiKeyController.text.trim();

    if (user.isEmpty && apiKey.isEmpty) return null;
    return AuthConfig(
      user: user.isNotEmpty ? user : null,
      pass: pass.isNotEmpty ? pass : null,
      apiKey: apiKey.isNotEmpty ? apiKey : null,
    );
  }

  Future<void> _save() async {
    final storage = ref.read(storageServiceProvider);
    final url = _urlController.text.trim();

    if (url.isEmpty) {
      await storage.setRommUrl(null);
      await storage.setRommAuth(null);
    } else {
      await storage.setRommUrl(url);
      final auth = _buildAuth();
      if (auth != null) {
        await storage.setRommAuth(jsonEncode(auth.toJson()));
      } else {
        await storage.setRommAuth(null);
      }
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _clear() async {
    final storage = ref.read(storageServiceProvider);
    await storage.setRommUrl(null);
    await storage.setRommAuth(null);
    setState(() {
      _urlController.clear();
      _userController.clear();
      _passController.clear();
      _apiKeyController.clear();
      _testSuccess = null;
      _testError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;

    return buildWithActions(
      PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _goBack();
        },
        child: ScreenLayout(
          backgroundColor: Colors.black,
          accentColor: AppTheme.primaryColor,
          body: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF1A1A1A), Colors.black],
                    ),
                  ),
                ),
              ),
              Column(
                children: [
                  SizedBox(height: rs.safeAreaTop + rs.spacing.lg),
                  _buildTitle(rs),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 800),
                        child: FocusTraversalGroup(
                          child: ListView(
                            padding: EdgeInsets.symmetric(
                              horizontal: rs.spacing.lg,
                              vertical: rs.spacing.md,
                            ),
                            children: [
                              _buildField(rs, 'URL', 'https://romm.example.com',
                                  _urlController, _urlFocusNode, _urlConsoleFocusNode),
                              SizedBox(height: rs.spacing.md),
                              _buildField(rs, 'API Key', '(optional)',
                                  _apiKeyController, null, null),
                              SizedBox(height: rs.spacing.md),
                              _buildField(rs, 'Username', '(optional)',
                                  _userController, null, null),
                              SizedBox(height: rs.spacing.md),
                              _buildField(rs, 'Password', '(optional)',
                                  _passController, null, null,
                                  obscure: true),
                              SizedBox(height: rs.spacing.lg),
                              _buildTestResult(rs),
                              SizedBox(height: rs.spacing.lg),
                              _buildActions(rs),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitle(Responsive rs) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: rs.spacing.lg),
      child: Column(
        children: [
          const Icon(Icons.dns_outlined, size: 48, color: Colors.white24),
          SizedBox(height: rs.spacing.sm),
          Text(
            'ROMM SERVER',
            style: AppTheme.headlineLarge.copyWith(
              fontSize: 42,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
            ),
          ),
          SizedBox(height: rs.spacing.xs),
          Text(
            'Configure once, auto-fill everywhere',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: rs.isSmall ? 12 : 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(
    Responsive rs,
    String label,
    String hint,
    TextEditingController controller,
    FocusNode? textFocusNode,
    FocusNode? consoleFocusNode, {
    bool obscure = false,
  }) {
    final fontSize = rs.isSmall ? 12.0 : 14.0;
    final labelFontSize = rs.isSmall ? 10.0 : 12.0;
    textFocusNode ??= FocusNode(skipTraversal: true);
    consoleFocusNode ??= FocusNode();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: Colors.grey.shade400,
            fontSize: labelFontSize,
            letterSpacing: 1,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: rs.spacing.xs),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: TextField(
            controller: controller,
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
          ),
        ),
      ],
    );
  }

  Widget _buildTestResult(Responsive rs) {
    if (_isTesting) {
      return Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.primaryColor.withValues(alpha: 0.7),
            ),
          ),
          SizedBox(width: rs.spacing.sm),
          Text(
            'Testing connection...',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          ),
        ],
      );
    }

    if (_testSuccess == true) {
      return Container(
        padding: EdgeInsets.all(rs.spacing.md),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade300, size: 18),
            SizedBox(width: rs.spacing.sm),
            Text(
              'Connection successful',
              style: TextStyle(color: Colors.green.shade200, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_testError != null) {
      return Container(
        padding: EdgeInsets.all(rs.spacing.md),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade300, size: 18),
            SizedBox(width: rs.spacing.sm),
            Expanded(
              child: Text(
                _testError!,
                style: TextStyle(color: Colors.red.shade200, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildActions(Responsive rs) {
    final hasUrl = _urlController.text.trim().isNotEmpty;

    return Column(
      children: [
        // Test Connection
        SettingsItem(
          title: 'Test Connection',
          subtitle: 'Verify server is reachable',
          trailing: Icon(
            Icons.wifi_find_rounded,
            color: hasUrl ? Colors.white70 : Colors.white24,
          ),
          onTap: hasUrl ? _testConnection : null,
        ),
        SizedBox(height: rs.spacing.md),
        // Save
        SettingsItem(
          title: 'Save',
          subtitle: 'Store credentials and return',
          trailing: Icon(
            Icons.save_rounded,
            color: hasUrl ? Colors.green : Colors.white24,
          ),
          onTap: _save,
        ),
        SizedBox(height: rs.spacing.md),
        // Clear
        SettingsItem(
          title: 'Clear',
          subtitle: 'Remove saved RomM credentials',
          trailing: const Icon(Icons.delete_outline, color: Colors.white70),
          onTap: _clear,
          isDestructive: true,
        ),
      ],
    );
  }
}
