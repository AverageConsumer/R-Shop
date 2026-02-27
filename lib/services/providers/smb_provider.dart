import 'package:path/path.dart' as p;

import '../../models/config/provider_config.dart';
import '../../models/config/system_config.dart';
import '../../models/game_item.dart';
import '../../models/system_model.dart';
import '../download_handle.dart';
import '../native_smb_service.dart';
import '../source_provider.dart';

class SmbProvider implements SourceProvider {
  @override
  final ProviderConfig config;

  final NativeSmbService _smbService;

  SmbProvider(this.config, this._smbService);

  String get _shareName {
    final share = config.share;
    if (share == null || share.isEmpty) {
      throw StateError('SMB provider requires a share name');
    }
    return share;
  }

  String get _path => config.path ?? '';
  String get _host {
    final host = config.host;
    if (host == null || host.isEmpty) {
      throw StateError('SMB provider requires a host');
    }
    return host;
  }

  int get _port => config.port ?? 445;
  String get _user => config.auth?.user ?? 'guest';
  String get _pass => config.auth?.pass ?? '';
  String get _domain => config.auth?.domain ?? '';

  static const int _maxScanDepth = 3;

  @override
  Future<List<GameItem>> fetchGames(SystemConfig system) async {
    final entries = await _smbService.listFiles(
      host: _host,
      port: _port,
      share: _shareName,
      path: _path,
      user: _user,
      pass: _pass,
      domain: _domain,
      maxDepth: _maxScanDepth,
    );

    final games = <GameItem>[];
    // Track game files per folder: folderPath → list of file entries
    final folderFiles = <String, List<SmbFileEntry>>{};
    final folderNames = <String, String>{}; // folderPath → display name

    for (final entry in entries) {
      if (entry.isDirectory) continue;
      if (!SystemModel.isGameFile(entry.name.toLowerCase())) continue;

      if (entry.parentPath == null) {
        // Root-level game file
        games.add(GameItem(
          filename: entry.name,
          displayName: GameItem.cleanDisplayName(entry.name),
          url: entry.path,
          providerConfig: config,
        ));
      } else {
        // File inside a subdirectory — extract the immediate parent directory
        // entry.path is e.g. "root/A/Ace Combat/game.bin"
        // The game folder is the directory directly containing this file
        final lastSlash = entry.path.lastIndexOf('/');
        if (lastSlash > 0) {
          final folderPath = entry.path.substring(0, lastSlash);
          final folderName = p.posix.basename(folderPath);
          folderNames.putIfAbsent(folderPath, () => folderName);
          folderFiles.putIfAbsent(folderPath, () => []).add(entry);
        }
      }
    }

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
  }

  @override
  Future<DownloadHandle> resolveDownload(GameItem game) async {
    if (game.isFolder) {
      return NativeSmbFolderDownloadHandle(
        host: _host,
        port: _port,
        share: _shareName,
        folderPath: game.url,
        user: _user,
        pass: _pass,
        domain: _domain,
      );
    }
    return NativeSmbDownloadHandle(
      host: _host,
      port: _port,
      share: _shareName,
      filePath: game.url,
      user: _user,
      pass: _pass,
      domain: _domain,
    );
  }

  @override
  Future<SourceConnectionResult> testConnection() async {
    try {
      final result = await _smbService.testConnection(
        host: _host,
        port: _port,
        share: _shareName,
        path: _path,
        user: _user,
        pass: _pass,
        domain: _domain,
      );
      if (result.success) {
        return const SourceConnectionResult.ok();
      }
      return SourceConnectionResult.failed(
        result.error ?? 'Connection failed',
      );
    } catch (e) {
      return SourceConnectionResult.failed(e.toString());
    }
  }

  @override
  String get displayLabel => 'SMB: $_host/$_shareName';
}
