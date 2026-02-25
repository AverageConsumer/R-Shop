import 'package:flutter_test/flutter_test.dart';
import 'package:retro_eshop/models/config/provider_config.dart';
import 'package:retro_eshop/models/game_item.dart';

void main() {
  group('AlternativeSource', () {
    test('stores url and providerConfig', () {
      const config = ProviderConfig(type: ProviderType.smb, priority: 2, host: 'nas.local', share: 'roms');
      const alt = AlternativeSource(url: 'smb://nas.local/roms/game.zip', providerConfig: config);

      expect(alt.url, 'smb://nas.local/roms/game.zip');
      expect(alt.providerConfig.type, ProviderType.smb);
      expect(alt.providerConfig.host, 'nas.local');
    });
  });

  group('GameItem.alternativeSources', () {
    test('defaults to empty list', () {
      const game = GameItem(
        filename: 'game.zip',
        displayName: 'Game',
        url: 'https://example.com/game.zip',
      );
      expect(game.alternativeSources, isEmpty);
    });

    test('copyWith preserves alternativeSources', () {
      const alt = AlternativeSource(
        url: 'smb://nas/game.zip',
        providerConfig: ProviderConfig(type: ProviderType.smb, priority: 2, host: 'nas'),
      );
      const game = GameItem(
        filename: 'game.zip',
        displayName: 'Game',
        url: 'https://example.com/game.zip',
        alternativeSources: [alt],
      );

      final copied = game.copyWith(hasThumbnail: true);
      expect(copied.alternativeSources, hasLength(1));
      expect(copied.alternativeSources.first.url, 'smb://nas/game.zip');
    });

    test('copyWith can replace alternativeSources', () {
      const game = GameItem(
        filename: 'game.zip',
        displayName: 'Game',
        url: 'https://example.com/game.zip',
        alternativeSources: [
          AlternativeSource(
            url: 'smb://nas/game.zip',
            providerConfig: ProviderConfig(type: ProviderType.smb, priority: 2, host: 'nas'),
          ),
        ],
      );

      final cleared = game.copyWith(alternativeSources: []);
      expect(cleared.alternativeSources, isEmpty);
    });

    test('copyWith can replace url', () {
      const game = GameItem(
        filename: 'game.zip',
        displayName: 'Game',
        url: 'https://example.com/game.zip',
      );

      final updated = game.copyWith(url: 'https://other.com/game.zip');
      expect(updated.url, 'https://other.com/game.zip');
      expect(updated.filename, 'game.zip');
    });

    test('toJson/fromJson does not include alternativeSources (transient)', () {
      const alt = AlternativeSource(
        url: 'smb://nas/game.zip',
        providerConfig: ProviderConfig(type: ProviderType.smb, priority: 2, host: 'nas'),
      );
      const game = GameItem(
        filename: 'game.zip',
        displayName: 'Game',
        url: 'https://example.com/game.zip',
        alternativeSources: [alt],
      );

      final json = game.toJson();
      expect(json.containsKey('alternativeSources'), isFalse);

      final restored = GameItem.fromJson(json);
      expect(restored.alternativeSources, isEmpty);
    });
  });

  group('Merge deduplication with alternatives', () {
    // Simulates the logic in UnifiedGameService._fetchMerged()
    test('duplicate filename from second provider becomes alternative', () {
      const webConfig = ProviderConfig(type: ProviderType.web, priority: 1, url: 'https://web.com/roms');
      const smbConfig = ProviderConfig(type: ProviderType.smb, priority: 2, host: 'nas.local', share: 'roms');

      final providerAGames = [
        const GameItem(
          filename: 'Mario (USA).zip',
          displayName: 'Mario',
          url: 'https://web.com/roms/Mario (USA).zip',
          providerConfig: webConfig,
        ),
      ];

      final providerBGames = [
        const GameItem(
          filename: 'Mario (USA).zip',
          displayName: 'Mario',
          url: 'smb://nas.local/roms/Mario (USA).zip',
          providerConfig: smbConfig,
        ),
      ];

      // Simulate _fetchMerged logic
      final results = <String, GameItem>{};
      for (final games in [providerAGames, providerBGames]) {
        for (final game in games) {
          if (results.containsKey(game.filename)) {
            if (game.providerConfig != null) {
              final existing = results[game.filename]!;
              results[game.filename] = existing.copyWith(
                alternativeSources: [
                  ...existing.alternativeSources,
                  AlternativeSource(url: game.url, providerConfig: game.providerConfig!),
                ],
              );
            }
          } else {
            results[game.filename] = game;
          }
        }
      }

      expect(results, hasLength(1));
      final merged = results['Mario (USA).zip']!;
      expect(merged.url, 'https://web.com/roms/Mario (USA).zip');
      expect(merged.providerConfig, webConfig);
      expect(merged.alternativeSources, hasLength(1));
      expect(merged.alternativeSources.first.url, 'smb://nas.local/roms/Mario (USA).zip');
      expect(merged.alternativeSources.first.providerConfig, smbConfig);
    });

    test('three providers yield two alternatives', () {
      const p1 = ProviderConfig(type: ProviderType.web, priority: 1, url: 'https://a.com');
      const p2 = ProviderConfig(type: ProviderType.smb, priority: 2, host: 'nas');
      const p3 = ProviderConfig(type: ProviderType.ftp, priority: 3, host: 'ftp.local');

      final allGames = [
        [const GameItem(filename: 'rom.zip', displayName: 'ROM', url: 'https://a.com/rom.zip', providerConfig: p1)],
        [const GameItem(filename: 'rom.zip', displayName: 'ROM', url: 'smb://nas/rom.zip', providerConfig: p2)],
        [const GameItem(filename: 'rom.zip', displayName: 'ROM', url: 'ftp://ftp.local/rom.zip', providerConfig: p3)],
      ];

      final results = <String, GameItem>{};
      for (final games in allGames) {
        for (final game in games) {
          if (results.containsKey(game.filename)) {
            if (game.providerConfig != null) {
              final existing = results[game.filename]!;
              results[game.filename] = existing.copyWith(
                alternativeSources: [
                  ...existing.alternativeSources,
                  AlternativeSource(url: game.url, providerConfig: game.providerConfig!),
                ],
              );
            }
          } else {
            results[game.filename] = game;
          }
        }
      }

      final merged = results['rom.zip']!;
      expect(merged.url, 'https://a.com/rom.zip');
      expect(merged.alternativeSources, hasLength(2));
      expect(merged.alternativeSources[0].providerConfig.type, ProviderType.smb);
      expect(merged.alternativeSources[1].providerConfig.type, ProviderType.ftp);
    });

    test('unique filenames have no alternatives', () {
      const p1 = ProviderConfig(type: ProviderType.web, priority: 1, url: 'https://a.com');
      const p2 = ProviderConfig(type: ProviderType.smb, priority: 2, host: 'nas');

      final allGames = [
        [const GameItem(filename: 'game_a.zip', displayName: 'A', url: 'https://a.com/a.zip', providerConfig: p1)],
        [const GameItem(filename: 'game_b.zip', displayName: 'B', url: 'smb://nas/b.zip', providerConfig: p2)],
      ];

      final results = <String, GameItem>{};
      for (final games in allGames) {
        for (final game in games) {
          if (results.containsKey(game.filename)) {
            if (game.providerConfig != null) {
              final existing = results[game.filename]!;
              results[game.filename] = existing.copyWith(
                alternativeSources: [
                  ...existing.alternativeSources,
                  AlternativeSource(url: game.url, providerConfig: game.providerConfig!),
                ],
              );
            }
          } else {
            results[game.filename] = game;
          }
        }
      }

      expect(results, hasLength(2));
      expect(results['game_a.zip']!.alternativeSources, isEmpty);
      expect(results['game_b.zip']!.alternativeSources, isEmpty);
    });
  });

  group('Source switching simulation', () {
    test('switching rotates to first alternative and removes it', () {
      const smbConfig = ProviderConfig(type: ProviderType.smb, priority: 2, host: 'nas');
      const ftpConfig = ProviderConfig(type: ProviderType.ftp, priority: 3, host: 'ftp.local');
      const game = GameItem(
        filename: 'rom.zip',
        displayName: 'ROM',
        url: 'https://web.com/rom.zip',
        providerConfig: ProviderConfig(type: ProviderType.web, priority: 1, url: 'https://web.com'),
        alternativeSources: [
          AlternativeSource(url: 'smb://nas/rom.zip', providerConfig: smbConfig),
          AlternativeSource(url: 'ftp://ftp.local/rom.zip', providerConfig: ftpConfig),
        ],
      );

      // Simulate _switchToAlternativeSource
      final next = game.alternativeSources.first;
      final remaining = game.alternativeSources.skip(1).toList();

      final switched = game.copyWith(
        url: next.url,
        providerConfig: next.providerConfig,
        alternativeSources: remaining,
      );

      expect(switched.url, 'smb://nas/rom.zip');
      expect(switched.providerConfig?.type, ProviderType.smb);
      expect(switched.alternativeSources, hasLength(1));
      expect(switched.alternativeSources.first.providerConfig.type, ProviderType.ftp);
    });

    test('last alternative leaves empty list', () {
      const smbConfig = ProviderConfig(type: ProviderType.smb, priority: 2, host: 'nas');
      const game = GameItem(
        filename: 'rom.zip',
        displayName: 'ROM',
        url: 'https://web.com/rom.zip',
        alternativeSources: [
          AlternativeSource(url: 'smb://nas/rom.zip', providerConfig: smbConfig),
        ],
      );

      final next = game.alternativeSources.first;
      final remaining = game.alternativeSources.skip(1).toList();

      final switched = game.copyWith(
        url: next.url,
        providerConfig: next.providerConfig,
        alternativeSources: remaining,
      );

      expect(switched.url, 'smb://nas/rom.zip');
      expect(switched.alternativeSources, isEmpty);
    });
  });
}
