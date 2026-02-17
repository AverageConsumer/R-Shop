import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/responsive/responsive.dart';
import '../../../models/system_model.dart';
import '../onboarding_controller.dart';

class ConsoleGrid extends ConsumerWidget {
  const ConsoleGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);
    final rs = context.rs;
    final systems = SystemModel.supportedSystems;

    final crossAxisCount = rs.isSmall
        ? (rs.isPortrait ? 3 : 5)
        : (rs.isPortrait ? 4 : 6);

    return FocusTraversalGroup(
      child: GridView.builder(
        padding: EdgeInsets.only(bottom: rs.spacing.lg),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: 0.85,
          crossAxisSpacing: rs.spacing.md,
          mainAxisSpacing: rs.spacing.md,
        ),
        itemCount: systems.length,
        itemBuilder: (context, index) {
          final system = systems[index];
          final isConfigured = state.configuredSystems.containsKey(system.id);

          return _ConsoleTile(
            system: system,
            isConfigured: isConfigured,
            onTap: () => controller.selectConsole(system.id),
            autofocus: index == 0,
          );
        },
      ),
    );
  }
}

class _ConsoleTile extends StatefulWidget {
  final SystemModel system;
  final bool isConfigured;
  final VoidCallback onTap;
  final bool autofocus;

  const _ConsoleTile({
    required this.system,
    required this.isConfigured,
    required this.onTap,
    this.autofocus = false,
  });

  @override
  State<_ConsoleTile> createState() => _ConsoleTileState();
}

class _ConsoleTileState extends State<_ConsoleTile> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final nameFontSize = rs.isSmall ? 9.0 : 11.0;
    final iconSize = rs.isSmall ? 28.0 : 36.0;

    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: (focused) {
        setState(() => _focused = focused);
        if (focused) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Scrollable.ensureVisible(context,
                  duration: const Duration(milliseconds: 200));
            }
          });
        }
      },
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
             event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: _focused
                ? widget.system.accentColor.withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(rs.radius.md),
            border: Border.all(
              color: _focused
                  ? widget.system.accentColor.withValues(alpha: 0.8)
                  : widget.isConfigured
                      ? Colors.green.withValues(alpha: 0.4)
                      : Colors.white.withValues(alpha: 0.08),
              width: _focused ? 2 : 1,
            ),
            boxShadow: _focused
                ? [
                    BoxShadow(
                      color: widget.system.accentColor.withValues(alpha: 0.3),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(rs.radius.sm),
                      child: Image.asset(
                        widget.system.iconAssetPath,
                        width: iconSize,
                        height: iconSize,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.videogame_asset,
                          color: widget.system.accentColor,
                          size: iconSize,
                        ),
                      ),
                    ),
                    SizedBox(height: rs.spacing.xs),
                    Text(
                      widget.system.name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _focused ? Colors.white : Colors.white70,
                        fontSize: nameFontSize,
                        fontWeight: _focused ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.isConfigured)
                Positioned(
                  top: rs.spacing.xs,
                  right: rs.spacing.xs,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check,
                      color: Colors.white,
                      size: rs.isSmall ? 10.0 : 12.0,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
