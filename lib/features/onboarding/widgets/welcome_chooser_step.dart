import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/console_focusable.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/config/source.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/game_providers.dart';
import '../../../services/romm_api_service.dart';
import '../../../services/romm_pairing_service.dart';
import '../../../services/romm_platform_matcher.dart';
import '../../../models/system_model.dart';
import '../../pairing/qr_pairing_screen.dart';
import '../../sources/manual_source_add_screen.dart';
import '../../sources/source_mappings_screen.dart';
import '../onboarding_controller.dart';
import 'romm_legacy_login_screen.dart';

/// First screen of the onboarding: a single question with four paths.
///
/// "Where do your games come from?" → RomM (QR/code), own server (manual
/// SMB/FTP/Web), local-only, or skip. Each branch produces a coherent
/// configured state without forcing the user through the legacy linear
/// stepper. The controller still owns the legacy steps for users who
/// pick the "Local games only" path; everything else lands directly on
/// the complete step.
class WelcomeChooserStep extends ConsumerStatefulWidget {
  const WelcomeChooserStep({super.key});

  @override
  ConsumerState<WelcomeChooserStep> createState() =>
      _WelcomeChooserStepState();
}

class _WelcomeChooserStepState extends ConsumerState<WelcomeChooserStep> {
  final FocusNode _qrFocus = FocusNode(debugLabel: 'welcome_qr');
  final FocusNode _legacyFocus = FocusNode(debugLabel: 'welcome_legacy');
  final FocusNode _serverFocus = FocusNode(debugLabel: 'welcome_server');
  final FocusNode _localFocus = FocusNode(debugLabel: 'welcome_local');
  final FocusNode _screenFocus =
      FocusNode(debugLabel: 'welcome_chooser_screen');

