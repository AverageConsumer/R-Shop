import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/input/input.dart';
import '../../core/responsive/responsive.dart';
import '../../models/download_item.dart';
import '../../models/game_item.dart';
import '../../models/system_model.dart';
import '../../providers/app_providers.dart';
import '../../providers/download_providers.dart';
import '../../services/download_queue_manager.dart';
import '../../services/input_debouncer.dart';
import '../../utils/game_metadata.dart';
import '../../utils/image_helper.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/console_hud.dart';
import '../../widgets/installed_indicator.dart';
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

  const GameDetailScreen({
    super.key,
    required this.game,
    required this.variants,
    required this.system,
    required this.targetFolder,
  });

  @override
  ConsumerState<GameDetailScreen> createState() => _GameDetailScreenState();
}

class _GameDetailScreenState extends ConsumerState<GameDetailScreen>
    with ConsoleScreenMixin {
  GameDetailController? _controller;
  late final ValueNotifier<String?> _backgroundNotifier;
  late InputDebouncer _debouncer;

  @override
  String get routeId => 'game_detail_${widget.game.filename}';

  @override
  Map<Type, Action<Intent>> get screenActions => {
        BackIntent: _DetailBackAction(this),
        ConfirmIntent: _DetailConfirmAction(this),
        InfoIntent: _DetailFilenameToggleAction(this),
        SearchIntent: _DetailTagInfoAction(this),
        NavigateIntent: _DetailNavigateAction(this),
      };

  @override
  void initState() {
    super.initState();
    _backgroundNotifier = ValueNotifier(null);
    _debouncer = ref.read(inputDebouncerProvider);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(mainFocusRequestProvider.notifier).state = screenFocusNode;
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
      showFullFilename: storage.getShowFullFilename(),
      queueManager: queueManager,
    );
    _controller!.addListener(_onControllerChanged);

    _updateBackground();
    setState(() {});
    _listenForDownloadCompletions();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      requestScreenFocus();
    });
  }

  void _listenForDownloadCompletions() {
    final expectedIds = <String>{
      for (final variant in widget.variants)
        '${widget.system.name}_${variant.filename}',
    };

    ref.listenManual<DownloadQueueManager>(
      downloadQueueManagerProvider,
      (previous, next) {
        if (previous == null) return;
        for (final item in next.state.queue) {
          if (!expectedIds.contains(item.id)) continue;
          if (item.status != DownloadItemStatus.completed) continue;
          final prev = previous.state.getDownloadById(item.id);
          if (prev != null && prev.status != DownloadItemStatus.completed) {
            _controller?.checkInstallationStatus();
            return;
          }
        }
      },
    );
  }

  void _onControllerChanged() {
    if (!mounted) return;

    setState(() {});
    _updateBackground();

    final error = _controller?.state.error;
    if (error != null) {
      ref.read(feedbackServiceProvider).error();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _updateBackground() {
    final controller = _controller;
    if (controller == null) return;

    final selectedVariant = controller.selectedVariant;
    final coverUrls = ImageHelper.getCoverUrlsForSingle(
        widget.system, selectedVariant.filename);
    final imageUrl = selectedVariant.cachedCoverUrl ??
        (coverUrls.isNotEmpty ? coverUrls.first : null);

    if (imageUrl != null && imageUrl != _backgroundNotifier.value) {
      _backgroundNotifier.value = imageUrl;
    }
  }

  @override
  void dispose() {
    _debouncer.stopHold();
    _controller?.removeListener(_onControllerChanged);
    _controller?.dispose();
    _backgroundNotifier.dispose();
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
      _executeDialogAction(controller);
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

    if (direction == GridDirection.left) {
      if (_debouncer.startHold(() {
        final newIndex = controller.selectedIndex - 1;
        if (newIndex >= 0) {
          controller.selectVariant(newIndex);
          _updateBackground();
        }
      })) {
        ref.read(feedbackServiceProvider).tick();
      }
    } else if (direction == GridDirection.right) {
      if (_debouncer.startHold(() {
        final newIndex = controller.selectedIndex + 1;
        if (newIndex < widget.variants.length) {
          controller.selectVariant(newIndex);
          _updateBackground();
        }
      })) {
        ref.read(feedbackServiceProvider).tick();
      }
    }
  }

  Future<void> _executeDialogAction(GameDetailController controller) async {
    final selection = controller.state.dialogSelection;

    if (selection == 0) {
      controller.cancelDialog();
      await controller.deleteRom();
    } else {
      controller.cancelDialog();
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) {
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
      return const Scaffold(
        backgroundColor: Color(0xFF121212),
        body: Center(child: CircularProgressIndicator()),
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
            DynamicBackground(
              backgroundNotifier: _backgroundNotifier,
              accentColor: widget.system.accentColor,
            ),
            TintedOverlay(accentColor: widget.system.accentColor),
            SafeArea(
              bottom: false,
              child: rs.isPortrait
                  ? _buildPortraitLayout(rs, state, controller, metadata,
                      isMultiRom, coverUrls, selectedVariant)
                  : _buildLandscapeLayout(rs, state, controller, metadata,
                      isMultiRom, coverUrls, selectedVariant),
            ),
            _buildControls(state, metadata),
            DialogFocusScope(
              isVisible: state.isDialogOpen,
              onClose: controller.cancelDialog,
              child: ConfirmDialog(
                type: ConfirmDialogType.delete,
                selection: state.dialogSelection,
                gameTitle: controller.cleanTitle,
                onPrimary: () async {
                  controller.cancelDialog();
                  await controller.deleteRom();
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
                _updateBackground();
              },
              onInfoTap: controller.toggleTagInfo,
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
              onInfoTap:
                  metadata.hasInfoDetails ? controller.toggleTagInfo : null,
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

    final actionLabel = state.isVariantInstalled ? 'Delete' : 'Download';

    final filenameLabel = state.showFullFilename ? 'Title' : 'Filename';

    return ConsoleHud(
      dpad: widget.variants.length > 1 ? (label: '\u2190\u2192', action: 'Navigate') : null,
      a: HudAction(actionLabel, onTap: controller.performAction),
      b: HudAction('Back', onTap: () => Navigator.pop(context)),
      x: HudAction(filenameLabel, onTap: controller.toggleFullFilename),
      y: metadata.allTags.isNotEmpty ? HudAction('Tags', onTap: controller.toggleTagInfo) : null,
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
            child: VersionCarousel(
              variants: widget.variants,
              system: widget.system,
              selectedIndex: state.selectedIndex,
              installedStatus: state.installedStatus,
              onSelectionChanged: (index) {
                controller.selectVariant(index);
                _updateBackground();
              },
              onInfoTap: controller.toggleTagInfo,
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
            onInfoTap:
                metadata.hasInfoDetails ? controller.toggleTagInfo : null,
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

class _DetailBackAction extends Action<BackIntent> {
  final _GameDetailScreenState screen;

  _DetailBackAction(this.screen);

  @override
  Object? invoke(BackIntent intent) {
    screen._handleBack();
    return null;
  }
}

class _DetailConfirmAction extends Action<ConfirmIntent> {
  final _GameDetailScreenState screen;

  _DetailConfirmAction(this.screen);

  @override
  Object? invoke(ConfirmIntent intent) {
    screen._handleConfirm();
    return null;
  }
}

class _DetailFilenameToggleAction extends Action<InfoIntent> {
  final _GameDetailScreenState screen;

  _DetailFilenameToggleAction(this.screen);

  @override
  Object? invoke(InfoIntent intent) {
    screen._handleFilenameToggle();
    return null;
  }
}

class _DetailTagInfoAction extends Action<SearchIntent> {
  final _GameDetailScreenState screen;

  _DetailTagInfoAction(this.screen);

  @override
  Object? invoke(SearchIntent intent) {
    screen._handleTagInfo();
    return null;
  }
}

class _DetailNavigateAction extends Action<NavigateIntent> {
  final _GameDetailScreenState screen;

  _DetailNavigateAction(this.screen);

  @override
  Object? invoke(NavigateIntent intent) {
    screen._handleNavigate(intent.direction);
    return null;
  }
}
