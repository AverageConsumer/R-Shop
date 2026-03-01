import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/input/input.dart';
import '../../core/responsive/responsive.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/console_focusable.dart';
import '../../core/widgets/screen_layout.dart';
import '../../models/system_model.dart';
import '../../providers/app_providers.dart';
import '../../providers/ra_providers.dart';
import '../../services/database_service.dart';
import '../../services/ra_sync_service.dart';
import '../../widgets/console_hud.dart';
import '../../widgets/console_notification.dart';

class _RaBackAction extends Action<BackIntent> {
  final List<FocusNode> _textFocusNodes;
  final VoidCallback _onBack;

  _RaBackAction(this._textFocusNodes, this._onBack);

  @override
  bool isEnabled(BackIntent intent) =>
      !_textFocusNodes.any((n) => n.hasFocus);

  @override
  Object? invoke(BackIntent intent) {
    _onBack();
    return null;
  }
}

class RaConfigScreen extends ConsumerStatefulWidget {
  const RaConfigScreen({super.key});
  @override
  ConsumerState<RaConfigScreen> createState() => _RaConfigScreenState();
}

class _RaConfigScreenState extends ConsumerState<RaConfigScreen>
    with ConsoleScreenMixin {
  final _scrollController = ScrollController();
  final _usernameController = TextEditingController();
  final _apiKeyController = TextEditingController();

  final _usernameTextFocus = FocusNode(skipTraversal: true);
  final _apiKeyTextFocus = FocusNode(skipTraversal: true);
  final _usernameConsoleFocus = FocusNode(debugLabel: 'ra_username');
  final _apiKeyConsoleFocus = FocusNode(debugLabel: 'ra_apikey');

  bool _isTesting = false;
  bool? _testSuccess;
  String? _testError;
  bool _enabled = false;

  @override
  String get routeId => 'ra_config';

  @override
  Map<ShortcutActivator, Intent>? get additionalShortcuts => {
        const SingleActivator(LogicalKeyboardKey.gameButtonX,
                includeRepeats: false):
            const MenuIntent(),
      };

  @override
  Map<Type, Action<Intent>> get screenActions => {
        BackIntent: _RaBackAction(
          [_usernameTextFocus, _apiKeyTextFocus],
          _goBack,
        ),
        SearchIntent: SearchAction(ref, onSearch: _testConnection),
        MenuIntent: MenuAction(ref, onMenu: _clear),
        ToggleOverlayIntent: ToggleOverlayAction(ref, onToggle: _save),
      };

  @override
  void initState() {
    super.initState();
    final storage = ref.read(storageServiceProvider);
    _usernameController.text = storage.getRaUsername() ?? '';
    _apiKeyController.text = storage.getRaApiKey() ?? '';
    _enabled = storage.getRaEnabled();

    // Focus the first interactive item (runs after ConsoleScreenMixin._restoreFocus)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _usernameConsoleFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _usernameController.dispose();
    _apiKeyController.dispose();
    _usernameTextFocus.dispose();
    _apiKeyTextFocus.dispose();
    _usernameConsoleFocus.dispose();
    _apiKeyConsoleFocus.dispose();
    super.dispose();
  }

  void _goBack() {
    ref.read(feedbackServiceProvider).cancel();
    Navigator.pop(context);
  }

  Future<void> _save() async {
    final storage = ref.read(storageServiceProvider);
    await storage.setRaUsername(_usernameController.text.trim());
    await storage.setRaApiKey(_apiKeyController.text.trim());
    await storage.setRaEnabled(_enabled);

    if (!mounted) return;
    ref.read(feedbackServiceProvider).confirm();
    showConsoleNotification(context, message: 'Settings saved');
    Navigator.pop(context);
  }

  void _clear() {
    ref.read(feedbackServiceProvider).tick();
    setState(() {
      _usernameController.clear();
      _apiKeyController.clear();
      _enabled = false;
      _testSuccess = null;
      _testError = null;
    });
  }

  Future<void> _testConnection() async {
    final username = _usernameController.text.trim();
    final apiKey = _apiKeyController.text.trim();

    if (username.isEmpty || apiKey.isEmpty) {
      showConsoleNotification(
        context,
        message: 'Enter username and API key first',
      );
      return;
    }

    setState(() {
      _isTesting = true;
      _testSuccess = null;
      _testError = null;
    });

    final result = await ref.read(raApiServiceProvider).testConnection(
          username: username,
          apiKey: apiKey,
        );

    if (!mounted) return;
    setState(() {
      _isTesting = false;
      _testSuccess = result.success;
      _testError = result.success ? null : result.error;
    });

    if (result.success) {
      // Persist credentials immediately so Refresh Database works right away
      final storage = ref.read(storageServiceProvider);
      storage.setRaUsername(username);
      storage.setRaApiKey(apiKey);
      storage.setRaEnabled(true);

      ref.read(feedbackServiceProvider).confirm();
      showConsoleNotification(context, message: 'Connected to RetroAchievements');
      setState(() => _enabled = true);
    } else {
      ref.read(feedbackServiceProvider).error();
      showConsoleNotification(context, message: result.error ?? 'Connection failed');
    }
  }

  Future<void> _refreshDatabase() async {
    final storage = ref.read(storageServiceProvider);
    if (!storage.isRaConfigured) {
      showConsoleNotification(context, message: 'Configure and test credentials first');
      return;
    }

    ref.read(feedbackServiceProvider).tick();
    showConsoleNotification(context, message: 'RA sync started in background');

    final syncService = ref.read(raSyncServiceProvider.notifier);
    final raSystems = SystemModel.supportedSystems
        .where((s) => s.hasRetroAchievements)
        .toList();
    syncService.syncAll(raSystems, force: true);
  }

  Future<void> _clearCache() async {
    ref.read(feedbackServiceProvider).tick();
    final db = DatabaseService();
    await db.clearRaCache();
    if (!mounted) return;
    showConsoleNotification(context, message: 'RA cache cleared');
    ref.read(raRefreshSignalProvider.notifier).state++;
  }

  void _toggleEnabled() {
    setState(() => _enabled = !_enabled);
    ref.read(feedbackServiceProvider).tick();
  }

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final syncState = ref.watch(raSyncServiceProvider);

    return buildWithActions(
      ScreenLayout(
        body: Stack(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: FocusTraversalGroup(
                  child: ListView(
                    controller: _scrollController,
                    padding: EdgeInsets.symmetric(
                      horizontal: rs.spacing.lg,
                      vertical: rs.spacing.md,
                    ),
                    children: [
                      _buildInfoBanner(rs),
                      SizedBox(height: rs.spacing.lg),
                      _buildTextField(
                        rs,
                        label: 'Username',
                        controller: _usernameController,
                        textFocus: _usernameTextFocus,
                        consoleFocus: _usernameConsoleFocus,
                        icon: Icons.person_outline,
                        autofocus: true,
                      ),
                      SizedBox(height: rs.spacing.md),
                      _buildTextField(
                        rs,
                        label: 'API Key',
                        controller: _apiKeyController,
                        textFocus: _apiKeyTextFocus,
                        consoleFocus: _apiKeyConsoleFocus,
                        icon: Icons.key_outlined,
                        obscure: true,
                      ),
                      SizedBox(height: rs.spacing.lg),
                      _buildTestButton(rs),
                      if (_testSuccess != null) ...[
                        SizedBox(height: rs.spacing.sm),
                        _buildTestResult(rs),
                      ],
                      SizedBox(height: rs.spacing.lg),
                      _buildEnableToggle(rs),
                      SizedBox(height: rs.spacing.lg),
                      if (_enabled) ...[
                        _buildSyncStatus(rs, syncState),
                        SizedBox(height: rs.spacing.md),
                        _buildActionButton(
                          rs,
                          label: 'Refresh Database',
                          icon: Icons.sync_rounded,
                          onTap: _refreshDatabase,
                        ),
                        SizedBox(height: rs.spacing.md),
                        _buildActionButton(
                          rs,
                          label: 'Clear Cache',
                          icon: Icons.delete_outline_rounded,
                          onTap: _clearCache,
                          destructive: true,
                        ),
                      ],
                      SizedBox(height: rs.spacing.xxl),
                    ],
                  ),
                ),
              ),
            ),
            ConsoleHud(
              b: HudAction('Back', onTap: _goBack),
              y: HudAction('Test', onTap: _testConnection),
              x: HudAction('Clear', onTap: _clear),
              start: HudAction('Save', onTap: _save),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBanner(Responsive rs) {
    return Container(
      padding: EdgeInsets.all(rs.isSmall ? 10 : 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD54F).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(rs.radius.md),
        border: Border.all(
          color: const Color(0xFFFFD54F).withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.emoji_events,
            size: rs.isSmall ? 24 : 32,
            color: const Color(0xFFFFD54F),
          ),
          SizedBox(width: rs.spacing.sm),
          Expanded(
            child: Text(
              'Get your API key at\nretroachievements.org/controlpanel.php',
              style: TextStyle(
                fontSize: rs.isSmall ? 10 : 12,
                color: Colors.white.withValues(alpha: 0.7),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    Responsive rs, {
    required String label,
    required TextEditingController controller,
    required FocusNode textFocus,
    required FocusNode consoleFocus,
    required IconData icon,
    bool obscure = false,
    bool autofocus = false,
  }) {
    return ConsoleFocusable(
      focusNode: consoleFocus,
      autofocus: autofocus,
      focusScale: 1.0,
      borderRadius: 12,
      onSelect: () => textFocus.requestFocus(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: rs.isSmall ? 9 : 10,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.5),
              letterSpacing: 1.0,
            ),
          ),
          SizedBox(height: rs.isSmall ? 4 : 6),
          ListenableBuilder(
            listenable: textFocus,
            builder: (context, child) {
              final hasFocus = textFocus.hasFocus;
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(rs.radius.md),
                  border: Border.all(
                    color: hasFocus
                        ? AppTheme.primaryColor
                        : Colors.white.withValues(alpha: 0.15),
                    width: hasFocus ? 2 : 1,
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
                    includeRepeats: false): () => consoleFocus.requestFocus(),
                const SingleActivator(LogicalKeyboardKey.gameButtonB,
                    includeRepeats: false): () => consoleFocus.requestFocus(),
                const SingleActivator(LogicalKeyboardKey.goBack,
                    includeRepeats: false): () => consoleFocus.requestFocus(),
              },
              child: TextField(
                controller: controller,
                focusNode: textFocus,
                obscureText: obscure,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: rs.isSmall ? 14 : 16,
                ),
                decoration: InputDecoration(
                  prefixIcon: Icon(
                    icon,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: rs.spacing.md,
                    vertical: rs.spacing.sm,
                  ),
                ),
                onSubmitted: (_) => consoleFocus.requestFocus(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestButton(Responsive rs) {
    return ConsoleFocusable(
      onSelect: _testConnection,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: rs.spacing.md,
          vertical: rs.spacing.sm + 2,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(rs.radius.md),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isTesting)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.primaryColor,
                ),
              )
            else
              Icon(
                Icons.wifi_tethering,
                size: rs.isSmall ? 16 : 18,
                color: Colors.white70,
              ),
            SizedBox(width: rs.spacing.sm),
            Text(
              _isTesting ? 'Testing...' : 'Test Connection',
              style: TextStyle(
                fontSize: rs.isSmall ? 12 : 14,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestResult(Responsive rs) {
    final success = _testSuccess ?? false;
    return Container(
      padding: EdgeInsets.all(rs.isSmall ? 8 : 10),
      decoration: BoxDecoration(
        color: success
            ? Colors.greenAccent.withValues(alpha: 0.1)
            : Colors.redAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(rs.radius.sm),
        border: Border.all(
          color: success
              ? Colors.greenAccent.withValues(alpha: 0.3)
              : Colors.redAccent.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            success ? Icons.check_circle : Icons.error_outline,
            size: 16,
            color: success ? Colors.greenAccent : Colors.redAccent,
          ),
          SizedBox(width: rs.spacing.sm),
          Expanded(
            child: Text(
              success
                  ? 'Connected successfully'
                  : _testError ?? 'Connection failed',
              style: TextStyle(
                fontSize: rs.isSmall ? 10 : 12,
                color: success ? Colors.greenAccent : Colors.redAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnableToggle(Responsive rs) {
    return Actions(
      actions: {
        NavigateIntent: NavigateAction(ref, onNavigate: (intent) {
          if (intent.direction == GridDirection.left ||
              intent.direction == GridDirection.right) {
            _toggleEnabled();
            return true;
          }
          return false;
        }),
      },
      child: ConsoleFocusable(
        onSelect: _toggleEnabled,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: rs.spacing.md,
            vertical: rs.spacing.sm + 2,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(rs.radius.md),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enable RetroAchievements',
                      style: TextStyle(
                        fontSize: rs.isSmall ? 13 : 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Show achievement data on game cards',
                      style: TextStyle(
                        fontSize: rs.isSmall ? 10 : 12,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              _AnimatedSwitch(value: _enabled),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSyncStatus(Responsive rs, RaSyncState syncState) {
    final storage = ref.read(storageServiceProvider);
    final lastSync = storage.getRaLastSync();
    final syncText = syncState.isSyncing
        ? 'Syncing ${syncState.currentSystem ?? ''}...'
        : lastSync != null
            ? 'Last sync: ${_formatDate(lastSync)}'
            : 'Not synced yet';

    return Container(
      padding: EdgeInsets.all(rs.isSmall ? 8 : 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(rs.radius.sm),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          if (syncState.isSyncing)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: const Color(0xFFFFD54F),
              ),
            )
          else
            Icon(
              Icons.sync,
              size: 14,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          SizedBox(width: rs.spacing.sm),
          Expanded(
            child: Text(
              syncText,
              style: TextStyle(
                fontSize: rs.isSmall ? 10 : 12,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ),
          if (syncState.isSyncing)
            Text(
              '${syncState.completedSystems}/${syncState.totalSystems}',
              style: TextStyle(
                fontSize: rs.isSmall ? 10 : 12,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    Responsive rs, {
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool destructive = false,
  }) {
    final color = destructive ? Colors.redAccent : Colors.white70;
    return ConsoleFocusable(
      onSelect: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: rs.spacing.md,
          vertical: rs.spacing.sm + 2,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(rs.radius.md),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: rs.isSmall ? 16 : 18, color: color),
            SizedBox(width: rs.spacing.sm),
            Text(
              label,
              style: TextStyle(
                fontSize: rs.isSmall ? 12 : 14,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _AnimatedSwitch extends StatelessWidget {
  final bool value;
  const _AnimatedSwitch({required this.value});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 50,
      height: 28,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: value
            ? AppTheme.primaryColor
            : Colors.grey.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Align(
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
