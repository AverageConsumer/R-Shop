import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/input/input.dart';
import '../../core/responsive/responsive.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/console_focusable.dart';
import '../../core/widgets/screen_layout.dart';
import '../../l10n/app_localizations.dart';
import '../../models/config/provider_config.dart';
import '../../models/config/source.dart';
import '../../models/system_model.dart';
import '../../providers/app_providers.dart';
import '../../providers/game_providers.dart';
import '../../providers/library_providers.dart';
import '../../providers/source_health_providers.dart';
import '../../services/romm_api_service.dart';
import '../../services/romm_pairing_service.dart';
import '../../services/romm_platform_matcher.dart';
import '../../services/sources_notifier.dart';
import '../../widgets/console_dialog.dart';
import '../../widgets/console_hud.dart';
import '../../widgets/console_notification.dart';
import '../onboarding/widgets/romm_legacy_login_screen.dart';
import '../pairing/qr_pairing_screen.dart';
import '../sources/fallback_picker_overlay.dart';
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


  /// Which source is designated as in use, read straight from the notifier.
  ///
  /// Deliberately not mirrored in a field of this State. It used to be, seeded
  /// with `_activeSourceId ??= stored` — and `??=` cannot represent
  /// "deliberately none", so the next build re-seeded it from the stored value
  /// and the toggle needed a second press to take. One source of truth.
  String? get _primarySourceId => ref.read(sourcesProvider).primarySourceId;

  /// Set while the fallback picker is open.
  String? _fallbackPickerSourceId;

  /// Set while creating a new source triggered from inside the fallback picker.
  /// When source creation finishes or cancels, fallback picker re-opens for this source.
  String? _addingFallbackForSourceId;

  /// Which card the gamepad is sitting on. The list-level shortcuts act on
  /// this source, and the HUD reads its state — the disable hint has to say
  /// which of the two things it is about to do.
  ///
  /// Kept rather than recomputed on demand because focus changes do not
  /// rebuild this widget by themselves, and a stale hint is worse than none.
  String? _focusedSourceId;

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
        _SourceShortcutIntent: _SourceShortcutAction(ref, _onSourceShortcut),
      };

  @override
  Map<ShortcutActivator, Intent>? get additionalShortcuts => {
        const SingleActivator(LogicalKeyboardKey.gameButtonY,
            includeRepeats: false): const SearchIntent(),
        // The three things done most often here, bound on the list itself so
        // they no longer cost a menu. The menu keeps them as well: the eye on
        // the row and the menu rows are the finger half of the same actions.
        //
        // L1/R1 are the grid column controls globally; this map is merged
        // after the defaults, so on this screen they mean these instead.
        const SingleActivator(LogicalKeyboardKey.gameButtonX,
                includeRepeats: false):
            const _SourceShortcutIntent(_SourceShortcut.toggleActive),
        const SingleActivator(LogicalKeyboardKey.gameButtonLeft1,
                includeRepeats: false):
            const _SourceShortcutIntent(_SourceShortcut.toggleEnabled),
        const SingleActivator(LogicalKeyboardKey.gameButtonRight1,
                includeRepeats: false):
            const _SourceShortcutIntent(_SourceShortcut.remove),
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
    // Deleting the last source disposes the card that had focus, leaving the
    // screen with nothing focusable — the gamepad then does nothing at all and
    // only touch still works. The claim has to be given up whenever the list
    // the focus was living in disappears, so the empty state can take it.
    if (_initialFocusClaimed &&
        !_cardFocusNodes.values.any((n) => n.hasFocus) &&
        !_addEmptyFocus.hasFocus) {
      _initialFocusClaimed = false;
    }
    // ...and it must not run while an overlay owns the focus. Any overlay,
    // not just the actions menu: the group editor stays open across a config
    // write (creating a group rewrites the sources list), and the rebuild that
    // followed used to yank focus onto the card behind it — the pad stopped
    // driving the overlay mid-edit while it was still on screen.
    if (_initialFocusClaimed || _anyOverlayOpen) return;
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

  /// True while anything is layered over the list. Each of these has its own
  /// focus scope, so the list must not compete for focus with it.
  bool get _anyOverlayOpen =>
      _activeActionsSource != null ||
      _fallbackPickerSourceId != null ||
      _showTypePicker;

  /// Returns the focus node for [sourceId], creating it on first access.
  /// Stable across rebuilds so the visible focus indicator doesn't jump
  /// when the list mutates.
  FocusNode _focusFor(String sourceId) {
    return _cardFocusNodes.putIfAbsent(
      sourceId,
      () {
        final node = FocusNode(debugLabel: 'source_card_$sourceId');
        // Only ever set, never cleared on focus loss: moving between cards
        // passes through a moment where nothing is focused, and clearing
        // there would blank the HUD hints on every press.
        node.addListener(() {
          if (!mounted || !node.hasFocus) return;
          if (_focusedSourceId == sourceId) return;
          setState(() => _focusedSourceId = sourceId);
        });
        return node;
      },
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
    // A removed source must not keep driving the HUD hints.
    if (_focusedSourceId != null && !liveIds.contains(_focusedSourceId)) {
      _focusedSourceId = null;
    }
  }

  /// The source the shortcuts and the HUD act on. Reads live focus first so a
  /// press is always applied to what the border is drawn around, and falls
  /// back to the last remembered card for the gap between two cards.
  Source? _focusedSource(List<Source> sources) {
    for (final entry in _cardFocusNodes.entries) {
      if (entry.value.hasFocus) {
        return sources.where((s) => s.id == entry.key).firstOrNull;
      }
    }
    final id = _focusedSourceId;
    if (id == null) return null;
    return sources.where((s) => s.id == id).firstOrNull;
  }

  /// Runs one of the three list-level shortcuts against the focused card.
  void _onSourceShortcut(_SourceShortcut shortcut) {
    final source = _focusedSource(ref.read(sourcesProvider).sources);
    if (source == null) return;
    switch (shortcut) {
      case _SourceShortcut.toggleActive:
        ref.read(feedbackServiceProvider).confirm();
        _toggleActiveSource(source);
      case _SourceShortcut.toggleEnabled:
        ref.read(feedbackServiceProvider).confirm();
        _toggleSourceEnabled(source);
      case _SourceShortcut.remove:
        _confirmRemoveSource(source);
    }
  }

  /// Removal from the list asks first. In the menu it takes three deliberate
  /// presses to reach; here it is one, and it drops the source's whole
  /// library listing — so the one press has to be the one that opens a
  /// question, not the one that does it.
  Future<void> _confirmRemoveSource(Source source) async {
    final l = L.of(context);
    ref.read(feedbackServiceProvider).tick();
    final confirmed = await showConsoleDialog(
      context,
      title: l.sources_removeConfirmTitle,
      message: l.sources_removeConfirmMessage(source.name),
      primaryLabel: l.common_remove,
      isDestructive: true,
    );
    if (confirmed != true || !mounted) return;
    await _removeSource(source);
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

  void _addFreshFallbackSource(String parentId) {
    _addingFallbackForSourceId = parentId;
    ref.read(feedbackServiceProvider).tick();
    setState(() {
      _fallbackPickerSourceId = null;
      _activeActionsSource = null;
      _showTypePicker = true;
    });
  }

  @visibleForTesting
  void addFreshFallbackSourceForTest(String parentId) =>
      _addFreshFallbackSource(parentId);

  @visibleForTesting
  void closeTypePickerForTest() => _closeTypePicker();

  void _closeTypePicker() {
    if (!_showTypePicker) return;
    setState(() {
      _showTypePicker = false;
      if (_addingFallbackForSourceId != null) {
        _fallbackPickerSourceId = _addingFallbackForSourceId;
        _addingFallbackForSourceId = null;
        _activeActionsSource = null;
      }
    });
  }

  Future<void> _onTypePicked(_TypeOption option) async {
    setState(() => _showTypePicker = false);
    if (option.type == SourceType.romm && !option.isLegacy) {
      await _addRommSource();
    } else if (option.type == SourceType.romm && option.isLegacy) {
      await _addRommLegacy();
    } else {
      await _addManualSource(option.type);
    }
  }

  Future<void> _addManualSource(SourceType type) async {
    final result = await Navigator.of(context).push<Source?>(
      MaterialPageRoute(builder: (_) => ManualSourceAddScreen(type: type)),
    );
    if (!mounted) return;
    if (result == null) {
      if (_addingFallbackForSourceId != null) {
        setState(() {
          _fallbackPickerSourceId = _addingFallbackForSourceId;
          _addingFallbackForSourceId = null;
          _activeActionsSource = null;
        });
      }
      return;
    }

    if (_addingFallbackForSourceId != null) {
      final parentId = _addingFallbackForSourceId!;
      _addingFallbackForSourceId = null;
      await ref.read(sourcesProvider.notifier).addFallbackSource(parentId, result.id);
      setState(() {
        _fallbackPickerSourceId = parentId;
        _activeActionsSource = null;
      });
    }

    ref.invalidate(bootstrappedConfigProvider);
    ref.invalidate(gamesProvider);
    if (!mounted) return;
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
      MaterialPageRoute(builder: (_) => QrPairingScreen()),
    );
    if (!mounted) return;
    if (result == null) {
      if (_addingFallbackForSourceId != null) {
        setState(() {
          _fallbackPickerSourceId = _addingFallbackForSourceId;
          _addingFallbackForSourceId = null;
          _activeActionsSource = null;
        });
      }
      return;
    }

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

    if (_addingFallbackForSourceId != null) {
      final parentId = _addingFallbackForSourceId!;
      _addingFallbackForSourceId = null;
      await notifier.addFallbackSource(parentId, addedSource.id);
      setState(() {
        _fallbackPickerSourceId = parentId;
        _activeActionsSource = null;
      });
    }

    // Auto-create SystemConfigs for platforms the user doesn't have yet.
    final basePath = ref.read(storageServiceProvider).getRomPath()
        ?? '/storage/emulated/0/ROMs';
    final newConsoles = await notifier.ensureSystemsForSource(
      addedSource,
      basePath: basePath,
    );

    ref.invalidate(bootstrappedConfigProvider);
    ref.invalidate(gamesProvider);
    ref.read(gameDbChangedProvider.notifier).state++;

    if (!mounted) return;

    // Move focus onto the freshly added card so the user can immediately
    // act on it without re-grabbing the controller.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusFor(addedSource.id).requestFocus();
      _initialFocusClaimed = true;
    });

    final String message;
    if (discoveryError != null) {
      message = 'Added ${source.name}, but platform discovery failed';
    } else if (newConsoles.names.isNotEmpty) {
      message = 'Added ${source.name} — '
          '${newConsoles.names.length} new console${newConsoles.names.length == 1 ? '' : 's'}: '
          '${newConsoles.names.join(', ')}';
    } else {
      message = 'Added ${source.name} '
          '(${knownPlatforms.length} '
          '${knownPlatforms.length == 1 ? "platform" : "platforms"})';
    }

    showSuccessNotification(context, ref, message: message);
  }

  Future<void> _addRommLegacy() async {
    final source = await Navigator.of(context).push<Source?>(
      MaterialPageRoute(builder: (_) => const RommLegacyLoginScreen()),
    );
    if (!mounted) return;
    if (source == null) {
      if (_addingFallbackForSourceId != null) {
        setState(() {
          _fallbackPickerSourceId = _addingFallbackForSourceId;
          _addingFallbackForSourceId = null;
          _activeActionsSource = null;
        });
      }
      return;
    }

    final notifier = ref.read(sourcesProvider.notifier);
    await notifier.addSource(source);

    if (_addingFallbackForSourceId != null) {
      final parentId = _addingFallbackForSourceId!;
      _addingFallbackForSourceId = null;
      await notifier.addFallbackSource(parentId, source.id);
      setState(() {
        _fallbackPickerSourceId = parentId;
        _activeActionsSource = null;
      });
    }

    final basePath = ref.read(storageServiceProvider).getRomPath()
        ?? '/storage/emulated/0/ROMs';
    final newConsoles = await notifier.ensureSystemsForSource(
      source,
      basePath: basePath,
    );

    ref.invalidate(bootstrappedConfigProvider);
    ref.invalidate(gamesProvider);
    ref.read(gameDbChangedProvider.notifier).state++;

    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusFor(source.id).requestFocus();
      _initialFocusClaimed = true;
    });

    final String message;
    if (newConsoles.names.isNotEmpty) {
      message = 'Added ${source.name} — '
          '${newConsoles.names.length} new console${newConsoles.names.length == 1 ? '' : 's'}: '
          '${newConsoles.names.join(', ')}';
    } else {
      message = 'Added ${source.name} '
          '(${source.knownPlatforms.length} '
          '${source.knownPlatforms.length == 1 ? "platform" : "platforms"})';
    }

    showSuccessNotification(context, ref, message: message);
  }

  void _openSourceActions(Source source) {
    ref.read(feedbackServiceProvider).tick();
    setState(() => _activeActionsSource = source);
  }

  Source? _sourceById(String id) =>
      ref.read(sourcesProvider).sources.where((s) => s.id == id).firstOrNull;

  void _openFallbackPicker(Source source) {
    setState(() {
      _activeActionsSource = null;
      _fallbackPickerSourceId = source.id;
    });
  }

  void _closeFallbackPicker() {
    if (_fallbackPickerSourceId == null) return;
    final source = _sourceById(_fallbackPickerSourceId!);
    setState(() {
      _fallbackPickerSourceId = null;
      _activeActionsSource = source;
    });
  }

  /// Designates the source in use — what syncs, and what the home screen
  /// opens on. A plain two-state toggle: this one, or none.
  ///
  /// Not the same button as the home screen's triggers. Those change what is
  /// **shown**, which is a look you can take back; this one changes what the
  /// app actually works against.
  ///
  /// **Never discards cached games** — the other source's library stays in the
  /// database so coming back is instant. That is what separates this from
  /// disabling a source.
  Future<void> _toggleActiveSource(Source source) async {
    final next = _primarySourceId == source.id ? null : source.id;
    setState(() => _activeActionsSource = null);
    try {
      await ref.read(sourcesProvider.notifier).setPrimarySource(next);
      ref.invalidate(bootstrappedConfigProvider);
    } catch (e) {
      debugPrint('SourcesScreen: setPrimarySource failed: $e');
    }
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
    ref.invalidate(gamesProvider);
    ref.read(gameDbChangedProvider.notifier).state++;
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
      MaterialPageRoute(builder: (_) => QrPairingScreen()),
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
      ref.invalidate(gamesProvider);
      ref.read(gameDbChangedProvider.notifier).state++;
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
      ref.read(gameDbChangedProvider.notifier).state++;
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
    ref.read(gameDbChangedProvider.notifier).state++;
    if (mounted) {
      // Skip the focus-restore-on-deleted-card path.
      setState(() => _activeActionsSource = null);
    }
  }

  /// The per-source hints only appear once a card is focused, because their
  /// labels depend on that card: "disable" or "enable", "use this" or "stop
  /// using". With nothing focused they would have to guess.
  Widget _buildHud(
    BuildContext context,
    SourcesState state,
    String? primary,
  ) {
    final l = L.of(context);
    final source = state.loading ? null : _focusedSource(state.sources);
    return ConsoleHud(
      b: HudAction(l.common_back, onTap: _goBack),
      y: HudAction(l.sources_addSource, onTap: _addSource),
      x: source == null
          ? null
          : HudAction(
              primary == source.id
                  ? l.sources_stopUsingShort
                  : l.sources_useThisShort,
              onTap: () => _toggleActiveSource(source),
            ),
      lb: source == null
          ? null
          : HudAction(
              source.enabled ? l.sources_disable : l.sources_enable,
              onTap: () => _toggleSourceEnabled(source),
            ),
      rb: source == null
          ? null
          : HudAction(
              l.common_remove,
              onTap: () => _confirmRemoveSource(source),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final state = ref.watch(sourcesProvider);
    // Watched, not mirrored: the config is the only thing that knows which
    // source is in use, and every label on this screen reads from it.
    // From the notifier, not the config future. Invalidating that one means a
    // disk read, and until it lands `valueOrNull` still hands back the old id
    // — the press looked like it had not registered.
    final primary = state.primarySourceId;
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
                              onToggleActive: _toggleActiveSource,
                              onToggleShown: _toggleSourceEnabled,
                              scrollController: _scrollController,
                              rs: rs,
                            ),
                ),
              ],
            ),
            // Every hint here is also a button: the HUD is the finger half of
            // the same three shortcuts, so neither input is a dead end.
            _buildHud(context, state, primary),
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
                onEditFallback: () =>
                    _openFallbackPicker(_activeActionsSource!),
                isActive: primary == _activeActionsSource!.id,
                onToggleActive: () =>
                    _toggleActiveSource(_activeActionsSource!),
                hasOtherSources: state.sources.length > 1,
              ),
            if (_showTypePicker)
              _SourceTypePickerOverlay(
                onClose: _closeTypePicker,
                onPick: _onTypePicked,
              ),
            if (_fallbackPickerSourceId != null)
              Builder(
                builder: (context) {
                  final src = ref
                      .watch(sourcesProvider)
                      .sources
                      .where((s) => s.id == _fallbackPickerSourceId)
                      .firstOrNull;
                  if (src == null) return const SizedBox.shrink();
                  return FallbackPickerOverlay(
                    sourceId: src.id,
                    onClose: _closeFallbackPicker,
                    onAddFreshSource: () => _addFreshFallbackSource(src.id),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// The list-level shortcuts. One intent with a payload rather than three
/// intent types, because [ConsoleScreenMixin.screenActions] is keyed by type
/// and three keys would need three near-identical actions.
enum _SourceShortcut { toggleActive, toggleEnabled, remove }

class _SourceShortcutIntent extends Intent {
  const _SourceShortcutIntent(this.shortcut);
  final _SourceShortcut shortcut;
}

class _SourceShortcutAction extends Action<_SourceShortcutIntent> {
  _SourceShortcutAction(this.ref, this.onShortcut);

  final WidgetRef ref;
  final void Function(_SourceShortcut) onShortcut;

  /// Held off while any overlay is up. The action menu answers X itself, but
  /// nothing answers L1/R1 — without this they would fire underneath an open
  /// overlay, acting on a card the user can no longer see.
  @override
  bool isEnabled(_SourceShortcutIntent intent) =>
      ref.read(overlayPriorityProvider) == OverlayPriority.none;

  @override
  Object? invoke(_SourceShortcutIntent intent) {
    onShortcut(intent.shortcut);
    return null;
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
            L.of(context).sources_title,
            style: TextStyle(
              fontSize: rs.isSmall ? 22 : 28,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 4,
            ),
          ),
          SizedBox(height: rs.spacing.xs),
          Text(
            // Was an English literal with a hardcoded [Y] in it. The key name
            // is the HUD's job — it draws from the configured controller
            // layout, which this line could not.
            count == 0
                ? L.of(context).sources_noSourcesConfigured
                : L.of(context).sources_countLabel(count),
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
              L.of(context).sources_noSourcesYet,
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
                L.of(context).sources_noSourcesDescription,
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
                  children: [
                    const Icon(Icons.add, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      L.of(context).sources_addSource,
                      style: const TextStyle(
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

class _SourceList extends ConsumerWidget {
  const _SourceList({
    required this.sources,
    required this.focusForId,
    required this.onTap,
    required this.onToggleActive,
    required this.onToggleShown,
    required this.scrollController,
    required this.rs,
  });

  final List<Source> sources;
  final FocusNode Function(String sourceId) focusForId;
  final void Function(Source source) onTap;
  final void Function(Source source) onToggleActive;
  final void Function(Source source) onToggleShown;
  final ScrollController scrollController;
  final Responsive rs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Tally per-source manual mapping counts so the card can show
    // "N mappings" for SMB/FTP/Web (where knownPlatforms is always 0).
    final cfg = ref.watch(bootstrappedConfigProvider).valueOrNull;
    final mappingCounts = <String, int>{};
    if (cfg != null) {
      for (final s in cfg.systems) {
        for (final m in s.manualMappings) {
          mappingCounts[m.sourceId] = (mappingCounts[m.sourceId] ?? 0) + 1;
        }
      }
    }
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
                mappingCount: mappingCounts[source.id] ?? 0,
                isActive: ref.watch(sourcesProvider).primarySourceId == source.id,
                onToggleActive: () => onToggleActive(source),
                // The eye is the on/off switch. It was briefly a second,
                // separate "show on home" flag — but that is what turning a
                // source off already did, so there is one switch again.
                isShown: source.enabled,
                onToggleShown: () => onToggleShown(source),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SourceCard extends ConsumerWidget {
  const _SourceCard({
    super.key,
    required this.source,
    required this.focusNode,
    required this.autofocus,
    required this.onTap,
    required this.rs,
    this.mappingCount = 0,
    this.isActive = false,
    this.onToggleActive,
    this.isShown = false,
    this.onToggleShown,
  });

  final Source source;
  final FocusNode focusNode;
  final bool autofocus;
  final VoidCallback onTap;
  final Responsive rs;
  final int mappingCount;

  /// True when this is the source in use — what syncs, and what the home
  /// screen opens on. Marked with a tick.
  final bool isActive;

  /// Designates this source as the one in use, from the tick on the row.
  final VoidCallback? onToggleActive;

  /// True when this source is switched on: its library is on the home screen
  /// and it takes part in syncs.
  final bool isShown;

  /// Switches this source on or off, from the eye on the row.
  final VoidCallback? onToggleShown;

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

  String? _expiryLabel(BuildContext context) {
    final exp = source.tokenExpiresAt;
    if (exp == null) return null;
    final delta = exp.difference(DateTime.now());
    if (delta.isNegative) return L.of(context).sources_expired;
    if (delta.inDays >= 2) return 'Expires in ${delta.inDays}d';
    if (delta.inHours >= 2) return 'Expires in ${delta.inHours}h';
    return 'Expires in ${delta.inMinutes}m';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // RomM auto-discovers platforms; everything else lives off manual
    // mappings, so the same "N entries" badge means different things
    // depending on the source type.
    final isAutoMapped = source.autoMap;
    final entryCount =
        isAutoMapped ? source.knownPlatforms.length : mappingCount;
    final entryNoun = isAutoMapped ? 'platform' : 'mapping';
    final expiry = _expiryLabel(context);
    final expiryUrgent = expiry != null &&
        source.tokenExpiresAt != null &&
        source.tokenExpiresAt!.difference(DateTime.now()).inDays < 7;

    // Token health from proactive background check.
    final healthState = ref.watch(sourceHealthProvider);
    final health = healthState.statusFor(source.id);
    final healthError = healthState.errorFor(source.id);

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
            color: Colors.white24,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            // Two separate decisions, two separate marks. Both are one tap on
            // the row, with no menu to open first — they are what this screen
            // is for, so they do not belong three presses deep.
            //
            // The eye is on/off: switched on, the library is on the home
            // screen. The tick is single and names the one the app works
            // against. Same shape for both would put the user back where the
            // one conflated setting had them.
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onToggleShown,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(
                  isShown ? Icons.visibility : Icons.visibility_outlined,
                  size: 21,
                  color: isShown
                      ? const Color(0xFF7BC67B)
                      : Colors.white24,
                ),
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onToggleActive,
              child: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Icon(
                  isActive
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  size: 21,
                  color: isActive
                      ? const Color(0xFF7BC67B)
                      : Colors.white24,
                ),
              ),
            ),
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
                      // Which source the library is actually showing is
                      // otherwise invisible, and with two sources configured
                      // that is the first thing you need to know.
                      if (isActive) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7BC67B)
                                .withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: const Color(0xFF7BC67B)
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                          child: Text(
                            L.of(context).sources_activeSource,
                            style: const TextStyle(
                              color: Color(0xFF7BC67B),
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                      if (source.fallbackSourceIds.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '備援 · ${source.fallbackSourceIds.length}組',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
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
                          child: Text(
                            L.of(context).sources_borrowed,
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
                          child: Text(
                            L.of(context).sources_off,
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
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.games,
                          size: 11, color: Colors.white70),
                      const SizedBox(width: 3),
                      Text(
                        entryCount == 0
                            ? (isAutoMapped
                                ? L.of(context).sources_noPlatforms
                                : 'No mappings — [A] to add')
                            : '$entryCount '
                                '${entryCount == 1 ? entryNoun : "${entryNoun}s"}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                      if (health == SourceHealth.invalid) ...[
                        const SizedBox(width: 10),
                        const Icon(Icons.error_outline,
                            size: 11, color: Colors.redAccent),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            healthError ?? 'Token invalid — re-pair',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ] else if (health == SourceHealth.checking) ...[
                        const SizedBox(width: 10),
                        const SizedBox(
                          width: 10,
                          height: 10,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: Colors.white38,
                          ),
                        ),
                      ] else if (expiry != null) ...[
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
    required this.onEditFallback,
    required this.onToggleActive,
    required this.isActive,
    required this.hasOtherSources,
  });

  final Source source;
  final VoidCallback onClose;
  final VoidCallback onToggleEnabled;
  final VoidCallback onRemove;
  final VoidCallback onRepair;
  final VoidCallback onEditMappings;
  final VoidCallback onEditFallback;
  final VoidCallback onToggleActive;
  final bool isActive;
  final bool hasOtherSources;

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
  List<_OverlayAction> _actions(BuildContext context) {
    final src = widget.source;
    final l = L.of(context);
    return [
      if (src.type == SourceType.romm)
        _OverlayAction(
          icon: Icons.qr_code_2,
          label: l.sources_rePair,
          onActivate: widget.onRepair,
        ),
      if (src.type != SourceType.romm)
        _OverlayAction(
          icon: Icons.tune,
          label: l.sources_editMappings,
          onActivate: widget.onEditMappings,
        ),
      _OverlayAction(
        icon: Icons.alt_route,
        label: '備援設定',
        onActivate: widget.onEditFallback,
      ),
      _OverlayAction(
        icon: src.enabled ? Icons.toggle_off : Icons.toggle_on,
        label: src.enabled ? l.sources_disable : l.sources_enable,
        onActivate: widget.onToggleEnabled,
      ),
      _OverlayAction(
        icon: Icons.delete_outline,
        label: l.common_remove,
        destructive: true,
        onActivate: widget.onRemove,
      ),
      _OverlayAction(
        icon: Icons.close,
        label: l.common_cancel,
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

    final count = _actions(context).length;
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
    // The gamepad half of the eye in the header. Without it that toggle would
    // be reachable by finger only.
    if (key == LogicalKeyboardKey.gameButtonX) {
      ref.read(feedbackServiceProvider).confirm();
      widget.onToggleActive();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _activate() {
    final action = _actions(context)[_selectedIndex];
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
    final l = L.of(context);
    final actions = _actions(context);
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
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  // Scrollable so the menu can outgrow a 3.92" screen without
                  // painting Flutter's yellow overflow stripe, which looks
                  // like a feature nobody can explain. It already overflowed
                  // by 39px once the routes and backup entries were added.
                  child: SingleChildScrollView(
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
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              src.hostLabel,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                          // Second entry for "show this source": the row eye
                          // is touch-only, this one answers [X] as well. A
                          // corner icon rather than another row — the menu
                          // already outgrew a 3.92" screen once.
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: widget.onToggleActive,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 8),
                              // Icon only. A bare "X" beside it read as a
                              // close button, and spelling out a button name
                              // here would go stale against the user's
                              // controller layout anyway — the footer hint
                              // is where the key belongs.
                              //
                              // A tick, not an eye: this marks the source in
                              // use. The eye means what is on screen, and the
                              // two must not wear the same icon.
                              child: Icon(
                                widget.isActive
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                size: 18,
                                color: widget.isActive
                                    ? const Color(0xFF7BC67B)
                                    : Colors.white38,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      for (int i = 0; i < actions.length; i++) ...[
                        if (i > 0) const SizedBox(height: 8),
                        _OverlayButton(
                          icon: actions[i].icon,
                          label: actions[i].label,
                          selected: _selectedIndex == i,
                          destructive: actions[i].destructive,
                          subdued: actions[i].cancelStyle,
                          // Tapping runs the action outright rather than just
                          // moving the cursor to it — a second tap to confirm
                          // what you already touched is pure friction.
                          onTap: () {
                            setState(() => _selectedIndex = i);
                            _activate();
                          },
                        ),
                      ],
                      const SizedBox(height: 12),
                      // Real buttons, not a typed-out line. The old one was a
                      // hardcoded Chinese string that named [A]/[X]/[B] — wrong
                      // on two of the three controller layouts, untranslated in
                      // the other six languages, and dead under a finger.
                      ConsoleHud(
                        embedded: true,
                        dpad: (label: '↑↓', action: l.common_navigate),
                        a: HudAction(l.common_select, onTap: _activate),
                        b: HudAction(l.common_back, onTap: widget.onClose),
                        x: HudAction(
                          widget.isActive
                              ? l.sources_stopUsingShort
                              : l.sources_useThisShort,
                          onTap: widget.onToggleActive,
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
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;

  /// The overlay is driven by the gamepad, but the device has a touchscreen
  /// and the cards behind it are tappable — so an overlay that only answers to
  /// buttons reads as frozen.
  final VoidCallback? onTap;
  final bool destructive;
  final bool subdued;

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? Colors.redAccent
        : subdued
            ? Colors.white70
            : AppTheme.primaryColor;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
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
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
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
  final void Function(_TypeOption option) onPick;

  @override
  ConsumerState<_SourceTypePickerOverlay> createState() =>
      _SourceTypePickerOverlayState();
}

class _SourceTypePickerOverlayState
    extends ConsumerState<_SourceTypePickerOverlay> {
  final FocusNode _scopeFocus =
      FocusNode(debugLabel: 'source_type_picker');
  int _selectedIndex = 0;
  List<_TypeOption> _options = const [];

  static List<_TypeOption> _buildOptions(L l) => [
    _TypeOption(
      type: SourceType.romm,
      icon: Icons.qr_code_2,
      label: l.sources_sourceTypeRomm,
      hint: l.sources_sourceTypeRommHint,
    ),
    _TypeOption(
      type: SourceType.romm,
      icon: Icons.password,
      label: l.sources_sourceTypeRommLegacy,
      hint: l.onboarding_legacyLoginSubtitle,
      isLegacy: true,
    ),
    _TypeOption(
      type: SourceType.smb,
      icon: Icons.folder_shared,
      label: l.sources_sourceTypeSmb,
      hint: 'Windows / NAS network share',
    ),
    _TypeOption(
      type: SourceType.ftp,
      icon: Icons.cloud_queue,
      label: l.sources_sourceTypeFtp,
      hint: 'Classic FTP/FTPS host',
    ),
    _TypeOption(
      type: SourceType.web,
      icon: Icons.public,
      label: l.sources_sourceTypeWeb,
      hint: l.sources_sourceTypeWebHint,
    ),
  ];

  @override
  void dispose() {
    _scopeFocus.dispose();
    super.dispose();
  }

  /// Single path for choosing an option, so [A] and a tap cannot drift apart
  /// as one of them later gains a step the other does not.
  void _pickSelected() {
    ref.read(feedbackServiceProvider).confirm();
    widget.onPick(_options[_selectedIndex]);
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
      _pickSelected();
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
    final l = L.of(context);
    _options = _buildOptions(l);
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
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.sources_addSource,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l.sources_whereDoGamesComeFrom,
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
                          onTap: () {
                            setState(() => _selectedIndex = i);
                            _pickSelected();
                          },
                        ),
                      ],
                      const SizedBox(height: 14),
                      // Same line was pasted here, and here it also promised
                      // an [X] this overlay does not answer.
                      ConsoleHud(
                        embedded: true,
                        dpad: (label: '↑↓', action: l.common_navigate),
                        a: HudAction(l.common_select, onTap: _pickSelected),
                        b: HudAction(l.common_back, onTap: widget.onClose),
                      ),
                    ],
                  ),
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
    this.isLegacy = false,
  });
  final SourceType type;
  final IconData icon;
  final String label;
  final String hint;
  final bool isLegacy;
}

class _TypeOptionTile extends StatelessWidget {
  const _TypeOptionTile({
    required this.option,
    required this.selected,
    this.onTap,
  });
  final _TypeOption option;
  final bool selected;

  /// This overlay is reached with [Y] and driven by the gamepad, but the
  /// device has a touchscreen and the list behind it answers to taps — a row
  /// that ignores a finger reads as frozen.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.primaryColor;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    option.hint,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
