import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/input/input.dart';
import '../../core/responsive/responsive.dart';
import '../../models/game_item.dart';
import '../../models/system_model.dart';
import '../../providers/app_providers.dart';
import '../../providers/download_providers.dart';
import '../../providers/rom_status_providers.dart';
import '../../providers/game_providers.dart';
import '../../services/download_queue_manager.dart';
import '../../services/input_debouncer.dart';
import '../../utils/game_metadata.dart';
import '../../utils/image_helper.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/console_notification.dart';
import '../../widgets/console_hud.dart';
import '../../widgets/download_overlay.dart';
import '../../widgets/installed_indicator.dart';
import '../../widgets/quick_menu.dart';
import '../game_list/widgets/dynamic_background.dart';
import '../game_list/widgets/tinted_overlay.dart';
import 'game_detail_controller.dart';
import 'game_detail_state.dart';
import 'widgets/cover_section.dart';
import 'widgets/metadata_badges.dart' hide InstalledBadge;
import 'widgets/tag_info_overlay.dart';
import 'widgets/version_card.dart';
import 'widgets/version_carousel.dart';

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
  bool _variantNavHeld = false;

  @override
  String get routeId => 'game_detail_${widget.game.filename}';

  bool _dialogOrNoOverlay(dynamic _) {
    final priority = ref.read(overlayPriorityProvider);
    if (priority == OverlayPriority.none) return true;
    return _controller?.state.isDialogOpen == true;
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
        InfoIntent: OverlayGuardedAction<InfoIntent>(ref,
          onInvoke: (_) { _handleFilenameToggle(); return null; },
        ),
        SearchIntent: OverlayGuardedAction<SearchIntent>(ref,
          onInvoke: (_) { _handleTagInfo(); return null; },
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final queueManager = ref.read(downloadQueueManagerProvider);
      _initController(queueManager);
    });
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
    );
    _controller!.addListener(_onControllerChanged);

    setState(() {});
    ref.listenManual(romChangeSignalProvider, (prev, next) {
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
    _debouncer.stopHold();
    _controller?.removeListener(_onControllerChanged);
    _controller?.dispose();
    super.dispose();
  }

  void _handleBack() {
    final controller = _controller;
    if (controller == null) return;

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

    if (controller.state.isDialogOpen) {
      final selection = controller.state.dialogSelection;
      if (selection == 0) {
        ref.read(feedbackServiceProvider).warning();
      } else {
        ref.read(feedbackServiceProvider).cancel();
      }
      _executeDialogAction(controller).then((_) => requestScreenFocus());
      return;
    }

    if (controller.state.showTagInfo) {
      return;
    }

    if (controller.state.isVariantInstalled) {
      ref.read(feedbackServiceProvider).warning();
    } else {
      ref.read(feedbackServiceProvider).confirm();
    }
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
    ref.read(favoriteGamesProvider.notifier).toggleFavorite(widget.game.displayName);
  }

  List<QuickMenuItem> _buildQuickMenuItems() {
    final controller = _controller;
    if (controller == null) return [];
    final metadata = GameMetadata.parse(controller.selectedVariant.filename);
    final isFavorite = ref.read(favoriteGamesProvider).contains(widget.game.displayName);
    final hasDownloads = ref.read(hasQueueItemsProvider);
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
          shortcutHint: 'Y',
          onSelect: _handleTagInfo,
        ),
      QuickMenuItem(
        label: controller.state.showFullFilename ? 'Show Title' : 'Show Filename',
        icon: Icons.text_fields_rounded,
        shortcutHint: 'X',
        onSelect: _handleFilenameToggle,
      ),
      if (hasDownloads)
        QuickMenuItem(
          label: 'Downloads',
          icon: Icons.download_rounded,
          onSelect: () => toggleDownloadOverlay(ref),
          highlight: true,
        ),
    ];
  }

  void _handleNavigate(GridDirection direction) {
    final controller = _controller;
    if (controller == null) return;

    if (controller.state.showTagInfo || controller.state.isDialogOpen) {
      if (controller.state.isDialogOpen) {
        if (direction == GridDirection.left) {
          ref.read(feedbackServiceProvider).tick();
          controller.selectDialogOption(1);
        } else if (direction == GridDirection.right) {
          ref.read(feedbackServiceProvider).tick();
          controller.selectDialogOption(0);
        }
      }
      return;
    }

    if (widget.variants.length <= 1) return;

    if (direction == GridDirection.up) {
      if (_variantNavHeld) return;
      _variantNavHeld = true;
      if (controller.selectedIndex <= 0) {
        ref.read(feedbackServiceProvider).error();
        return;
      }
      ref.read(feedbackServiceProvider).tick();
      controller.selectVariant(controller.selectedIndex - 1);
    } else if (direction == GridDirection.down) {
      if (_variantNavHeld) return;
      _variantNavHeld = true;
      if (controller.selectedIndex >= widget.variants.length - 1) {
        ref.read(feedbackServiceProvider).error();
        return;
      }
      ref.read(feedbackServiceProvider).tick();
      controller.selectVariant(controller.selectedIndex + 1);
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
      _variantNavHeld = false;
      _debouncer.stopHold();
      return KeyEventResult.ignored;
    }

    if (event is! KeyDownEvent) return KeyEventResult.ignored;

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
    final isFavorite = ref.watch(favoriteGamesProvider).contains(widget.game.displayName);
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
                      isMultiRom, coverUrls, selectedVariant, isFavorite)
                  : _buildLandscapeLayout(rs, state, controller, metadata,
                      isMultiRom, coverUrls, selectedVariant, isFavorite),
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
            flex: isMultiRom ? 35 : 40,
            child: CoverSection(
              game: widget.game,
              system: widget.system,
              coverUrls: coverUrls,
              cachedUrl: selectedVariant.cachedCoverUrl,
              metadata: metadata,
              isFavorite: isFavorite,
              hasThumbnail: selectedVariant.hasThumbnail,
            ),
          ),
          SizedBox(width: rs.spacing.lg),
          Expanded(
            flex: isMultiRom ? 65 : 60,
            child:
                _buildInfoSection(rs, state, controller, metadata, isMultiRom),
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
  ) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: rs.spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: rs.spacing.md),
          AspectRatio(
            aspectRatio: 0.75,
            child: CoverSection(
              game: widget.game,
              system: widget.system,
              coverUrls: coverUrls,
              cachedUrl: selectedVariant.cachedCoverUrl,
              metadata: metadata,
              isFavorite: isFavorite,
              hasThumbnail: selectedVariant.hasThumbnail,
            ),
          ),
          SizedBox(height: rs.spacing.md),
          _buildTitleSection(rs, controller),
          SizedBox(height: rs.spacing.sm),
          _buildMetadataRow(rs, metadata),
          SizedBox(height: rs.spacing.lg),
          if (isMultiRom)
            VersionCarousel(
              variants: widget.variants,
              system: widget.system,
              selectedIndex: state.selectedIndex,
              installedStatus: state.installedStatus,
              onSelectionChanged: (index) {
                controller.selectVariant(index);
              },
            )
          else ...[
            Text(
              'VERSION INFO',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: rs.isSmall ? 9 : 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            SizedBox(height: rs.spacing.sm),
            SingleVersionDisplay(
              variant: controller.selectedVariant,
              system: widget.system,
              isInstalled: state.isVariantInstalled,
            ),
          ],
          SizedBox(height: rs.spacing.xxl),
        ],
      ),
    );
  }

  Widget _buildControls(
      GameDetailState state, GameMetadataFull metadata) {
    final controller = _controller;
    if (controller == null) return const SizedBox.shrink();

    final String actionLabel;
    final VoidCallback? actionCallback;
    if (widget.isLocalOnly && !state.isVariantInstalled) {
      actionLabel = 'Deleted';
      actionCallback = null;
    } else {
      actionLabel = state.isVariantInstalled ? 'Delete' : 'Download';
      actionCallback = controller.performAction;
    }

    if (showQuickMenu) return const SizedBox.shrink();

    return ConsoleHud(
      dpad: widget.variants.length > 1 ? (label: '\u2191\u2193', action: 'Navigate') : null,
      a: HudAction(actionLabel, onTap: actionCallback),
      b: HudAction('Back', onTap: () => Navigator.pop(context)),
      start: HudAction('Menu', onTap: toggleQuickMenu),
    );
  }

  Widget _buildInfoSection(
    Responsive rs,
    GameDetailState state,
    GameDetailController controller,
    GameMetadataFull metadata,
    bool isMultiRom,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTitleSection(rs, controller),
        SizedBox(height: rs.spacing.md),
        _buildMetadataRow(rs, metadata),
        SizedBox(height: rs.spacing.lg),
        if (isMultiRom)
          Expanded(
            child: SingleChildScrollView(
              child: VersionCarousel(
                variants: widget.variants,
                system: widget.system,
                selectedIndex: state.selectedIndex,
                installedStatus: state.installedStatus,
                onSelectionChanged: (index) {
                  controller.selectVariant(index);
                },
                ),
            ),
          )
        else ...[
          SizedBox(height: rs.spacing.sm),
          Text(
            'VERSION INFO',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: rs.isSmall ? 9 : 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          SizedBox(height: rs.spacing.sm),
          SingleVersionDisplay(
            variant: controller.selectedVariant,
            system: widget.system,
            isInstalled: state.isVariantInstalled,
          ),
          const Spacer(),
        ],
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
              Text(
                widget.system.name,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.95),
                  fontWeight: FontWeight.w600,
                  fontSize: badgeFontSize,
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
        if (controller.state.isVariantInstalled) ...[
          SizedBox(height: rs.spacing.xs),
          const InstalledBadge(compact: false),
        ],
      ],
    );
  }

  Widget _buildMetadataRow(Responsive rs, GameMetadataFull metadata) {
    final badgeFontSize = rs.isSmall ? 12.0 : 16.0;

    return Wrap(
      spacing: rs.spacing.sm,
      runSpacing: rs.spacing.sm,
      children: [
        RegionBadge(region: metadata.region, fontSize: badgeFontSize),
        if (metadata.languages.isNotEmpty)
          LanguageBadges(
            languages: metadata.languages,
            maxVisible: rs.isSmall ? 3 : 4,
          ),
        FileTypeBadge(fileType: metadata.fileType),
      ],
    );
  }
}

