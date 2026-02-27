import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/input/input.dart';
import '../../services/input_debouncer.dart';
import '../../core/responsive/responsive.dart';
import '../../models/ra_models.dart';
import '../../providers/app_providers.dart';
import '../../providers/ra_providers.dart';
import '../../services/ra_api_service.dart';
import '../../widgets/console_hud.dart';
import '../../widgets/selection_aware_item.dart';
import '../game_list/widgets/dynamic_background.dart';
import '../game_list/widgets/tinted_overlay.dart';

class AchievementsScreen extends ConsumerStatefulWidget {
  final int raGameId;
  final String? raTitle;
  final String? imageIcon;
  final Color accentColor;

  const AchievementsScreen({
    super.key,
    required this.raGameId,
    this.raTitle,
    this.imageIcon,
    required this.accentColor,
  });

  @override
  ConsumerState<AchievementsScreen> createState() =>
      _AchievementsScreenState();
}

class _AchievementsScreenState extends ConsumerState<AchievementsScreen>
    with ConsoleScreenMixin {
  final ScrollController _scrollController = ScrollController();
  late final FocusSyncManager _focusManager;
  final ValueNotifier<int> _selectedIndexNotifier = ValueNotifier(0);
  final Map<int, GlobalKey> _itemKeys = {};
  late final InputDebouncer _debouncer;

  @override
  String get routeId => 'achievements_${widget.raGameId}';

  @override
  void initState() {
    super.initState();
    _debouncer = ref.read(inputDebouncerProvider);
    _focusManager = FocusSyncManager(
      scrollController: _scrollController,
      getCrossAxisCount: () => 1,
      getItemCount: () => _getAchievementCount(),
      getGridRatio: () => 1.0,
      onSelectionChanged: (index) => _selectedIndexNotifier.value = index,
    );
  }

  int _getAchievementCount() {
    return ref.read(raGameProgressProvider(widget.raGameId)).value
            ?.achievements.length ?? 0;
  }

  @override
  Map<Type, Action<Intent>> get screenActions => {
        BackIntent: CallbackAction<BackIntent>(
          onInvoke: (_) {
            ref.read(feedbackServiceProvider).cancel();
            Navigator.pop(context);
            return null;
          },
        ),
        NavigateIntent: OverlayGuardedAction<NavigateIntent>(
          ref,
          onInvoke: (intent) {
            _navigateList(intent.direction);
            return null;
          },
        ),
      };

  void _navigateList(GridDirection direction) {
    if (direction == GridDirection.left || direction == GridDirection.right) {
      return;
    }

    if (_debouncer.startHold(() {
      if (_focusManager.moveFocus(direction)) {
        _focusManager.scrollToSelected(
          _itemKeys[_focusManager.selectedIndex],
          instant: _debouncer.isHolding,
        );
      } else {
        ref.read(feedbackServiceProvider).error();
      }
    })) {
      ref.read(feedbackServiceProvider).tick();
    }
  }

  void _updateItemKeys(int count) {
    if (_itemKeys.length == count) return;
    _itemKeys.clear();
    for (int i = 0; i < count; i++) {
      _itemKeys[i] = GlobalKey();
    }
    _focusManager.ensureFocusNodes(count);
  }

  void _syncFocusToVisibleItem() {
    if (!_scrollController.hasClients) return;
    final count = _getAchievementCount();
    if (count == 0) return;

    final maxExtent = _scrollController.position.maxScrollExtent;
    final viewportHeight = _scrollController.position.viewportDimension;
    final totalHeight = maxExtent + viewportHeight;
    if (totalHeight <= 0) return;

    final centerOffset = _scrollController.offset + viewportHeight / 2;
    final estimatedIndex =
        ((centerOffset / totalHeight) * count).round().clamp(0, count - 1);

    if (estimatedIndex != _focusManager.selectedIndex) {
      _focusManager.setSelectedIndex(estimatedIndex);
      _selectedIndexNotifier.value = estimatedIndex;
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
  void dispose() {
    _debouncer.stopHold();
    _focusManager.dispose();
    _scrollController.dispose();
    _selectedIndexNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final progress = ref.watch(raGameProgressProvider(widget.raGameId));

    return buildWithActions(Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned.fill(
              child: DynamicBackground(accentColor: widget.accentColor),
            ),
            TintedOverlay(accentColor: widget.accentColor),
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _buildHeader(rs),
                  Expanded(
                    child: progress.when(
                      data: (data) => data != null
                          ? _buildAchievementList(rs, data)
                          : _buildEmpty(rs),
                      loading: () => Center(
                        child: CircularProgressIndicator(
                          color: widget.accentColor,
                        ),
                      ),
                      error: (e, _) => _buildError(rs, e.toString()),
                    ),
                  ),
                ],
              ),
            ),
            ConsoleHud(
              b: HudAction('Back', onTap: () => Navigator.pop(context)),
              dpad: (label: '\u2191\u2193', action: 'Navigate'),
            ),
          ],
        ),
      ),
      onKeyEvent: _handleKeyEvent,
    );
  }

  Widget _buildHeader(Responsive rs) {
    final iconSize = rs.isSmall ? 36.0 : 48.0;
    final titleFontSize = rs.isSmall ? 16.0 : 20.0;
    final subtitleFontSize = rs.isSmall ? 10.0 : 12.0;
    final progress = ref.watch(raGameProgressProvider(widget.raGameId)).value;

    final isMastered = progress?.isCompleted ?? false;

    return Container(
      padding: EdgeInsets.fromLTRB(
        rs.spacing.lg,
        rs.spacing.md,
        rs.spacing.lg,
        rs.spacing.md,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        border: Border(
          bottom: BorderSide(
            color: isMastered
                ? Colors.greenAccent.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: Row(
        children: [
          if (widget.imageIcon != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: CachedNetworkImage(
                imageUrl:
                    RetroAchievementsService.gameIconUrl(widget.imageIcon!),
                width: iconSize,
                height: iconSize,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _iconPlaceholder(iconSize),
              ),
            )
          else
            _iconPlaceholder(iconSize),
          SizedBox(width: rs.spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.raTitle ?? 'Achievements',
                  style: TextStyle(
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (progress != null) ...[
                  SizedBox(height: rs.spacing.xs),
                  _buildProgressSummary(rs, progress, subtitleFontSize),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconPlaceholder(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(
        Icons.emoji_events,
        size: size * 0.5,
        color: Colors.white.withValues(alpha: 0.2),
      ),
    );
  }

  Widget _buildProgressSummary(
      Responsive rs, RaGameProgress progress, double fontSize) {
    final earned = progress.earnedCount;
    final total = progress.numAchievements;
    final pct = progress.completionPercent;
    final hasUserProgress = earned > 0;
    final isMastered = progress.isCompleted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (isMastered) ...[
              Icon(
                Icons.military_tech,
                size: fontSize + 2,
                color: Colors.greenAccent,
              ),
              SizedBox(width: rs.isSmall ? 3 : 4),
              Text(
                'MASTERED',
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                  color: Colors.greenAccent,
                  letterSpacing: 1.0,
                ),
              ),
              Text(
                '  \u2022  ',
                style: TextStyle(
                  fontSize: fontSize,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
              ),
            ],
            Text(
              '$total achievements',
              style: TextStyle(
                fontSize: fontSize,
                color: isMastered
                    ? Colors.greenAccent.withValues(alpha: 0.7)
                    : Colors.white.withValues(alpha: 0.6),
              ),
            ),
            if (progress.points > 0) ...[
              Text(
                '  \u2022  ',
                style: TextStyle(
                  fontSize: fontSize,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
              ),
              Text(
                '${progress.points} pts',
                style: TextStyle(
                  fontSize: fontSize,
                  color: isMastered
                      ? Colors.greenAccent.withValues(alpha: 0.6)
                      : Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ],
            if (hasUserProgress && !isMastered) ...[
              Text(
                '  \u2022  ',
                style: TextStyle(
                  fontSize: fontSize,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
              ),
              Text(
                '$earned / $total (${(pct * 100).toStringAsFixed(0)}%)',
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFFFD54F),
                ),
              ),
            ],
          ],
        ),
        if (hasUserProgress) ...[
          SizedBox(height: rs.isSmall ? 4 : 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: pct.clamp(0.0, 1.0),
              minHeight: rs.isSmall ? 3 : 4,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation(
                isMastered ? Colors.greenAccent : const Color(0xFFFFD54F),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAchievementList(Responsive rs, RaGameProgress progress) {
    if (progress.achievements.isEmpty) return _buildEmpty(rs);

    final count = progress.achievements.length;
    _updateItemKeys(count);
    _focusManager.validateState(1);

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (_focusManager.isProgrammaticScroll) return false;
        if (notification is ScrollEndNotification &&
            !_focusManager.isHardwareInput) {
          _syncFocusToVisibleItem();
        }
        return false;
      },
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.only(
          left: rs.spacing.lg,
          right: rs.spacing.lg,
          top: rs.spacing.md,
          bottom: rs.isPortrait ? 80 : 100,
        ),
        itemCount: count,
        itemBuilder: (context, index) {
          final achievement = progress.achievements[index];
          return SelectionAwareItem(
            key: _itemKeys[index],
            selectedIndexNotifier: _selectedIndexNotifier,
            index: index,
            builder: (isSelected) => _AchievementTile(
              achievement: achievement,
              isSelected: isSelected,
              isSmall: rs.isSmall,
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmpty(Responsive rs) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.emoji_events_outlined,
            size: rs.isSmall ? 48 : 64,
            color: Colors.white.withValues(alpha: 0.15),
          ),
          SizedBox(height: rs.spacing.md),
          Text(
            'No achievements found',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: rs.isSmall ? 14 : 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(Responsive rs, String error) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: rs.isSmall ? 36 : 48,
            color: Colors.redAccent,
          ),
          SizedBox(height: rs.spacing.md),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: rs.spacing.xl),
            child: Text(
              error,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: rs.isSmall ? 10 : 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  final RaAchievement achievement;
  final bool isSelected;
  final bool isSmall;

  const _AchievementTile({
    required this.achievement,
    required this.isSelected,
    required this.isSmall,
  });

  @override
  Widget build(BuildContext context) {
    final badgeSize = isSmall ? 40.0 : 52.0;
    final titleFontSize = isSmall ? 11.0 : 13.0;
    final descFontSize = isSmall ? 9.0 : 10.0;
    final pointsFontSize = isSmall ? 10.0 : 12.0;
    final pad = isSmall ? 8.0 : 12.0;

    final isEarned = achievement.isEarned;
    final badgeUrl = isEarned
        ? RetroAchievementsService.badgeUrl(achievement.badgeName)
        : RetroAchievementsService.badgeLockedUrl(achievement.badgeName);

    return Container(
      margin: EdgeInsets.only(bottom: isSmall ? 4 : 6),
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        color: isSelected
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(isSmall ? 8 : 10),
        border: Border.all(
          color: isSelected
              ? Colors.white.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.06),
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          // Badge image
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: ColorFiltered(
              colorFilter: isEarned
                  ? const ColorFilter.mode(
                      Colors.transparent, BlendMode.multiply)
                  : const ColorFilter.matrix(<double>[
                      0.2126, 0.7152, 0.0722, 0, 0,
                      0.2126, 0.7152, 0.0722, 0, 0,
                      0.2126, 0.7152, 0.0722, 0, 0,
                      0, 0, 0, 0.5, 0,
                    ]),
              child: CachedNetworkImage(
                imageUrl: badgeUrl,
                width: badgeSize,
                height: badgeSize,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  width: badgeSize,
                  height: badgeSize,
                  color: Colors.white.withValues(alpha: 0.08),
                  child: Icon(
                    Icons.emoji_events,
                    size: badgeSize * 0.5,
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: isSmall ? 8 : 12),
          // Title + description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  achievement.title,
                  style: TextStyle(
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.w600,
                    color: isEarned
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.5),
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (achievement.description.isNotEmpty) ...[
                  SizedBox(height: isSmall ? 2 : 3),
                  Text(
                    achievement.description,
                    style: TextStyle(
                      fontSize: descFontSize,
                      color: Colors.white.withValues(alpha: 0.4),
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (isEarned && achievement.dateEarned != null) ...[
                  SizedBox(height: isSmall ? 2 : 3),
                  Text(
                    _formatDate(achievement.dateEarned!),
                    style: TextStyle(
                      fontSize: descFontSize - 1,
                      color: Colors.greenAccent.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: isSmall ? 6 : 8),
          // Points + status
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmall ? 6 : 8,
                  vertical: isSmall ? 3 : 4,
                ),
                decoration: BoxDecoration(
                  color: isEarned
                      ? Colors.greenAccent.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${achievement.points}',
                  style: TextStyle(
                    fontSize: pointsFontSize,
                    fontWeight: FontWeight.w700,
                    color: isEarned
                        ? Colors.greenAccent
                        : Colors.white.withValues(alpha: 0.4),
                  ),
                ),
              ),
              if (isEarned) ...[
                SizedBox(height: isSmall ? 2 : 3),
                Icon(
                  Icons.check_circle,
                  size: isSmall ? 12 : 14,
                  color: Colors.greenAccent,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
