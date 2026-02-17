import 'dart:io';

import 'package:ftpconnect/ftpconnect.dart';

import '../../models/config/provider_config.dart';
import '../../models/config/system_config.dart';
import '../../models/game_item.dart';
import '../download_handle.dart';
import '../source_provider.dart';

class FtpProvider implements SourceProvider {
  @override
  final ProviderConfig config;

  FtpProvider(this.config);

  String get _remotePath => config.path ?? '/';

  FTPConnect _createClient() {
    return FTPConnect(
      config.host!,
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
        if (!_isGameFile(name.toLowerCase())) continue;

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
    return FtpDownloadHandle(downloadToFile: (dest) => downloadToFile(game.url, dest));
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
      // Navigate to the parent directory
      final lastSlash = remotePath.lastIndexOf('/');
      if (lastSlash > 0) {
        await ftp.changeDirectory(remotePath.substring(0, lastSlash));
      }
      final fileName = remotePath.substring(lastSlash + 1);
      await ftp.downloadFile(fileName, destination);
    } finally {
      await ftp.disconnect();
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
