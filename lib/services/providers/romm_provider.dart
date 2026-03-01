import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../models/config/provider_config.dart';
import '../../models/config/system_config.dart';
import '../../models/game_item.dart';
import '../../models/game_metadata_info.dart';
import '../database_service.dart';
import '../download_handle.dart';
import '../romm_api_service.dart';
import '../source_provider.dart';

class RommProvider implements SourceProvider {
  @override
  final ProviderConfig config;

  final RommApiService _api;

  RommProvider(this.config, {RommApiService? api})
      : _api = api ?? RommApiService();

  String get _baseUrl {
    final url = config.url;
    if (url == null || url.isEmpty) {
      throw StateError('RomM provider requires a URL');
    }
    return url;
  }

  AuthConfig? get _auth => config.auth;

  Map<String, String> get _authHeaders {
    final auth = _auth;
    if (auth == null) return {};

    if (auth.apiKey != null && auth.apiKey!.isNotEmpty) {
      return {'Authorization': 'Bearer ${auth.apiKey}'};
    }
    if (auth.user != null && auth.user!.isNotEmpty) {
      final credentials = base64Encode(
        utf8.encode('${auth.user}:${auth.pass ?? ''}'),
      );
      return {'Authorization': 'Basic $credentials'};
    }
    return {};
  }

  @override
  Future<List<GameItem>> fetchGames(SystemConfig system) async {
    final platformId = config.platformId;
    if (platformId == null) {
      throw StateError('RomM provider requires a platformId');
    }

    final roms = await _api.fetchRoms(_baseUrl, platformId, auth: _auth);
    final games = <GameItem>[];
    final metadata = <GameMetadataInfo>[];
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final rom in roms) {
      final downloadUrl = _api.buildRomDownloadUrl(_baseUrl, rom);
      final coverUrl = _api.buildCoverUrl(_baseUrl, rom);

      games.add(GameItem(
        filename: rom.fileName,
        displayName: rom.name.isNotEmpty
            ? rom.name
            : GameItem.cleanDisplayName(rom.fileName),
        url: downloadUrl,
        cachedCoverUrl: coverUrl,
        providerConfig: config,
      ));

      final releaseYear = rom.firstReleaseDate != null
          ? DateTime.fromMillisecondsSinceEpoch(
                  rom.firstReleaseDate! * 1000)
              .year
          : null;

      if (rom.summary != null ||
          rom.genres != null ||
          rom.developer != null ||
          releaseYear != null) {
        metadata.add(GameMetadataInfo(
          filename: rom.fileName,
          systemSlug: system.id,
          summary: rom.summary,
          genres: rom.genres,
          developer: rom.developer,
          releaseYear: releaseYear,
          gameModes: rom.gameModes,
          rating: rom.averageRating,
          lastUpdated: now,
        ));
      }
    }

    // Persist metadata as side effect (non-blocking)
    if (metadata.isNotEmpty) {
      DatabaseService().saveGameMetadata(system.id, metadata).catchError((e) {
        debugPrint('RommProvider: failed to save metadata: $e');
      });
    }

    return games;
  }

  @override
  Future<DownloadHandle> resolveDownload(GameItem game) async {
    return HttpDownloadHandle(
      url: game.url,
      headers: _authHeaders.isNotEmpty ? _authHeaders : null,
    );
  }

  @override
  Future<SourceConnectionResult> testConnection() async {
    return _api.testConnection(_baseUrl, auth: _auth);
  }

  @override
  String get displayLabel {
    final name = config.platformName;
    if (name != null) return 'RomM: $name';
    return 'RomM: ${config.url}';
  }
}
