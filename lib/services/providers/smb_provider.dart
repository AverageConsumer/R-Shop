import 'package:smb_connect/smb_connect.dart';

import '../../models/config/provider_config.dart';
import '../../models/config/system_config.dart';
import '../../models/game_item.dart';
import '../../models/system_model.dart';
import '../download_handle.dart';
import '../source_provider.dart';

class SmbProvider implements SourceProvider {
  static const _timeout = Duration(seconds: 30);

  @override
  final ProviderConfig config;

  SmbProvider(this.config);

  String get _smbRoot {
    final share = config.share;
    if (share == null || share.isEmpty) {
      throw StateError('SMB provider requires a share name');
    }
    final path = config.path;
    if (path == null || path.isEmpty) return '/$share';
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return '/$share$cleanPath';
  }

  Future<SmbConnect> _connect() async {
    final host = config.host;
    if (host == null || host.isEmpty) {
      throw StateError('SMB provider requires a host');
    }
    return SmbConnect.connectAuth(
      host: host,
      username: config.auth?.user ?? 'guest',
      password: config.auth?.pass ?? '',
      domain: config.auth?.domain ?? '',
    ).timeout(_timeout);
  }

  @override
  Future<List<GameItem>> fetchGames(SystemConfig system) async {
    final connection = await _connect();
    try {
      final folder = await connection.file(_smbRoot).timeout(_timeout);
      final files = await connection.listFiles(folder).timeout(_timeout);
      final games = <GameItem>[];

      for (final file in files) {
        if (!file.isFile()) continue;
        final name = file.name;
        if (!SystemModel.isGameFile(name.toLowerCase())) continue;

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
        final folder = await connection.file(_smbRoot).timeout(_timeout);
        await connection.listFiles(folder).timeout(_timeout);
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
      final file = await connection.file(smbPath).timeout(_timeout);
      final stream = await connection.openRead(file).timeout(_timeout);
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

}

/// Handle returned by [SmbProvider.openFile] for streaming downloads.
///
/// The caller MUST call [close] when done to release the SMB connection.
class SmbFileReader {
  final Stream<List<int>> stream;
  final int size;
  final SmbConnect connection;
  bool _closed = false;

  SmbFileReader({
    required this.stream,
    required this.size,
    required this.connection,
  });

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await connection.close();
  }
}
