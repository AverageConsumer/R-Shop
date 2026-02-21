import 'dart:io';

import 'package:ftpconnect/ftpconnect.dart';

import '../../models/config/provider_config.dart';
import '../../models/config/system_config.dart';
import '../../models/game_item.dart';
import '../../models/system_model.dart';
import '../download_handle.dart';
import '../source_provider.dart';

class FtpProvider implements SourceProvider {
  @override
  final ProviderConfig config;

  FtpProvider(this.config);

  String get _remotePath => config.path ?? '/';

  FTPConnect _createClient() {
    final host = config.host;
    if (host == null || host.isEmpty) {
      throw StateError('FTP provider requires a host');
    }
    return FTPConnect(
      host,
      port: config.port ?? 21,
      user: config.auth?.user ?? 'anonymous',
      pass: config.auth?.pass ?? '',
      timeout: 30,
    );
  }

  @override
  Future<List<GameItem>> fetchGames(SystemConfig system) async {
    final ftp = _createClient();
    await ftp.connect();
    try {
      await ftp.changeDirectory(_remotePath);
      final entries = await ftp.listDirectoryContent();
      final games = <GameItem>[];

      for (final entry in entries) {
        if (entry.type != FTPEntryType.file) continue;
        final name = entry.name;
        if (!SystemModel.isGameFile(name.toLowerCase())) continue;

        final filePath =
            _remotePath.endsWith('/') ? '$_remotePath$name' : '$_remotePath/$name';

        games.add(GameItem(
          filename: name,
          displayName: GameItem.cleanDisplayName(name),
          url: filePath,
          providerConfig: config,
        ));
      }

      return games;
    } finally {
      await ftp.disconnect();
    }
  }

  @override
  Future<DownloadHandle> resolveDownload(GameItem game) async {
    FTPConnect? activeClient;
    return FtpDownloadHandle(
      downloadToFile: (dest, {onProgress}) async {
        final ftp = _createClient();
        activeClient = ftp;
        await ftp.connect();
        try {
          final (dir, fileName) = _splitPath(game.url);
          if (dir.isNotEmpty) {
            await ftp.changeDirectory(dir);
          }
          await ftp.downloadFile(fileName, dest, onProgress: onProgress);
        } finally {
          activeClient = null;
          await ftp.disconnect();
        }
      },
      disconnect: () async {
        final client = activeClient;
        if (client == null) return;
        activeClient = null;
        try {
          await client.disconnect();
        } catch (_) {}
      },
    );
  }

  @override
  Future<SourceConnectionResult> testConnection() async {
    final ftp = _createClient();
    try {
      await ftp.connect();
      await ftp.changeDirectory(_remotePath);
      return const SourceConnectionResult.ok();
    } catch (e) {
      return SourceConnectionResult.failed(e.toString());
    } finally {
      try { await ftp.disconnect(); } catch (_) {}
    }
  }

  @override
  String get displayLabel {
    final port = config.port != null && config.port != 21 ? ':${config.port}' : '';
    return 'FTP: ${config.host}$port';
  }

  /// Downloads a file from the FTP server to a local path.
  ///
  /// This is used by the download layer for FTP-based transfers
  /// since FTP files can't be fetched via HTTP.
  Future<void> downloadToFile(String remotePath, File destination) async {
    final ftp = _createClient();
    await ftp.connect();
    try {
      final (dir, fileName) = _splitPath(remotePath);
      if (dir.isNotEmpty) {
        await ftp.changeDirectory(dir);
      }
      await ftp.downloadFile(fileName, destination);
    } finally {
      await ftp.disconnect();
    }
  }

  /// Splits a remote path into (directory, filename).
  /// Returns an empty directory string when the path has no `/`.
  static (String dir, String name) _splitPath(String remotePath) {
    final lastSlash = remotePath.lastIndexOf('/');
    if (lastSlash < 0) return ('', remotePath);
    return (remotePath.substring(0, lastSlash), remotePath.substring(lastSlash + 1));
  }

}
