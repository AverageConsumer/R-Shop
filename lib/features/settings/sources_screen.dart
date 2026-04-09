import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/input/input.dart';
import '../../core/responsive/responsive.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/console_focusable.dart';
import '../../core/widgets/screen_layout.dart';
import '../../models/config/provider_config.dart';
import '../../models/config/source.dart';
import '../../models/system_model.dart';
import '../../providers/app_providers.dart';
import '../../providers/game_providers.dart';
import '../../services/romm_api_service.dart';
import '../../services/romm_pairing_service.dart';
import '../../services/romm_platform_matcher.dart';
import '../../services/sources_notifier.dart';
import '../../widgets/console_hud.dart';
import '../../widgets/console_notification.dart';
import '../pairing/qr_pairing_screen.dart';
import '../sources/manual_source_add_screen.dart';
import '../sources/source_mappings_screen.dart';

/// Verwaltungs-Screen für alle gepairten / konfigurierten [Source]s.
///
/// Listet jede Source als fokussierbare Karte. [Y] öffnet den
/// QR-Pairing-Flow um eine neue Source hinzuzufügen, [A] auf einer
/// Karte öffnet einen Action-Overlay (Enable/Disable, Remove). Empty-
/// State zeigt einen Hinweis sobald nichts konfiguriert ist.
///
/// Focus management:
/// - FocusNodes sind in `_focusNodes` per `source.id` gepinned, damit
///   sie ListView-Rebuilds (z.B. beim setState nach addSource)
///   überleben und der Cursor nicht zurückspringt.
/// - Source-Liste lebt in einer FocusTraversalGroup mit Reading-Order-
///   Policy (Top→Bottom).
/// - Action-Overlay nutzt OverlayFocusScope mit OverlayPriority.dialog,
///   um die Screen-Actions korrekt zu pausieren während die Aktionen
///   sichtbar sind.
class SourcesScreen extends ConsumerStatefulWidget {
  const SourcesScreen({super.key});

  @override
  ConsumerState<SourcesScreen> createState() => _SourcesScreenState();
}

