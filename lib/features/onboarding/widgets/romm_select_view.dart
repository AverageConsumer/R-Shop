import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/responsive/responsive.dart';
import '../../../core/widgets/console_focusable.dart';
import '../../../models/system_model.dart';
import '../../../services/romm_api_service.dart';
import '../onboarding_controller.dart';
import 'chat_bubble.dart';

class RommSelectView extends ConsumerWidget {
  final VoidCallback onComplete;
  const RommSelectView({super.key, required this.onComplete});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);
    final rs = context.rs;
    final rommSetup = state.rommSetupState;
    if (rommSetup == null) return const SizedBox.shrink();

    final matchedCount = rommSetup.matchedCount;
    final selectedCount = rommSetup.selectedCount;
    final allSelected = selectedCount == matchedCount;

    // Build sorted list of matched systems
    final matchedEntries = rommSetup.systemMatches.entries.toList()
      ..sort((a, b) {
        final sysA = SystemModel.supportedSystems
            .firstWhere((s) => s.id == a.key);
        final sysB = SystemModel.supportedSystems
            .firstWhere((s) => s.id == b.key);
        return sysA.name.compareTo(sysB.name);
      });

    return FocusScope(
      child: Column(
        key: const ValueKey('rommSelect'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ChatBubble(
            key: ValueKey('bubble_rommSelect_$matchedCount'),
            message: matchedCount == 0
                ? "Hmm, I couldn't match any consoles from your RomM server. You can still set them up manually."
                : "I found $matchedCount ${matchedCount == 1 ? 'console' : 'consoles'} on your RomM server! Uncheck any you don't want.",
            accentColor: matchedCount > 0 ? Colors.green : Colors.orange,
            onComplete: onComplete,
          ),
          SizedBox(height: rs.spacing.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                left: rs.isSmall ? 40 : 60,
                bottom: 64,
              ),
              child: matchedCount == 0
                  ? const SizedBox.shrink()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(rs, selectedCount, matchedCount,
                            allSelected, controller),
                        SizedBox(height: rs.spacing.sm),
                        Expanded(
                          child: FocusTraversalGroup(
                            child: ListView.builder(
                              itemCount: matchedEntries.length,
                              itemBuilder: (context, index) {
                                final entry = matchedEntries[index];
                                final systemId = entry.key;
                                final platform = entry.value;
                                final system =
                                    SystemModel.supportedSystems.firstWhere(
                                  (s) => s.id == systemId,
                                );
                                final isSelected = rommSetup.selectedSystemIds
                                    .contains(systemId);

                                return SystemRow(
                                  system: system,
                                  platform: platform,
                                  isSelected: isSelected,
                                  autofocus: index == 0,
                                  onToggle: () =>
                                      controller.toggleRommSystem(systemId),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(Responsive rs, int selectedCount, int matchedCount,
      bool allSelected, OnboardingController controller) {
    final fontSize = rs.isSmall ? 11.0 : 13.0;

    return Row(
      children: [
        Text(
          '$selectedCount / $matchedCount selected',
          style: TextStyle(
            color: Colors.grey.shade400,
            fontSize: fontSize,
          ),
        ),
        const Spacer(),
        ConsoleFocusable(
          onSelect: () => controller.toggleAllRommSystems(!allSelected),
          borderRadius: 4,
          child: GestureDetector(
            onTap: () => controller.toggleAllRommSystems(!allSelected),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
              child: Text(
                allSelected ? 'Deselect All' : 'Select All',
                style: TextStyle(
                  color: Colors.blue.shade300,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class SystemRow extends StatelessWidget {
  final SystemModel system;
  final RommPlatform platform;
  final bool isSelected;
  final bool autofocus;
  final VoidCallback onToggle;

  const SystemRow({
    super.key,
    required this.system,
    required this.platform,
    required this.isSelected,
    required this.onToggle,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final nameFontSize = rs.isSmall ? 12.0 : 14.0;
    final detailFontSize = rs.isSmall ? 10.0 : 12.0;
    final iconSize = rs.isSmall ? 24.0 : 30.0;
    final checkSize = rs.isSmall ? 18.0 : 22.0;

    return Padding(
      padding: EdgeInsets.only(bottom: rs.spacing.xs),
      child: ConsoleFocusableListItem(
        autofocus: autofocus,
        onSelect: onToggle,
        borderRadius: rs.radius.sm,
        padding: EdgeInsets.symmetric(
          horizontal: rs.spacing.md,
          vertical: rs.spacing.sm,
        ),
        child: Row(
          children: [
            // System icon
            ClipRRect(
              borderRadius: BorderRadius.circular(rs.radius.sm),
              child: SvgPicture.asset(
                system.iconAssetPath,
                width: iconSize,
                height: iconSize,
                colorFilter: ColorFilter.mode(system.iconColor, BlendMode.srcIn),
                placeholderBuilder: (_) => Icon(
                  Icons.videogame_asset,
                  color: system.accentColor,
                  size: iconSize,
                ),
              ),
            ),
            SizedBox(width: rs.spacing.md),
            // System + platform info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    system.name,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: nameFontSize,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${platform.name} \u2022 ${platform.romCount} ROMs',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: detailFontSize,
                    ),
                  ),
                ],
              ),
            ),
            // Checkbox
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
                      : Colors.white.withValues(alpha: 0.2),
                ),
              ),
              child: isSelected
                  ? Icon(Icons.check, color: Colors.green, size: checkSize - 6)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
