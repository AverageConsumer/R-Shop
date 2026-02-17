import '../models/config/provider_config.dart';
import '../models/config/system_config.dart';
import '../models/game_item.dart';
import 'download_handle.dart';

class SourceConnectionResult {
  final bool success;
  final String? error;
  final String? warning;

  const SourceConnectionResult.ok({this.warning})
      : success = true,
        error = null;

  const SourceConnectionResult.failed(this.error)
      : success = false,
        warning = null;
}

abstract class SourceProvider {
  ProviderConfig get config;

  Future<List<GameItem>> fetchGames(SystemConfig system);

  Future<DownloadHandle> resolveDownload(GameItem game);

  Future<SourceConnectionResult> testConnection();

  String get displayLabel;
}