  bool _busy = false;
  String? _busyMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _qrFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _qrFocus.dispose();
    _legacyFocus.dispose();
    _serverFocus.dispose();
    _localFocus.dispose();
    _screenFocus.dispose();
    super.dispose();
  }

  List<FocusNode> get _navOrder =>
      [_qrFocus, _legacyFocus, _serverFocus, _localFocus];

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      _moveFocus(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _moveFocus(-1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _moveFocus(int delta) {
    final order = _navOrder;
    final cur = order.indexWhere((n) => n.hasFocus);
    final start = cur < 0 ? (delta > 0 ? -1 : order.length) : cur;
    final next = (start + delta).clamp(0, order.length - 1);
    if (next == cur) return;
    final target = order[next];
    if (target.canRequestFocus) {
      target.requestFocus();
      ref.read(feedbackServiceProvider).tick();
    }
  }

  // ---- path handlers ----

  Future<String?> _pickRomBaseFolder() async {
    final l = L.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1C),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Colors.white12),
        ),
        title: Text(l.onboarding_folderExplanationTitle,
            style: const TextStyle(color: Colors.white)),
        content: Text(
          l.onboarding_folderExplanationMessage,
          style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.common_cancel,
                style: const TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: Text(l.onboarding_continueToPicker),
          ),
        ],
      ),
    );

    if (confirmed != true) return null;

    try {
      return await FilePicker.platform.getDirectoryPath(
        dialogTitle: l.onboarding_selectFolderPrompt,
      );
    } catch (e) {
      debugPrint('WelcomeChooser: folder picker failed: $e');
      return null;
    }
  }

  Future<void> _handleQrPair() async {
    if (_busy) return;
    final basePath = await _pickRomBaseFolder();
    if (!mounted || basePath == null) return;

    setState(() {
      _busy = true;
      _busyMessage = L.of(context).onboarding_scanningFolders;
    });
    final controller =
        ref.read(onboardingControllerProvider.notifier);
    await controller.seedLocalSystemsFromBase(basePath);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _busyMessage = null;
    });

    final result = await Navigator.of(context).push<RommPairResult?>(
      MaterialPageRoute(builder: (_) => const QrPairingScreen()),
    );
    if (!mounted || result == null) return;

    setState(() {
      _busy = true;
      _busyMessage = L.of(context).onboarding_discoveringPlatforms;
    });
    final source = buildSourceFromPairResult(result);
    Map<String, int> knownPlatforms = const {};
    try {
      final api = RommApiService();
      final platforms =
          await api.fetchPlatforms(result.serverUrl, auth: source.auth);
      final allSystemIds = SystemModel.supportedSystems.map((s) => s.id);
      knownPlatforms =
          RommPlatformMatcher.buildKnownPlatforms(allSystemIds, platforms);
    } catch (e) {
      debugPrint('WelcomeChooser: platform discovery failed: $e');
    }
    final hydrated = source.copyWith(knownPlatforms: knownPlatforms);

    final notifier = ref.read(sourcesProvider.notifier);
    await controller.completeFromRommPairing(
      sourcesNotifier: notifier,
      source: hydrated,
      basePath: basePath,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _busyMessage = null;
    });
  }

  Future<void> _handleLegacyLogin() async {
    if (_busy) return;
    final basePath = await _pickRomBaseFolder();
    if (!mounted || basePath == null) return;

    setState(() {
      _busy = true;
      _busyMessage = L.of(context).onboarding_scanningFolders;
    });
    final controller =
        ref.read(onboardingControllerProvider.notifier);
    await controller.seedLocalSystemsFromBase(basePath);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _busyMessage = null;
    });

    final source = await Navigator.of(context).push<Source?>(
      MaterialPageRoute(builder: (_) => const RommLegacyLoginScreen()),
    );
    if (!mounted || source == null) return;

    setState(() {
      _busy = true;
      _busyMessage = L.of(context).onboarding_savingSource;
    });
    final notifier = ref.read(sourcesProvider.notifier);
    await controller.completeFromRommPairing(
      sourcesNotifier: notifier,
      source: source,
      basePath: basePath,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _busyMessage = null;
    });
  }

  Future<void> _handleManualServer() async {
    if (_busy) return;
    final basePath = await _pickRomBaseFolder();
    if (!mounted || basePath == null) return;

    setState(() {
      _busy = true;
      _busyMessage = L.of(context).onboarding_scanningFolders;
    });
    final controller =
        ref.read(onboardingControllerProvider.notifier);
    await controller.seedLocalSystemsFromBase(basePath);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _busyMessage = null;
    });

    final type = await _showTypePicker();
    if (type == null || !mounted) return;

    final source = await Navigator.of(context).push<Source?>(
      MaterialPageRoute(builder: (_) => ManualSourceAddScreen(type: type)),
    );
    if (!mounted || source == null) return;

    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => SourceMappingsScreen(source: source)),
    );
    if (!mounted || saved != true) return;

    // Read back the system ids the user mapped against this source.
    final cfg = ref.read(bootstrappedConfigProvider).valueOrNull;
    final mappedSystemIds = <String>[];
    if (cfg != null) {
      for (final s in cfg.systems) {
        for (final m in s.manualMappings) {
          if (m.sourceId == source.id) {
            mappedSystemIds.add(s.id);
            break;
          }
        }
      }
    }

    await controller.completeFromManualSource(
      sourceId: source.id,
      mappedSystemIds: mappedSystemIds,
      basePath: basePath,
    );
  }

  Future<SourceType?> _showTypePicker() async {
    return showDialog<SourceType>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1C1C1C),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Colors.white12),
          ),
          title: Text(L.of(context).onboarding_serverType,
              style: const TextStyle(color: Colors.white)),
          content: _TypePickerBody(
            types: const [SourceType.smb, SourceType.ftp, SourceType.web],
            iconFor: _iconFor,
            onPick: (t) => Navigator.of(ctx).pop(t),
          ),
        );
      },
    );
  }

  IconData _iconFor(SourceType t) {
    switch (t) {
      case SourceType.smb:
        return Icons.folder_shared;
      case SourceType.ftp:
        return Icons.cloud_queue;
      case SourceType.web:
        return Icons.public;
      default:
        return Icons.dns_outlined;
    }
  }

  Future<void> _handleLocalOnly() async {
    if (_busy) return;
    final basePath = await _pickRomBaseFolder();
    if (!mounted || basePath == null) return;

    setState(() {
      _busy = true;
      _busyMessage = L.of(context).onboarding_scanningFolders;
    });
    final controller =
        ref.read(onboardingControllerProvider.notifier);
    await controller.seedLocalSystemsFromBase(basePath);
    if (!mounted) return;
    controller.completeFromLocalOnly(basePath: basePath);
    setState(() {
      _busy = false;
      _busyMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Focus(
      focusNode: _screenFocus,
      onKeyEvent: _onKeyEvent,
      child: SingleChildScrollView(
        child: Column(
          key: const ValueKey('welcome_chooser'),
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
          Text(
            l.onboarding_welcomeTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l.onboarding_welcomeSubtitle,
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          _ChoiceTile(
            focusNode: _qrFocus,
            icon: Icons.qr_code_2,
            title: l.onboarding_pairQrTitle,
            subtitle: l.onboarding_pairQrSubtitle,
            onSelect: _handleQrPair,
          ),
          const SizedBox(height: 12),
          _ChoiceTile(
            focusNode: _legacyFocus,
            icon: Icons.password,
            title: l.onboarding_legacyLoginTitle,
            subtitle: l.onboarding_legacyLoginSubtitle,
            onSelect: _handleLegacyLogin,
          ),
          const SizedBox(height: 12),
          _ChoiceTile(
            focusNode: _serverFocus,
            icon: Icons.dns_outlined,
            title: l.onboarding_addServerTitle,
            subtitle: l.onboarding_addServerSubtitle,
            onSelect: _handleManualServer,
          ),
          const SizedBox(height: 12),
          _ChoiceTile(
            focusNode: _localFocus,
            icon: Icons.sd_card,
            title: l.onboarding_localOnlyTitle,
            subtitle: l.onboarding_localOnlySubtitle,
            onSelect: _handleLocalOnly,
          ),
          if (_busy) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _busyMessage ?? l.onboarding_working,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ],
        ],
        ),
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.focusNode,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onSelect,
  });

  final FocusNode focusNode;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return ConsoleFocusable(
      focusNode: focusNode,
      onSelect: onSelect,
      borderRadius: 12,
      focusScale: 1.0,
      focusBorderColor: AppTheme.primaryColor,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1C),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppTheme.primaryColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white30),
          ],
        ),
      ),
    );
  }
}


