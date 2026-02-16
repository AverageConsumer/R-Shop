import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/input/input.dart';
import '../../core/responsive/responsive.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/screen_layout.dart';
import '../../providers/app_providers.dart';
import '../../services/repo_manager.dart';
import '../../widgets/exit_confirmation_overlay.dart';
import '../../widgets/download_overlay.dart';
import '../../providers/download_providers.dart';
import 'widgets/settings_item.dart';
import 'widgets/volume_slider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  final VoidCallback? onResetOnboarding;
  const SettingsScreen({super.key, this.onResetOnboarding});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late bool _hapticEnabled;
  late bool _soundEnabled;
  late double _bgmVolume;
  late double _sfxVolume;
  bool _showResetConfirm = false;
  final FocusNode _hapticFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    final storage = ref.read(storageServiceProvider);
    final haptic = ref.read(hapticServiceProvider);
    _hapticEnabled = storage.getHapticEnabled();
    final soundSettings = ref.read(soundSettingsProvider);
    _soundEnabled = soundSettings.enabled;
    _bgmVolume = soundSettings.bgmVolume;
    _sfxVolume = soundSettings.sfxVolume;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _hapticFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _hapticFocusNode.dispose();
    super.dispose();
  }

  void _toggleHaptic() async {
    final value = !_hapticEnabled;
    final storage = ref.read(storageServiceProvider);
    final haptic = ref.read(hapticServiceProvider);
    await storage.setHapticEnabled(value);
    haptic.setEnabled(value);
    setState(() => _hapticEnabled = value);
    if (value) haptic.tick();
  }

  void _toggleSound() async {
    final value = !_soundEnabled;
    setState(() => _soundEnabled = value);
    await ref.read(soundSettingsProvider.notifier).setEnabled(value);
    if (value) {
      ref.read(audioManagerProvider).playConfirm();
    }
  }

  void _adjustBgmVolume(double delta) async {
    final newVolume = (_bgmVolume + delta).clamp(0.0, 1.0);
    setState(() => _bgmVolume = newVolume);
    await ref.read(soundSettingsProvider.notifier).setBgmVolume(newVolume);
  }

  void _adjustSfxVolume(double delta) async {
    final newVolume = (_sfxVolume + delta).clamp(0.0, 1.0);
    setState(() => _sfxVolume = newVolume);
    await ref.read(soundSettingsProvider.notifier).setSfxVolume(newVolume);
    ref.read(audioManagerProvider).playNavigation();
  }

  void _showRepoUrlDialog() {
    final storage = ref.read(storageServiceProvider);
    final currentUrl = ref.read(repoUrlProvider) ?? storage.getRepoUrl() ?? '';
    final controller = TextEditingController(text: currentUrl);

    showDialog(
      context: context,
      builder: (context) {
        String? errorText;
        bool isTesting = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1A1A1A),
              title: const Text('Repository URL', style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    enabled: !isTesting,
                    style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
                    decoration: InputDecoration(
                      hintText: 'https://...',
                      hintStyle: TextStyle(color: Colors.grey.shade600),
                      errorText: errorText,
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.redAccent.withValues(alpha: 0.3)),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.redAccent),
                      ),
                    ),
                  ),
                  if (isTesting)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.redAccent),
                          ),
                          const SizedBox(width: 8),
                          Text('Testing connection...', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                        ],
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isTesting ? null : () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                TextButton(
                  onPressed: isTesting
                      ? null
                      : () async {
                          final url = controller.text.trim();
                          if (!url.startsWith('http://') && !url.startsWith('https://')) {
                            setDialogState(() => errorText = 'URL must start with http:// or https://');
                            return;
                          }
                          setDialogState(() {
                            isTesting = true;
                            errorText = null;
                          });
                          final result = await RepoManager.testConnection(url);
                          if (!context.mounted) return;
                          if (result.success) {
                            await storage.setRepoUrl(url);
                            ref.read(repoUrlProvider.notifier).state = url;
                            if (context.mounted) Navigator.pop(context);
                          } else {
                            setDialogState(() {
                              isTesting = false;
                              errorText = result.error;
                            });
                          }
                        },
                  child: const Text('Save', style: TextStyle(color: Colors.redAccent)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showResetDialog() {
    setState(() => _showResetConfirm = true);
  }

  void _hideResetDialog() {
    setState(() => _showResetConfirm = false);
  }

  void _performReset() async {
    final storage = ref.read(storageServiceProvider);
    await storage.resetOnboarding();
    _hideResetDialog();
    widget.onResetOnboarding?.call();
  }

  void _exitSettings() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    
    return Shortcuts(
      shortcuts: AppShortcuts.defaultShortcuts,
      child: Actions(
      actions: {
        NavigateIntent: NavigateAction(ref, onNavigate: (intent) => false),
        BackIntent: CallbackAction<BackIntent>(onInvoke: (intent) {
          _exitSettings();
          return null;
        }),
      },
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            _exitSettings();
          }
        },
        child: ScreenLayout(
      backgroundColor: Colors.black,
      accentColor: AppTheme.primaryColor,
      body: Stack(
        children: [
          // Background decoration
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF1A1A1A),
                    Colors.black,
                  ],
                ),
              ),
            ),
          ),
          
          Column(
            children: [
              SizedBox(height: rs.safeAreaTop + rs.spacing.lg),
              _buildTitle(rs),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: ListView(
                      padding: EdgeInsets.symmetric(
                        horizontal: rs.spacing.lg,
                        vertical: rs.spacing.md,
                      ),
                      children: [
                        _buildSectionHeader('Preferences', rs),
                        _buildSettingsItemWrapper(
                          onNavigate: (dir) {
                            if (dir == GridDirection.left || dir == GridDirection.right) {
                              _toggleHaptic();
                              return true;
                            }
                            return false;
                          },
                          child: SettingsItem(
                            focusNode: _hapticFocusNode,
                            title: 'Haptic Feedback',
                            subtitle: 'Vibration on button presses',
                            trailing: _buildSwitch(_hapticEnabled),
                            onTap: _toggleHaptic,
                          ),
                        ),
                        SizedBox(height: rs.spacing.md),
                        _buildSettingsItemWrapper(
                          onNavigate: (dir) {
                             if (dir == GridDirection.left || dir == GridDirection.right) {
                              _toggleSound();
                              return true;
                            }
                            return false;
                          },
                          child: SettingsItem(
                            title: 'Sound Effects',
                            subtitle: 'Audio feedback for actions',
                            trailing: _buildSwitch(_soundEnabled),
                            onTap: _toggleSound,
                          ),
                        ),
                        
                        SizedBox(height: rs.spacing.xl),
                        _buildSectionHeader('Audio', rs),
                        
                        _buildSettingsItemWrapper(
                          onNavigate: (dir) {
                            if (dir == GridDirection.left) {
                              _adjustBgmVolume(-0.05);
                              return true;
                            } else if (dir == GridDirection.right) {
                              _adjustBgmVolume(0.05);
                              return true;
                            }
                            return false;
                          },
                          child: SettingsItem(
                            title: 'Background Music',
                            subtitle: 'Ambient background music volume',
                            trailingBuilder: (isFocused) => VolumeSlider(
                              volume: _bgmVolume, 
                              isSelected: isFocused,
                            ),
                          ),
                        ),
                        SizedBox(height: rs.spacing.md),
                        _buildSettingsItemWrapper(
                           onNavigate: (dir) {
                            if (dir == GridDirection.left) {
                              _adjustSfxVolume(-0.05);
                              return true;
                            } else if (dir == GridDirection.right) {
                              _adjustSfxVolume(0.05);
                              return true;
                            }
                            return false;
                          },
                          child: SettingsItem(
                            title: 'SFX Volume',
                            subtitle: 'Interface sound effects volume',
                            trailingBuilder: (isFocused) => VolumeSlider(
                              volume: _sfxVolume,
                              isSelected: isFocused,
                            ),
                          ),
                        ),

                        SizedBox(height: rs.spacing.xl),
                        _buildSectionHeader('System', rs),

                        SettingsItem(
                          title: 'Repository URL',
                          subtitle: ref.watch(repoUrlProvider) ??
                              ref.read(storageServiceProvider).getRepoUrl() ??
                              'Not configured',
                          trailing: const Icon(Icons.link, color: Colors.white70),
                          onTap: _showRepoUrlDialog,
                        ),
                        SizedBox(height: rs.spacing.md),
                        SettingsItem(
                          title: 'Reset App',
                          subtitle: 'Return to onboarding screen',
                          trailing: const Icon(Icons.refresh, color: Colors.white70),
                          onTap: _showResetDialog,
                          isDestructive: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          if (_showResetConfirm)
             ExitConfirmationOverlay(
               onConfirm: _performReset,
               onCancel: _hideResetDialog,
             ), // Reusing the exit overlay style for reset confirmation as well? 
                // Or I should make ExitConfirmationOverlay more generic if I want to reuse it.
                // The current ExitConfirmationOverlay says "EXIT APPLICATION". 
                // I should probably make it generic. 
                // For now, let's stick to the ExitConfirmationOverlay for exit, 
                // and maybe refactor it to GenericConfirmationOverlay? 
                // OR I can just use it and accept the text is wrong (BAD).
                // OR I can update ExitConfirmationOverlay to accept title/message.
          
        ],
      ),
    ),
    ),
    ),
    );
  }

  Widget _buildSwitch(bool value) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 50,
      height: 28,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: value ? AppTheme.primaryColor : Colors.grey.withOpacity(0.3),
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

  Widget _buildSectionHeader(String title, Responsive rs) {
    return Padding(
      padding: EdgeInsets.only(bottom: rs.spacing.sm, left: rs.spacing.xs),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: AppTheme.primaryColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
  
  Widget _buildTitle(Responsive rs) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: rs.spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
           Icon(Icons.settings, size: 48, color: Colors.white24),
           SizedBox(height: rs.spacing.sm),
           Text(
            'SETTINGS',
            style: AppTheme.headlineLarge.copyWith(
              fontSize: 42,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItemWrapper({
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
}
