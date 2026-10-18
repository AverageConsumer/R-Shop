import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:retro_eshop/models/config/app_config.dart';
import 'package:retro_eshop/models/config/provider_config.dart';
import 'package:retro_eshop/models/config/source.dart';
import 'package:retro_eshop/models/config/system_config.dart';
import 'package:retro_eshop/models/download_item.dart';
import 'package:retro_eshop/models/game_item.dart';
import 'package:retro_eshop/models/system_model.dart';
import 'package:retro_eshop/providers/source_health_providers.dart';
import 'package:retro_eshop/services/config_parser.dart';
import 'package:retro_eshop/services/config_storage_service.dart';
import 'package:retro_eshop/services/download_service.dart';
import 'package:retro_eshop/services/download_handle.dart';
import 'package:retro_eshop/services/native_smb_service.dart';
import 'package:retro_eshop/services/providers/romm_provider.dart';
import 'package:retro_eshop/services/source_resolver.dart';
import 'package:retro_eshop/services/sources_notifier.dart';
import 'package:retro_eshop/services/unified_game_service.dart';

Future<String> _serve(FutureOr<void> Function(HttpRequest) handle) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  addTearDown(() => server.close(force: true));
  server.listen((request) async {
    await handle(request);
    await request.response.close();
  });
  return 'http://127.0.0.1:${server.port}';
}

