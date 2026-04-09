import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/console_focusable.dart';
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
  final FocusNode _serverFocus = FocusNode(debugLabel: 'welcome_server');
  final FocusNode _localFocus = FocusNode(debugLabel: 'welcome_local');
  final FocusNode _skipFocus = FocusNode(debugLabel: 'welcome_skip');
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
    _serverFocus.dispose();
    _localFocus.dispose();
    _skipFocus.dispose();
    _screenFocus.dispose();
    super.dispose();
  }

  List<FocusNode> get _navOrder =>
      [_qrFocus, _serverFocus, _localFocus, _skipFocus];

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
    try {
      return await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Pick the folder where ROMs should be saved',
      );
    } catch (e) {
      debugPrint('WelcomeChooser: folder picker failed: $e');
      return null;
    }
  }

  Future<void> _handleQrPair() async {
    if (_busy) return;
    final result = await Navigator.of(context).push<RommPairResult?>(
      MaterialPageRoute(builder: (_) => const QrPairingScreen()),
    );
    if (!mounted || result == null) return;

    final basePath = await _pickRomBaseFolder();
    if (!mounted || basePath == null) return;

    setState(() {
      _busy = true;
      _busyMessage = 'Discovering platforms…';
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

    final controller =
        ref.read(onboardingControllerProvider.notifier);
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

  Future<void> _handleManualServer() async {
    if (_busy) return;
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

    final basePath = await _pickRomBaseFolder();
    if (!mounted || basePath == null) return;

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

    final controller =
        ref.read(onboardingControllerProvider.notifier);
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
          title: const Text('Server type',
              style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final t in const [
                SourceType.smb,
                SourceType.ftp,
                SourceType.web,
              ])
                ListTile(
                  leading: Icon(_iconFor(t), color: AppTheme.primaryColor),
                  title: Text(t.name.toUpperCase(),
                      style: const TextStyle(color: Colors.white)),
                  onTap: () => Navigator.of(ctx).pop(t),
                ),
            ],
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

  void _handleLocalOnly() {
    if (_busy) return;
    ref.read(onboardingControllerProvider.notifier).startLocalOnlyFromWelcome();
  }

  void _handleSkip() {
    if (_busy) return;
    ref.read(onboardingControllerProvider.notifier).skipFromWelcome();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _screenFocus,
      onKeyEvent: _onKeyEvent,
      child: SingleChildScrollView(
        child: Column(
          key: const ValueKey('welcome_chooser'),
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
          const Text(
            'Welcome to R-Shop',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Where do your games come from?',
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          _ChoiceTile(
            focusNode: _qrFocus,
            icon: Icons.qr_code_2,
            title: 'Pair RomM via QR',
            subtitle: 'Scan a code from your RomM server',
            onSelect: _handleQrPair,
          ),
          const SizedBox(height: 12),
          _ChoiceTile(
            focusNode: _serverFocus,
            icon: Icons.dns_outlined,
            title: 'Add my own server',
            subtitle: 'SMB, FTP or Web mirror — map systems manually',
            onSelect: _handleManualServer,
          ),
          const SizedBox(height: 12),
          _ChoiceTile(
            focusNode: _localFocus,
            icon: Icons.sd_card,
            title: 'Local games only',
            subtitle: 'ROMs already on this device',
            onSelect: _handleLocalOnly,
          ),
          const SizedBox(height: 12),
          _ChoiceTile(
            focusNode: _skipFocus,
            icon: Icons.skip_next_outlined,
            title: 'Skip for now',
            subtitle: 'Set everything up later from Settings',
            onSelect: _handleSkip,
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
                  _busyMessage ?? 'Working…',
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
