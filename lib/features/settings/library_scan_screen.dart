import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/input/input.dart';
import '../../core/responsive/responsive.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/screen_layout.dart';
import '../../models/system_model.dart';
import '../../models/config/app_config.dart';
import '../../providers/game_providers.dart';
import '../../providers/library_providers.dart';
import '../../services/library_sync_service.dart';
import '../../widgets/console_hud.dart';
import 'widgets/scan_console_tile.dart';

class LibraryScanScreen extends ConsumerStatefulWidget {
  const LibraryScanScreen({super.key});

  @override
  ConsumerState<LibraryScanScreen> createState() => _LibraryScanScreenState();
}

class _LibraryScanScreenState extends ConsumerState<LibraryScanScreen>
    with ConsoleGridScreenMixin {
  bool _scanStarted = false;
  bool _scanComplete = false;
  int _selectedIndex = 0;
  int _crossAxisCount = 3;
  final Map<int, GlobalKey> _itemKeys = {};

  @override
  String get routeId => 'library_scan';

  @override
  int get currentSelectedIndex => _selectedIndex;

  @override
  set currentSelectedIndex(int value) => _selectedIndex = value;

  @override
  Map<Type, Action<Intent>> get screenActions => {
        BackIntent: CallbackAction<BackIntent>(onInvoke: (_) {
          _onBack();
          return null;
        }),
      };

  @override
  void onNavigate(GridDirection direction) {
    final itemCount = _itemKeys.length;
    if (itemCount == 0) return;

    final row = _selectedIndex ~/ _crossAxisCount;
    final col = _selectedIndex % _crossAxisCount;
    final lastRow = (itemCount - 1) ~/ _crossAxisCount;

    int newIndex = _selectedIndex;

    switch (direction) {
      case GridDirection.up:
        if (row > 0) newIndex = (row - 1) * _crossAxisCount + col;
      case GridDirection.down:
        if (row < lastRow) {
          newIndex = math.min((row + 1) * _crossAxisCount + col, itemCount - 1);
        }
      case GridDirection.left:
        if (col > 0) newIndex = row * _crossAxisCount + (col - 1);
      case GridDirection.right:
        final rowEnd = math.min((row + 1) * _crossAxisCount - 1, itemCount - 1);
        if (_selectedIndex < rowEnd) newIndex = _selectedIndex + 1;
    }

    if (newIndex != _selectedIndex) {
      setState(() => _selectedIndex = newIndex);
      _scrollToSelected();
    }
  }

  @override
  void onConfirm() {
    if (_scanComplete) _onBack();
  }

  void _scrollToSelected() {
    final key = _itemKeys[_selectedIndex];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        alignment: 0.5,
        duration: const Duration(milliseconds: 200),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startScan();
    });
  }

  Future<void> _startScan() async {
    if (_scanStarted) return;
    setState(() => _scanStarted = true);

    final config = ref.read(bootstrappedConfigProvider).value ?? AppConfig.empty;
    await ref.read(librarySyncServiceProvider.notifier).discoverAll(config);

    if (mounted) {
      setState(() => _scanComplete = true);
    }
  }

  void _onBack() {
    if (!_scanComplete) {
      ref.read(librarySyncServiceProvider.notifier).cancel();
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final syncState = ref.watch(librarySyncServiceProvider);
    final config = ref.watch(bootstrappedConfigProvider).value ?? AppConfig.empty;
    final configuredIds = config.systems.map((s) => s.id).toSet();

    // Only show systems that are configured
    final systems = SystemModel.supportedSystems
        .where((s) => configuredIds.contains(s.id))
        .toList();

    _crossAxisCount = rs.isSmall
        ? (rs.isPortrait ? 3 : 5)
        : (rs.isPortrait ? 4 : 6);

    // Rebuild item keys when count changes
    if (_itemKeys.length != systems.length) {
      _itemKeys.clear();
      for (var i = 0; i < systems.length; i++) {
        _itemKeys[i] = GlobalKey();
      }
    }

    // Clamp selection to valid range
    if (systems.isNotEmpty && _selectedIndex >= systems.length) {
      _selectedIndex = systems.length - 1;
    }

    return buildWithGridActions(
      PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _onBack();
        },
        child: ScreenLayout(
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
                  SizedBox(height: rs.safeAreaTop + rs.spacing.lg),
                  _buildHeader(rs, syncState, systems.length),
                  SizedBox(height: rs.spacing.lg),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: rs.spacing.lg),
                      child: GridView.builder(
                        padding: EdgeInsets.only(bottom: rs.spacing.xl * 2),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: _crossAxisCount,
                          childAspectRatio: 0.85,
                          crossAxisSpacing: rs.spacing.md,
                          mainAxisSpacing: rs.spacing.md,
                        ),
                        itemCount: systems.length,
                        itemBuilder: (context, index) {
                          final system = systems[index];
                          return ScanConsoleTile(
                            key: _itemKeys[index],
                            system: system,
                            scanState: _getTileState(system.id, syncState, config),
                            gameCount: syncState.gamesPerSystem[system.id] ?? 0,
                            isFocused: index == _selectedIndex,
                          );
                        },
                      ),
                    ),
                  ),
                  ConsoleHud(
                    dpad: (label: '✦', action: 'Navigate'),
                    b: HudAction('Back', onTap: _onBack),
                    a: _scanComplete
                        ? HudAction('Done', onTap: _onBack)
                        : null,
                    embedded: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  ScanTileState _getTileState(
    String systemId,
    LibrarySyncState syncState,
    dynamic config,
  ) {
    if (syncState.gamesPerSystem.containsKey(systemId)) {
      return ScanTileState.complete;
    }

    if (syncState.isSyncing) {
      // Find if this system is the current one being scanned
      final systemModel = SystemModel.supportedSystems
          .where((s) => s.id == systemId)
          .firstOrNull;
      if (systemModel != null && syncState.currentSystem == systemModel.name) {
        return ScanTileState.scanning;
      }
    }

    return ScanTileState.pending;
  }

  Widget _buildHeader(Responsive rs, LibrarySyncState syncState, int totalSystems) {
    final String title;
    final String subtitle;

    if (!_scanStarted || (syncState.isSyncing && syncState.completedSystems == 0)) {
      title = 'SCAN LIBRARY';
      subtitle = 'Preparing scan...';
    } else if (syncState.isSyncing) {
      title = 'SCANNING...';
      subtitle = 'System ${syncState.completedSystems} of $totalSystems'
          '${syncState.currentSystem != null ? ' \u2022 ${syncState.currentSystem}' : ''}';
    } else if (_scanComplete) {
      final systemsWithGames = syncState.gamesPerSystem.values
          .where((c) => c > 0)
          .length;
      title = 'SCAN COMPLETE';
      subtitle = 'Discovered ${syncState.totalGamesFound} games '
          'across $systemsWithGames consoles';
    } else {
      title = 'SCAN LIBRARY';
      subtitle = 'Discover all games across all consoles';
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: rs.spacing.lg),
      child: Column(
        children: [
          Icon(
            _scanComplete ? Icons.check_circle_outline : Icons.radar_rounded,
            size: 40,
            color: _scanComplete
                ? Colors.greenAccent
                : AppTheme.primaryColor.withValues(alpha: 0.5),
          ),
          SizedBox(height: rs.spacing.sm),
          Text(
            title,
            style: AppTheme.headlineLarge.copyWith(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
              color: _scanComplete ? Colors.greenAccent : Colors.white,
            ),
          ),
          SizedBox(height: rs.spacing.xs),
          Text(
            subtitle,
            style: AppTheme.bodySmall.copyWith(
              color: Colors.white54,
              fontSize: 14,
            ),
          ),
          if (syncState.isSyncing) ...[
            SizedBox(height: rs.spacing.md),
            SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                value: totalSystems > 0
                    ? syncState.completedSystems / totalSystems
                    : 0,
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                valueColor: const AlwaysStoppedAnimation<Color>(
                    AppTheme.primaryColor),
                minHeight: 3,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
