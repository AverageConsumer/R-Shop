import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/input/input.dart';
import '../../core/responsive/responsive.dart';
import '../../l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/util/color_contrast.dart';
import '../../core/widgets/console_focusable.dart';
import '../../core/widgets/screen_layout.dart';
import '../../models/config/system_config.dart';
import '../../models/system_model.dart';
import '../../providers/app_providers.dart';
import '../../utils/friendly_error.dart';
import '../../providers/game_providers.dart';
import '../../providers/library_providers.dart';
import '../../widgets/console_hud.dart';
import '../../widgets/console_notification.dart';
import '../onboarding/onboarding_controller.dart';
import 'widgets/system_detail_view.dart';

class ConfigModeScreen extends ConsumerStatefulWidget {
  const ConfigModeScreen({super.key});
  @override
  ConsumerState<ConfigModeScreen> createState() => _ConfigModeScreenState();
}

class _ConfigModeScreenState extends ConsumerState<ConfigModeScreen>
    with ConsoleScreenMixin {
  bool _initialized = false;
  final FocusNode _firstListNode = FocusNode();
  final FocusNode _firstDetailNode = FocusNode();

  @override
  String get routeId => 'config_mode';

  @override
  Map<Type, Action<Intent>> get screenActions => {
        BackIntent: CallbackAction<BackIntent>(onInvoke: (_) {
          _handleBack();
          return null;
        }),
      };

  @override
  void dispose() {
    _firstListNode.dispose();
    _firstDetailNode.dispose();
    super.dispose();
  }

  void _initFromConfig() {
    if (_initialized) return;
    _initialized = true;
    final configAsync = ref.read(bootstrappedConfigProvider);
    if (configAsync case AsyncData(value: final config)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(onboardingControllerProvider.notifier)
              .loadFromConfig(config);
          // Focus the first system card after config is loaded and the
          // list has been built.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _firstListNode.canRequestFocus) {
              _firstListNode.requestFocus();
            }
          });
        }
      });
    }
  }

  void _handleBack() {
    final state = ref.read(onboardingControllerProvider);
    if (state.hasConsoleSelected) {
      ref.read(onboardingControllerProvider.notifier).deselectConsole();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _firstListNode.requestFocus();
      });
    } else {
      _saveAndGoBack();
    }
  }

  Future<void> _saveAndGoBack() async {
    final controller = ref.read(onboardingControllerProvider.notifier);
    final config = await controller.buildFinalConfig();
    final jsonString =
        const JsonEncoder.withIndent('  ').convert(config.toJson());
    await ref.read(configStorageServiceProvider).saveConfig(jsonString);
    ref.invalidate(bootstrappedConfigProvider);
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _exportConfig() async {
    try {
      final controller = ref.read(onboardingControllerProvider.notifier);
      await controller.exportConfig();
    } catch (e) {
      if (!mounted) return;
      showErrorNotification(context, ref,
          message: 'Export failed: ${getUserFriendlyError(e)}');
    }
  }

  Future<void> _importConfig() async {
    final result = await importConfigFile(ref);
    if (!mounted) return;
    if (result.cancelled) return;
    if (result.error != null) {
      showErrorNotification(context, ref,
          message: 'Invalid config: ${result.error}');
    } else {
      ref
          .read(onboardingControllerProvider.notifier)
          .loadFromConfig(result.config!);
      ref.read(sourcesProvider.notifier).replaceAll(result.config!.sources);
      ref.invalidate(gamesProvider);
      ref.read(gameDbChangedProvider.notifier).state++;
      final count = result.config!.systems
          .expand((s) => s.providers)
          .where((p) => p.needsAuth)
          .length;
      showSuccessNotification(
        context,
        ref,
        message: count > 0
            ? 'Config imported — $count provider${count > 1 ? 's' : ''} need credentials'
            : L.of(context).settings_configImported,
      );
    }
  }

  void _selectSystem(String id) {
    ref.read(onboardingControllerProvider.notifier).selectConsole(id);
    ref.read(feedbackServiceProvider).tick();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _firstDetailNode.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final state = ref.watch(onboardingControllerProvider);
    final rs = context.rs;

    if (ref.watch(bootstrappedConfigProvider) case AsyncData()) {
      _initFromConfig();
    }

    final topPadding = rs.safeAreaTop + (rs.isSmall ? 56 : 72);

    return buildWithActions(
      ScreenLayout(
        backgroundColor: Colors.black,
        accentColor: AppTheme.primaryColor,
        body: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1A1A1A), Colors.black],
                  ),
                ),
              ),
            ),
            Column(
              children: [
                SizedBox(height: topPadding),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: state.hasConsoleSelected
                        ? SystemDetailView(
                            key: ValueKey(
                                'detail_${state.selectedConsoleId}'),
                            firstFocusNode: _firstDetailNode,
                          )
                        : _SystemList(
                            key: const ValueKey('system_list'),
                            systems: state.configuredSystems,
                            firstFocusNode: _firstListNode,
                            onSelect: _selectSystem,
                          ),
                  ),
                ),
              ],
            ),
            _buildHeader(rs, state, l),
            ConsoleHud(
              b: HudAction(l.common_back, onTap: _handleBack),
              start: state.hasConsoleSelected
                  ? null
                  : HudAction(l.configMode_export, onTap: _exportConfig),
              select: state.hasConsoleSelected
                  ? null
                  : HudAction(l.configMode_import, onTap: _importConfig),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Responsive rs, OnboardingState state, L l) {
    final system = state.selectedSystem;
    final title = system != null
        ? system.name.toUpperCase()
        : l.configMode_title;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black,
              Color.fromRGBO(0, 0, 0, 0.9),
              Color.fromRGBO(0, 0, 0, 0.6),
              Colors.transparent,
            ],
            stops: [0.0, 0.5, 0.8, 1.0],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: rs.isSmall ? 16.0 : 24.0,
              vertical: rs.isSmall ? 8.0 : 12.0,
            ),
            child: Text(
              title,
              style: TextStyle(
                fontSize: rs.isSmall ? 18 : 22,
                fontWeight: FontWeight.w900,
                color: system != null
                    ? system.accentColor.forText
                    : Colors.white,
                letterSpacing: 4,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SystemList extends ConsumerWidget {
  final Map<String, SystemConfig> systems;
  final FocusNode firstFocusNode;
  final ValueChanged<String> onSelect;

  const _SystemList({
    super.key,
    required this.systems,
    required this.firstFocusNode,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final rs = context.rs;
    const allSystems = SystemModel.supportedSystems;
    // Show configured systems first, then unconfigured ones.
    final configured = allSystems
        .where((s) => systems.containsKey(s.id))
        .toList();
    final unconfigured = allSystems
        .where((s) => !systems.containsKey(s.id))
        .toList();
    final sorted = [...configured, ...unconfigured];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: FocusTraversalGroup(
          child: ListView.separated(
            padding: EdgeInsets.symmetric(
              horizontal: rs.spacing.lg,
              vertical: rs.spacing.md,
            ),
            itemCount: sorted.length,
            separatorBuilder: (_, __) => SizedBox(height: rs.spacing.sm),
            itemBuilder: (context, index) {
              final system = sorted[index];
              final config = systems[system.id];
              final isConfigured = config != null;
              final accent = system.accentColor;

              return ConsoleFocusable(
                focusNode: index == 0 ? firstFocusNode : null,
                onSelect: () => onSelect(system.id),
                borderRadius: 12,
                focusScale: 1.0,
                focusBorderColor: accent,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1C),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isConfigured
                          ? accent.withValues(alpha: 0.3)
                          : Colors.white12,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isConfigured
                              ? Icons.sports_esports
                              : Icons.sports_esports_outlined,
                          color: accent.forIcon,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              system.name,
                              style: TextStyle(
                                color: isConfigured
                                    ? Colors.white
                                    : Colors.white54,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isConfigured
                                  ? config.targetFolder.isEmpty ? l.configMode_noFolderSet : config.targetFolder
                                  : l.configMode_notConfigured,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isConfigured)
                        Icon(Icons.check_circle,
                            color: accent.forIcon,
                            size: 18),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right,
                          color: Colors.white30),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