class _TypePickerBody extends StatefulWidget {
  const _TypePickerBody({
    required this.types,
    required this.iconFor,
    required this.onPick,
  });

  final List<SourceType> types;
  final IconData Function(SourceType) iconFor;
  final ValueChanged<SourceType> onPick;

  @override
  State<_TypePickerBody> createState() => _TypePickerBodyState();
}

class _TypePickerBodyState extends State<_TypePickerBody> {
  late final List<FocusNode> _nodes;

  @override
  void initState() {
    super.initState();
    _nodes = List.generate(
      widget.types.length,
      (i) => FocusNode(debugLabel: 'type_picker_$i'),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _nodes.isNotEmpty) _nodes.first.requestFocus();
    });
  }

  @override
  void dispose() {
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  void _move(int delta) {
    final cur = _nodes.indexWhere((n) => n.hasFocus);
    final next = (cur < 0 ? 0 : cur + delta).clamp(0, _nodes.length - 1);
    _nodes[next].requestFocus();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      _move(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _move(-1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < widget.types.length; i++)
            ConsoleFocusable(
              focusNode: _nodes[i],
              focusScale: 1.0,
              onSelect: () => widget.onPick(widget.types[i]),
              child: ListTile(
                leading: Icon(widget.iconFor(widget.types[i]),
                    color: AppTheme.primaryColor),
                title: Text(widget.types[i].name.toUpperCase(),
                    style: const TextStyle(color: Colors.white)),
                onTap: () => widget.onPick(widget.types[i]),
              ),
            ),
        ],
      ),
    );
  }
}

