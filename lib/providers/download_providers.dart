import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/download_item.dart';
import '../models/ra_models.dart';
import '../services/database_service.dart';
import '../services/download_queue_manager.dart';
import '../services/ra_api_service.dart';
import '../services/ra_hash_service.dart';
import '../services/rom_manager.dart';
import 'app_providers.dart';
import 'ra_providers.dart';

final downloadQueueManagerProvider =
    ChangeNotifierProvider<DownloadQueueManager>((ref) {
  final qm = DownloadQueueManager(
    ref.read(storageServiceProvider),
    ref.read(nativeSmbServiceProvider),
  );

  // Wire up post-download RA hash verification
  final storage = ref.read(storageServiceProvider);
  if (storage.isRaConfigured) {
    final raService = ref.read(raApiServiceProvider);
    final apiKey = storage.getRaApiKey();
    qm.onItemCompleted = (item) {
      _verifyRaHash(item, raService, apiKey, ref);
    };
  }

  return qm;
});

/// Performs RA hash verification after a successful download.
Future<void> _verifyRaHash(
  DownloadItem item,
  RetroAchievementsService raService,
  String? apiKey,
  Ref ref,
) async {
  if (apiKey == null || apiKey.isEmpty) return;
  if (!item.system.hasRetroAchievements) return;

  final hashMethod = RaHashService.getHashMethod(item.system.id);
  if (hashMethod == null) {
    debugPrint('RetroAchievements: hash not supported for ${item.system.id}');
    return;
  }

  try {
    final filePath = await RomManager.resolveInstalledPath(
        item.game, item.system, item.targetFolder);
    if (filePath == null) {
      debugPrint('RetroAchievements: installed ROM not found for ${item.game.filename}');
      return;
    }
    final hash = await RaHashService.computeHash(filePath, item.system.id);
    if (hash == null) {
      debugPrint('RetroAchievements: hash computation failed for ${item.game.filename}');
      return;
    }

    debugPrint('RetroAchievements: hash for ${item.game.filename}: $hash');

    // Look up locally first
    final db = DatabaseService();
    int? raGameId = await db.lookupRaGameByHash(hash);

    // If not found locally, try API
    raGameId ??= await raService.lookupGameByHash(hash, apiKey: apiKey);

    // Determine match result
    final RaMatchResult match;
    if (raGameId != null && raGameId > 0) {
      final game = await db.getRaGame(raGameId);
      if (game != null) {
        match = RaMatchResult.hashVerified(game);
      } else {
        match = RaMatchResult(
          type: RaMatchType.hashVerified,
          raGameId: raGameId,
        );
      }
      debugPrint('RetroAchievements: ROM verified for ${item.game.filename} '
          '(raGameId=$raGameId)');
    } else {
      // Preserve existing name match — ROM might be a regional variant
      final existingMatches = await db.getRaMatchesForSystem(item.system.id);
      final existing = existingMatches[item.game.filename];
      if (existing != null && existing.type == RaMatchType.nameMatch) {
        debugPrint('RetroAchievements: hash not found, keeping name match '
            'for ${item.game.filename}');
        return;
      }
      match = const RaMatchResult.hashIncompatible();
      debugPrint('RetroAchievements: ROM incompatible for ${item.game.filename}');
    }

    // Save the match result
    await db.saveRaMatch(item.game.filename, item.system.id, match);

    // Trigger refresh of RA matches for this system
    ref.read(raRefreshSignalProvider.notifier).state++;
  } catch (e) {
    debugPrint('RetroAchievements: hash verification failed: $e');
  }
}

final downloadQueueProvider = Provider<List<DownloadItem>>((ref) {
  return ref.watch(downloadQueueManagerProvider).state.queue;
});

final hasQueueItemsProvider = Provider<bool>((ref) {
  return !ref.watch(downloadQueueManagerProvider).state.isEmpty;
});

/// Event data for the "added to queue" animation.
class AddToQueueEvent {
  final String gameTitle;
  final Color accentColor;
  final DateTime timestamp;

  const AddToQueueEvent({
    required this.gameTitle,
    required this.accentColor,
    required this.timestamp,
  });
}

/// Set when an item is successfully added to the download queue.
/// Consumed by AddToQueueToast and _DownloadBadge for animations.
final addToQueueEventProvider = StateProvider<AddToQueueEvent?>((ref) => null);
