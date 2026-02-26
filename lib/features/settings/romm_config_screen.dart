import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/input/input.dart';
import '../../core/responsive/responsive.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/console_focusable.dart';
import '../../core/widgets/screen_layout.dart';
import '../../models/config/app_config.dart';
import '../../models/config/provider_config.dart';
import '../../providers/app_providers.dart';
import '../../providers/game_providers.dart';
import '../../services/romm_api_service.dart';
import '../../widgets/console_hud.dart';
import '../../widgets/console_notification.dart';
import '../onboarding/widgets/provider_form.dart' show isPrivateNetworkUrl;
import 'widgets/settings_item.dart';

enum _ConsoleStatus { synced, stale, independent }

class _RommConsoleInfo {
  final String systemId;
  final String systemName;
  final int providerIndex;
  final String url;
  final _ConsoleStatus status;

  const _RommConsoleInfo({
    required this.systemId,
    required this.systemName,
    required this.providerIndex,
    required this.url,
    required this.status,
  });
}

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

  // Text editing focus nodes (skipTraversal: keyboard input only)
  final _urlTextFocus = FocusNode(skipTraversal: true);
  final _apiKeyTextFocus = FocusNode(skipTraversal: true);
  final _userTextFocus = FocusNode(skipTraversal: true);
  final _passTextFocus = FocusNode(skipTraversal: true);

  // Console navigation focus nodes (D-pad navigable)
  final _urlConsoleFocus = FocusNode(debugLabel: 'romm_url');
  final _apiKeyConsoleFocus = FocusNode(debugLabel: 'romm_apikey');
  final _userConsoleFocus = FocusNode(debugLabel: 'romm_user');
  final _passConsoleFocus = FocusNode(debugLabel: 'romm_pass');

  bool _isTesting = false;

  String? _originalUrl;

  @override
  String get routeId => 'romm_config';

  @override
  Map<Type, Action<Intent>> get screenActions => {
        BackIntent: CallbackAction<BackIntent>(onInvoke: (_) {
          _goBack();
          return null;
        }),
        SearchIntent: SearchAction(ref, onSearch: _testConnection),
        InfoIntent: InfoAction(ref, onInfo: _clear),
        ToggleOverlayIntent: ToggleOverlayAction(ref, onToggle: _save),
      };

  @override
  void initState() {
    super.initState();
    final storage = ref.read(storageServiceProvider);
    _urlController.text = storage.getRommUrl() ?? '';
    _originalUrl = storage.getRommUrl();

    final authJson = storage.getRommAuth();
    if (authJson != null) {
      try {
        final map = jsonDecode(authJson) as Map<String, dynamic>;
        final auth = AuthConfig.fromJson(map);
        _userController.text = auth.user ?? '';
        _passController.text = auth.pass ?? '';
        _apiKeyController.text = auth.apiKey ?? '';
      } catch (e) { debugPrint('RommConfigScreen: auth parse failed: $e'); }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _urlConsoleFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    _userController.dispose();
    _passController.dispose();
    _apiKeyController.dispose();
    _urlTextFocus.dispose();
    _apiKeyTextFocus.dispose();
    _userTextFocus.dispose();
    _passTextFocus.dispose();
    _urlConsoleFocus.dispose();
    _apiKeyConsoleFocus.dispose();
    _userConsoleFocus.dispose();
    _passConsoleFocus.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // URL / Auth comparison helpers
  // ---------------------------------------------------------------------------

  static String _normalizeUrl(String? url) {
    final s = url?.trim() ?? '';
    return s.endsWith('/') ? s.substring(0, s.length - 1) : s;
  }

  static bool _urlsMatch(String? a, String? b) =>
      _normalizeUrl(a) == _normalizeUrl(b);

  static String _norm(String? s) => s?.trim() ?? '';

  static bool _authMatches(AuthConfig? a, AuthConfig? b) =>
      _norm(a?.user) == _norm(b?.user) &&
      _norm(a?.pass) == _norm(b?.pass) &&
      _norm(a?.apiKey) == _norm(b?.apiKey);

  static String _shortenUrl(String url) {
    var s = url;
    if (s.startsWith('https://')) s = s.substring(8);
    if (s.startsWith('http://')) s = s.substring(7);
    if (s.endsWith('/')) s = s.substring(0, s.length - 1);
    return s;
  }

  // ---------------------------------------------------------------------------
  // Console status classification
  // ---------------------------------------------------------------------------

  List<_RommConsoleInfo> _getRommConsoles() {
    final config = ref.read(bootstrappedConfigProvider).value;
    if (config == null) return [];
    final currentUrl = _urlController.text.trim();
    final currentAuth = _buildAuth();
    final result = <_RommConsoleInfo>[];

    for (final system in config.systems) {
      for (var i = 0; i < system.providers.length; i++) {
        final p = system.providers[i];
        if (p.type != ProviderType.romm) continue;
        result.add(_RommConsoleInfo(
          systemId: system.id,
          systemName: system.name,
          providerIndex: i,
          url: p.url ?? '',
          status: _classifyProvider(p, currentUrl, currentAuth),
        ));
      }
    }
    return result;
  }

  _ConsoleStatus _classifyProvider(
      ProviderConfig p, String currentUrl, AuthConfig? currentAuth) {
    if (currentUrl.isEmpty) return _ConsoleStatus.independent;

    // URL matches current form value
    if (_urlsMatch(p.url, currentUrl)) {
      return _authMatches(p.auth, currentAuth)
          ? _ConsoleStatus.synced
          : _ConsoleStatus.stale;
    }

    // URL matches the original global URL (user changed the global URL)
    if (_originalUrl != null &&
        _originalUrl!.isNotEmpty &&
        _urlsMatch(p.url, _originalUrl)) {
      return _ConsoleStatus.stale;
    }

    return _ConsoleStatus.independent;
  }

  // ---------------------------------------------------------------------------
  // Config update helpers
  // ---------------------------------------------------------------------------

  AppConfig _updateRommProvider(
      AppConfig config, String systemId, int providerIndex,
      String newUrl, AuthConfig? newAuth) {
    final systems = config.systems.map((system) {
      if (system.id != systemId) return system;
      final providers = List<ProviderConfig>.from(system.providers);
      final old = providers[providerIndex];
      providers[providerIndex] = ProviderConfig(
        type: old.type,
        priority: old.priority,
        url: newUrl,
        auth: newAuth,
        platformId: old.platformId,
        platformName: old.platformName,
      );
      return system.copyWith(providers: providers);
    }).toList();
    return AppConfig(version: config.version, systems: systems);
  }

  Future<void> _persistConfig(AppConfig config) async {
    final jsonString =
        const JsonEncoder.withIndent('  ').convert(config.toJson());
    await ref.read(configStorageServiceProvider).saveConfig(jsonString);
    ref.invalidate(bootstrappedConfigProvider);
  }

  Future<void> _updateSingleConsole(_RommConsoleInfo info) async {
    final config = ref.read(bootstrappedConfigProvider).value;
    if (config == null) return;

    final newUrl = _urlController.text.trim();
    final newAuth = _buildAuth();
    final updatedConfig = _updateRommProvider(
        config, info.systemId, info.providerIndex, newUrl, newAuth);

    await _persistConfig(updatedConfig);
    setState(() {});
  }

  Future<void> _updateAllStale() async {
    final config = ref.read(bootstrappedConfigProvider).value;
    if (config == null) return;

    final newUrl = _urlController.text.trim();
    final newAuth = _buildAuth();
    var updated = config;
    final consoles = _getRommConsoles();
    for (final info in consoles.where((c) => c.status == _ConsoleStatus.stale)) {
      updated = _updateRommProvider(
          updated, info.systemId, info.providerIndex, newUrl, newAuth);
    }

    await _persistConfig(updated);
    setState(() {});
  }

  // ---------------------------------------------------------------------------
  // Navigation / actions
  // ---------------------------------------------------------------------------

  void _goBack() {
    Navigator.pop(context);
  }

  Future<void> _testConnection() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() => _isTesting = true);

    final auth = _buildAuth();
    final result = await RommApiService().testConnection(url, auth: auth);

    if (!mounted) return;
    setState(() => _isTesting = false);
    showConsoleNotification(
      context,
      message: result.success ? 'Connection successful' : result.error ?? 'Connection failed',
      isError: !result.success,
    );
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

    // Block non-LAN HTTP when the setting is off
    if (url.startsWith('http://') &&
        !isPrivateNetworkUrl(url) &&
        !storage.getAllowNonLanHttp()) {
      if (mounted) {
        showConsoleNotification(
          context,
          message: 'HTTP to non-local servers is blocked. '
              'Enable in Settings → System.',
          isError: true,
        );
      }
      return;
    }

    if (url.isEmpty) {
      await storage.setRommUrl(null);
      await storage.setRommAuth(null);
    } else {
      await storage.setRommUrl(url);
      final auth = _buildAuth();
      if (auth != null) {
        await storage.setRommAuth(jsonEncode(auth.toJson()));

        // Warn when sending credentials over plain HTTP
        if (mounted &&
            url.startsWith('http://') &&
            !url.startsWith('http://localhost') &&
            !url.startsWith('http://127.0.0.1')) {
          showConsoleNotification(
            context,
            message: 'Warning: credentials sent unencrypted over HTTP',
            isError: true,
          );
        }
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
    });
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

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
                                  _urlController, _urlTextFocus, _urlConsoleFocus),
                              SizedBox(height: rs.spacing.md),
                              _buildField(rs, 'API Key', '(optional)',
                                  _apiKeyController, _apiKeyTextFocus, _apiKeyConsoleFocus),
                              SizedBox(height: rs.spacing.md),
                              _buildField(rs, 'Username', '(optional)',
                                  _userController, _userTextFocus, _userConsoleFocus),
                              SizedBox(height: rs.spacing.md),
                              _buildField(rs, 'Password', '(optional)',
                                  _passController, _passTextFocus, _passConsoleFocus,
                                  obscure: true),
                              SizedBox(height: rs.spacing.lg),
                              _buildConsoleSection(rs),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  ConsoleHud(
                    y: HudAction(
                      'Test',
                      onTap: _urlController.text.trim().isNotEmpty && !_isTesting
                          ? _testConnection
                          : null,
                    ),
                    x: HudAction('Clear', onTap: _clear),
                    b: HudAction('Back', onTap: _goBack),
                    start: HudAction('Save', onTap: _save, highlight: true),
                    embedded: true,
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
            'Default server for new consoles',
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
    FocusNode textFocusNode,
    FocusNode consoleFocusNode, {
    bool obscure = false,
  }) {
    final fontSize = rs.isSmall ? 12.0 : 14.0;
    final labelFontSize = rs.isSmall ? 10.0 : 12.0;

    return ConsoleFocusable(
      focusNode: consoleFocusNode,
      focusScale: 1.0,
      borderRadius: 12,
      onSelect: () => textFocusNode.requestFocus(),
      child: Column(
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
          ListenableBuilder(
            listenable: textFocusNode,
            builder: (context, child) {
              final hasFocus = textFocusNode.hasFocus;
              return Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF252525),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: hasFocus
                        ? AppTheme.primaryColor
                        : AppTheme.primaryColor.withValues(alpha: 0.4),
                    width: 2,
                  ),
                  boxShadow: hasFocus
                      ? [
                          BoxShadow(
                            color:
                                AppTheme.primaryColor.withValues(alpha: 0.3),
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
                const SingleActivator(LogicalKeyboardKey.escape,
                    includeRepeats: false): () =>
                    consoleFocusNode.requestFocus(),
                const SingleActivator(LogicalKeyboardKey.gameButtonB,
                    includeRepeats: false): () =>
                    consoleFocusNode.requestFocus(),
                const SingleActivator(LogicalKeyboardKey.goBack,
                    includeRepeats: false): () =>
                    consoleFocusNode.requestFocus(),
              },
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
                onSubmitted: (_) => consoleFocusNode.requestFocus(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Connected Consoles section
  // ---------------------------------------------------------------------------

  Widget _buildConsoleSection(Responsive rs) {
    final consoles = _getRommConsoles();
    if (consoles.isEmpty) return const SizedBox.shrink();

    final staleCount =
        consoles.where((c) => c.status == _ConsoleStatus.stale).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: rs.spacing.sm),
          child: Text(
            'CONNECTED CONSOLES',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: rs.isSmall ? 10.0 : 12.0,
              letterSpacing: 2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        SizedBox(height: rs.spacing.sm),
        ...consoles.map((info) => Padding(
              padding: EdgeInsets.only(bottom: rs.spacing.xs),
              child: _buildConsoleRow(rs, info),
            )),
        if (staleCount > 0) ...[
          SizedBox(height: rs.spacing.sm),
          SettingsItem(
            title: 'Update $staleCount stale',
            subtitle: 'Sync outdated consoles with current credentials',
            trailing: const Icon(Icons.sync, color: Colors.orange),
            onTap: _updateAllStale,
          ),
        ],
      ],
    );
  }

  Widget _buildConsoleRow(Responsive rs, _RommConsoleInfo info) {
    final (IconData icon, Color color, String label) = switch (info.status) {
      _ConsoleStatus.synced => (Icons.check_circle, Colors.green, ''),
      _ConsoleStatus.stale =>
        (Icons.warning_amber_rounded, Colors.orange, ''),
      _ConsoleStatus.independent =>
        (Icons.circle_outlined, Colors.grey.shade700, 'other'),
    };

    final fontSize = rs.isSmall ? 11.0 : 13.0;

    final row = Padding(
      padding: EdgeInsets.symmetric(
          horizontal: rs.spacing.md, vertical: rs.spacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              info.systemName,
              style: TextStyle(
                color: Colors.white,
                fontSize: fontSize,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              _shortenUrl(info.url),
              textAlign: TextAlign.end,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontFamily: 'monospace',
                fontSize: fontSize - 1,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (label.isNotEmpty) ...[
            SizedBox(width: rs.spacing.xs),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: fontSize - 2,
              ),
            ),
          ],
          SizedBox(width: rs.spacing.sm),
          Icon(icon, color: color, size: 16),
        ],
      ),
    );

    return ConsoleFocusableListItem(
      onSelect: info.status == _ConsoleStatus.stale
          ? () => _updateSingleConsole(info)
          : null,
      child: row,
    );
  }

}
