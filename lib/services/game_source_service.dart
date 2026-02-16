import 'package:dio/dio.dart';
import 'package:html/parser.dart';

import '../models/game_item.dart';
import '../models/system_model.dart';
import 'database_service.dart';

class GameSourceService {
  final String baseUrl;
  final Dio _dio;
  final DatabaseService _databaseService;

  GameSourceService({
    required this.baseUrl,
    Dio? dio,
    DatabaseService? databaseService,
  })  : _dio = dio ?? Dio(),
        _databaseService = databaseService ?? DatabaseService();

  Future<List<GameItem>> fetchGames(
    SystemModel system, {
    bool forceRefresh = false,
  }) async {
    final cacheKey = system.sourceSlugs?.first ?? system.sourceSlug;

    if (!forceRefresh) {
      final hasCache = await _databaseService.hasCache(cacheKey);
      if (hasCache) {
        return _databaseService.getGames(cacheKey);
      }
    }

    final games = await _fetchFromNetwork(system);
    await _databaseService.saveGames(cacheKey, games);
    return games;
  }

  Future<List<GameItem>> _fetchFromNetwork(SystemModel system) async {
    final slugs = system.sourceSlugs ?? [system.sourceSlug];
    final allGames = <String, GameItem>{};

    for (final slug in slugs) {
      final games = await _fetchGamesFromSlug(slug, system.extensions);
      for (final game in games) {
        allGames[game.filename] = game;
      }
    }

    return allGames.values.toList();
  }

  Future<List<GameItem>> _fetchGamesFromSlug(
      String slug, List<String> extensions) async {
    final normalizedBase = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    final url = '$normalizedBase$slug/';
    final response = await _dio.get<String>(url);
    final document = parse(response.data);

    final links = document.querySelectorAll('a');
    final games = <GameItem>[];

    final systemExts = extensions.map((e) => e.toLowerCase()).toList();

    for (final link in links) {
      final href = link.attributes['href'];
      if (href == null) continue;

      final text = link.text.trim();

      if (text == 'Parent Directory' ||
          text == '..' ||
          text.startsWith('/') ||
          href == '/') {
        continue;
      }

      final hrefLower = href.toLowerCase();
      final isArchive = hrefLower.endsWith('.zip') || hrefLower.endsWith('.7z');
      final isSystemFile = systemExts.any((ext) => hrefLower.endsWith(ext));
      final isGameFile = isArchive || isSystemFile;

      if (isGameFile) {
        final decodedFilename = Uri.decodeFull(href);
        games.add(GameItem(
          filename: decodedFilename,
          displayName: GameItem.cleanDisplayName(decodedFilename),
          url: '$url$href',
        ));
      }
    }

    return games;
  }

  Future<List<GameItem>> searchGames(String query) async {
    return _databaseService.searchGames(query);
  }

  Future<void> updateCoverUrl(String filename, String coverUrl) async {
    await _databaseService.updateGameCover(filename, coverUrl);
  }
}
