import 'package:flutter_test/flutter_test.dart';
import 'package:retro_eshop/models/config/provider_config.dart';
import 'package:retro_eshop/models/config/system_config.dart';
import 'package:retro_eshop/models/game_item.dart';
import 'package:retro_eshop/services/download_handle.dart';
import 'package:retro_eshop/services/native_smb_service.dart';
import 'package:retro_eshop/services/providers/smb_provider.dart';

class FakeNativeSmbService extends NativeSmbService {
  List<SmbFileEntry> stubbedFiles = [];
  ({bool success, String? error}) stubbedTestResult = (success: true, error: null);
  Exception? listError;
  Exception? testError;

  // Track calls for assertion
  Map<String, dynamic>? lastListFilesArgs;
  Map<String, dynamic>? lastTestConnectionArgs;

  @override
  Future<List<SmbFileEntry>> listFiles({
    required String host,
    int port = 445,
    required String share,
    required String path,
    String user = 'guest',
    String pass = '',
    String domain = '',
    int maxDepth = 0,
  }) async {
    lastListFilesArgs = {
      'host': host,
      'port': port,
      'share': share,
      'path': path,
      'user': user,
      'pass': pass,
      'domain': domain,
      'maxDepth': maxDepth,
    };
    if (listError != null) throw listError!;
    return stubbedFiles;
  }

  @override
  Future<({bool success, String? error})> testConnection({
    required String host,
    int port = 445,
    required String share,
    String path = '',
    String user = 'guest',
    String pass = '',
    String domain = '',
  }) async {
    lastTestConnectionArgs = {
      'host': host,
      'port': port,
      'share': share,
      'path': path,
      'user': user,
      'pass': pass,
      'domain': domain,
    };
    if (testError != null) throw testError!;
    return stubbedTestResult;
  }
}

