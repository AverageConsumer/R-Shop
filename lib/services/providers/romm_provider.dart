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

export '../../models/game_metadata_info.dart' show SiblingInfo;

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

    // RomM 4.8+ Client API Token (preferred — granular scopes, revocable).
    if (auth.clientToken != null && auth.clientToken!.isNotEmpty) {
      return {'Authorization': 'Bearer ${auth.clientToken}'};
    }
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

      int? releaseYear;
      String? releaseDate;
      if (rom.firstReleaseDate != null) {
        // RomM/IGDB gives Unix seconds, but guard against ms values
        final raw = rom.firstReleaseDate!;
        final ms = raw > 9999999999 ? raw : raw * 1000;
        final dt = DateTime.fromMillisecondsSinceEpoch(ms);
        releaseYear = dt.year;
        releaseDate = dt.toIso8601String().split('T').first;
      }

      // Build full screenshot URLs (resolve relative paths)
      String? screenshotsCsv;
      if (rom.mergedScreenshots.isNotEmpty) {
        final fullUrls = rom.mergedScreenshots.map((s) {
          if (s.toLowerCase().startsWith('http')) return s;
          return '$_baseUrl$s';
        }).toList();
        screenshotsCsv = fullUrls.join(',');
      }

      // Serialize siblings to JSON
      String? siblingsJson;
      if (rom.siblings.isNotEmpty) {
        final siblingData = rom.siblings.map((s) => {
              'name': s.name,
              if (s.fsNameNoExt != null) 'filename': s.fsNameNoExt,
            }).toList();
        siblingsJson = jsonEncode(siblingData);
      }

      final info = GameMetadataInfo(
        filename: rom.fileName,
        systemSlug: system.id,
        summary: rom.summary,
        genres: rom.genres,
        developer: rom.developer,
        publisher: rom.publisher,
        releaseYear: releaseYear,
        releaseDate: releaseDate,
        gameModes: rom.gameModes,
        rating: rom.averageRating,
        franchises: rom.franchises,
        themes: rom.themes,
        playerPerspectives: rom.playerPerspectives,
        ageRating: rom.ageRatings,
        screenshots: screenshotsCsv,
        fileSizeBytes: rom.fileSizeBytes,
        siblings: siblingsJson,
        lastUpdated: now,
      );

      if (info.hasContent) {
        metadata.add(info);
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