class _SourcesScreenState extends ConsumerState<SourcesScreen>
    with ConsoleScreenMixin {
  final FocusNode _addEmptyFocus = FocusNode(debugLabel: 'sources_add_empty');
  final Map<String, FocusNode> _cardFocusNodes = {};
  final ScrollController _scrollController = ScrollController();

  Source? _activeActionsSource;
  bool _showTypePicker = false;

  /// True once we've successfully moved focus off of the screen-level
  /// Focus stub created by [ConsoleScreenMixin.buildWithActions]. Until
  /// that happens, the gamepad input bypasses our cards entirely (the
  /// stub eats the key event before it reaches ConsoleFocusable).
  bool _initialFocusClaimed = false;

  @override
  String get routeId => 'sources_screen';

  @override
  Map<Type, Action<Intent>> get screenActions => {
        BackIntent: BackAction(context, ref),
        SearchIntent: SearchAction(ref, onSearch: _addSource),
        // Custom navigation: only step between source cards on up/down,
        // swallow everything else so the global focus traversal can't
        // leak focus into the screen-level Focus stub or the HUD when
        // there is nothing to move to.
        NavigateIntent: NavigateAction(ref, onNavigate: _onNavigate),
      };

  @override
  Map<ShortcutActivator, Intent>? get additionalShortcuts => {
        const SingleActivator(LogicalKeyboardKey.gameButtonY,
            includeRepeats: false): const SearchIntent(),
      };

  @override
  void dispose() {
    _addEmptyFocus.dispose();
    for (final node in _cardFocusNodes.values) {
      node.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  /// Pulls focus from the mixin's screen-level Focus stub onto either
  /// the first source card or the empty-state add button. Idempotent:
  /// once focus has landed on a real interactive widget the flag stays
  /// flipped and subsequent state changes won't yank focus around.
  void _ensureInteractiveFocus(SourcesState state) {
    if (_initialFocusClaimed || _activeActionsSource != null) return;
    if (state.loading) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _initialFocusClaimed) return;
      if (state.sources.isNotEmpty) {
        final firstId = state.sources.first.id;
        final node = _cardFocusNodes[firstId];
        if (node != null && node.canRequestFocus) {
          node.requestFocus();
          _initialFocusClaimed = true;
        }
      } else if (_addEmptyFocus.canRequestFocus) {
        _addEmptyFocus.requestFocus();
        _initialFocusClaimed = true;
      }
    });
  }

  /// Returns the focus node for [sourceId], creating it on first access.
  /// Stable across rebuilds so the visible focus indicator doesn't jump
  /// when the list mutates.
  FocusNode _focusFor(String sourceId) {
    return _cardFocusNodes.putIfAbsent(
      sourceId,
      () => FocusNode(debugLabel: 'source_card_$sourceId'),
    );
  }

  /// Drops focus nodes for sources that are no longer in the list. Call
  /// after every state read so the map doesn't grow unbounded across
  /// add/remove cycles.
  void _gcFocusNodes(List<Source> currentSources) {
    final liveIds = currentSources.map((s) => s.id).toSet();
    final stale = _cardFocusNodes.keys
        .where((id) => !liveIds.contains(id))
        .toList();
    for (final id in stale) {
      _cardFocusNodes.remove(id)?.dispose();
    }
  }

  void _goBack() {
    ref.read(feedbackServiceProvider).cancel();
    Navigator.of(context).pop();
  }

  /// Handles vertical navigation between source cards. Returns `true`
  /// for every up/down event (even when there's nothing to move to)
  /// so the dispatcher considers the intent handled and the global
  /// focus traversal does not get a second shot at moving focus
  /// somewhere unrelated. Left/right are no-ops on this screen.
  bool _onNavigate(NavigateIntent intent) {
    if (intent.direction == GridDirection.left ||
        intent.direction == GridDirection.right) {
      return true; // swallow
    }
    final sources = ref.read(sourcesProvider).sources;
    if (sources.isEmpty) return true;

    // Find which card currently has focus.
    String? focusedId;
    for (final entry in _cardFocusNodes.entries) {
      if (entry.value.hasFocus) {
        focusedId = entry.key;
        break;
      }
    }
    final currentIndex =
        focusedId == null ? -1 : sources.indexWhere((s) => s.id == focusedId);

    // Nothing focused yet → land on first card.
    if (currentIndex < 0) {
      _cardFocusNodes[sources.first.id]?.requestFocus();
      ref.read(feedbackServiceProvider).tick();
      return true;
    }

    final delta =
        intent.direction == GridDirection.down ? 1 : -1;
    final nextIndex = currentIndex + delta;
    if (nextIndex < 0 || nextIndex >= sources.length) {
      // At the edge — swallow without moving so the global traversal
      // can't claim a sibling outside the list.
      return true;
    }

    _cardFocusNodes[sources[nextIndex].id]?.requestFocus();
    ref.read(feedbackServiceProvider).tick();
    return true;
  }

  void _addSource() {
    // NB: do NOT call canPerformAction() here — SearchAction.invoke
    // already consumed the debounce slot, calling it again immediately
    // would always fail and silently swallow the Y press.
    ref.read(feedbackServiceProvider).tick();
    setState(() => _showTypePicker = true);
  }

  void _closeTypePicker() {
    if (!_showTypePicker) return;
    setState(() => _showTypePicker = false);
  }

  Future<void> _onTypePicked(SourceType type) async {
    setState(() => _showTypePicker = false);
    if (type == SourceType.romm) {
      await _addRommSource();
    } else {
      await _addManualSource(type);
    }
  }

  Future<void> _addManualSource(SourceType type) async {
    final result = await Navigator.of(context).push<Source?>(
      MaterialPageRoute(builder: (_) => ManualSourceAddScreen(type: type)),
    );
    if (!mounted || result == null) return;
    ref.invalidate(bootstrappedConfigProvider);
    ref.invalidate(gamesProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusFor(result.id).requestFocus();
      _initialFocusClaimed = true;
    });
    showSuccessNotification(
      context,
      ref,
      message: 'Added ${result.name} — map systems from its actions menu',
    );
  }

  Future<void> _addRommSource() async {
    final result = await Navigator.of(context).push<RommPairResult?>(
      MaterialPageRoute(builder: (_) => const QrPairingScreen()),
    );
    if (!mounted || result == null) return;

    final source = buildSourceFromPairResult(result);

    Map<String, int> knownPlatforms = const {};
    String? discoveryError;
    try {
      final api = RommApiService();
      final platforms =
          await api.fetchPlatforms(result.serverUrl, auth: source.auth);
      final allSystemIds = SystemModel.supportedSystems.map((s) => s.id);
      knownPlatforms =
          RommPlatformMatcher.buildKnownPlatforms(allSystemIds, platforms);
    } catch (e) {
      debugPrint('SourcesScreen: platform discovery failed: $e');
      discoveryError = e.toString();
    }

    final notifier = ref.read(sourcesProvider.notifier);
    final addedSource = source.copyWith(knownPlatforms: knownPlatforms);
    await notifier.addSource(addedSource);
    ref.invalidate(bootstrappedConfigProvider);

    if (!mounted) return;

    // Move focus onto the freshly added card so the user can immediately
    // act on it without re-grabbing the controller.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusFor(addedSource.id).requestFocus();
      _initialFocusClaimed = true;
    });

    showSuccessNotification(
      context,
      ref,
      message: discoveryError != null
          ? 'Added ${source.name}, but platform discovery failed'
          : 'Added ${source.name} '
              '(${knownPlatforms.length} '
              '${knownPlatforms.length == 1 ? "platform" : "platforms"})',
    );
  }

  void _openSourceActions(Source source) {
    ref.read(feedbackServiceProvider).tick();
    setState(() => _activeActionsSource = source);
  }

  void _closeSourceActions() {
    if (_activeActionsSource == null) return;
    final source = _activeActionsSource!;
    setState(() => _activeActionsSource = null);
    // Restore focus on the card the dialog opened from.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final node = _cardFocusNodes[source.id];
      if (node != null && node.canRequestFocus) node.requestFocus();
    });
  }

  Future<void> _toggleSourceEnabled(Source source) async {
    final notifier = ref.read(sourcesProvider.notifier);
    await notifier.setEnabled(source.id, !source.enabled);
    ref.invalidate(bootstrappedConfigProvider);
    // gamesProvider doesn't watch bootstrappedConfig, so the DB-cached
    // game lists in HomeView/Library wouldn't refresh on their own.
    ref.invalidate(gamesProvider);
    if (mounted) _closeSourceActions();
  }

  /// Re-pair flow: closes the action overlay, opens the QR scanner, and on
  /// success calls [SourcesNotifier.refreshTokenFromPair] which preserves
  /// the existing source's id, name, and per-system mappings while
  /// swapping in the fresh bearer token + expiry. Used by the user when a
  /// borrowed token is about to expire (or already has).
  Future<void> _repairSource(Source source) async {
    setState(() => _activeActionsSource = null);

    final result = await Navigator.of(context).push<RommPairResult?>(
      MaterialPageRoute(builder: (_) => const QrPairingScreen()),
    );
    if (!mounted || result == null) return;

    // Re-discover the platform map against the (possibly new) URL so the
    // existing knownPlatforms cache stays in sync after re-pair.
    Map<String, int>? platforms;
    try {
      final api = RommApiService();
      final fetched = await api.fetchPlatforms(
        result.serverUrl,
        auth: AuthConfig(clientToken: result.token),
      );
      final allSystemIds = SystemModel.supportedSystems.map((s) => s.id);
      platforms =
          RommPlatformMatcher.buildKnownPlatforms(allSystemIds, fetched);
    } catch (e) {
      debugPrint('SourcesScreen: re-pair platform discovery failed: $e');
    }

    final notifier = ref.read(sourcesProvider.notifier);
    try {
      await notifier.refreshTokenFromPair(
        source.id,
        result,
        knownPlatforms: platforms,
      );
      ref.invalidate(bootstrappedConfigProvider);
    } catch (e) {
      debugPrint('SourcesScreen: refreshTokenFromPair failed: $e');
      if (mounted) {
        showErrorNotification(context, ref,
            message: 'Re-pair failed: $e');
      }
      return;
    }

    if (!mounted) return;
    // Restore focus to the (still-existing) card.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusFor(source.id).requestFocus();
    });
    showSuccessNotification(
      context,
      ref,
      message: 'Re-paired ${source.name}',
    );
  }

  /// Edit per-system path mappings for a manual source. Closes the
  /// action overlay, opens the mapping editor, and on save invalidates
  /// the game/config providers so the new mappings take effect.
  Future<void> _editMappings(Source source) async {
    setState(() => _activeActionsSource = null);
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => SourceMappingsScreen(source: source)),
    );
    if (!mounted) return;
    if (saved == true) {
      ref.invalidate(bootstrappedConfigProvider);
      ref.invalidate(gamesProvider);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusFor(source.id).requestFocus();
    });
  }

  Future<void> _removeSource(Source source) async {
    final notifier = ref.read(sourcesProvider.notifier);
    await notifier.removeSource(source.id);
    ref.invalidate(bootstrappedConfigProvider);
    ref.invalidate(gamesProvider);
    if (mounted) {
      // Skip the focus-restore-on-deleted-card path.
      setState(() => _activeActionsSource = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final state = ref.watch(sourcesProvider);
    _gcFocusNodes(state.sources);
    _ensureInteractiveFocus(state);

    return buildWithActions(
      ScreenLayout(
        body: Stack(
          children: [
            Column(
              children: [
                _Header(rs: rs, count: state.sources.length),
                Expanded(
                  child: state.loading
                      ? const Center(child: CircularProgressIndicator())
                      : state.sources.isEmpty
                          ? _EmptyState(
                              rs: rs,
                              focusNode: _addEmptyFocus,
                              onAdd: _addSource,
                            )
                          : _SourceList(
                              sources: state.sources,
                              focusForId: _focusFor,
                              onTap: _openSourceActions,
                              scrollController: _scrollController,
                              rs: rs,
                            ),
                ),
              ],
            ),
            ConsoleHud(
              b: HudAction('Back', onTap: _goBack),
              y: HudAction('Add Source', onTap: _addSource),
            ),
            if (_activeActionsSource != null)
              _SourceActionsOverlay(
                source: _activeActionsSource!,
                onClose: _closeSourceActions,
                onToggleEnabled: () =>
                    _toggleSourceEnabled(_activeActionsSource!),
                onRemove: () => _removeSource(_activeActionsSource!),
                onRepair: () => _repairSource(_activeActionsSource!),
                onEditMappings: () =>
                    _editMappings(_activeActionsSource!),
              ),
            if (_showTypePicker)
              _SourceTypePickerOverlay(
                onClose: _closeTypePicker,
                onPick: _onTypePicked,
              ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.rs, required this.count});
  final Responsive rs;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        rs.spacing.lg,
        rs.safeAreaTop + rs.spacing.md,
        rs.spacing.lg,
        rs.spacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SOURCES',
            style: TextStyle(
              fontSize: rs.isSmall ? 22 : 28,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 4,
            ),
          ),
          SizedBox(height: rs.spacing.xs),
          Text(
            count == 0
                ? 'No sources configured'
                : '$count source${count == 1 ? "" : "s"} · [Y] add new',
            style: TextStyle(
              fontSize: rs.isSmall ? 10 : 12,
              color: Colors.grey.shade500,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.rs,
    required this.focusNode,
    required this.onAdd,
  });
  final Responsive rs;
  final FocusNode focusNode;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: rs.isSmall ? 56 : 72,
              color: Colors.white24,
            ),
            SizedBox(height: rs.spacing.lg),
            Text(
              'No sources yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: rs.isSmall ? 16 : 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: rs.spacing.sm),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: rs.spacing.lg),
              child: Text(
                'Pair a RomM server to start downloading games. '
                'Press [Y] or tap below to add one.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: rs.isSmall ? 11 : 13,
                ),
              ),
            ),
            SizedBox(height: rs.spacing.lg),
            ConsoleFocusable(
              focusNode: focusNode,
              autofocus: true,
              onSelect: onAdd,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: rs.spacing.lg,
                  vertical: rs.spacing.md,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.primaryColor, width: 2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.add, color: AppTheme.primaryColor),
                    SizedBox(width: 8),
                    Text(
                      'Add source',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceList extends StatelessWidget {
  const _SourceList({
    required this.sources,
    required this.focusForId,
    required this.onTap,
    required this.scrollController,
    required this.rs,
  });

  final List<Source> sources;
  final FocusNode Function(String sourceId) focusForId;
  final void Function(Source source) onTap;
  final ScrollController scrollController;
  final Responsive rs;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: FocusTraversalGroup(
          policy: ReadingOrderTraversalPolicy(),
          child: ListView.separated(
            controller: scrollController,
            padding: EdgeInsets.symmetric(
              horizontal: rs.spacing.lg,
              vertical: rs.spacing.md,
            ),
            itemCount: sources.length,
            separatorBuilder: (_, __) => SizedBox(height: rs.spacing.md),
            itemBuilder: (context, index) {
              final source = sources[index];
              return _SourceCard(
                key: ValueKey('source_card_${source.id}'),
                source: source,
                focusNode: focusForId(source.id),
                autofocus: index == 0,
                onTap: () => onTap(source),
                rs: rs,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({
    super.key,
    required this.source,
    required this.focusNode,
    required this.autofocus,
    required this.onTap,
    required this.rs,
  });

  final Source source;
  final FocusNode focusNode;
  final bool autofocus;
  final VoidCallback onTap;
  final Responsive rs;

  Color get _accent {
    if (source.borrowed) return Colors.lightBlueAccent;
    switch (source.type) {
      case SourceType.romm:
        return Colors.greenAccent;
      case SourceType.smb:
        return Colors.amberAccent;
      case SourceType.ftp:
        return Colors.purpleAccent;
      case SourceType.web:
        return Colors.tealAccent;
      case SourceType.local:
        return Colors.white70;
    }
  }

  IconData get _icon {
    switch (source.type) {
      case SourceType.romm:
        return source.borrowed ? Icons.share : Icons.dns_outlined;
      case SourceType.smb:
        return Icons.folder_shared;
      case SourceType.ftp:
        return Icons.cloud_queue;
      case SourceType.web:
        return Icons.public;
      case SourceType.local:
        return Icons.sd_card;
    }
  }

  String? _expiryLabel() {
    final exp = source.tokenExpiresAt;
    if (exp == null) return null;
    final delta = exp.difference(DateTime.now());
    if (delta.isNegative) return 'EXPIRED';
    if (delta.inDays >= 2) return 'Expires in ${delta.inDays}d';
    if (delta.inHours >= 2) return 'Expires in ${delta.inHours}h';
    return 'Expires in ${delta.inMinutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final platformCount = source.knownPlatforms.length;
    final expiry = _expiryLabel();
    final expiryUrgent = expiry != null &&
        source.tokenExpiresAt != null &&
        source.tokenExpiresAt!.difference(DateTime.now()).inDays < 7;

    return ConsoleFocusable(
      focusNode: focusNode,
      autofocus: autofocus,
      onSelect: onTap,
      borderRadius: 12,
      child: Container(
        padding: EdgeInsets.all(rs.spacing.md),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1C),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: source.enabled
                ? _accent.withValues(alpha: 0.4)
                : Colors.white12,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(_icon, color: _accent, size: 22),
            ),
            SizedBox(width: rs.spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          source.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: source.enabled
                                ? Colors.white
                                : Colors.white54,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (source.borrowed) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color:
                                Colors.lightBlueAccent.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: Colors.lightBlueAccent
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                          child: const Text(
                            'BORROWED',
                            style: TextStyle(
                              color: Colors.lightBlueAccent,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                      if (!source.enabled) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white12,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'OFF',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${source.type.name.toUpperCase()} · ${source.hostLabel}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.games,
                          size: 11, color: Colors.grey.shade500),
                      const SizedBox(width: 3),
                      Text(
                        platformCount == 0
                            ? 'No platforms'
                            : '$platformCount '
                                '${platformCount == 1 ? "platform" : "platforms"}',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 11,
                        ),
                      ),
                      if (expiry != null) ...[
                        const SizedBox(width: 10),
                        Icon(
                          Icons.schedule,
                          size: 11,
                          color: expiryUrgent
                              ? Colors.orangeAccent
                              : Colors.grey.shade500,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          expiry,
                          style: TextStyle(
                            color: expiryUrgent
                                ? Colors.orangeAccent
                                : Colors.grey.shade500,
                            fontSize: 11,
                            fontWeight: expiryUrgent
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white30),
          ],
        ),
      ),
    );
  }
}

/// Modal-style overlay for source actions. Lives inside the screen's
/// own Stack (not a separate route) so the existing focus tree, gamepad
/// shortcuts and ConsoleScreenMixin keep working without dialog-routing
/// gymnastics. Uses [OverlayFocusScope] so the parent screen's actions
/// are correctly suppressed while the overlay is visible.
class _SourceActionsOverlay extends ConsumerStatefulWidget {
  const _SourceActionsOverlay({
    required this.source,
    required this.onClose,
    required this.onToggleEnabled,
    required this.onRemove,
    required this.onRepair,
    required this.onEditMappings,
  });

  final Source source;
  final VoidCallback onClose;
  final VoidCallback onToggleEnabled;
  final VoidCallback onRemove;
  final VoidCallback onRepair;
  final VoidCallback onEditMappings;

  @override
  ConsumerState<_SourceActionsOverlay> createState() =>
      _SourceActionsOverlayState();
}

class _SourceActionsOverlayState extends ConsumerState<_SourceActionsOverlay> {
  final FocusNode _scopeFocus =
      FocusNode(debugLabel: 'source_actions_overlay');
  int _selectedIndex = 0;

  /// Build the ordered list of actions for the current source. Re-pair is
  /// only offered for RomM sources because the QR/code flow is RomM-only.
  List<_OverlayAction> get _actions {
    final src = widget.source;
    return [
      if (src.type == SourceType.romm)
        _OverlayAction(
          icon: Icons.qr_code_2,
          label: 'Re-pair',
          onActivate: widget.onRepair,
        ),
      if (src.type != SourceType.romm)
        _OverlayAction(
          icon: Icons.tune,
          label: 'Edit mappings',
          onActivate: widget.onEditMappings,
        ),
      _OverlayAction(
        icon: src.enabled ? Icons.toggle_off : Icons.toggle_on,
        label: src.enabled ? 'Disable' : 'Enable',
        onActivate: widget.onToggleEnabled,
      ),
      _OverlayAction(
        icon: Icons.delete_outline,
        label: 'Remove',
        destructive: true,
        onActivate: widget.onRemove,
      ),
      _OverlayAction(
        icon: Icons.close,
        label: 'Cancel',
        cancelStyle: true,
        onActivate: widget.onClose,
      ),
    ];
  }

  @override
  void dispose() {
    _scopeFocus.dispose();
    super.dispose();
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;

    final count = _actions.length;
    if (key == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _selectedIndex = (_selectedIndex - 1 + count) % count;
      });
      ref.read(feedbackServiceProvider).tick();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _selectedIndex = (_selectedIndex + 1) % count;
      });
      ref.read(feedbackServiceProvider).tick();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.gameButtonA ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.select) {
      _activate();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.gameButtonB ||
        key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack) {
      ref.read(feedbackServiceProvider).cancel();
      widget.onClose();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _activate() {
    final action = _actions[_selectedIndex];
    if (action.cancelStyle) {
      ref.read(feedbackServiceProvider).cancel();
    } else {
      ref.read(feedbackServiceProvider).confirm();
    }
    action.onActivate();
  }

  @override
  Widget build(BuildContext context) {
    final src = widget.source;
    return OverlayFocusScope(
      priority: OverlayPriority.dialog,
      isVisible: true,
      onClose: widget.onClose,
      child: Focus(
        focusNode: _scopeFocus,
        autofocus: true,
        onKeyEvent: _onKeyEvent,
        child: Container(
          color: Colors.black.withValues(alpha: 0.75),
          child: Center(
            child: Material(
              type: MaterialType.transparency,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1C),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        src.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        src.hostLabel,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 20),
                      for (int i = 0; i < _actions.length; i++) ...[
                        if (i > 0) const SizedBox(height: 8),
                        _OverlayButton(
                          icon: _actions[i].icon,
                          label: _actions[i].label,
                          selected: _selectedIndex == i,
                          destructive: _actions[i].destructive,
                          subdued: _actions[i].cancelStyle,
                        ),
                      ],
                      const SizedBox(height: 12),
                      const Center(
                        child: Text(
                          '↑↓ navigate · [A] select · [B] back',
                          style: TextStyle(
                            color: Colors.white30,
                            fontSize: 10,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OverlayAction {
  const _OverlayAction({
    required this.icon,
    required this.label,
    required this.onActivate,
    this.destructive = false,
    this.cancelStyle = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onActivate;
  final bool destructive;
  final bool cancelStyle;
}

class _OverlayButton extends StatelessWidget {
  const _OverlayButton({
    required this.icon,
    required this.label,
    required this.selected,
    this.destructive = false,
    this.subdued = false,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool destructive;
  final bool subdued;

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? Colors.redAccent
        : subdued
            ? Colors.white70
            : AppTheme.primaryColor;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: selected ? 0.25 : 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected ? color : color.withValues(alpha: 0.3),
          width: selected ? 2 : 1,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 12,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

/// Modal that asks the user which kind of source they want to add. RomM
/// hands off to the QR/code pairing flow; the other types open the
/// generic [ManualSourceAddScreen]. Local folders are intentionally not
/// offered here — they live on each system as `targetFolder` already, so
/// a "local source" entry would just duplicate state.
class _SourceTypePickerOverlay extends ConsumerStatefulWidget {
  const _SourceTypePickerOverlay({
    required this.onClose,
    required this.onPick,
  });

  final VoidCallback onClose;
  final void Function(SourceType type) onPick;

  @override
  ConsumerState<_SourceTypePickerOverlay> createState() =>
      _SourceTypePickerOverlayState();
}

class _SourceTypePickerOverlayState
    extends ConsumerState<_SourceTypePickerOverlay> {
  final FocusNode _scopeFocus =
      FocusNode(debugLabel: 'source_type_picker');
  int _selectedIndex = 0;

  static const List<_TypeOption> _options = [
    _TypeOption(
      type: SourceType.romm,
      icon: Icons.qr_code_2,
      label: 'RomM Server',
      hint: 'Pair via QR or 8-digit code',
    ),
    _TypeOption(
      type: SourceType.smb,
      icon: Icons.folder_shared,
      label: 'SMB Share',
      hint: 'Windows / NAS network share',
    ),
    _TypeOption(
      type: SourceType.ftp,
      icon: Icons.cloud_queue,
      label: 'FTP Server',
      hint: 'Classic FTP/FTPS host',
    ),
    _TypeOption(
      type: SourceType.web,
      icon: Icons.public,
      label: 'Web Mirror',
      hint: 'HTTPS directory listing',
    ),
  ];

  @override
  void dispose() {
    _scopeFocus.dispose();
    super.dispose();
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowUp) {
      setState(() => _selectedIndex =
          (_selectedIndex - 1 + _options.length) % _options.length);
      ref.read(feedbackServiceProvider).tick();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      setState(() =>
          _selectedIndex = (_selectedIndex + 1) % _options.length);
      ref.read(feedbackServiceProvider).tick();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.gameButtonA ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.select) {
      ref.read(feedbackServiceProvider).confirm();
      widget.onPick(_options[_selectedIndex].type);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.gameButtonB ||
        key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack) {
      ref.read(feedbackServiceProvider).cancel();
      widget.onClose();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return OverlayFocusScope(
      priority: OverlayPriority.dialog,
      isVisible: true,
      onClose: widget.onClose,
      child: Focus(
        focusNode: _scopeFocus,
        autofocus: true,
        onKeyEvent: _onKeyEvent,
        child: Container(
          color: Colors.black.withValues(alpha: 0.78),
          child: Center(
            child: Material(
              type: MaterialType.transparency,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1C),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Add a source',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Where do your games come from?',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 16),
                      for (int i = 0; i < _options.length; i++) ...[
                        if (i > 0) const SizedBox(height: 8),
                        _TypeOptionTile(
                          option: _options[i],
                          selected: _selectedIndex == i,
                        ),
                      ],
                      const SizedBox(height: 14),
                      const Center(
                        child: Text(
                          '↑↓ navigate · [A] select · [B] back',
                          style: TextStyle(
                            color: Colors.white30,
                            fontSize: 10,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeOption {
  const _TypeOption({
    required this.type,
    required this.icon,
    required this.label,
    required this.hint,
  });
  final SourceType type;
  final IconData icon;
  final String label;
  final String hint;
}

class _TypeOptionTile extends StatelessWidget {
  const _TypeOptionTile({required this.option, required this.selected});
  final _TypeOption option;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.primaryColor;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: selected ? 0.22 : 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected ? color : color.withValues(alpha: 0.3),
          width: selected ? 2 : 1,
        ),
        boxShadow: selected
            ? [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 12)]
            : null,
      ),
      child: Row(
        children: [
          Icon(option.icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  option.label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  option.hint,
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 11,
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
