import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/input/input.dart';
import '../../../core/responsive/responsive.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/app_providers.dart';
import 'settings_item.dart';
import 'volume_slider.dart';

class SettingsPreferencesTab extends ConsumerWidget {
  final ControllerLayout controllerLayout;
  final bool isHomeGrid;
  final bool hapticEnabled;
  final bool soundEnabled;
  final bool hideEmptyConsoles;
  final double bgmVolume;
  final double sfxVolume;
  final FocusNode homeLayoutFocusNode;
  final FocusNode layoutFocusNode;
  final FocusNode hapticFocusNode;
  final FocusNode hideEmptyFocusNode;
  final VoidCallback onToggleHomeLayout;
  final VoidCallback onCycleLayout;
  final VoidCallback onToggleHaptic;
  final VoidCallback onToggleSound;
  final VoidCallback onToggleHideEmpty;
  final ValueChanged<double> onAdjustBgmVolume;
  final ValueChanged<double> onAdjustSfxVolume;
  final ValueChanged<double> onSetBgmVolume;
  final ValueChanged<double> onSetSfxVolume;

  const SettingsPreferencesTab({
    super.key,
    required this.controllerLayout,
    required this.isHomeGrid,
    required this.hapticEnabled,
    required this.soundEnabled,
    required this.hideEmptyConsoles,
    required this.bgmVolume,
    required this.sfxVolume,
    required this.homeLayoutFocusNode,
    required this.layoutFocusNode,
    required this.hapticFocusNode,
    required this.hideEmptyFocusNode,
    required this.onToggleHomeLayout,
    required this.onCycleLayout,
    required this.onToggleHaptic,
    required this.onToggleSound,
    required this.onToggleHideEmpty,
    required this.onAdjustBgmVolume,
    required this.onAdjustSfxVolume,
    required this.onSetBgmVolume,
    required this.onSetSfxVolume,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rs = context.rs;

    return FocusTraversalGroup(
      key: const ValueKey(0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: EdgeInsets.symmetric(
              horizontal: rs.spacing.lg,
              vertical: rs.spacing.md,
            ),
            children: [
              _buildSettingsItemWrapper(
                ref: ref,
                onNavigate: (dir) {
                  if (dir == GridDirection.left ||
                      dir == GridDirection.right) {
                    onToggleHomeLayout();
                    return true;
                  }
                  return false;
                },
                child: SettingsItem(
                  focusNode: homeLayoutFocusNode,
                  title: 'Home Screen Layout',
                  subtitle:
                      isHomeGrid ? 'Grid View' : 'Horizontal Carousel',
                  trailing: _buildSwitch(isHomeGrid),
                  onTap: onToggleHomeLayout,
                ),
              ),
              SizedBox(height: rs.spacing.md),
              _buildSettingsItemWrapper(
                ref: ref,
                onNavigate: (dir) {
                  if (dir == GridDirection.left ||
                      dir == GridDirection.right) {
                    onToggleHideEmpty();
                    return true;
                  }
                  return false;
                },
                child: SettingsItem(
                  focusNode: hideEmptyFocusNode,
                  title: 'Hide Empty Consoles',
                  subtitle: 'Hide systems with no games',
                  trailing: _buildSwitch(hideEmptyConsoles),
                  onTap: onToggleHideEmpty,
                ),
              ),
              SizedBox(height: rs.spacing.md),
              _buildSettingsItemWrapper(
                ref: ref,
                onNavigate: (dir) {
                  if (dir == GridDirection.left ||
                      dir == GridDirection.right) {
                    onCycleLayout();
                    return true;
                  }
                  return false;
                },
                child: SettingsItem(
                  focusNode: layoutFocusNode,
                  title: 'Controller Layout',
                  subtitle: switch (controllerLayout) {
                    ControllerLayout.nintendo => 'Nintendo (default)',
                    ControllerLayout.xbox => 'Xbox (A/B & X/Y swapped)',
                    ControllerLayout.playstation =>
                      'PlayStation (\u2715 \u25CB \u25A1 \u25B3)',
                  },
                  trailing: _buildLayoutLabel(controllerLayout),
                  onTap: onCycleLayout,
                ),
              ),
              SizedBox(height: rs.spacing.md),
              _buildSettingsItemWrapper(
                ref: ref,
                onNavigate: (dir) {
                  if (dir == GridDirection.left ||
                      dir == GridDirection.right) {
                    onToggleHaptic();
                    return true;
                  }
                  return false;
                },
                child: SettingsItem(
                  focusNode: hapticFocusNode,
                  title: 'Haptic Feedback',
                  subtitle: 'Vibration on button presses',
                  trailing: _buildSwitch(hapticEnabled),
                  onTap: onToggleHaptic,
                ),
              ),
              SizedBox(height: rs.spacing.md),
              _buildSettingsItemWrapper(
                ref: ref,
                onNavigate: (dir) {
                  if (dir == GridDirection.left ||
                      dir == GridDirection.right) {
                    onToggleSound();
                    return true;
                  }
                  return false;
                },
                child: SettingsItem(
                  title: 'Sound Effects',
                  subtitle: 'Audio feedback for actions',
                  trailing: _buildSwitch(soundEnabled),
                  onTap: onToggleSound,
                ),
              ),
              SizedBox(height: rs.spacing.md),
              _buildSettingsItemWrapper(
                ref: ref,
                onNavigate: (dir) {
                  if (dir == GridDirection.left) {
                    onAdjustBgmVolume(-0.05);
                    ref.read(feedbackServiceProvider).tick();
                    return true;
                  } else if (dir == GridDirection.right) {
                    onAdjustBgmVolume(0.05);
                    ref.read(feedbackServiceProvider).tick();
                    return true;
                  }
                  return false;
                },
                child: SettingsItem(
                  title: 'Background Music',
                  subtitle: 'Ambient background music volume',
                  trailingBuilder: (isFocused) => VolumeSlider(
                    volume: bgmVolume,
                    isSelected: isFocused,
                    onChanged: onSetBgmVolume,
                  ),
                ),
              ),
              SizedBox(height: rs.spacing.md),
              _buildSettingsItemWrapper(
                ref: ref,
                onNavigate: (dir) {
                  if (dir == GridDirection.left) {
                    onAdjustSfxVolume(-0.05);
                    ref.read(feedbackServiceProvider).tick();
                    return true;
                  } else if (dir == GridDirection.right) {
                    onAdjustSfxVolume(0.05);
                    ref.read(feedbackServiceProvider).tick();
                    return true;
                  }
                  return false;
                },
                child: SettingsItem(
                  title: 'SFX Volume',
                  subtitle: 'Interface sound effects volume',
                  trailingBuilder: (isFocused) => VolumeSlider(
                    volume: sfxVolume,
                    isSelected: isFocused,
                    onChanged: onSetSfxVolume,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsItemWrapper({
    required WidgetRef ref,
    required Widget child,
    required bool Function(GridDirection) onNavigate,
  }) {
    return Actions(
      actions: {
        NavigateIntent: NavigateAction(ref, onNavigate: (intent) {
          return onNavigate(intent.direction);
        }),
      },
      child: child,
    );
  }

  Widget _buildSwitch(bool value) {
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

  Widget _buildLayoutLabel(ControllerLayout layout) {
    final label = switch (layout) {
      ControllerLayout.nintendo => 'NIN',
      ControllerLayout.xbox => 'XBOX',
      ControllerLayout.playstation => 'PS',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.4),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.primaryColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
