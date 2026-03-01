import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/input/input.dart';
import '../../core/responsive/responsive.dart';
import '../../models/game_item.dart';
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
import '../game_list/widgets/dynamic_background.dart';
import '../game_list/widgets/tinted_overlay.dart';
import '../library/widgets/shelf_picker_dialog.dart';
import 'achievements_screen.dart';
import 'game_detail_controller.dart';
import 'game_detail_state.dart';
import 'widgets/cover_section.dart';
import 'widgets/game_info_card.dart';
import 'widgets/metadata_badges.dart';
import 'widgets/ra_info_section.dart';
import 'widgets/download_action_button.dart';
import 'widgets/description_overlay.dart';
import 'widgets/tag_info_overlay.dart';
import 'widgets/variant_picker_overlay.dart';

class GameDetailScreen extends ConsumerStatefulWidget {
  final GameItem game;
  final List<GameItem> variants;
  final SystemModel system;
  final String targetFolder;
  final bool isLocalOnly;

  const GameDetailScreen({
    super.key,
    required this.game,
    required this.variants,
    required this.system,
    required this.targetFolder,
    this.isLocalOnly = false,
  });

  @override
  ConsumerState<GameDetailScreen> createState() => _GameDetailScreenState();
}

class _GameDetailScreenState extends ConsumerState<GameDetailScreen>
    with ConsoleScreenMixin {
  GameDetailController? _controller;
  late InputDebouncer _debouncer;
  ProviderSubscription? _romChangeSubscription;

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
      ref.read(feedbackServiceProvider).error();
      showConsoleNotification(context, message: 'Error: $error');
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

  void _handleBack() {
    final controller = _controller;
    if (controller == null) return;

    if (controller.state.showVariantPicker) {
      ref.read(feedbackServiceProvider).cancel();
      controller.closeVariantPicker();
      return;
    }

    if (controller.state.showDescription) {
      ref.read(feedbackServiceProvider).cancel();
      controller.closeDescription();
      return;
    }

    if (controller.state.showTagInfo) {
      ref.read(feedbackServiceProvider).cancel();
      controller.closeTagInfo();
      return;
    }

    if (controller.state.isDialogOpen) {
      ref.read(feedbackServiceProvider).cancel();
      controller.cancelDialog();
      return;
    }

    ref.read(feedbackServiceProvider).cancel();
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

    if (controller.state.showTagInfo) {
      return;
    }

    ref.read(feedbackServiceProvider).confirm();
    controller.performAction();
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

  void _handleTagInfo() {
    final controller = _controller;
    if (controller == null) return;

    if (controller.state.showTagInfo) {
      ref.read(feedbackServiceProvider).cancel();
      controller.closeTagInfo();
      return;
    }

    if (controller.state.isDialogOpen) {
      return;
    }

    ref.read(feedbackServiceProvider).tick();
    controller.toggleTagInfo();
  }

  void _handleFavorite() {
    final controller = _controller;
    if (controller == null) return;
    if (controller.state.isOverlayOpen) return;

    ref.read(feedbackServiceProvider).tick();
    ref.read(favoriteGamesProvider.notifier).toggleFavorite(controller.selectedVariant.filename);
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
    queueManager.addToQueue(modifiedGame, widget.system, widget.targetFolder);
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
    final richMetadata = ref.read(gameMetadataProvider(
      (filename: variant.filename, systemSlug: widget.system.id),
    )).valueOrNull;
    final hasSummary = richMetadata?.summary != null;
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
      if (metadata.allTags.isNotEmpty)
        QuickMenuItem(
          label: 'Tags',
          icon: Icons.label_rounded,
          onSelect: _handleTagInfo,
        ),
      if (hasSummary)
        QuickMenuItem(
          label: 'Description',
          icon: Icons.description_outlined,
          onSelect: () => controller.openDescription(),
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
          icon: Icons.playlist_add_rounded,
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
    }
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
    final GameMetadataFull metadata =
        GameMetadata.parse(selectedVariant.filename);
    final isMultiRom = widget.variants.length > 1;
    final isFavorite = ref.watch(favoriteGamesProvider).contains(controller.selectedVariant.filename);
    final raMatches =
        ref.watch(raMatchesForSystemProvider(widget.system.id)).value ?? {};
    final raMatch = raMatches[selectedVariant.filename];
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
              child: DynamicBackground(
                accentColor: widget.system.accentColor,
              ),
            ),
            TintedOverlay(accentColor: widget.system.accentColor),
            SafeArea(
              bottom: false,
              child: rs.isPortrait
                  ? _buildPortraitLayout(rs, state, controller, metadata,
                      isMultiRom, coverUrls, selectedVariant, isFavorite, raMatch)
                  : _buildLandscapeLayout(rs, state, controller, metadata,
                      isMultiRom, coverUrls, selectedVariant, isFavorite, raMatch),
            ),
            _buildControls(state, metadata),
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
            OverlayFocusScope(
              priority: OverlayPriority.dialog,
              isVisible: state.showTagInfo,
              onClose: controller.closeTagInfo,
              child: TagInfoOverlay(
                metadata:
                    GameMetadata.parse(controller.selectedVariant.filename),
                onClose: controller.closeTagInfo,
              ),
            ),
            if (state.showDescription)
              OverlayFocusScope(
                priority: OverlayPriority.dialog,
                isVisible: state.showDescription,
                onClose: controller.closeDescription,
                child: Builder(
                  builder: (context) {
                    final richMetadata = ref.read(gameMetadataProvider(
                      (filename: selectedVariant.filename, systemSlug: widget.system.id),
                    )).valueOrNull;
                    if (richMetadata == null) return const SizedBox.shrink();
                    return DescriptionOverlay(
                      metadata: richMetadata,
                      gameTitle: controller.cleanTitle,
                      accentColor: widget.system.accentColor,
                      onClose: controller.closeDescription,
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
          ],
        ),
      ),
      ),
      onKeyEvent: _handleKeyEvent,
    );
  }

  Widget _buildLandscapeLayout(
    Responsive rs,
    GameDetailState state,
    GameDetailController controller,
    GameMetadataFull metadata,
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
          Expanded(
            flex: 40,
            child: CoverSection(
              game: widget.game,
              system: widget.system,
              coverUrls: coverUrls,
              cachedUrl: selectedVariant.cachedCoverUrl,
              metadata: metadata,
              isFavorite: isFavorite,
              isInstalled: state.isVariantInstalled,
              hasThumbnail: selectedVariant.hasThumbnail,
            ),
          ),
          SizedBox(width: rs.spacing.lg),
          Expanded(
            flex: 60,
            child:
                _buildInfoSection(rs, state, controller, metadata, raMatch),
          ),
        ],
      ),
    );
  }

  Widget _buildPortraitLayout(
    Responsive rs,
    GameDetailState state,
    GameDetailController controller,
    GameMetadataFull metadata,
    bool isMultiRom,
    List<String> coverUrls,
    GameItem selectedVariant,
    bool isFavorite,
    RaMatchResult? raMatch,
  ) {
    final gameMetadata = ref.watch(gameMetadataProvider(
      (filename: selectedVariant.filename, systemSlug: widget.system.id),
    ));
    final richMetadata = gameMetadata.valueOrNull;
    final hasRichMetadata = richMetadata?.hasContent ?? false;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: rs.spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: rs.spacing.md),
          AspectRatio(
            aspectRatio: hasRichMetadata ? 0.85 : 0.75,
            child: CoverSection(
              game: widget.game,
              system: widget.system,
              coverUrls: coverUrls,
              cachedUrl: selectedVariant.cachedCoverUrl,
              metadata: metadata,
              isFavorite: isFavorite,
              isInstalled: state.isVariantInstalled,
              hasThumbnail: selectedVariant.hasThumbnail,
            ),
          ),
          SizedBox(height: rs.spacing.md),
          _buildTitleSection(rs, controller),
          if (hasRichMetadata) ...[
            _buildSectionHeader('About This Game', rs),
            GameInfoCard(
              metadata: richMetadata!,
              accentColor: widget.system.accentColor,
            ),
          ],
          SizedBox(height: rs.spacing.lg),
          _buildDownloadArea(rs, state, controller, isMultiRom),
          if (!isMultiRom) ...[
            _buildSectionHeader('Details', rs),
            _buildStructuredDetails(rs, metadata),
          ],
          if (raMatch != null && raMatch.hasMatch) ...[
            _buildSectionHeader('Achievements', rs),
            RaInfoSection(
              match: raMatch,
              filename: selectedVariant.filename,
              systemSlug: widget.system.id,
              onViewAchievements: () => _navigateToAchievements(raMatch),
            ),
          ],
          SizedBox(height: rs.spacing.xxl),
        ],
      ),
    );
  }

  Widget _buildControls(
      GameDetailState state, GameMetadataFull metadata) {
    if (_controller == null) return const SizedBox.shrink();
    if (showQuickMenu) return const SizedBox.shrink();

    return ConsoleHud(
      b: HudAction('Back', onTap: () => Navigator.pop(context)),
      start: HudAction('Menu', onTap: toggleQuickMenu),
    );
  }

  Widget _buildInfoSection(
    Responsive rs,
    GameDetailState state,
    GameDetailController controller,
    GameMetadataFull metadata,
    RaMatchResult? raMatch,
  ) {
    final isMultiRom = widget.variants.length > 1;
    final gameMetadata = ref.watch(gameMetadataProvider(
      (filename: controller.selectedVariant.filename, systemSlug: widget.system.id),
    ));
    final richMetadata = gameMetadata.valueOrNull;
    final hasRichMetadata = richMetadata?.hasContent ?? false;

    // Landscape: compact layout without section headers or scroll —
    // gamepad can't scroll here since nothing is focused.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTitleSection(rs, controller),
        if (hasRichMetadata) ...[
          SizedBox(height: rs.spacing.sm),
          Expanded(
            child: GameInfoCard(
              metadata: richMetadata!,
              accentColor: widget.system.accentColor,
            ),
          ),
        ],
        SizedBox(height: rs.spacing.md),
        _buildDownloadButton(state, controller, isMultiRom),
        if (!isMultiRom) ...[
          SizedBox(height: rs.spacing.md),
          _buildStructuredDetails(rs, metadata),
        ],
        if (raMatch != null && raMatch.hasMatch) ...[
          SizedBox(height: rs.spacing.md),
          RaInfoSection(
            match: raMatch,
            filename: controller.selectedVariant.filename,
            systemSlug: widget.system.id,
          ),
        ],
        if (!hasRichMetadata) const Spacer(),
      ],
    );
  }

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

  Widget _buildDownloadButton(
    GameDetailState state,
    GameDetailController controller,
    bool isMultiRom,
  ) {
    final DownloadButtonState buttonState;
    if (state.isAddingToQueue) {
      buttonState = DownloadButtonState.adding;
    } else if (widget.isLocalOnly && !state.isVariantInstalled) {
      buttonState = DownloadButtonState.unavailable;
    } else if (isMultiRom) {
      final allInstalled = state.installedStatus.length == widget.variants.length &&
          state.installedStatus.values.every((v) => v);
      buttonState = allInstalled
          ? DownloadButtonState.installed
          : DownloadButtonState.download;
    } else if (state.isVariantInstalled) {
      buttonState = DownloadButtonState.delete;
    } else {
      buttonState = DownloadButtonState.download;
    }

    return DownloadActionButton(
      state: buttonState,
      accentColor: widget.system.accentColor,
      variantCount: isMultiRom ? widget.variants.length : null,
      onTap: controller.performAction,
    );
  }

  Widget _buildSectionHeader(String label, Responsive rs) {
    return Padding(
      padding: EdgeInsets.only(
        top: rs.spacing.lg,
        bottom: rs.spacing.sm,
        left: rs.spacing.xs,
      ),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: rs.isSmall ? 10 : 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
          SizedBox(width: rs.spacing.md),
          Expanded(
            child: Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.06),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStructuredDetails(Responsive rs, GameMetadataFull metadata) {
    final labelStyle = TextStyle(
      color: Colors.white.withValues(alpha: 0.4),
      fontSize: rs.isSmall ? 10 : 12,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(rs.spacing.md),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(rs.radius.md),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          _detailRow(
            rs,
            label: 'Region',
            labelStyle: labelStyle,
            child: RegionBadge(region: metadata.region, fontSize: rs.isSmall ? 12 : 14),
          ),
          if (metadata.languages.isNotEmpty) ...[
            Divider(color: Colors.white.withValues(alpha: 0.04), height: rs.spacing.md),
            _detailRow(
              rs,
              label: 'Languages',
              labelStyle: labelStyle,
              child: LanguageBadges(
                languages: metadata.languages,
                maxVisible: rs.isSmall ? 4 : 6,
              ),
            ),
          ],
          Divider(color: Colors.white.withValues(alpha: 0.04), height: rs.spacing.md),
          _detailRow(
            rs,
            label: 'Format',
            labelStyle: labelStyle,
            child: FileTypeBadge(fileType: metadata.fileType),
          ),
          if (metadata.primaryTags.isNotEmpty) ...[
            Divider(color: Colors.white.withValues(alpha: 0.04), height: rs.spacing.md),
            _detailRow(
              rs,
              label: 'Tags',
              labelStyle: labelStyle,
              child: TagBadges(tags: metadata.primaryTags, maxVisible: 4),
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailRow(
    Responsive rs, {
    required String label,
    required TextStyle labelStyle,
    required Widget child,
  }) {
    return Row(
      children: [
        SizedBox(
          width: rs.isSmall ? 70 : 85,
          child: Text(label, style: labelStyle),
        ),
        SizedBox(width: rs.spacing.sm),
        Expanded(child: child),
      ],
    );
  }

  Widget _buildDownloadArea(
    Responsive rs,
    GameDetailState state,
    GameDetailController controller,
    bool isMultiRom,
  ) {
    final accentColor = widget.system.accentColor;

    return Container(
      padding: EdgeInsets.all(rs.spacing.md),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(rs.radius.md),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.08),
            blurRadius: 16,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Column(
        children: [
          _buildDownloadButton(state, controller, isMultiRom),
          SizedBox(height: rs.spacing.xs),
          Text(
            _getButtonHintText(state, isMultiRom),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.25),
              fontSize: rs.isSmall ? 9 : 10,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  String _getButtonHintText(GameDetailState state, bool isMultiRom) {
    if (state.isAddingToQueue) return '';
    if (isMultiRom) return 'Press A to pick a version';
    if (state.isVariantInstalled) return 'Press A to manage';
    return 'Press A to download';
  }
}

