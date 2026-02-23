import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/config/app_config.dart';
import '../models/download_item.dart';
import 'download_providers.dart';
import 'game_providers.dart';

/// Monotonic counter that bumps whenever ROM installation state may have
/// changed (download completed, ROM deleted, filesystem change detected).
/// Screens `ref.listenManual` on this to refresh their installed-status caches.
final romChangeSignalProvider = StateProvider<int>((ref) => 0);

/// Kept alive by `ref.watch` in the app root.  Listens for download
/// completions and filesystem changes, then bumps [romChangeSignalProvider].
final romWatcherProvider = Provider<void>((ref) {
  Timer? downloadDebounce;
  Timer? fsDebounce;
  final fsSubscriptions = <StreamSubscription<FileSystemEvent>>[];

  void bump() {
    ref.read(romChangeSignalProvider.notifier).state++;
  }

  // --- Download completion watcher ---
  final seenCompleted = <String>{};

  // Seed with already-completed items to avoid false triggers on init
  final initialQueue = ref.read(downloadQueueManagerProvider).state.queue;
  for (final item in initialQueue) {
    if (item.status == DownloadItemStatus.completed) {
      seenCompleted.add(item.id);
    }
  }

  ref.listen(downloadQueueManagerProvider, (_, next) {
    final currentIds = <String>{};
    bool foundNew = false;

    for (final item in next.state.queue) {
      currentIds.add(item.id);
      if (item.status == DownloadItemStatus.completed &&
          seenCompleted.add(item.id)) {
        foundNew = true;
      }
    }

    seenCompleted.retainAll(currentIds);

    if (foundNew) {
      // Leading edge: bump immediately if no pending debounce (first in burst)
      if (downloadDebounce?.isActive != true) {
        bump();
      }
      // Trailing edge: always schedule a final sweep after the burst settles
      downloadDebounce?.cancel();
      downloadDebounce = Timer(const Duration(milliseconds: 500), bump);
    }
  });

  // --- Filesystem watcher ---
  void tearDownFsWatchers() {
    for (final sub in fsSubscriptions) {
      sub.cancel();
    }
    fsSubscriptions.clear();
  }

  void setupFsWatchers(AppConfig config) {
    tearDownFsWatchers();
    for (final sysConfig in config.systems) {
      final path = sysConfig.targetFolder;
      if (path.isEmpty) continue;
      final dir = Directory(path);
      bool dirExists;
      try {
        dirExists = dir.existsSync();
      } on FileSystemException {
        continue;
      }
      if (!dirExists) continue;
      try {
        final sub = dir.watch().listen((_) {
          fsDebounce?.cancel();
          fsDebounce = Timer(const Duration(seconds: 1), bump);
        });
        fsSubscriptions.add(sub);
      } catch (e) {
        debugPrint('romWatcher: cannot watch $path: $e');
      }
    }
  }

  ref.listen<AsyncValue<AppConfig>>(
    bootstrappedConfigProvider,
    (_, next) {
      final config = next.value;
      if (config != null) {
        setupFsWatchers(config);
      }
    },
    fireImmediately: true,
  );

  ref.onDispose(() {
    downloadDebounce?.cancel();
    fsDebounce?.cancel();
    tearDownFsWatchers();
  });
});
