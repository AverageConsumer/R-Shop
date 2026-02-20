import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/config/system_config.dart';
import '../models/game_item.dart';
import 'provider_factory.dart';

class UnifiedGameService {
  /// Fetches games for a system from its configured providers.
  ///
  /// In failover mode (default), providers are tried in priority order and the
  /// first successful result is returned.
  ///
  /// In merge mode, all providers are attempted and results are combined,
  /// deduplicating by filename (higher-priority provider wins).
  Future<List<GameItem>> fetchGamesForSystem(
    SystemConfig system, {
    bool? merge,
  }) async {
    if (system.providers.isEmpty) {
      throw StateError('No providers configured for system "${system.name}"');
    }

    final useMerge = merge ?? system.mergeMode;
    if (useMerge) {
      return _fetchMerged(system);
    } else {
      return _fetchFailover(system);
    }
  }

  Future<List<GameItem>> _fetchFailover(SystemConfig system) async {
    Object? lastError;

    for (final providerConfig in system.providers) {
      try {
        final provider = ProviderFactory.getProvider(providerConfig);
        return await provider.fetchGames(system).timeout(
              const Duration(seconds: 30),
              onTimeout: () =>
                  throw TimeoutException('Server not responding'),
            );
      } catch (e) {
        lastError = e;
        continue;
      }
    }

    throw lastError ?? StateError('All providers failed for system "${system.name}"');
  }

  Future<List<GameItem>> _fetchMerged(SystemConfig system) async {
    final results = <String, GameItem>{};
    var successes = 0;

    for (final providerConfig in system.providers) {
      try {
        final provider = ProviderFactory.getProvider(providerConfig);
        final games = await provider.fetchGames(system).timeout(
              const Duration(seconds: 30),
              onTimeout: () =>
                  throw TimeoutException('Server not responding'),
            );
        successes++;

        for (final game in games) {
          // Higher-priority (lower number) providers come first in the list,
          // so only add if not already present. Use filename as key to
          // preserve region variants (e.g. "Mario (USA).zip" vs "Mario (EUR).zip").
          results.putIfAbsent(game.filename, () => game);
        }
      } catch (e) {
        debugPrint('Provider failed: $e');
        continue;
      }
    }

    if (successes == 0) {
      throw StateError('All providers failed for system "${system.name}"');
    }

    return results.values.toList();
  }
}
