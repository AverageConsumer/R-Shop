import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/input/input.dart';
import '../../core/responsive/responsive.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/console_focusable.dart';
import '../../core/widgets/screen_layout.dart';
import '../../models/config/app_config.dart';
import '../../models/config/provider_config.dart';
import '../../models/config/system_config.dart';
import '../../models/system_model.dart';
import '../../providers/app_providers.dart';
import '../../providers/game_providers.dart';
import '../../services/romm_api_service.dart';
import '../../services/romm_platform_matcher.dart';
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

class _RommBackAction extends Action<BackIntent> {
  final List<FocusNode> _textFocusNodes;
  final VoidCallback _onBack;

  _RommBackAction(this._textFocusNodes, this._onBack);

  @override
  bool isEnabled(BackIntent intent) =>
      !_textFocusNodes.any((n) => n.hasFocus);

  @override
  Object? invoke(BackIntent intent) {
    _onBack();
    return null;
  }
}

class RommConfigScreen extends ConsumerStatefulWidget {
  const RommConfigScreen({super.key});
  @override
  ConsumerState<RommConfigScreen> createState() => _RommConfigScreenState();
}

class _RommConfigScreenState extends ConsumerState<RommConfigScreen>
    with ConsoleScreenMixin {
  final _scrollController = ScrollController();
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
  bool _isDiscovering = false;
  Map<String, RommPlatform>? _discoveredMatches;
  Set<String> _selectedNewSystems = {};

  String? _originalUrl;

  @override
  String get routeId => 'romm_config';

  @override
  Map<Type, Action<Intent>> get screenActions => {
        BackIntent: _RommBackAction(
          [_urlTextFocus, _apiKeyTextFocus, _userTextFocus, _passTextFocus],
          _goBack,
        ),
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
    _scrollController.dispose();
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

    if (result.success) {
      await _discoverPlatforms(url, auth);
    }
  }

  Future<void> _discoverPlatforms(String url, AuthConfig? auth) async {
    setState(() => _isDiscovering = true);

    try {
      final platforms = await RommApiService().fetchPlatforms(url, auth: auth);
      if (!mounted) return;

      final matches = <String, RommPlatform>{};
      for (final system in SystemModel.supportedSystems) {
        final match = RommPlatformMatcher.findMatch(system.id, platforms);
        if (match != null) matches[system.id] = match;
      }

      final systemRommUrls = _getSystemRommUrls();
      final currentNormUrl = _normalizeUrl(url);

      setState(() {
        _discoveredMatches = matches;
        // Pre-select systems that don't already have this exact URL
        _selectedNewSystems = matches.keys
            .where((id) {
              final urls = systemRommUrls[id];
              return urls == null || !urls.contains(currentNormUrl);
            })
            .toSet();
        _isDiscovering = false;
      });

      // Scroll down to show discovery results
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
          );
        }
      });
    } catch (e) {
      debugPrint('RommConfigScreen: discovery failed: $e');
      if (!mounted) return;
      setState(() => _isDiscovering = false);
    }
  }

  /// Returns a map of systemId → set of normalized URLs for all systems with RomM providers.
  Map<String, Set<String>> _getSystemRommUrls() {
    final config = ref.read(bootstrappedConfigProvider).value;
    if (config == null) return {};
    final result = <String, Set<String>>{};
    for (final system in config.systems) {
      final rommUrls = system.providers
          .where((p) => p.type == ProviderType.romm)
          .map((p) => _normalizeUrl(p.url))
          .toSet();
      if (rommUrls.isNotEmpty) result[system.id] = rommUrls;
    }
    return result;
  }

  void _toggleSystem(String systemId) {
    setState(() {
      if (_selectedNewSystems.contains(systemId)) {
        _selectedNewSystems.remove(systemId);
      } else {
        _selectedNewSystems.add(systemId);
      }
    });
  }

  void _toggleAll() {
    final systemRommUrls = _getSystemRommUrls();
    final currentNormUrl = _normalizeUrl(_urlController.text.trim());
    final selectable = _discoveredMatches?.keys
            .where((id) {
              final urls = systemRommUrls[id];
              return urls == null || !urls.contains(currentNormUrl);
            })
            .toSet() ??
        {};
    setState(() {
      if (_selectedNewSystems.length == selectable.length) {
        _selectedNewSystems = {};
      } else {
        _selectedNewSystems = Set.from(selectable);
      }
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

    // Add RomM provider to selected discovered systems
    if (_discoveredMatches != null && _selectedNewSystems.isNotEmpty) {
      await _applyRommToSystems(url);
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _applyRommToSystems(String url) async {
    var config = ref.read(bootstrappedConfigProvider).value;
    if (config == null || _discoveredMatches == null) return;

    final auth = _buildAuth();
    final basePath = _deriveBasePath(config);
    var systems = List<SystemConfig>.from(config.systems);

    for (final systemId in _selectedNewSystems) {
      final match = _discoveredMatches![systemId];
      if (match == null) continue;

      final existingIdx = systems.indexWhere((s) => s.id == systemId);
      if (existingIdx >= 0) {
        final existing = systems[existingIdx];

        // Skip if a RomM provider with the same URL already exists
        final alreadyHasThisUrl = existing.providers.any(
          (p) => p.type == ProviderType.romm && _urlsMatch(p.url, url),
        );
        if (alreadyHasThisUrl) continue;

        // Next free priority (after existing providers = fallback)
        final maxPrio = existing.providers.fold(0,
            (int m, ProviderConfig p) => p.priority > m ? p.priority : m);
        final rommProvider = ProviderConfig(
          type: ProviderType.romm,
          priority: maxPrio + 1,
          url: url,
          auth: auth,
          platformId: match.id,
          platformName: match.name,
        );
        final providers = [...existing.providers, rommProvider];
        systems[existingIdx] = existing.copyWith(providers: providers);
      } else {
        final rommProvider = ProviderConfig(
          type: ProviderType.romm,
          priority: 0,
          url: url,
          auth: auth,
          platformId: match.id,
          platformName: match.name,
        );
        final system = SystemModel.supportedSystems.firstWhere(
          (s) => s.id == systemId,
        );
        systems.add(SystemConfig(
          id: systemId,
          name: system.name,
          targetFolder: '$basePath/$systemId',
          providers: [rommProvider],
          autoExtract: system.isZipped,
          mergeMode: false,
        ));
      }
    }

    final updated = AppConfig(version: config.version, systems: systems);
    await _persistConfig(updated);
  }

  String _deriveBasePath(AppConfig config) {
    if (config.systems.isEmpty) return '/storage/emulated/0/ROMs';

    final folders = config.systems.map((s) => s.targetFolder).toList();
    final parts = folders.first.split('/');
    var commonLen = parts.length - 1;
    for (final folder in folders.skip(1)) {
      final fParts = folder.split('/');
      var match = 0;
      while (match < commonLen &&
          match < fParts.length &&
          parts[match] == fParts[match]) {
        match++;
      }
      commonLen = match;
    }
    return parts.take(commonLen).join('/');
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
      _discoveredMatches = null;
      _selectedNewSystems = {};
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
                            controller: _scrollController,
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
                              _buildDiscoverySection(rs),
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
  // Discovery section
  // ---------------------------------------------------------------------------

  Widget _buildDiscoverySection(Responsive rs) {
    if (_isDiscovering) {
      return Padding(
        padding: EdgeInsets.only(bottom: rs.spacing.lg),
        child: Column(
          children: [
            SizedBox(height: rs.spacing.md),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(height: rs.spacing.sm),
            Text(
              'Discovering platforms...',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: rs.isSmall ? 11.0 : 13.0,
              ),
            ),
          ],
        ),
      );
    }

    final matches = _discoveredMatches;
    if (matches == null || matches.isEmpty) return const SizedBox.shrink();

    final systemRommUrls = _getSystemRommUrls();
    final currentNormUrl = _normalizeUrl(_urlController.text.trim());
    final selectable = matches.keys
        .where((id) {
          final urls = systemRommUrls[id];
          return urls == null || !urls.contains(currentNormUrl);
        })
        .toSet();
    final allSelected = selectable.isNotEmpty &&
        _selectedNewSystems.length == selectable.length;

    // Sort systems alphabetically by name
    final sortedEntries = matches.entries.toList()
      ..sort((a, b) {
        final sysA = SystemModel.supportedSystems
            .firstWhere((s) => s.id == a.key);
        final sysB = SystemModel.supportedSystems
            .firstWhere((s) => s.id == b.key);
        return sysA.name.compareTo(sysB.name);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: rs.spacing.sm),
          child: Row(
            children: [
              Text(
                'DISCOVERED SYSTEMS',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: rs.isSmall ? 10.0 : 12.0,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(width: rs.spacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${_selectedNewSystems.length}/${selectable.length}',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: rs.isSmall ? 9.0 : 11.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: rs.spacing.sm),
        if (selectable.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(bottom: rs.spacing.xs),
            child: ConsoleFocusableListItem(
              onSelect: _toggleAll,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: rs.spacing.md,
                  vertical: rs.spacing.sm,
                ),
                child: Row(
                  children: [
                    Icon(
                      allSelected
                          ? Icons.deselect
                          : Icons.select_all,
                      color: Colors.grey.shade400,
                      size: 18,
                    ),
                    SizedBox(width: rs.spacing.sm),
                    Text(
                      allSelected ? 'Deselect All' : 'Select All',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: rs.isSmall ? 12.0 : 14.0,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ...sortedEntries.map((entry) {
          final systemId = entry.key;
          final platform = entry.value;
          final system = SystemModel.supportedSystems
              .firstWhere((s) => s.id == systemId);
          final urls = systemRommUrls[systemId];
          final hasSameUrl = urls != null && urls.contains(currentNormUrl);
          final hasOtherServer = urls != null && !hasSameUrl;
          final isSelected = _selectedNewSystems.contains(systemId);

          return _buildDiscoveryRow(
            rs, system, platform, isSelected,
            isAlreadyConnected: hasSameUrl,
            hasOtherServer: hasOtherServer,
          );
        }),
        SizedBox(height: rs.spacing.lg),
      ],
    );
  }

  Widget _buildDiscoveryRow(Responsive rs, SystemModel system,
      RommPlatform platform, bool isSelected, {
      bool isAlreadyConnected = false,
      bool hasOtherServer = false,
  }) {
    final nameFontSize = rs.isSmall ? 12.0 : 14.0;
    final detailFontSize = rs.isSmall ? 10.0 : 12.0;
    final iconSize = rs.isSmall ? 24.0 : 30.0;
    final checkSize = rs.isSmall ? 18.0 : 22.0;

    final String subtitle;
    if (isAlreadyConnected) {
      subtitle = 'already connected';
    } else if (hasOtherServer) {
      subtitle = '${platform.name} \u2022 ${platform.romCount} ROMs (other server connected)';
    } else {
      subtitle = '${platform.name} \u2022 ${platform.romCount} ROMs';
    }

    return Padding(
      padding: EdgeInsets.only(bottom: rs.spacing.xs),
      child: ConsoleFocusableListItem(
        onSelect: isAlreadyConnected ? null : () => _toggleSystem(system.id),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: rs.spacing.md,
            vertical: rs.spacing.sm,
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(rs.radius.sm),
                child: SvgPicture.asset(
                  system.iconAssetPath,
                  width: iconSize,
                  height: iconSize,
                  colorFilter: ColorFilter.mode(
                    isAlreadyConnected
                        ? Colors.grey.shade700
                        : system.iconColor,
                    BlendMode.srcIn,
                  ),
                  placeholderBuilder: (_) => Icon(
                    Icons.videogame_asset,
                    color: isAlreadyConnected
                        ? Colors.grey.shade700
                        : system.accentColor,
                    size: iconSize,
                  ),
                ),
              ),
              SizedBox(width: rs.spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      system.name,
                      style: TextStyle(
                        color: isAlreadyConnected
                            ? Colors.grey.shade600
                            : Colors.white,
                        fontSize: nameFontSize,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: isAlreadyConnected
                            ? Colors.grey.shade700
                            : hasOtherServer
                                ? Colors.orange.shade300
                                : Colors.grey.shade500,
                        fontSize: detailFontSize,
                      ),
                    ),
                  ],
                ),
              ),
              if (isAlreadyConnected)
                Icon(Icons.link, color: Colors.grey.shade700, size: 16)
              else
                Container(
                  width: checkSize,
                  height: checkSize,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.green.withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isSelected
                          ? Colors.green.withValues(alpha: 0.7)
                          : Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.green, size: 14)
                      : null,
                ),
            ],
          ),
        ),
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
