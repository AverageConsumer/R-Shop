import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../models/config/app_config.dart';
import '../models/system_model.dart';
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

  // Build valid ROM extensions per system (includes multiFileExtensions)
  final extsBySystem = <String, Set<String>>{};
  for (final sysConfig in config.systems) {
    final system = SystemModel.supportedSystems
        .where((s) => s.id == sysConfig.id)
        .firstOrNull;
    if (system != null) {
      extsBySystem[sysConfig.id] = {
        ...system.romExtensions.map((e) => e.toLowerCase()),
        if (system.multiFileExtensions != null)
          ...system.multiFileExtensions!.map((e) => e.toLowerCase()),
      };
    }
  }

  for (final sysConfig in config.systems) {
    if (sysConfig.targetFolder.isEmpty) continue;
    final dir = Directory(sysConfig.targetFolder);
    if (!dir.existsSync()) continue;
    final filenames = <String>{};
    final validExts = extsBySystem[sysConfig.id] ?? {};
    try {
      for (final entity in dir.listSync(followLinks: false)) {
        final name = p.basename(entity.path);
        if (entity is Directory) {
          // Only count directories that contain ROM files (one level deep)
          if (_directoryContainsRom(entity, validExts)) {
            filenames.add(name);
          }
        } else {
          filenames.add(name);
        }
      }
    } catch (e) { debugPrint('InstalledFiles: listSync failed: $e'); }
    bySystem[sysConfig.id] = filenames;
    all.addAll(filenames);
  }

  return InstalledFilesState(bySystem: bySystem, all: all);
}

/// Checks if a directory contains at least one file with a valid ROM extension.
bool _directoryContainsRom(Directory dir, Set<String> validExts) {
  if (validExts.isEmpty) return true;
  try {
    for (final entity in dir.listSync(followLinks: false)) {
      if (entity is File &&
          validExts.contains(p.extension(entity.path).toLowerCase())) {
        return true;
      }
    }
  } catch (e) { debugPrint('InstalledFiles: subfolder scan failed: $e'); }
  return false;
}
