import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:ftpconnect/ftpconnect.dart';
import 'package:path/path.dart' as p;

import '../../models/config/provider_config.dart';
import '../../utils/network_constants.dart';
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

  // Matches hostname, IPv4, or bracketed IPv6
  static final _hostPattern = RegExp(
    r'^([a-zA-Z0-9]([a-zA-Z0-9\-]*[a-zA-Z0-9])?\.)*[a-zA-Z0-9]([a-zA-Z0-9\-]*[a-zA-Z0-9])?$'
    r'|'
    r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$'
    r'|'
    r'^\[[:0-9a-fA-F]+\]$',
  );

  FTPConnect _createClient() {
    final host = config.host;
    if (host == null || host.isEmpty) {
      throw StateError('FTP provider requires a host');
    }
    if (!_hostPattern.hasMatch(host)) {
      throw StateError('Invalid FTP host format: $host');
    }
    return FTPConnect(
      host,
      port: config.port ?? 21,
      user: config.auth?.user ?? 'anonymous',
      pass: config.auth?.pass ?? '',
      timeout: 30,
    );
  }

  static const int _maxScanDepth = 3;
  static const Duration _scanTimeout = Duration(minutes: 5);

  @override
  Future<List<GameItem>> fetchGames(SystemConfig system) async {
    final ftp = _createClient();
    await ftp.connect().timeout(NetworkTimeouts.ftpConnect);
    try {
      final games = <GameItem>[];
      // Track game files per folder: folderPath → list of (name, path)
      final folderFiles = <String, List<({String name, String path})>>{};
      final folderNames = <String, String>{}; // folderPath → display name

      // Wrap recursive scan with overall timeout to prevent runaway recursion
      await _scanDirectory(ftp, _remotePath, 0, games, folderFiles, folderNames)
          .timeout(_scanTimeout, onTimeout: () {
        debugPrint('FtpProvider: scan timed out after $_scanTimeout');
      });

      // Promote single-file folders to flat GameItems
      for (final entry in folderFiles.entries) {
        final files = entry.value;
        if (files.length == 1) {
          // Single file in subfolder → regular flat GameItem
          final file = files.first;
          games.add(GameItem(
            filename: file.name,
            displayName: GameItem.cleanDisplayName(file.name),
            url: file.path,
            providerConfig: config,
          ));
        } else {
          // Multiple files → folder GameItem (existing behavior)
          final folderName = folderNames[entry.key]!;
          games.add(GameItem(
            filename: folderName,
            displayName: GameItem.cleanDisplayName(folderName),
            url: entry.key,
            providerConfig: config,
            isFolder: true,
          ));
        }
      }

      return games;
    } finally {
      await ftp.disconnect();
    }
  }

  Future<void> _scanDirectory(
    FTPConnect ftp,
    String dirPath,
    int depth,
    List<GameItem> games,
    Map<String, List<({String name, String path})>> folderFiles,
    Map<String, String> folderNames,
  ) async {
    await ftp.changeDirectory(dirPath).timeout(NetworkTimeouts.ftpCommand);
    final entries = await ftp
        .listDirectoryContent()
        .timeout(NetworkTimeouts.ftpList);

    final subdirs = <String>[];

    for (final entry in entries) {
      final name = entry.name;
      if (entry.type == FTPEntryType.file) {
        if (!SystemModel.isGameFile(name.toLowerCase())) continue;
        final filePath =
            dirPath.endsWith('/') ? '$dirPath$name' : '$dirPath/$name';

        if (depth == 0) {
          // Root-level game file
          games.add(GameItem(
            filename: name,
            displayName: GameItem.cleanDisplayName(name),
            url: filePath,
            providerConfig: config,
          ));
        } else {
          // File in a subdirectory — track per folder for promotion check
          final folderName = p.posix.basename(dirPath);
          folderNames.putIfAbsent(dirPath, () => folderName);
          folderFiles.putIfAbsent(dirPath, () => []).add((name: name, path: filePath));
        }
      } else if (entry.type == FTPEntryType.dir &&
          !name.startsWith('.') &&
          depth < _maxScanDepth) {
        subdirs.add(name);
      }
    }

    // Recurse into subdirectories
    for (final subName in subdirs) {
      final subPath =
          dirPath.endsWith('/') ? '$dirPath$subName' : '$dirPath/$subName';
      try {
        await _scanDirectory(ftp, subPath, depth + 1, games, folderFiles, folderNames);
      } catch (e) {
        debugPrint('FtpProvider: failed to scan subdirectory $subPath: $e');
      }
    }
  }

  @override
  Future<DownloadHandle> resolveDownload(GameItem game) async {
    if (game.isFolder) {
      FTPConnect? activeClient;
      return FtpFolderDownloadHandle(
        listFiles: () async {
          final ftp = _createClient();
          activeClient = ftp;
          await ftp.connect().timeout(NetworkTimeouts.ftpConnect);
          try {
            await ftp.changeDirectory(game.url).timeout(NetworkTimeouts.ftpCommand);
            final entries = await ftp
                .listDirectoryContent()
                .timeout(NetworkTimeouts.ftpList);
            return entries
                .where((e) => e.type == FTPEntryType.file)
                .map((e) => e.name)
                .toList();
          } finally {
            activeClient = null;
            await ftp.disconnect();
          }
        },
        downloadFile: (remotePath, dest, {onProgress}) async {
          final ftp = _createClient();
          activeClient = ftp;
          await ftp.connect().timeout(NetworkTimeouts.ftpConnect);
          try {
            final (dir, fileName) = _splitPath(remotePath);
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
          } catch (e) {
            debugPrint('FtpProvider: disconnect failed: $e');
          }
        },
      );
    }

    FTPConnect? activeClient;
    return FtpDownloadHandle(
      downloadToFile: (dest, {onProgress}) async {
        final ftp = _createClient();
        activeClient = ftp;
        await ftp.connect().timeout(NetworkTimeouts.ftpConnect);
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
        } catch (e) {
          debugPrint('FtpProvider: disconnect failed: $e');
        }
      },
    );
  }

  @override
  Future<SourceConnectionResult> testConnection() async {
    final ftp = _createClient();
    try {
      await ftp.connect().timeout(NetworkTimeouts.ftpConnect);
      await ftp.changeDirectory(_remotePath).timeout(NetworkTimeouts.ftpCommand);
      return const SourceConnectionResult.ok();
    } catch (e) {
      return SourceConnectionResult.failed(e.toString());
    } finally {
      try { await ftp.disconnect(); } catch (e) {
        debugPrint('FtpProvider: testConnection disconnect failed: $e');
      }
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
    await ftp.connect().timeout(NetworkTimeouts.ftpConnect);
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
    // Strip trailing slash
    final path = remotePath.endsWith('/') && remotePath.length > 1
        ? remotePath.substring(0, remotePath.length - 1)
        : remotePath;
    final lastSlash = path.lastIndexOf('/');
    if (lastSlash < 0) return ('', path);
    final name = path.substring(lastSlash + 1);
    if (name.isEmpty) return ('/', '');
    return (path.substring(0, lastSlash), name);
  }

}
