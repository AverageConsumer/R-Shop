import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/input/input.dart';
import '../../core/responsive/responsive.dart';
import '../../models/game_item.dart';
import '../../models/game_metadata_info.dart';
import '../../models/system_model.dart';
import '../../models/ra_models.dart';
import '../../providers/app_providers.dart';
import '../../providers/download_providers.dart';
import '../../providers/ra_providers.dart';
import '../../providers/rom_status_providers.dart';
import '../../providers/game_providers.dart';
import '../../providers/shelf_providers.dart';
import '../../services/download_queue_manager.dart';
import '../../services/input_debouncer.dart';
import '../../utils/game_metadata.dart';
import '../../utils/image_helper.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/console_notification.dart';
import '../../widgets/console_hud.dart';
import '../../widgets/download_overlay.dart';
import '../../widgets/quick_menu.dart';
import '../library/widgets/shelf_picker_dialog.dart';
import 'achievements_screen.dart';
import 'game_detail_controller.dart';
import 'game_detail_state.dart';
import 'widgets/cover_section.dart';
import 'widgets/ra_info_section.dart';
import 'widgets/action_buttons_row.dart';
import 'widgets/badges_row.dart';
import 'widgets/details_section.dart';
import 'widgets/download_action_button.dart';
import 'widgets/file_details_row.dart';
import 'widgets/game_detail_overlay.dart';
import 'widgets/other_versions_section.dart';
import 'widgets/screenshot_fullscreen.dart';
import 'widgets/screenshots_carousel.dart';
import 'widgets/section_header.dart';
import 'widgets/summary_section.dart';
import 'widgets/variant_picker_overlay.dart';

class GameDetailScreen extends ConsumerStatefulWidget {
  final GameItem game;
  final List<GameItem> variants;
  final SystemModel system;
  final String targetFolder;
  final bool isLocalOnly;
  final bool autoExtract;

  const GameDetailScreen({
    super.key,
    required this.game,
    required this.variants,
    required this.system,
    required this.targetFolder,
    this.isLocalOnly = false,
    this.autoExtract = false,
  });

  @override
  ConsumerState<GameDetailScreen> createState() => _GameDetailScreenState();
}

