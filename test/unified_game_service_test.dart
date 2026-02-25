import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:retro_eshop/models/config/provider_config.dart';
import 'package:retro_eshop/models/config/system_config.dart';
import 'package:retro_eshop/models/game_item.dart';
import 'package:retro_eshop/services/unified_game_service.dart';

// ─── Test doubles ────────────────────────────────────────

class _FakeProvider {
  final ProviderConfig config;
  final List<GameItem> games;
  final Exception? error;

  _FakeProvider({
    required this.config,
    this.games = const [],
    this.error,
  });

  Future<List<GameItem>> fetchGames(SystemConfig system) async {
    if (error != null) throw error!;
    return games;
  }
}

// Testable subclass that injects fake providers
class _TestableUnifiedGameService extends UnifiedGameService {
  final Map<ProviderType, _FakeProvider> _fakeProviders;

  _TestableUnifiedGameService(this._fakeProviders);

  @override
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
        final provider = _fakeProviders[providerConfig.type];
        if (provider == null) throw StateError('No fake for ${providerConfig.type}');
        return await provider.fetchGames(system).timeout(
              const Duration(seconds: 30),
              onTimeout: () => throw TimeoutException('Server not responding'),
            );
      } catch (e) {
        lastError = e;
        continue;
      }
    }

    throw lastError ?? StateError('All providers failed');
  }

  Future<List<GameItem>> _fetchMerged(SystemConfig system) async {
    final results = <String, GameItem>{};
    var successes = 0;

    for (final providerConfig in system.providers) {
      try {
        final provider = _fakeProviders[providerConfig.type];
        if (provider == null) throw StateError('No fake for ${providerConfig.type}');
        final games = await provider.fetchGames(system).timeout(
              const Duration(seconds: 30),
              onTimeout: () => throw TimeoutException('Server not responding'),
            );
        successes++;

        for (final game in games) {
          if (results.containsKey(game.filename)) {
            if (game.providerConfig != null) {
              final existing = results[game.filename]!;
              results[game.filename] = existing.copyWith(
                alternativeSources: [
                  ...existing.alternativeSources,
                  AlternativeSource(
                    url: game.url,
                    providerConfig: game.providerConfig!,
                  ),
                ],
              );
            }
          } else {
            results[game.filename] = game;
          }
        }
      } catch (e) {
        continue;
      }
    }

    if (successes == 0) {
      throw StateError('All providers failed for system "${system.name}"');
    }

    return results.values.toList();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const webConfig = ProviderConfig(
    type: ProviderType.web,
    priority: 1,
    url: 'https://example.com/roms',
  );

  const smbConfig = ProviderConfig(
    type: ProviderType.smb,
    priority: 2,
    host: 'nas.local',
    share: 'roms',
  );

  const ftpConfig = ProviderConfig(
    type: ProviderType.ftp,
    priority: 3,
    host: 'ftp.example.com',
  );

  const systemWithWeb = SystemConfig(
    id: 'nes',
    name: 'NES',
    targetFolder: '/roms/nes',
    providers: [webConfig],
  );

  const systemWithMultiple = SystemConfig(
    id: 'nes',
    name: 'NES',
    targetFolder: '/roms/nes',
    providers: [webConfig, smbConfig],
  );

  const systemMerge = SystemConfig(
    id: 'nes',
    name: 'NES',
    targetFolder: '/roms/nes',
    providers: [webConfig, smbConfig],
    mergeMode: true,
  );

  const systemNoProviders = SystemConfig(
    id: 'nes',
    name: 'NES',
    targetFolder: '/roms/nes',
    providers: [],
  );

  const game1 = GameItem(
    filename: 'mario.nes',
    displayName: 'Mario',
    url: 'https://example.com/mario.nes',
    providerConfig: webConfig,
  );

  const game2 = GameItem(
    filename: 'zelda.nes',
    displayName: 'Zelda',
    url: 'https://example.com/zelda.nes',
    providerConfig: webConfig,
  );

  const game1Smb = GameItem(
    filename: 'mario.nes',
    displayName: 'Mario',
    url: 'smb://nas.local/roms/mario.nes',
    providerConfig: smbConfig,
  );

  const game3Smb = GameItem(
    filename: 'metroid.nes',
    displayName: 'Metroid',
    url: 'smb://nas.local/roms/metroid.nes',
    providerConfig: smbConfig,
  );

  // ─── Failover mode ────────────────────────────────────

  group('Failover mode', () {
    test('returns games from first successful provider', () async {
      final service = _TestableUnifiedGameService({
        ProviderType.web: _FakeProvider(
          config: webConfig,
          games: [game1, game2],
        ),
        ProviderType.smb: _FakeProvider(
          config: smbConfig,
          games: [game1Smb, game3Smb],
        ),
      });

      final result = await service.fetchGamesForSystem(systemWithMultiple);
      expect(result, hasLength(2));
      expect(result.first.filename, 'mario.nes');
      expect(result.first.url, contains('example.com'));
    });

    test('falls back to second provider when first fails', () async {
      final service = _TestableUnifiedGameService({
        ProviderType.web: _FakeProvider(
          config: webConfig,
          error: Exception('Connection refused'),
        ),
        ProviderType.smb: _FakeProvider(
          config: smbConfig,
          games: [game1Smb, game3Smb],
        ),
      });

      final result = await service.fetchGamesForSystem(systemWithMultiple);
      expect(result, hasLength(2));
      expect(result.first.url, contains('nas.local'));
    });

    test('throws last error when all providers fail', () async {
      final service = _TestableUnifiedGameService({
        ProviderType.web: _FakeProvider(
          config: webConfig,
          error: Exception('Web failed'),
        ),
        ProviderType.smb: _FakeProvider(
          config: smbConfig,
          error: Exception('SMB failed'),
        ),
      });

      expect(
        () => service.fetchGamesForSystem(systemWithMultiple),
        throwsA(isA<Exception>()),
      );
    });

    test('throws StateError when no providers configured', () async {
      final service = _TestableUnifiedGameService({});

      expect(
        () => service.fetchGamesForSystem(systemNoProviders),
        throwsA(isA<StateError>()),
      );
    });

    test('returns empty list from successful provider with no games', () async {
      final service = _TestableUnifiedGameService({
        ProviderType.web: _FakeProvider(
          config: webConfig,
          games: [],
        ),
      });

      final result = await service.fetchGamesForSystem(systemWithWeb);
      expect(result, isEmpty);
    });
  });

  // ─── Merge mode ────────────────────────────────────────

  group('Merge mode', () {
    test('combines unique games from multiple providers', () async {
      final service = _TestableUnifiedGameService({
        ProviderType.web: _FakeProvider(
          config: webConfig,
          games: [game1, game2],
        ),
        ProviderType.smb: _FakeProvider(
          config: smbConfig,
          games: [game3Smb],
        ),
      });

      final result = await service.fetchGamesForSystem(systemMerge);
      expect(result, hasLength(3));
      final filenames = result.map((g) => g.filename).toSet();
      expect(filenames, containsAll(['mario.nes', 'zelda.nes', 'metroid.nes']));
    });

    test('deduplicates by filename, higher priority wins', () async {
      final service = _TestableUnifiedGameService({
        ProviderType.web: _FakeProvider(
          config: webConfig,
          games: [game1], // priority 1
        ),
        ProviderType.smb: _FakeProvider(
          config: smbConfig,
          games: [game1Smb], // priority 2, same filename
        ),
      });

      final result = await service.fetchGamesForSystem(systemMerge);
      expect(result, hasLength(1));
      expect(result.first.url, contains('example.com')); // web (priority 1) wins
    });

    test('duplicate from lower-priority provider becomes alternative source', () async {
      final service = _TestableUnifiedGameService({
        ProviderType.web: _FakeProvider(
          config: webConfig,
          games: [game1],
        ),
        ProviderType.smb: _FakeProvider(
          config: smbConfig,
          games: [game1Smb],
        ),
      });

      final result = await service.fetchGamesForSystem(systemMerge);
      expect(result, hasLength(1));

      final mario = result.first;
      expect(mario.alternativeSources, hasLength(1));
      expect(mario.alternativeSources.first.providerConfig.type, ProviderType.smb);
      expect(mario.alternativeSources.first.url, contains('nas.local'));
    });

    test('continues when one provider fails, succeeds with others', () async {
      final service = _TestableUnifiedGameService({
        ProviderType.web: _FakeProvider(
          config: webConfig,
          error: Exception('Web down'),
        ),
        ProviderType.smb: _FakeProvider(
          config: smbConfig,
          games: [game1Smb, game3Smb],
        ),
      });

      final result = await service.fetchGamesForSystem(systemMerge);
      expect(result, hasLength(2));
    });

    test('throws when all providers fail in merge mode', () async {
      final service = _TestableUnifiedGameService({
        ProviderType.web: _FakeProvider(
          config: webConfig,
          error: Exception('Web failed'),
        ),
        ProviderType.smb: _FakeProvider(
          config: smbConfig,
          error: Exception('SMB failed'),
        ),
      });

      expect(
        () => service.fetchGamesForSystem(systemMerge),
        throwsA(isA<StateError>()),
      );
    });

    test('merge with three providers yields two alternatives for same file', () async {
      const game1Ftp = GameItem(
        filename: 'mario.nes',
        displayName: 'Mario',
        url: 'ftp://ftp.example.com/mario.nes',
        providerConfig: ftpConfig,
      );

      const systemTriple = SystemConfig(
        id: 'nes',
        name: 'NES',
        targetFolder: '/roms/nes',
        providers: [webConfig, smbConfig, ftpConfig],
        mergeMode: true,
      );

      final service = _TestableUnifiedGameService({
        ProviderType.web: _FakeProvider(
          config: webConfig,
          games: [game1],
        ),
        ProviderType.smb: _FakeProvider(
          config: smbConfig,
          games: [game1Smb],
        ),
        ProviderType.ftp: _FakeProvider(
          config: ftpConfig,
          games: [game1Ftp],
        ),
      });

      final result = await service.fetchGamesForSystem(systemTriple);
      expect(result, hasLength(1));

      final mario = result.first;
      expect(mario.alternativeSources, hasLength(2));
      expect(
        mario.alternativeSources.map((a) => a.providerConfig.type),
        containsAll([ProviderType.smb, ProviderType.ftp]),
      );
    });
  });

  // ─── Merge flag override ───────────────────────────────

  group('Merge flag', () {
    test('explicit merge=true overrides system config', () async {
      final service = _TestableUnifiedGameService({
        ProviderType.web: _FakeProvider(
          config: webConfig,
          games: [game1],
        ),
        ProviderType.smb: _FakeProvider(
          config: smbConfig,
          games: [game3Smb],
        ),
      });

      // systemWithMultiple has mergeMode=false, but we override
      final result = await service.fetchGamesForSystem(
        systemWithMultiple,
        merge: true,
      );
      expect(result, hasLength(2));
    });

    test('explicit merge=false overrides system config', () async {
      final service = _TestableUnifiedGameService({
        ProviderType.web: _FakeProvider(
          config: webConfig,
          games: [game1, game2],
        ),
        ProviderType.smb: _FakeProvider(
          config: smbConfig,
          games: [game1Smb, game3Smb],
        ),
      });

      // systemMerge has mergeMode=true, but we override
      final result = await service.fetchGamesForSystem(
        systemMerge,
        merge: false,
      );
      // Failover: only returns from first successful provider
      expect(result, hasLength(2));
      expect(result.first.url, contains('example.com'));
    });
  });
}