void main() {
  const systemConfig = SystemConfig(
    id: 'psx',
    name: 'PlayStation',
    targetFolder: '/sdcard/Roms/PSX',
    providers: [],
  );

  late FakeNativeSmbService fakeSmbService;

  setUp(() {
    fakeSmbService = FakeNativeSmbService();
  });

  group('SmbProvider', () {
    group('construction', () {
      test('returns failed on null host', () async {
        const config = ProviderConfig(type: ProviderType.smb, priority: 1, share: 'roms');
        final provider = SmbProvider(config, fakeSmbService);
        final result = await provider.testConnection();
        expect(result.success, false);
        expect(result.error, contains('requires a host'));
      });

      test('returns failed on null share', () async {
        const config = ProviderConfig(type: ProviderType.smb, priority: 1, host: 'nas');
        final provider = SmbProvider(config, fakeSmbService);
        final result = await provider.testConnection();
        expect(result.success, false);
        expect(result.error, contains('requires a share'));
      });

      test('displayLabel shows host/share', () {
        const config = ProviderConfig(type: ProviderType.smb, priority: 1, host: 'mynas', share: 'roms');
        final provider = SmbProvider(config, fakeSmbService);
        expect(provider.displayLabel, 'SMB: mynas/roms');
      });
    });

    group('fetchGames', () {
      test('returns games from root-level files', () async {
        const config = ProviderConfig(
          type: ProviderType.smb,
          priority: 1,
          host: '192.168.1.100',
          share: 'roms',
          path: '/psx',
        );
        final provider = SmbProvider(config, fakeSmbService);

        fakeSmbService.stubbedFiles = [
          const SmbFileEntry(name: 'Crash Bandicoot.bin', path: 'Crash Bandicoot.bin', isDirectory: false, size: 1024),
          const SmbFileEntry(name: 'Spyro.iso', path: 'Spyro.iso', isDirectory: false, size: 2048),
          const SmbFileEntry(name: 'readme.txt', path: 'readme.txt', isDirectory: false, size: 10),
        ];

        final games = await provider.fetchGames(systemConfig);
        expect(games.length, 2);
        expect(games[0].filename, 'Crash Bandicoot.bin');
        expect(games[1].filename, 'Spyro.iso');
      });

      test('skips directories', () async {
        const config = ProviderConfig(type: ProviderType.smb, priority: 1, host: 'nas', share: 'roms');
        final provider = SmbProvider(config, fakeSmbService);

        fakeSmbService.stubbedFiles = [
          const SmbFileEntry(name: 'subdir', path: 'subdir', isDirectory: true, size: 0),
          const SmbFileEntry(name: 'game.bin', path: 'game.bin', isDirectory: false, size: 100),
        ];

        final games = await provider.fetchGames(systemConfig);
        expect(games.length, 1);
        expect(games[0].filename, 'game.bin');
      });

      test('creates folder GameItem for multi-file subdirectories', () async {
        const config = ProviderConfig(type: ProviderType.smb, priority: 1, host: 'nas', share: 'roms');
        final provider = SmbProvider(config, fakeSmbService);

        fakeSmbService.stubbedFiles = [
          const SmbFileEntry(name: 'disc1.bin', path: 'FF7/disc1.bin', isDirectory: false, size: 100, parentPath: 'FF7'),
          const SmbFileEntry(name: 'disc2.bin', path: 'FF7/disc2.bin', isDirectory: false, size: 100, parentPath: 'FF7'),
        ];

        final games = await provider.fetchGames(systemConfig);
        expect(games.length, 1);
        expect(games[0].filename, 'FF7');
        expect(games[0].isFolder, true);
      });

      test('promotes single-file subfolder to flat GameItem', () async {
        const config = ProviderConfig(type: ProviderType.smb, priority: 1, host: 'nas', share: 'roms');
        final provider = SmbProvider(config, fakeSmbService);

        fakeSmbService.stubbedFiles = [
          const SmbFileEntry(name: 'game.bin', path: 'MyGame/game.bin', isDirectory: false, size: 100, parentPath: 'MyGame'),
        ];

        final games = await provider.fetchGames(systemConfig);
        expect(games.length, 1);
        expect(games[0].filename, 'game.bin');
        expect(games[0].isFolder, false);
      });

      test('returns empty list when no game files found', () async {
        const config = ProviderConfig(type: ProviderType.smb, priority: 1, host: 'nas', share: 'roms');
        final provider = SmbProvider(config, fakeSmbService);

        fakeSmbService.stubbedFiles = [
          const SmbFileEntry(name: 'readme.txt', path: 'readme.txt', isDirectory: false, size: 10),
        ];

        final games = await provider.fetchGames(systemConfig);
        expect(games, isEmpty);
      });

      test('passes correct parameters to NativeSmbService', () async {
        const config = ProviderConfig(
          type: ProviderType.smb,
          priority: 1,
          host: '10.0.0.5',
          port: 4455,
          share: 'games',
          path: '/retro/psx',
          auth: AuthConfig(user: 'admin', pass: 'secret', domain: 'WORKGROUP'),
        );
        final provider = SmbProvider(config, fakeSmbService);
        fakeSmbService.stubbedFiles = [];

        await provider.fetchGames(systemConfig);

        expect(fakeSmbService.lastListFilesArgs!['host'], '10.0.0.5');
        expect(fakeSmbService.lastListFilesArgs!['port'], 4455);
        expect(fakeSmbService.lastListFilesArgs!['share'], 'games');
        expect(fakeSmbService.lastListFilesArgs!['path'], '/retro/psx');
        expect(fakeSmbService.lastListFilesArgs!['user'], 'admin');
        expect(fakeSmbService.lastListFilesArgs!['pass'], 'secret');
        expect(fakeSmbService.lastListFilesArgs!['domain'], 'WORKGROUP');
        expect(fakeSmbService.lastListFilesArgs!['maxDepth'], 3);
      });
    });

    group('resolveDownload', () {
      test('returns NativeSmbDownloadHandle for single file', () async {
        const config = ProviderConfig(type: ProviderType.smb, priority: 1, host: 'nas', share: 'roms');
        final provider = SmbProvider(config, fakeSmbService);

        const game = GameItem(
          filename: 'game.bin',
          displayName: 'Game',
          url: '/psx/game.bin',
          providerConfig: config,
        );

        final handle = await provider.resolveDownload(game);
        expect(handle, isA<NativeSmbDownloadHandle>());
        final smbHandle = handle as NativeSmbDownloadHandle;
        expect(smbHandle.host, 'nas');
        expect(smbHandle.share, 'roms');
        expect(smbHandle.filePath, '/psx/game.bin');
      });

      test('returns NativeSmbFolderDownloadHandle for folder', () async {
        const config = ProviderConfig(type: ProviderType.smb, priority: 1, host: 'nas', share: 'roms');
        final provider = SmbProvider(config, fakeSmbService);

        const game = GameItem(
          filename: 'FF7',
          displayName: 'FF7',
          url: '/psx/FF7',
          providerConfig: config,
          isFolder: true,
        );

        final handle = await provider.resolveDownload(game);
        expect(handle, isA<NativeSmbFolderDownloadHandle>());
        final folderHandle = handle as NativeSmbFolderDownloadHandle;
        expect(folderHandle.folderPath, '/psx/FF7');
      });
    });

    group('testConnection', () {
      test('returns ok on success', () async {
        const config = ProviderConfig(type: ProviderType.smb, priority: 1, host: 'nas', share: 'roms');
        final provider = SmbProvider(config, fakeSmbService);
        fakeSmbService.stubbedTestResult = (success: true, error: null);

        final result = await provider.testConnection();
        expect(result.success, true);
      });

      test('returns failed on connection error', () async {
        const config = ProviderConfig(type: ProviderType.smb, priority: 1, host: 'nas', share: 'roms');
        final provider = SmbProvider(config, fakeSmbService);
        fakeSmbService.stubbedTestResult = (success: false, error: 'Access denied');

        final result = await provider.testConnection();
        expect(result.success, false);
        expect(result.error, 'Access denied');
      });

      test('returns failed on exception', () async {
        const config = ProviderConfig(type: ProviderType.smb, priority: 1, host: 'nas', share: 'roms');
        final provider = SmbProvider(config, fakeSmbService);
        fakeSmbService.testError = Exception('Network unreachable');

        final result = await provider.testConnection();
        expect(result.success, false);
        expect(result.error, contains('Network unreachable'));
      });

      test('passes auth parameters', () async {
        const config = ProviderConfig(
          type: ProviderType.smb,
          priority: 1,
          host: 'nas',
          share: 'roms',
          auth: AuthConfig(user: 'admin', pass: 'pass123', domain: 'HOME'),
        );
        final provider = SmbProvider(config, fakeSmbService);

        await provider.testConnection();
        expect(fakeSmbService.lastTestConnectionArgs!['user'], 'admin');
        expect(fakeSmbService.lastTestConnectionArgs!['pass'], 'pass123');
        expect(fakeSmbService.lastTestConnectionArgs!['domain'], 'HOME');
      });

      test('uses guest defaults when no auth', () async {
        const config = ProviderConfig(type: ProviderType.smb, priority: 1, host: 'nas', share: 'roms');
        final provider = SmbProvider(config, fakeSmbService);

        await provider.testConnection();
        expect(fakeSmbService.lastTestConnectionArgs!['user'], 'guest');
        expect(fakeSmbService.lastTestConnectionArgs!['pass'], '');
        expect(fakeSmbService.lastTestConnectionArgs!['domain'], '');
      });
    });
  });
}