void _listing(HttpRequest request, List<String> games) {
  request.response.headers.contentType = ContentType.html;
  request.response.write(games.map((g) => '<a href="$g">$g</a>').join());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // These integration tests use only loopback servers, not Flutter's HTTP 400 stub.
  HttpOverrides.global = null;

  test(
      'real sync keeps independent sources, priority, duplicate alternatives and returns to LAN',
      () async {
    var lanOnline = false;
    var lanHits = 0;
    var wanHits = 0;
    var otherHits = 0;
    final lan = await _serve((r) {
      lanHits++;
      if (!lanOnline) {
        r.response.statusCode = 503;
        return;
      }
      _listing(r, ['shared.nes', 'lan.nes']);
    });
    final wan = await _serve((r) {
      wanHits++;
      _listing(r, ['shared.nes', 'wan.nes']);
    });
    final other = await _serve((r) {
      otherHits++;
      _listing(r, ['shared.nes', 'other.nes']);
    });
    final sources = [
      Source(
          id: 'home',
          name: 'Home',
          type: SourceType.web,
          url: lan,
          priority: 1,
          fallbackUrls: [wan]),
      Source(
          id: 'other',
          name: 'Other',
          type: SourceType.web,
          url: other,
          priority: 2),
    ];
    const system = SystemConfig(
        id: 'nes',
        name: 'NES',
        targetFolder: '/nes',
        providers: [],
        manualMappings: [
          SystemSourceMapping(sourceId: 'home', remotePath: '/nes'),
          SystemSourceMapping(sourceId: 'other', remotePath: '/nes')
        ]);
    final resolved = system.copyWith(
        providers: SourceResolver.providersFor(system, sources));
    final games = await UnifiedGameService().fetchGamesForSystem(resolved);
    expect(games.map((g) => g.filename),
        containsAll(['wan.nes', 'other.nes', 'shared.nes']));
    final shared = games.singleWhere((g) => g.filename == 'shared.nes');
    expect(shared.providerConfig!.sourceId, 'home');
    expect(shared.providerConfig!.url, '$lan/nes');
    expect(shared.alternativeSources.single.providerConfig.sourceId, 'other');
    expect([lanHits, wanHits, otherHits], [1, 1, 1]);
    lanOnline = true;
    final refreshed = await UnifiedGameService().fetchGamesForSystem(resolved);
    expect(refreshed.map((g) => g.filename),
        containsAll(['lan.nes', 'other.nes']));
    expect(refreshed.map((g) => g.filename), isNot(contains('wan.nes')));
    expect([lanHits, wanHits, otherHits], [2, 1, 2]);
  });

  test('all endpoint failures do not report an empty successful library',
      () async {
    final lan = await _serve((r) => r.response.statusCode = 503);
    final wan = await _serve((r) => r.response.statusCode = 502);
    final system =
        SystemConfig(id: 'nes', name: 'NES', targetFolder: '/nes', providers: [
      ProviderConfig(
          type: ProviderType.web, priority: 1, url: lan, fallbackUrls: [wan])
    ]);
    await expectLater(
        UnifiedGameService().fetchGamesForSystem(system), throwsStateError);
  });

  test(
      'offline LAN falls back for RomM data and cover URLs while source identity stays canonical',
      () async {
    final closed = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final lan = 'http://127.0.0.1:${closed.port}/romm';
    await closed.close(force: true);
    final wan = await _serve((r) {
      expect(r.uri.path, '/proxy/api/roms');
      expect(r.uri.queryParameters['platform_ids'], '17');
      r.response.headers.contentType = ContentType.json;
      r.response.write(
          '[{"id":1,"name":"Game","fs_name":"game.nes","platform_id":17,"path_cover_small":"/cover.png"}]');
    });
    final config = ProviderConfig(
        type: ProviderType.romm,
        priority: 1,
        url: lan,
        fallbackUrls: ['$wan/proxy'],
        platformId: 17,
        managedBySource: true,
        sourceId: 'home');
    final provider = RommProvider(config);
    final games = await provider.fetchGames(SystemConfig(
        id: 'nes', name: 'NES', targetFolder: '/nes', providers: [config]));
    final game = games.single;
    expect(game.providerConfig!.url, lan);
    expect(game.providerConfig!.sourceId, 'home');
    expect(game.url, '$wan/proxy/api/roms/1/content/game.nes');
    expect(game.cachedCoverUrl, '$wan/proxy/cover.png');
    final handle = await provider.resolveDownload(game) as HttpDownloadHandle;
    expect(handle.url, '$lan/api/roms/1/content/game.nes');
    expect(handle.fallbackUrls, [game.url]);
  });

  test(
      'startup health checks every RomM independently using the same auth and platform IDs',
      () async {
    final authHeaders = <String?>[];
    final lan = await _serve((r) => r.response.statusCode = 503);
    final wan = await _serve((r) {
      authHeaders.add(r.headers.value('authorization'));
      r.response.headers.contentType = ContentType.json;
      r.response.write(
          '[{"id":17,"slug":"nes","fs_slug":"nes","name":"NES","rom_count":1}]');
    });
    final notifier = SourceHealthNotifier();
    addTearDown(notifier.dispose);
    final other = await _serve((r) {
      expect(r.headers.value('authorization'), 'Bearer other-token');
      r.response.headers.contentType = ContentType.json;
      r.response.write(
          '[{"id":42,"slug":"gb","fs_slug":"gb","name":"Game Boy","rom_count":1}]');
    });
    final sources = [
      Source(
          id: 'home',
          name: 'Home',
          type: SourceType.romm,
          url: lan,
          fallbackUrls: [wan],
          auth: const AuthConfig(clientToken: 'home-token')),
      Source(
          id: 'other',
          name: 'Other',
          type: SourceType.romm,
          url: other,
          auth: const AuthConfig(clientToken: 'other-token'))
    ];
    final platforms = await notifier.checkAll(sources);
    expect(notifier.state.statusFor('home'), SourceHealth.valid);
    expect(platforms['home'], {'nes': 17});
    expect(platforms['other'], {'gb': 42});
    expect(notifier.state.statusFor('other'), SourceHealth.valid);
    expect(authHeaders, ['Bearer home-token']);
    expect(sources.first.url, lan);
  });

  test('allow-lists, disabled sources and mapping priorities still gate routes',
      () {
    const a = Source(
        id: 'a',
        name: 'A',
        type: SourceType.romm,
        url: 'http://lan.test',
        fallbackUrls: ['https://wan.test'],
        autoMap: true,
        knownPlatforms: {'nes': 17},
        priority: 1);
    const b = Source(
        id: 'b',
        name: 'B',
        type: SourceType.romm,
        url: 'https://other.test',
        autoMap: true,
        knownPlatforms: {'nes': 42});
    const web = Source(
        id: 'web',
        name: 'Web',
        type: SourceType.web,
        url: 'http://local.test/roms',
        fallbackUrls: ['https://remote.test/library']);
    const system = SystemConfig(
        id: 'nes',
        name: 'NES',
        targetFolder: '/nes',
        providers: [],
        enabledSourceIds: [
          'a',
          'web'
        ],
        manualMappings: [
          SystemSourceMapping(
              sourceId: 'web', remotePath: '/nes', priorityOverride: 0)
        ]);
    final providers = SourceResolver.providersFor(system, [a, b, web]);
    expect(providers.map((p) => p.sourceId), ['web', 'a']);
    expect(providers.first.fallbackUrls, ['https://remote.test/library/nes']);
    expect(providers.last.platformId, 17);
    expect(
        SourceResolver.providersFor(
                system, [a.copyWith(enabled: false), b, web])
            .map((p) => p.sourceId),
        ['web']);
  });

  test(
      'legacy configs stay opt-in and imports reject invalid or credential-bearing endpoints',
      () {
    const source = Source(
        id: 'a', name: 'A', type: SourceType.romm, url: 'http://lan.test');
    final oldConfig = const AppConfig(systems: [], sources: [source]).toJson();
    expect(
        ConfigParser.parse(jsonEncode(oldConfig)).sources.single.fallbackUrls,
        isEmpty);
    expect(source.toJson(), isNot(contains('fallback_urls')));
    for (final invalid in [
      'ftp://wrong.test',
      'https://user:secret@remote.test',
      'https://remote.test?a=1'
    ]) {
      final json = AppConfig(systems: [], sources: [
        source.copyWith(fallbackUrls: [invalid])
      ]).toJson();
      expect(() => ConfigParser.parse(jsonEncode(json)),
          throwsA(isA<ConfigParseException>()));
    }
  });

  test(
      'settings dual-write keeps routes, mappings, allow-list, auth stripping and unrelated sources',
      () async {
    final dir = Directory.systemTemp.createTempSync('rshop_routes_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final storage = ConfigStorageService(directoryProvider: () async => dir);
    const source = Source(
        id: 'home',
        name: 'Home',
        type: SourceType.romm,
        url: 'http://lan.test',
        auth: AuthConfig(clientToken: 'secret'),
        autoMap: true,
        knownPlatforms: {'nes': 17});
    const system = SystemConfig(
        id: 'nes',
        name: 'NES',
        targetFolder: '/nes',
        providers: [],
        enabledSourceIds: [
          'home'
        ],
        manualMappings: [
          SystemSourceMapping(sourceId: 'other', remotePath: '/nes')
        ]);
    await storage.saveConfig(jsonEncode(
        const AppConfig(systems: [system], sources: [source]).toJson()));
    final notifier = SourcesNotifier(storage);
    addTearDown(notifier.dispose);
    await notifier.ready;
    await notifier.setFallbackUrls(
        'home', ['https://wan.test/proxy/', 'https://wan.test/proxy']);
    final saved = (await storage.loadConfig())!;
    expect(saved.sources.single.id, 'home');
    expect(saved.sources.single.fallbackUrls, ['https://wan.test/proxy']);
    final provider = saved.systems.single.providers.single;
    expect(provider.sourceId, 'home');
    expect(provider.fallbackUrls, ['https://wan.test/proxy']);
    expect(saved.systems.single.enabledSourceIds, ['home']);
    expect(saved.systems.single.manualMappings.single.sourceId, 'other');
    final exported = jsonEncode(saved.toJsonWithoutAuth());
    expect(exported, isNot(contains('secret')));
    expect(ConfigParser.parse(exported).sources.single.fallbackUrls,
        provider.fallbackUrls);
    final cached = GameItem(
        filename: 'game.nes',
        displayName: 'Game',
        url: 'http://lan.test/api/roms/1',
        providerConfig: provider.copyWith(fallbackUrls: []));
    final clean = GameItem.fromJson({
      ...cached.toJson(),
      'providerConfig': cached.providerConfig!.toJsonWithoutAuth()
    });
    final hydrated = GameItem.rehydrateAuth([clean], [provider]).single;
    expect(hydrated.providerConfig!.auth!.clientToken, 'secret');
    expect(hydrated.providerConfig!.fallbackUrls, provider.fallbackUrls);
    await notifier.setFallbackUrls('home', []);
    expect(
        (await storage.loadConfig())!
            .systems
            .single
            .providers
            .single
            .fallbackUrls,
        isEmpty);
  });

  test('download switches endpoints without appending an old partial file',
      () async {
    var fallbackHits = 0;
    final lan = await _serve((r) => r.response.statusCode = 503);
    final wan = await _serve((r) {
      fallbackHits++;
      expect(r.headers.value('range'), isNull);
      expect(r.headers.value('authorization'), 'Bearer secret');
      r.response.contentLength = 4;
      r.response.add([1, 2, 3, 4]);
    });
    final dir = Directory.systemTemp.createTempSync('rshop_download_routes_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final target = await Directory('${dir.path}/target').create();
    final partial = File('${dir.path}/partial.nes')
      ..writeAsStringSync('OLD PARTIAL');
    final service = DownloadService(NativeSmbService());
    addTearDown(service.dispose);
    final game = GameItem(
        filename: 'game.nes',
        displayName: 'Game',
        url: '$lan/api/roms/1/content/game.nes',
        providerConfig: ProviderConfig(
            type: ProviderType.romm,
            priority: 1,
            url: lan,
            fallbackUrls: [wan],
            auth: const AuthConfig(clientToken: 'secret')));
    final events = await service
        .downloadGameStream(
            game, target.path, SystemModel.supportedSystems.first,
            existingTempFilePath: partial.path)
        .toList();
    expect(events.last.status, DownloadStatus.completed,
        reason: events.last.error);
    expect(File('${target.path}/game.nes').readAsBytesSync(), [1, 2, 3, 4]);
    expect(fallbackHits, 1);
  });
}
