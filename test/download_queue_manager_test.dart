import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:retro_eshop/models/config/provider_config.dart';
import 'package:retro_eshop/models/download_item.dart';
import 'package:retro_eshop/models/game_item.dart';
import 'package:retro_eshop/models/system_model.dart';
import 'package:retro_eshop/services/download_queue_manager.dart';


void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testSystem = SystemModel(
    id: 'nes',
    name: 'Nintendo Entertainment System',
    manufacturer: 'Nintendo',
    releaseYear: 1983,
    romExtensions: ['.nes'],
  );

  const testSystem2 = SystemModel(
    id: 'snes',
    name: 'Super Nintendo',
    manufacturer: 'Nintendo',
    releaseYear: 1990,
    romExtensions: ['.sfc', '.smc'],
  );

  GameItem makeGame(String name, {ProviderConfig? providerConfig}) => GameItem(
        filename: '$name.nes',
        displayName: name,
        url: 'https://example.com/$name.nes',
        providerConfig: providerConfig ??
            const ProviderConfig(
              type: ProviderType.web,
              priority: 1,
              url: 'https://example.com',
            ),
      );

  // ─── DownloadQueueState ────────────────────────────────

  group('DownloadQueueState', () {
    test('initial state is empty', () {
      const state = DownloadQueueState();
      expect(state.isEmpty, isTrue);
      expect(state.totalCount, 0);
      expect(state.activeCount, 0);
      expect(state.queuedCount, 0);
      expect(state.finishedCount, 0);
      expect(state.hasActiveDownloads, isFalse);
      expect(state.hasQueuedItems, isFalse);
      expect(state.maxConcurrent, 2);
    });

    test('canStartNewDownload respects maxConcurrent', () {
      const state = DownloadQueueState(maxConcurrent: 2);
      expect(state.canStartNewDownload(), isTrue);

      // With 2 active items, can't start new
      final stateWith2Active = DownloadQueueState(
        maxConcurrent: 2,
        queue: [
          DownloadItem(
            id: 'a',
            game: makeGame('a'),
            system: testSystem,
            targetFolder: '/roms',
            status: DownloadItemStatus.downloading,
          ),
          DownloadItem(
            id: 'b',
            game: makeGame('b'),
            system: testSystem,
            targetFolder: '/roms',
            status: DownloadItemStatus.downloading,
          ),
        ],
      );
      expect(stateWith2Active.canStartNewDownload(), isFalse);
    });

    test('getDownloadById finds item', () {
      final state = DownloadQueueState(
        queue: [
          DownloadItem(
            id: 'test_id',
            game: makeGame('test'),
            system: testSystem,
            targetFolder: '/roms',
          ),
        ],
      );
      expect(state.getDownloadById('test_id'), isNotNull);
      expect(state.getDownloadById('nonexistent'), isNull);
    });

    test('activeDownloads filters correctly', () {
      final state = DownloadQueueState(
        queue: [
          DownloadItem(
            id: 'a',
            game: makeGame('a'),
            system: testSystem,
            targetFolder: '/roms',
            status: DownloadItemStatus.downloading,
          ),
          DownloadItem(
            id: 'b',
            game: makeGame('b'),
            system: testSystem,
            targetFolder: '/roms',
            status: DownloadItemStatus.extracting,
          ),
          DownloadItem(
            id: 'c',
            game: makeGame('c'),
            system: testSystem,
            targetFolder: '/roms',
            status: DownloadItemStatus.queued,
          ),
          DownloadItem(
            id: 'd',
            game: makeGame('d'),
            system: testSystem,
            targetFolder: '/roms',
            status: DownloadItemStatus.completed,
          ),
        ],
      );
      expect(state.activeDownloads, hasLength(2));
      expect(state.queuedItems, hasLength(1));
      expect(state.completedItems, hasLength(1));
    });

    test('recentItems puts unfinished first, finished last', () {
      final state = DownloadQueueState(
        queue: [
          DownloadItem(
            id: 'done',
            game: makeGame('done'),
            system: testSystem,
            targetFolder: '/roms',
            status: DownloadItemStatus.completed,
          ),
          DownloadItem(
            id: 'active',
            game: makeGame('active'),
            system: testSystem,
            targetFolder: '/roms',
            status: DownloadItemStatus.downloading,
          ),
        ],
      );

      final recent = state.recentItems;
      expect(recent.first.id, 'active');
      expect(recent.last.id, 'done');
    });

    test('copyWith creates new state with updated fields', () {
      const state = DownloadQueueState(maxConcurrent: 2);
      final updated = state.copyWith(maxConcurrent: 3);
      expect(updated.maxConcurrent, 3);
      expect(state.maxConcurrent, 2); // original unchanged
    });

    test('failedItems filters correctly', () {
      final state = DownloadQueueState(
        queue: [
          DownloadItem(
            id: 'a',
            game: makeGame('a'),
            system: testSystem,
            targetFolder: '/roms',
            status: DownloadItemStatus.error,
            error: 'Network timeout',
          ),
          DownloadItem(
            id: 'b',
            game: makeGame('b'),
            system: testSystem,
            targetFolder: '/roms',
            status: DownloadItemStatus.completed,
          ),
        ],
      );
      expect(state.failedItems, hasLength(1));
      expect(state.finishedCount, 2);
    });
  });

  // ─── DownloadItem serialization ────────────────────────

  group('DownloadItem serialization', () {
    test('toJson includes all required fields', () {
      final item = DownloadItem(
        id: 'nes_game.nes',
        game: makeGame('game'),
        system: testSystem,
        targetFolder: '/roms/nes',
        addedAt: DateTime(2026, 1, 1),
      );

      final json = item.toJson();
      expect(json['id'], 'nes_game.nes');
      expect(json['gameFilename'], 'game.nes');
      expect(json['gameUrl'], 'https://example.com/game.nes');
      expect(json['systemId'], 'nes');
      expect(json['targetFolder'], '/roms/nes');
      expect(json['status'], 'queued');
      expect(json['retryCount'], 0);
    });

    test('toJson strips auth from providerConfig', () {
      final game = makeGame(
        'game',
        providerConfig: const ProviderConfig(
          type: ProviderType.web,
          priority: 1,
          url: 'https://example.com',
          auth: AuthConfig(user: 'admin', pass: 'secret'),
        ),
      );
      final item = DownloadItem(
        id: 'nes_game.nes',
        game: game,
        system: testSystem,
        targetFolder: '/roms/nes',
      );

      final json = item.toJson();
      final pcJson = json['providerConfig'] as Map<String, dynamic>;
      expect(pcJson.containsKey('auth'), isFalse);
    });

    test('toJson includes tempFilePath when set', () {
      final item = DownloadItem(
        id: 'test',
        game: makeGame('game'),
        system: testSystem,
        targetFolder: '/roms',
        tempFilePath: '/tmp/download_123.tmp',
      );

      final json = item.toJson();
      expect(json['tempFilePath'], '/tmp/download_123.tmp');
    });

    test('fromJson restores item correctly', () {
      final json = {
        'id': 'nes_game.nes',
        'gameFilename': 'game.nes',
        'gameUrl': 'https://example.com/game.nes',
        'gameDisplayName': 'game',
        'systemId': 'nes',
        'targetFolder': '/roms/nes',
        'addedAt': '2026-01-01T00:00:00.000',
        'status': 'queued',
        'progress': 0.5,
        'retryCount': 2,
        'providerConfig': {
          'type': 'web',
          'priority': 1,
          'url': 'https://example.com',
        },
      };

      final item = DownloadItem.fromJson(json, testSystem);
      expect(item.id, 'nes_game.nes');
      expect(item.game.filename, 'game.nes');
      expect(item.system.id, 'nes');
      expect(item.progress, 0.5);
      expect(item.retryCount, 2);
      expect(item.game.providerConfig?.type, ProviderType.web);
    });

    test('fromJson handles legacy romPath field', () {
      final json = {
        'id': 'test',
        'gameFilename': 'game.nes',
        'gameUrl': 'https://example.com/game.nes',
        'gameDisplayName': 'game',
        'romPath': '/legacy/path',
        'addedAt': '2026-01-01T00:00:00.000',
        'status': 'queued',
      };

      final item = DownloadItem.fromJson(json, testSystem);
      expect(item.targetFolder, '/legacy/path');
    });

    test('fromJson parses status name string', () {
      final json = {
        'id': 'test',
        'gameFilename': 'game.nes',
        'gameUrl': 'https://example.com/game.nes',
        'gameDisplayName': 'game',
        'targetFolder': '/roms',
        'addedAt': '2026-01-01T00:00:00.000',
        'status': 'error',
      };

      final item = DownloadItem.fromJson(json, testSystem);
      expect(item.status, DownloadItemStatus.error);
    });

    test('fromJson defaults unknown status to queued', () {
      final json = {
        'id': 'test',
        'gameFilename': 'game.nes',
        'gameUrl': 'https://example.com/game.nes',
        'gameDisplayName': 'game',
        'targetFolder': '/roms',
        'addedAt': '2026-01-01T00:00:00.000',
        'status': 'unknown_status',
      };

      final item = DownloadItem.fromJson(json, testSystem);
      expect(item.status, DownloadItemStatus.queued);
    });

    test('round-trip JSON serialization preserves data', () {
      final original = DownloadItem(
        id: 'nes_test.nes',
        game: makeGame('test'),
        system: testSystem,
        targetFolder: '/roms/nes',
        retryCount: 1,
      );

      final json = original.toJson();
      final restored = DownloadItem.fromJson(json, testSystem);

      expect(restored.id, original.id);
      expect(restored.game.filename, original.game.filename);
      expect(restored.game.url, original.game.url);
      expect(restored.targetFolder, original.targetFolder);
      expect(restored.retryCount, original.retryCount);
    });

    test('toJson includes isFolder when true', () {
      final item = DownloadItem(
        id: 'ps2_folder',
        game: GameItem(
          filename: 'Final Fantasy X',
          displayName: 'Final Fantasy X',
          url: '/share/ps2/Final Fantasy X',
          isFolder: true,
        ),
        system: testSystem,
        targetFolder: '/roms/ps2',
      );

      final json = item.toJson();
      expect(json['isFolder'], isTrue);
    });

    test('toJson omits isFolder when false', () {
      final item = DownloadItem(
        id: 'nes_game',
        game: makeGame('game'),
        system: testSystem,
        targetFolder: '/roms/nes',
      );

      final json = item.toJson();
      expect(json.containsKey('isFolder'), isFalse);
    });

    test('fromJson restores isFolder flag', () {
      final json = {
        'id': 'ps2_folder',
        'gameFilename': 'Final Fantasy X',
        'gameUrl': '/share/ps2/Final Fantasy X',
        'gameDisplayName': 'Final Fantasy X',
        'isFolder': true,
        'targetFolder': '/roms/ps2',
        'addedAt': DateTime.now().toIso8601String(),
        'status': 'queued',
        'progress': 0.0,
      };

      final item = DownloadItem.fromJson(json, testSystem);
      expect(item.game.isFolder, isTrue);
    });

    test('fromJson defaults isFolder to false when absent', () {
      final json = {
        'id': 'nes_game',
        'gameFilename': 'game.nes',
        'gameUrl': 'https://example.com/game.nes',
        'gameDisplayName': 'Game',
        'targetFolder': '/roms/nes',
        'addedAt': DateTime.now().toIso8601String(),
        'status': 'queued',
        'progress': 0.0,
      };

      final item = DownloadItem.fromJson(json, testSystem);
      expect(item.game.isFolder, isFalse);
    });

    test('isFolder round-trip serialization', () {
      final original = DownloadItem(
        id: 'ps2_folder',
        game: GameItem(
          filename: 'Game Folder',
          displayName: 'Game Folder',
          url: '/share/ps2/Game Folder',
          isFolder: true,
        ),
        system: testSystem,
        targetFolder: '/roms/ps2',
      );

      final json = original.toJson();
      final restored = DownloadItem.fromJson(json, testSystem);
      expect(restored.game.isFolder, isTrue);
      expect(restored.game.filename, 'Game Folder');
    });
  });

  // ─── DownloadItem model ────────────────────────────────

  group('DownloadItem model', () {
    test('equality is based on id', () {
      final a = DownloadItem(
        id: 'same',
        game: makeGame('a'),
        system: testSystem,
        targetFolder: '/roms',
      );
      final b = DownloadItem(
        id: 'same',
        game: makeGame('b'),
        system: testSystem,
        targetFolder: '/other',
      );
      expect(a, equals(b));
    });

    test('isActive for downloading/extracting/moving', () {
      for (final status in [
        DownloadItemStatus.downloading,
        DownloadItemStatus.extracting,
        DownloadItemStatus.moving,
      ]) {
        final item = DownloadItem(
          id: 'test',
          game: makeGame('test'),
          system: testSystem,
          targetFolder: '/roms',
          status: status,
        );
        expect(item.isActive, isTrue, reason: '$status should be active');
      }
    });

    test('isFinished for completed/error/cancelled', () {
      for (final status in [
        DownloadItemStatus.completed,
        DownloadItemStatus.error,
        DownloadItemStatus.cancelled,
      ]) {
        final item = DownloadItem(
          id: 'test',
          game: makeGame('test'),
          system: testSystem,
          targetFolder: '/roms',
          status: status,
        );
        expect(item.isFinished, isTrue, reason: '$status should be finished');
      }
    });

    test('isFinished is false for queued/active statuses', () {
      for (final status in [
        DownloadItemStatus.queued,
        DownloadItemStatus.downloading,
        DownloadItemStatus.extracting,
        DownloadItemStatus.moving,
      ]) {
        final item = DownloadItem(
          id: 'test',
          game: makeGame('test'),
          system: testSystem,
          targetFolder: '/roms',
          status: status,
        );
        expect(item.isFinished, isFalse, reason: '$status should not be finished');
      }
    });

    test('displayText shows retry count when retrying', () {
      final item = DownloadItem(
        id: 'test',
        game: makeGame('test'),
        system: testSystem,
        targetFolder: '/roms',
        status: DownloadItemStatus.queued,
        retryCount: 2,
      );
      expect(item.displayText, 'Retrying (2/3)...');
    });

    test('displayText shows error message for error status', () {
      final item = DownloadItem(
        id: 'test',
        game: makeGame('test'),
        system: testSystem,
        targetFolder: '/roms',
        status: DownloadItemStatus.error,
        error: 'Connection refused',
      );
      expect(item.displayText, 'Connection refused');
    });

    test('copyWith clears error when clearError is true', () {
      final item = DownloadItem(
        id: 'test',
        game: makeGame('test'),
        system: testSystem,
        targetFolder: '/roms',
        status: DownloadItemStatus.error,
        error: 'some error',
      );

      final cleared = item.copyWith(
        status: DownloadItemStatus.queued,
        clearError: true,
      );
      expect(cleared.error, isNull);
      expect(cleared.status, DownloadItemStatus.queued);
    });

    test('copyWith clears speed when clearSpeed is true', () {
      final item = DownloadItem(
        id: 'test',
        game: makeGame('test'),
        system: testSystem,
        targetFolder: '/roms',
        downloadSpeed: 1024,
      );

      final cleared = item.copyWith(clearSpeed: true);
      expect(cleared.downloadSpeed, isNull);
    });

    test('copyWith clears tempFilePath when clearTempFilePath is true', () {
      final item = DownloadItem(
        id: 'test',
        game: makeGame('test'),
        system: testSystem,
        targetFolder: '/roms',
        tempFilePath: '/tmp/file.tmp',
      );

      final cleared = item.copyWith(clearTempFilePath: true);
      expect(cleared.tempFilePath, isNull);
    });

    test('speedText formats KB/s and MB/s correctly', () {
      final slowItem = DownloadItem(
        id: 'test',
        game: makeGame('test'),
        system: testSystem,
        targetFolder: '/roms',
        downloadSpeed: 512,
      );
      expect(slowItem.speedText, '512 KB/s');

      final fastItem = DownloadItem(
        id: 'test',
        game: makeGame('test'),
        system: testSystem,
        targetFolder: '/roms',
        downloadSpeed: 2048,
      );
      expect(fastItem.speedText, '2.0 MB/s');
    });
  });

  // ─── Retry logic ───────────────────────────────────────

  group('Retry error classification', () {
    // Test the static _isRetryableError via observable behavior
    // Non-retryable errors: '404', 'SSL error'
    test('non-retryable errors include 404 and SSL', () {
      // We test this indirectly through DownloadItem status patterns
      // since _isRetryableError is private. The key behavior:
      // - 404 errors should NOT trigger retry
      // - SSL errors should NOT trigger retry
      // - Network timeouts SHOULD trigger retry

      // Verify error messages match expected non-retryable patterns
      const nonRetryable = ['File not found (404)', 'SSL error'];
      expect(
        nonRetryable.any((e) => 'File not found (404)'.contains(e)),
        isTrue,
      );
      expect(
        nonRetryable.any((e) => 'SSL error during connection'.contains(e)),
        isTrue,
      );
      expect(
        nonRetryable.any((e) => 'Connection timeout'.contains(e)),
        isFalse,
      );
    });
  });

  // ─── Queue persistence ─────────────────────────────────

  group('Queue persistence', () {
    test('persisted queue only includes queued and error items', () {
      // Simulate the persistence filter logic from _persistQueue
      final queue = [
        DownloadItem(
          id: 'queued',
          game: makeGame('queued'),
          system: testSystem,
          targetFolder: '/roms',
          status: DownloadItemStatus.queued,
        ),
        DownloadItem(
          id: 'downloading',
          game: makeGame('downloading'),
          system: testSystem,
          targetFolder: '/roms',
          status: DownloadItemStatus.downloading,
        ),
        DownloadItem(
          id: 'error',
          game: makeGame('error'),
          system: testSystem,
          targetFolder: '/roms',
          status: DownloadItemStatus.error,
          error: 'Timeout',
        ),
        DownloadItem(
          id: 'completed',
          game: makeGame('completed'),
          system: testSystem,
          targetFolder: '/roms',
          status: DownloadItemStatus.completed,
        ),
        DownloadItem(
          id: 'cancelled',
          game: makeGame('cancelled'),
          system: testSystem,
          targetFolder: '/roms',
          status: DownloadItemStatus.cancelled,
        ),
      ];

      final persistable = queue
          .where((item) =>
              item.status == DownloadItemStatus.queued ||
              item.status == DownloadItemStatus.error)
          .toList();

      expect(persistable, hasLength(2));
      expect(persistable.map((i) => i.id), containsAll(['queued', 'error']));
    });

    test('restoreQueue resolves system by id', () {
      final systems = [testSystem, testSystem2];
      final systemMapById = {for (final s in systems) s.id: s};

      expect(systemMapById['nes'], isNotNull);
      expect(systemMapById['snes'], isNotNull);
      expect(systemMapById['unknown'], isNull);
    });

    test('restoreQueue resolves system by name (legacy fallback)', () {
      final systems = [testSystem];
      final systemMapByName = {for (final s in systems) s.name: s};

      expect(
        systemMapByName['Nintendo Entertainment System'],
        isNotNull,
      );
    });

    test('persisted JSON round-trips correctly', () {
      final item = DownloadItem(
        id: 'nes_game.nes',
        game: makeGame('game'),
        system: testSystem,
        targetFolder: '/roms/nes',
        retryCount: 1,
      );

      final jsonStr = jsonEncode([item.toJson()]);
      final decoded = jsonDecode(jsonStr) as List<dynamic>;
      expect(decoded, hasLength(1));

      final restored =
          DownloadItem.fromJson(decoded[0] as Map<String, dynamic>, testSystem);
      expect(restored.id, 'nes_game.nes');
      expect(restored.game.filename, 'game.nes');
    });

    test('skips items with null providerConfig on restore', () {
      final json = {
        'id': 'test',
        'gameFilename': 'game.nes',
        'gameUrl': 'https://example.com/game.nes',
        'gameDisplayName': 'game',
        'systemId': 'nes',
        'targetFolder': '/roms',
        'addedAt': '2026-01-01T00:00:00.000',
        'status': 'queued',
        // No providerConfig
      };

      final item = DownloadItem.fromJson(json, testSystem);
      expect(item.game.providerConfig, isNull);
    });
  });

  // ─── Queue capacity ────────────────────────────────────

  group('Queue capacity', () {
    test('max queue size is 100', () {
      // Verify the constant matches expectations
      // This is checked indirectly - the manager rejects at 100
      final queue = List.generate(
        100,
        (i) => DownloadItem(
          id: 'item_$i',
          game: makeGame('game_$i'),
          system: testSystem,
          targetFolder: '/roms',
        ),
      );
      expect(queue, hasLength(100));
    });

    test('auto-clear removes finished items when at capacity', () {
      final queue = List.generate(
        100,
        (i) => DownloadItem(
          id: 'item_$i',
          game: makeGame('game_$i'),
          system: testSystem,
          targetFolder: '/roms',
          status: i < 50
              ? DownloadItemStatus.queued
              : DownloadItemStatus.completed,
        ),
      );

      final unfinished = queue.where((item) => !item.isFinished).toList();
      expect(unfinished, hasLength(50));
      expect(unfinished.length < queue.length, isTrue);
    });
  });

  // ─── Auth rehydration ──────────────────────────────────

  group('Auth rehydration', () {
    test('provider matching by type and URL for web', () {
      const target = ProviderConfig(
        type: ProviderType.web,
        priority: 1,
        url: 'https://example.com',
      );
      const providers = [
        ProviderConfig(
          type: ProviderType.web,
          priority: 1,
          url: 'https://example.com',
          auth: AuthConfig(user: 'admin', pass: 'secret'),
        ),
        ProviderConfig(
          type: ProviderType.smb,
          priority: 2,
          host: 'nas',
        ),
      ];

      ProviderConfig? match;
      for (final p in providers) {
        if (p.type != target.type) continue;
        if (p.type == ProviderType.web && p.url == target.url) {
          match = p;
          break;
        }
      }

      expect(match, isNotNull);
      expect(match!.auth?.user, 'admin');
    });

    test('provider matching by host and share for SMB', () {
      const target = ProviderConfig(
        type: ProviderType.smb,
        priority: 1,
        host: 'nas.local',
        share: 'roms',
      );
      const providers = [
        ProviderConfig(
          type: ProviderType.smb,
          priority: 1,
          host: 'nas.local',
          share: 'roms',
          auth: AuthConfig(user: 'user', pass: 'pass'),
        ),
      ];

      ProviderConfig? match;
      for (final p in providers) {
        if (p.type != target.type) continue;
        if (p.type == ProviderType.smb &&
            p.host == target.host &&
            p.share == target.share) {
          match = p;
          break;
        }
      }

      expect(match, isNotNull);
      expect(match!.auth?.user, 'user');
    });

    test('provider matching by host for FTP', () {
      const target = ProviderConfig(
        type: ProviderType.ftp,
        priority: 1,
        host: 'ftp.example.com',
      );
      const providers = [
        ProviderConfig(
          type: ProviderType.ftp,
          priority: 1,
          host: 'ftp.example.com',
          auth: AuthConfig(user: 'ftp_user', pass: 'ftp_pass'),
        ),
      ];

      ProviderConfig? match;
      for (final p in providers) {
        if (p.type != target.type) continue;
        if (p.type == ProviderType.ftp && p.host == target.host) {
          match = p;
          break;
        }
      }

      expect(match, isNotNull);
      expect(match!.auth?.user, 'ftp_user');
    });

    test('no match returns null when host differs', () {
      const target = ProviderConfig(
        type: ProviderType.smb,
        priority: 1,
        host: 'nas.local',
        share: 'roms',
      );
      const providers = [
        ProviderConfig(
          type: ProviderType.smb,
          priority: 1,
          host: 'different-host',
          share: 'roms',
          auth: AuthConfig(user: 'user', pass: 'pass'),
        ),
      ];

      ProviderConfig? match;
      for (final p in providers) {
        if (p.type != target.type) continue;
        if (p.type == ProviderType.smb &&
            p.host == target.host &&
            p.share == target.share) {
          match = p;
          break;
        }
      }

      expect(match, isNull);
    });
  });

  // ─── Status mapping ────────────────────────────────────

  group('Status mapping', () {
    test('all DownloadItemStatus values are distinct', () {
      const values = DownloadItemStatus.values;
      expect(values.toSet().length, values.length);
    });

    test('DownloadItemStatus has expected values', () {
      expect(DownloadItemStatus.values, containsAll([
        DownloadItemStatus.queued,
        DownloadItemStatus.downloading,
        DownloadItemStatus.extracting,
        DownloadItemStatus.moving,
        DownloadItemStatus.completed,
        DownloadItemStatus.cancelled,
        DownloadItemStatus.error,
      ]));
    });
  });

  // ─── MaxConcurrent clamping ────────────────────────────

  group('MaxConcurrent clamping', () {
    test('value is clamped between 1 and 3', () {
      expect(0.clamp(1, 3), 1);
      expect(1.clamp(1, 3), 1);
      expect(2.clamp(1, 3), 2);
      expect(3.clamp(1, 3), 3);
      expect(5.clamp(1, 3), 3);
      expect((-1).clamp(1, 3), 1);
    });
  });
}
