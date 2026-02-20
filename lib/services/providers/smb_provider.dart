import 'package:smb_connect/smb_connect.dart';

import '../../models/config/provider_config.dart';
import '../../models/config/system_config.dart';
import '../../models/game_item.dart';
import '../download_handle.dart';
import '../source_provider.dart';

class SmbProvider implements SourceProvider {
  @override
  final ProviderConfig config;

  SmbProvider(this.config);

  String get _smbRoot {
    final share = config.share!;
    final path = config.path;
    if (path == null || path.isEmpty) return '/$share';
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return '/$share$cleanPath';
  }

  Future<SmbConnect> _connect() async {
    return SmbConnect.connectAuth(
      host: config.host!,
      username: config.auth?.user ?? 'guest',
      password: config.auth?.pass ?? '',
      domain: config.auth?.domain ?? '',
    );
  }

  @override
  Future<List<GameItem>> fetchGames(SystemConfig system) async {
    final connection = await _connect();
    try {
      final folder = await connection.file(_smbRoot);
      final files = await connection.listFiles(folder);
      final games = <GameItem>[];

      for (final file in files) {
        if (!file.isFile()) continue;
        final name = file.name;
        if (!_isGameFile(name.toLowerCase())) continue;

        games.add(GameItem(
          filename: name,
          displayName: GameItem.cleanDisplayName(name),
          url: file.path,
          providerConfig: config,
        ));
      }

      return games;
    } finally {
      await connection.close();
    }
  }

  @override
  Future<DownloadHandle> resolveDownload(GameItem game) async {
    return SmbDownloadHandle(openFile: () => openFile(game.url));
  }

  @override
  Future<SourceConnectionResult> testConnection() async {
    try {
      final connection = await _connect();
      try {
        final folder = await connection.file(_smbRoot);
        await connection.listFiles(folder);
      } finally {
        await connection.close();
      }
      if (config.port != null && config.port != 445) {
        return SourceConnectionResult.ok(
          warning: 'Connected, but custom port ${config.port} is ignored. '
              'The SMB library only supports the default port (445).',
        );
      }
      return const SourceConnectionResult.ok();
    } catch (e) {
      return SourceConnectionResult.failed(e.toString());
    }
  }

  @override
  String get displayLabel => 'SMB: ${config.host}/${config.share}';

  /// Opens a read stream for the given SMB file path.
  ///
  /// This is used by the download layer to stream file contents
  /// without going through an HTTP URL.
  Future<SmbFileReader> openFile(String smbPath) async {
    final connection = await _connect();
    try {
      final file = await connection.file(smbPath);
      final stream = await connection.openRead(file);
      return SmbFileReader(
        stream: stream,
        size: file.size,
        connection: connection,
      );
    } catch (e) {
      await connection.close();
      rethrow;
    }
  }

  static bool _isGameFile(String name) {
    return _gameExtensions.any((ext) => name.endsWith(ext));
  }

  static const _gameExtensions = [
    '.zip', '.7z', '.rar',
    '.nes', '.sfc', '.z64', '.n64', '.v64',
    '.gb', '.gbc', '.gba', '.nds', '.3ds', '.cia',
    '.iso', '.cso', '.chd', '.pbp', '.cue', '.rvz',
    '.sms', '.md', '.gen', '.gg',
  ];
}

/// Handle returned by [SmbProvider.openFile] for streaming downloads.
///
/// The caller must call [close] when done to release the SMB connection.
class SmbFileReader {
  final Stream<List<int>> stream;
  final int size;
  final SmbConnect connection;

  SmbFileReader({
    required this.stream,
    required this.size,
    required this.connection,
  });

  Future<void> close() async {
    await connection.close();
  }
}