class _GameDetailScreenState extends ConsumerState<GameDetailScreen>
    with ConsoleScreenMixin {
  GameDetailController? _controller;
  late InputDebouncer _debouncer;
  ProviderSubscription? _romChangeSubscription;

  // Section scroll keys for auto-scroll on D-pad navigation
  final Map<DetailSection, GlobalKey> _sectionKeys = {};

  @override
  String get routeId => 'game_detail_${widget.game.filename}';

  bool _dialogOrNoOverlay(dynamic _) {
    final priority = ref.read(overlayPriorityProvider);
    if (priority == OverlayPriority.none) return true;
    final state = _controller?.state;
    return state?.isDialogOpen == true || state?.showVariantPicker == true;
  }

  @override
  Map<Type, Action<Intent>> get screenActions => {
        BackIntent: CallbackAction<BackIntent>(
          onInvoke: (_) { _handleBack(); return null; },
        ),
        ConfirmIntent: OverlayGuardedAction<ConfirmIntent>(ref,
          onInvoke: (_) { _handleConfirm(); return null; },
          isEnabledOverride: _dialogOrNoOverlay,
        ),
        NavigateIntent: OverlayGuardedAction<NavigateIntent>(ref,
          onInvoke: (intent) { _handleNavigate(intent.direction); return null; },
          isEnabledOverride: _dialogOrNoOverlay,
        ),
        FavoriteIntent: OverlayGuardedAction<FavoriteIntent>(ref,
          onInvoke: (_) { _handleFavorite(); return null; },
        ),
        ToggleOverlayIntent: ToggleOverlayAction(ref, onToggle: toggleQuickMenu),
      };

  @override
  void initState() {
    super.initState();
    _debouncer = ref.read(inputDebouncerProvider);
    final queueManager = ref.read(downloadQueueManagerProvider);
    _initController(queueManager);
  }

  void _initController(DownloadQueueManager queueManager) {
    final storage = ref.read(storageServiceProvider);
    _controller = GameDetailController(
      game: widget.game,
      variants: widget.variants,
      system: widget.system,
      targetFolder: widget.targetFolder,
      isLocalOnly: widget.isLocalOnly,
      autoExtract: widget.autoExtract,
      showFullFilename: storage.getShowFullFilename(),
      queueManager: queueManager,
      onAddedToQueue: _fireAddToQueueAnimation,
    );
    _controller!.addListener(_onControllerChanged);

    _romChangeSubscription = ref.listenManual(romChangeSignalProvider, (prev, next) {
      if (!mounted) return;
      if (prev != null && prev != next) {
        _controller?.checkInstallationStatus();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      requestScreenFocus();
    });
  }

  void _onControllerChanged() {
    if (!mounted) return;

    setState(() {});

    final error = _controller?.state.error;
    if (error != null) {
      showErrorNotification(context, ref, message: 'Error: $error');
    }
  }

  @override
  void dispose() {
    _romChangeSubscription?.close();
    _debouncer.stopHold();
    _controller?.removeListener(_onControllerChanged);
    _controller?.dispose();
    super.dispose();
  }

  GlobalKey _keyForSection(DetailSection section) {
    return _sectionKeys.putIfAbsent(section, () => GlobalKey());
  }

  void _scrollToFocusedSection({bool scrollingUp = false}) {
    final controller = _controller;
    if (controller == null) return;
    final section = controller.focusedSection;
    final key = _sectionKeys[section];
    if (key == null) return;
    final ctx = key.currentContext;
    if (ctx == null) return;
    // Use alignment to position the section with breathing room above the HUD.
    // 0.0 = top of viewport, 1.0 = bottom. 0.7 keeps it comfortably visible.
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      alignment: scrollingUp ? 0.2 : 0.7,
    );
  }

  // ---------------------------------------------------------------------------
  // Input handling
  // ---------------------------------------------------------------------------

  void _handleBack() {
    final controller = _controller;
    if (controller == null) return;

    ref.read(feedbackServiceProvider).cancel();

    if (controller.state.isOverlayOpen) {
      controller.closeOverlay();
      return;
    }

    Navigator.pop(context);
  }

  void _handleConfirm() {
    final controller = _controller;
    if (controller == null) return;

    // Variant picker handles its own A-button input
    if (controller.state.showVariantPicker) return;

    if (controller.state.isDialogOpen) {
      final selection = controller.state.dialogSelection;
      if (selection == 0) {
        ref.read(feedbackServiceProvider).warning();
      } else {
        ref.read(feedbackServiceProvider).cancel();
      }
      _executeDialogAction(controller).then((_) {
        if (mounted) requestScreenFocus();
      });
      return;
    }

    if (controller.state.showGameInfo) {
      return;
    }

    // Context-sensitive A-button per focused section
    ref.read(feedbackServiceProvider).confirm();
    final section = controller.focusedSection;
    switch (section) {
      case DetailSection.summary:
        controller.toggleSummaryExpanded();
      case DetailSection.screenshots:
        controller.openScreenshotViewer();
      case DetailSection.otherVersions:
        // Only select if index points to a real variant (not an unmatched sibling)
        final idx = controller.state.siblingIndex;
        if (idx < controller.variants.length) {
          controller.selectVariant(idx);
        }
      case DetailSection.primaryAction:
        controller.performAction();
      case DetailSection.actions:
        _handleActionButtonConfirm(controller);
      case DetailSection.achievements:
        _tryNavigateToAchievements();
      case DetailSection.title:
      case DetailSection.badges:
      case DetailSection.fileDetails:
      case DetailSection.details:
        break; // Non-actionable sections
    }
  }

  void _handleNavigate(GridDirection direction) {
    final controller = _controller;
    if (controller == null) return;

    if (controller.state.isDialogOpen) {
      if (direction == GridDirection.left) {
        ref.read(feedbackServiceProvider).tick();
        controller.selectDialogOption(1);
      } else if (direction == GridDirection.right) {
        ref.read(feedbackServiceProvider).tick();
        controller.selectDialogOption(0);
      }
      return;
    }

    final rs = context.rs;
    final isLandscape = !rs.isPortrait;

    // Up/down within left column (primaryAction ↔ actions)
    if (isLandscape &&
        (direction == GridDirection.up || direction == GridDirection.down) &&
        controller.navigateLeftColumn(direction)) {
      ref.read(feedbackServiceProvider).tick();
      return;
    }

    // Up/down: navigate between sections (skips left-column in landscape)
    if (direction == GridDirection.up) {
      ref.read(feedbackServiceProvider).tick();
      controller.focusPreviousSection();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToFocusedSection(scrollingUp: true);
      });
      return;
    }
    if (direction == GridDirection.down) {
      ref.read(feedbackServiceProvider).tick();
      controller.focusNextSection();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToFocusedSection();
      });
      return;
    }

    // Left/right: navigate within horizontal sections first
    if (controller.navigateInSection(direction)) {
      ref.read(feedbackServiceProvider).tick();
      return;
    }

    // Cross-column navigation (landscape only): LEFT → left column, RIGHT → back
    if (isLandscape && controller.navigateCrossColumn(direction)) {
      ref.read(feedbackServiceProvider).tick();
    }
  }

  /// Dispatches A-button press per focused icon button index.
  /// 0 = favorite, 1 = share, 2 = collection
  void _handleActionButtonConfirm(GameDetailController controller) {
    switch (controller.state.actionButtonIndex) {
      case 0:
        _handleFavorite();
      case 1:
        _handleShare();
      case 2:
        _handleCollection(controller);
    }
  }

  void _handleShare() {
    final controller = _controller;
    if (controller == null) return;
    final title = controller.cleanTitle;
    final system = widget.system.name;
    Share.share('$title ($system)', subject: title);
  }

  void _handleCollection(GameDetailController controller) {
    final variant = controller.selectedVariant;
    final shelves = ref.read(customShelvesProvider)
        .where((s) => !s.containsGame(
            variant.filename, variant.displayName, widget.system.id))
        .toList();
    if (shelves.isEmpty) return;
    showShelfPickerDialog(
      context: context,
      ref: ref,
      shelves: shelves,
      onSelect: (shelfId) {
        ref.read(customShelvesProvider.notifier)
            .addGameToShelf(shelfId, variant.filename);
      },
    );
  }

  void _handleFilenameToggle() {
    final controller = _controller;
    if (controller == null) return;
    if (controller.state.isOverlayOpen) return;

    ref.read(feedbackServiceProvider).tick();
    controller.toggleFullFilename();
    ref.read(storageServiceProvider).setShowFullFilename(
      controller.state.showFullFilename,
    );
  }

  void _handleFavorite() {
    final controller = _controller;
    if (controller == null) return;
    if (controller.state.isOverlayOpen) return;

    ref.read(feedbackServiceProvider).tick();
    ref.read(favoriteGamesProvider.notifier).toggleFavorite(controller.selectedVariant.filename);
  }

  void _tryNavigateToAchievements() {
    final raMatches =
        ref.read(raMatchesForSystemProvider(widget.system.id)).value ?? {};
    final raMatch = raMatches[_controller?.selectedVariant.filename];
    if (raMatch != null && raMatch.raGameId != null) {
      _navigateToAchievements(raMatch);
    }
  }

  void _navigateToAchievements(RaMatchResult match) {
    if (match.raGameId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AchievementsScreen(
          raGameId: match.raGameId!,
          raTitle: match.raTitle,
          imageIcon: match.imageIcon,
          accentColor: widget.system.accentColor,
        ),
      ),
    );
  }

  void _fireAddToQueueAnimation() {
    final controller = _controller;
    if (controller == null) return;
    ref.read(addToQueueEventProvider.notifier).state = AddToQueueEvent(
      gameTitle: controller.cleanTitle,
      accentColor: widget.system.accentColor,
      timestamp: DateTime.now(),
    );
  }

  void _downloadFromSource(AlternativeSource source) {
    final controller = _controller;
    if (controller == null) return;

    final variant = controller.selectedVariant;
    final modifiedGame = variant.copyWith(
      url: source.url,
      providerConfig: source.providerConfig,
    );

    final queueManager = ref.read(downloadQueueManagerProvider);
    final sizeBefore = queueManager.state.queue.length;
    queueManager.addToQueue(modifiedGame, widget.system, widget.targetFolder, autoExtract: widget.autoExtract);
    if (queueManager.state.queue.length > sizeBefore) {
      _fireAddToQueueAnimation();
    }
  }

  List<QuickMenuItem?> _buildQuickMenuItems() {
    final controller = _controller;
    if (controller == null) return [];
    final variant = controller.selectedVariant;
    final metadata = GameMetadata.parse(variant.filename);
    final isFavorite = ref.read(favoriteGamesProvider).contains(variant.filename);
    final hasDownloads = ref.read(hasQueueItemsProvider);
    final hasAlternatives = variant.alternativeSources.isNotEmpty;
    final variantFilenames = widget.variants.map((v) => v.filename).join('\n');
    final richMetadata = ref.read(groupMetadataProvider(
      (filenames: variantFilenames, systemSlug: widget.system.id),
    )).valueOrNull;
    final hasDetails = richMetadata?.hasContent ?? false;
    final raMatches =
        ref.read(raMatchesForSystemProvider(widget.system.id)).value ?? {};
    final raMatch = raMatches[variant.filename];
    return [
      QuickMenuItem(
        label: isFavorite ? 'Unfavorite' : 'Favorite',
        icon: isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        shortcutHint: '−',
        onSelect: _handleFavorite,
        highlight: isFavorite,
      ),
      if (metadata.allTags.isNotEmpty || hasDetails)
        QuickMenuItem(
          label: 'Game Info',
          icon: Icons.info_outline_rounded,
          onSelect: () => controller.openGameInfo(),
        ),
      if (raMatch != null && raMatch.hasMatch && raMatch.raGameId != null)
        QuickMenuItem(
          label: 'Achievements',
          icon: Icons.emoji_events_rounded,
          onSelect: () => _navigateToAchievements(raMatch),
        ),
      QuickMenuItem(
        label: controller.state.showFullFilename ? 'Show Title' : 'Show Filename',
        icon: Icons.text_fields_rounded,
        onSelect: _handleFilenameToggle,
      ),
      if (hasAlternatives && !controller.state.isVariantInstalled) ...[
        null,
        QuickMenuItem(
          label: 'from ${variant.providerConfig?.detailLabel ?? "Primary"}',
          icon: Icons.cloud_download_outlined,
          onSelect: () => controller.performAction(),
        ),
        for (final alt in variant.alternativeSources)
          QuickMenuItem(
            label: 'from ${alt.providerConfig.detailLabel}',
            icon: Icons.cloud_download_outlined,
            onSelect: () => _downloadFromSource(alt),
          ),
      ],
      if (ref.read(customShelvesProvider)
          .any((s) => !s.containsGame(
              variant.filename, variant.displayName, widget.system.id))) ...[
        null,
        QuickMenuItem(
          label: 'Add to Shelf',
          icon: Icons.shelves,
          onSelect: () {
            final shelves = ref.read(customShelvesProvider)
                .where((s) => !s.containsGame(
                    variant.filename, variant.displayName, widget.system.id))
                .toList();
            showShelfPickerDialog(
              context: context,
              ref: ref,
              shelves: shelves,
              onSelect: (shelfId) {
                ref.read(customShelvesProvider.notifier)
                    .addGameToShelf(shelfId, variant.filename);
              },
            );
          },
        ),
      ],
      if (hasDownloads) ...[
        null,
        QuickMenuItem(
          label: 'Downloads',
          icon: Icons.download_rounded,
          onSelect: () => toggleDownloadOverlay(ref),
          highlight: true,
        ),
      ],
    ];
  }

  Future<void> _executeDialogAction(GameDetailController controller) async {
    final selection = controller.state.dialogSelection;

    if (selection == 0) {
      await controller.deleteRom();
      ref.read(romChangeSignalProvider.notifier).state++;
      ref.invalidate(visibleSystemsProvider);
      controller.cancelDialog();
    } else {
      controller.cancelDialog();
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) {
      _debouncer.stopHold();
      return KeyEventResult.ignored;
    }

    return KeyEventResult.ignored;
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF121212),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: widget.system.accentColor),
              const SizedBox(height: 16),
              Text(
                widget.game.displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.system.name,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final rs = context.rs;
    final state = controller.state;
    final selectedVariant = controller.selectedVariant;
    final coverUrls = ImageHelper.getCoverUrlsForSingle(
        widget.system, selectedVariant.filename);
    final GameMetadataFull fileMetadata =
        GameMetadata.parse(selectedVariant.filename);
    final isMultiRom = widget.variants.length > 1;
    final isFavorite = ref.watch(favoriteGamesProvider).contains(controller.selectedVariant.filename);
    final raMatches =
        ref.watch(raMatchesForSystemProvider(widget.system.id)).value ?? {};
    final raMatch = raMatches[selectedVariant.filename];

    // Fetch rich metadata
    final variantFilenames = widget.variants.map((v) => v.filename).join('\n');
    final gameMetadata = ref.watch(groupMetadataProvider(
      (filenames: variantFilenames, systemSlug: widget.system.id),
    ));
    final richMetadata = gameMetadata.valueOrNull;

    // Update available sections based on current data
    controller.updateAvailableSections(
      metadata: richMetadata,
      fileMetadata: fileMetadata,
      raMatch: raMatch,
    );

    // In landscape, actions are in a separate left column — skip in up/down nav
    controller.skipActionsInVerticalNav = !rs.isPortrait;

    // Clamp horizontal indices
    controller.clampHorizontalIndices(
      screenshotCount: richMetadata?.screenshotUrlList.length ?? 0,
      siblingCount: _getSiblingOrVariantCount(richMetadata, isMultiRom),
      actionButtonCount: ActionButtonsRow.itemCount,
    );

    return buildWithActions(
      PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            _handleBack();
          }
        },
        child: Scaffold(
          backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned.fill(
              child: _CoverBackground(
                coverUrl: selectedVariant.cachedCoverUrl ?? coverUrls.firstOrNull,
                accentColor: widget.system.accentColor,
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                // Reserve space at the bottom so content never sits behind the HUD
                padding: const EdgeInsets.only(bottom: 56),
                child: rs.isPortrait
                    ? _buildPortraitLayout(rs, state, controller, fileMetadata,
                        richMetadata, isMultiRom, coverUrls, selectedVariant,
                        isFavorite, raMatch)
                    : _buildLandscapeLayout(rs, state, controller, fileMetadata,
                        richMetadata, isMultiRom, coverUrls, selectedVariant,
                        isFavorite, raMatch),
              ),
            ),
            _buildControls(state, controller),
            if (showQuickMenu)
              QuickMenuOverlay(
                items: _buildQuickMenuItems(),
                onClose: closeQuickMenu,
              ),
            DialogFocusScope(
              isVisible: state.isDialogOpen,
              onClose: controller.cancelDialog,
              child: ConfirmDialog(
                type: ConfirmDialogType.delete,
                selection: state.dialogSelection,
                gameTitle: controller.cleanTitle,
                onPrimary: () async {
                  await controller.deleteRom();
                  ref.read(romChangeSignalProvider.notifier).state++;
                  ref.invalidate(visibleSystemsProvider);
                  controller.cancelDialog();
                  requestScreenFocus();
                },
                onSecondary: controller.cancelDialog,
              ),
            ),
            if (state.showGameInfo)
              OverlayFocusScope(
                priority: OverlayPriority.dialog,
                isVisible: state.showGameInfo,
                onClose: controller.closeGameInfo,
                child: Builder(
                  builder: (context) {
                    return GameDetailOverlay(
                      richMetadata: richMetadata,
                      fileMetadata: fileMetadata,
                      gameTitle: controller.cleanTitle,
                      accentColor: widget.system.accentColor,
                      onClose: controller.closeGameInfo,
                    );
                  },
                ),
              ),
            if (state.showVariantPicker && isMultiRom)
              VariantPickerOverlay(
                variants: widget.variants,
                system: widget.system,
                installedStatus: state.installedStatus,
                onDownload: (index) async {
                  final success = await controller.addVariantToQueue(index);
                  if (success) _fireAddToQueueAnimation();
                  return success;
                },
                onDelete: (index) {
                  controller.selectVariant(index);
                  controller.closeVariantPicker();
                  controller.showDeleteDialog();
                },
                onClose: () {
                  controller.closeVariantPicker();
                  requestScreenFocus();
                },
              ),
            if (state.showScreenshotViewer &&
                (richMetadata?.screenshotUrlList.isNotEmpty ?? false))
              ScreenshotFullscreen(
                screenshots: richMetadata!.screenshotUrlList,
                initialIndex: state.screenshotIndex,
                accentColor: widget.system.accentColor,
                onClose: () {
                  controller.closeScreenshotViewer();
                  requestScreenFocus();
                },
              ),
          ],
        ),
      ),
      ),
      onKeyEvent: _handleKeyEvent,
    );
  }

  int _getSiblingOrVariantCount(GameMetadataInfo? richMetadata, bool isMultiRom) {
    return OtherVersionsSection.entryCount(
      variants: widget.variants,
      siblings: richMetadata?.siblingList ?? const [],
    );
  }

  // ---------------------------------------------------------------------------
  // Landscape layout: Cover + actions left (~30%), sections right (~70%)
  // ---------------------------------------------------------------------------

  Widget _buildLandscapeLayout(
    Responsive rs,
    GameDetailState state,
    GameDetailController controller,
    GameMetadataFull fileMetadata,
    GameMetadataInfo? richMetadata,
    bool isMultiRom,
    List<String> coverUrls,
    GameItem selectedVariant,
    bool isFavorite,
    RaMatchResult? raMatch,
  ) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        rs.spacing.lg,
        rs.spacing.md,
        rs.spacing.lg,
        0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left column: Cover + action buttons (fixed)
          SizedBox(
            width: rs.isSmall ? 180 : (rs.isMedium ? 220 : 260),
            child: Column(
              children: [
                AspectRatio(
                  aspectRatio: 0.75,
                  child: CoverSection(
                    game: widget.game,
                    system: widget.system,
                    coverUrls: coverUrls,
                    cachedUrl: selectedVariant.cachedCoverUrl,
                    metadata: fileMetadata,
                    isFavorite: isFavorite,
                    isInstalled: state.isVariantInstalled,
                    hasThumbnail: selectedVariant.hasThumbnail,
                  ),
                ),
                SizedBox(height: rs.spacing.md),
                // Primary action button (Download/Delete/Manage)
                _buildSection(
                  rs, state, controller, DetailSection.primaryAction,
                  fileMetadata: fileMetadata,
                  richMetadata: richMetadata,
                  isMultiRom: isMultiRom,
                  raMatch: raMatch,
                  isFocused: controller.focusedSection == DetailSection.primaryAction,
                ),
                // Icon action buttons (Favorite/Share/Shelf)
                _buildSection(
                  rs, state, controller, DetailSection.actions,
                  fileMetadata: fileMetadata,
                  richMetadata: richMetadata,
                  isMultiRom: isMultiRom,
                  raMatch: raMatch,
                  isFocused: controller.focusedSection == DetailSection.actions,
                ),
              ],
            ),
          ),
          SizedBox(width: rs.spacing.lg),
          // Right column: all other sections (scrollable)
          Expanded(
            child: SingleChildScrollView(
              child: _buildSections(rs, state, controller, fileMetadata,
                  richMetadata, isMultiRom, raMatch,
                  excludeActions: true),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Portrait layout: Cover header + scrollable sections
  // ---------------------------------------------------------------------------

  Widget _buildPortraitLayout(
    Responsive rs,
    GameDetailState state,
    GameDetailController controller,
    GameMetadataFull fileMetadata,
    GameMetadataInfo? richMetadata,
    bool isMultiRom,
    List<String> coverUrls,
    GameItem selectedVariant,
    bool isFavorite,
    RaMatchResult? raMatch,
  ) {
    final hasCardContent = richMetadata?.hasCardContent ?? false;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: rs.spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: rs.spacing.md),
          AspectRatio(
            aspectRatio: hasCardContent ? 0.85 : 0.75,
            child: CoverSection(
              game: widget.game,
              system: widget.system,
              coverUrls: coverUrls,
              cachedUrl: selectedVariant.cachedCoverUrl,
              metadata: fileMetadata,
              isFavorite: isFavorite,
              isInstalled: state.isVariantInstalled,
              hasThumbnail: selectedVariant.hasThumbnail,
            ),
          ),
          SizedBox(height: rs.spacing.md),
          _buildSections(rs, state, controller, fileMetadata, richMetadata,
              isMultiRom, raMatch),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Shared section builder — renders all visible sections in order
  // ---------------------------------------------------------------------------

  Widget _buildSections(
    Responsive rs,
    GameDetailState state,
    GameDetailController controller,
    GameMetadataFull fileMetadata,
    GameMetadataInfo? richMetadata,
    bool isMultiRom,
    RaMatchResult? raMatch, {
    bool excludeActions = false,
  }) {
    const leftColumnSections = {
      DetailSection.primaryAction,
      DetailSection.actions,
    };
    final sections = controller.availableSections;
    final focused = controller.focusedSection;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final section in sections)
          if (!(excludeActions && leftColumnSections.contains(section)))
            _buildSection(
              rs, state, controller, section,
              fileMetadata: fileMetadata,
              richMetadata: richMetadata,
              isMultiRom: isMultiRom,
              raMatch: raMatch,
              isFocused: section == focused,
            ),
      ],
    );
  }

  Widget _buildSection(
    Responsive rs,
    GameDetailState state,
    GameDetailController controller,
    DetailSection section, {
    required GameMetadataFull fileMetadata,
    GameMetadataInfo? richMetadata,
    required bool isMultiRom,
    RaMatchResult? raMatch,
    required bool isFocused,
  }) {
    final Widget content;

    switch (section) {
      case DetailSection.title:
        content = _buildTitleSection(rs, controller);

      case DetailSection.badges:
        content = BadgesRow(
          metadata: richMetadata!,
          accentColor: widget.system.accentColor,
        );

      case DetailSection.fileDetails:
        content = FileDetailsRow(
          fileMetadata: fileMetadata,
          richMetadata: richMetadata,
        );

      case DetailSection.summary:
        content = SummarySection(
          metadata: richMetadata!,
          accentColor: widget.system.accentColor,
          isExpanded: state.summaryExpanded,
          onToggle: controller.toggleSummaryExpanded,
        );

      case DetailSection.primaryAction:
        content = _buildPrimaryActionSection(state, controller, isMultiRom);

      case DetailSection.actions:
        content = _buildIconButtonsSection(state, controller);

      case DetailSection.screenshots:
        content = ScreenshotsCarousel(
          screenshots: richMetadata!.screenshotUrlList,
          focusedIndex: state.screenshotIndex,
          accentColor: widget.system.accentColor,
          onOpenViewer: controller.openScreenshotViewer,
        );

      case DetailSection.otherVersions:
        content = OtherVersionsSection(
          siblings: richMetadata?.siblingList ?? const [],
          variants: widget.variants,
          isMultiRom: isMultiRom,
          focusedIndex: state.siblingIndex,
          installedStatus: state.installedStatus,
          accentColor: widget.system.accentColor,
        );

      case DetailSection.details:
        content = DetailsSection(
          fileMetadata: fileMetadata,
        );

      case DetailSection.achievements:
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(label: 'Achievements'),
            RaInfoSection(
              match: raMatch!,
              filename: controller.selectedVariant.filename,
              systemSlug: widget.system.id,
              onViewAchievements: () => _navigateToAchievements(raMatch),
            ),
          ],
        );
    }

    return Container(
      key: _keyForSection(section),
      margin: EdgeInsets.only(bottom: rs.spacing.sm),
      decoration: isFocused
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(rs.radius.md),
              border: Border.all(
                color: widget.system.accentColor.withValues(alpha: 0.4),
                width: 1.5,
              ),
            )
          : null,
      padding: EdgeInsets.all(rs.spacing.xs),
      child: content,
    );
  }

  // ---------------------------------------------------------------------------
  // HUD controls
  // ---------------------------------------------------------------------------

  Widget _buildControls(GameDetailState state, GameDetailController controller) {
    if (showQuickMenu) return const SizedBox.shrink();

    // Context-sensitive A-button hint per focused section
    String aHint;
    final section = controller.focusedSection;
    switch (section) {
      case DetailSection.summary:
        aHint = state.summaryExpanded ? 'Collapse' : 'Read More';
      case DetailSection.screenshots:
        aHint = 'View';
      case DetailSection.otherVersions:
        aHint = 'View';
      case DetailSection.primaryAction:
        aHint = 'Select';
      case DetailSection.actions:
        // Show hint based on focused icon button
        switch (state.actionButtonIndex) {
          case 0:
            aHint = 'Favorite';
          case 1:
            aHint = 'Share';
          case 2:
            aHint = 'Add to Shelf';
          default:
            aHint = 'Select';
        }
      case DetailSection.achievements:
        aHint = 'View';
      case DetailSection.title:
      case DetailSection.badges:
      case DetailSection.fileDetails:
      case DetailSection.details:
        aHint = '';
    }

    // Show D-pad hint for horizontal sections
    final bool hasHorizontalNav = section == DetailSection.screenshots ||
        section == DetailSection.otherVersions ||
        section == DetailSection.actions;

    return ConsoleHud(
      b: HudAction('Back', onTap: () => Navigator.pop(context)),
      a: aHint.isNotEmpty ? HudAction(aHint) : null,
      dpad: hasHorizontalNav
          ? (label: '', action: 'Navigate')
          : null,
      select: HudAction('Favorite', onTap: _handleFavorite),
      start: HudAction('Menu', onTap: toggleQuickMenu),
    );
  }

  // ---------------------------------------------------------------------------
  // Section widgets
  // ---------------------------------------------------------------------------

  Widget _buildTitleSection(Responsive rs, GameDetailController controller) {
    final titleFontSize = rs.isSmall ? 20.0 : (rs.isMedium ? 24.0 : 28.0);
    final badgeFontSize = rs.isSmall ? 10.0 : 12.0;
    final manufacturerFontSize = rs.isSmall ? 8.0 : 10.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          controller.displayTitle,
          style: TextStyle(
            color: controller.state.showFullFilename
                ? Colors.white.withValues(alpha: 0.85)
                : Colors.white,
            fontSize: controller.state.showFullFilename
                ? titleFontSize * 0.8
                : titleFontSize,
            fontWeight: FontWeight.bold,
            fontFamily:
                controller.state.showFullFilename ? 'monospace' : null,
            height: 1.1,
            shadows: const [
              Shadow(
                color: Colors.black54,
                blurRadius: 8,
              ),
            ],
          ),
          maxLines: controller.state.showFullFilename ? 3 : 2,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: rs.spacing.sm),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: rs.spacing.sm,
            vertical: rs.spacing.xs,
          ),
          decoration: BoxDecoration(
            color: widget.system.accentColor.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(rs.radius.sm),
            border: Border.all(
              color: widget.system.accentColor.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  widget.system.name,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontWeight: FontWeight.w600,
                    fontSize: badgeFontSize,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                margin: EdgeInsets.only(left: rs.spacing.sm),
                padding: EdgeInsets.symmetric(
                  horizontal: rs.spacing.xs,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  widget.system.manufacturer,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: manufacturerFontSize,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }


  Widget _buildPrimaryActionSection(
    GameDetailState state,
    GameDetailController controller,
    bool isMultiRom,
  ) {
    return ActionButtonsRow.primaryOnly(
      accentColor: widget.system.accentColor,
      downloadButtonState: _getDownloadButtonState(state, isMultiRom),
      variantCount: isMultiRom ? widget.variants.length : null,
      onPrimaryAction: controller.performAction,
      hintText: _getButtonHintText(state, isMultiRom),
    );
  }

  Widget _buildIconButtonsSection(
    GameDetailState state,
    GameDetailController controller,
  ) {
    final isFavorite = ref.watch(favoriteGamesProvider)
        .contains(controller.selectedVariant.filename);

    return ActionButtonsRow.iconsOnly(
      accentColor: widget.system.accentColor,
      isFavorite: isFavorite,
      focusedButtonIndex: state.actionButtonIndex,
      onFavorite: _handleFavorite,
      onShare: _handleShare,
      onCollection: () => _handleCollection(controller),
    );
  }


  // ---------------------------------------------------------------------------
  // Shared helpers
  // ---------------------------------------------------------------------------

  DownloadButtonState _getDownloadButtonState(
    GameDetailState state,
    bool isMultiRom,
  ) {
    if (state.isAddingToQueue) return DownloadButtonState.adding;
    if (widget.isLocalOnly && !state.isVariantInstalled) {
      return DownloadButtonState.unavailable;
    }
    if (isMultiRom) {
      final allInstalled =
          state.installedStatus.length == widget.variants.length &&
              state.installedStatus.values.every((v) => v);
      return allInstalled
          ? DownloadButtonState.installed
          : DownloadButtonState.download;
    }
    if (state.isVariantInstalled) return DownloadButtonState.delete;
    return DownloadButtonState.download;
  }

  String _getButtonHintText(GameDetailState state, bool isMultiRom) {
    if (state.isAddingToQueue) return '';
    if (isMultiRom) return 'Press A to pick a version';
    if (state.isVariantInstalled) return 'Press A to manage';
    return 'Press A to download';
  }
}

/// Blurred cover art background with dark gradient overlay.
/// Falls back to accent-color gradient when no cover is available.
class _CoverBackground extends StatelessWidget {
  final String? coverUrl;
  final Color accentColor;

  const _CoverBackground({
    required this.coverUrl,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Layer 1: Cover image or accent gradient fallback
        if (coverUrl != null)
          ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Image.network(
              coverUrl!,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              errorBuilder: (_, __, ___) => _accentFallback(),
            ),
          )
        else
          _accentFallback(),
        // Layer 2: Dark gradient overlay for readability
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.4),
                Colors.black.withValues(alpha: 0.7),
                Colors.black.withValues(alpha: 0.92),
                Colors.black,
              ],
              stops: const [0.0, 0.3, 0.6, 1.0],
            ),
          ),
        ),
        // Layer 3: Subtle accent tint
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accentColor.withValues(alpha: 0.15),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _accentFallback() {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor.withValues(alpha: 0.3),
            accentColor.withValues(alpha: 0.1),
            const Color(0xFF0A0A0A),
            Colors.black,
          ],
          stops: const [0.0, 0.2, 0.5, 1.0],
        ),
      ),
    );
  }
}
