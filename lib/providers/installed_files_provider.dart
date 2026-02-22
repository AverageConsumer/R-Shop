import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../models/config/app_config.dart';
import 'game_providers.dart';
import 'rom_status_providers.dart';

class InstalledFilesState {
  /// systemId → Set of basenames found in that system's target folder.
  final Map<String, Set<String>> bySystem;

  /// Flat union of all filenames across every system.
  final Set<String> all;

  const InstalledFilesState({
    this.bySystem = const {},
    this.all = const {},
  });
}

/// Central index of all installed ROM files, scanned on an isolate.
/// Re-scans whenever [romChangeSignalProvider] bumps.
final installedFilesProvider = FutureProvider<InstalledFilesState>((ref) async {
  ref.watch(romChangeSignalProvider);
  final config = await ref.watch(bootstrappedConfigProvider.future);
  return compute(_scanAllSystems, config);
});

InstalledFilesState _scanAllSystems(AppConfig config) {
  final bySystem = <String, Set<String>>{};
  final all = <String>{};

  for (final sysConfig in config.systems) {
    if (sysConfig.targetFolder.isEmpty) continue;
    final dir = Directory(sysConfig.targetFolder);
    if (!dir.existsSync()) continue;
    final filenames = <String>{};
    try {
      for (final entity in dir.listSync(followLinks: false)) {
        filenames.add(p.basename(entity.path));
      }
    } catch (_) {}
    bySystem[sysConfig.id] = filenames;
    all.addAll(filenames);
  }

  return InstalledFilesState(bySystem: bySystem, all: all);
}
