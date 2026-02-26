import 'package:flutter_test/flutter_test.dart';
import 'package:retro_eshop/models/config/provider_config.dart';

void main() {
  // ─── AuthConfig ───────────────────────────────────────────────────

  group('AuthConfig', () {
    test('fromJson/toJson round-trips all four fields', () {
      final json = {
        'user': 'alice',
        'pass': 'secret',
        'api_key': 'key123',
        'domain': 'WORKGROUP',
      };
      final auth = AuthConfig.fromJson(json);
      expect(auth.user, 'alice');
      expect(auth.pass, 'secret');
      expect(auth.apiKey, 'key123');
      expect(auth.domain, 'WORKGROUP');
      expect(auth.toJson(), json);
    });

    test('toJson omits null fields', () {
      const auth = AuthConfig();
      expect(auth.toJson(), <String, dynamic>{});
    });

    test('fromJson with empty map yields all-null fields', () {
      final auth = AuthConfig.fromJson({});
      expect(auth.user, isNull);
      expect(auth.pass, isNull);
      expect(auth.apiKey, isNull);
      expect(auth.domain, isNull);
    });
  });

  // ─── ProviderConfig — fromJson / toJson ───────────────────────────

  group('ProviderConfig fromJson/toJson', () {
    test('web provider round-trips all fields', () {
      final json = {
        'type': 'web',
        'priority': 1,
        'url': 'https://roms.example.com/gba/',
        'path': '/gba',
      };
      final config = ProviderConfig.fromJson(json);
      expect(config.type, ProviderType.web);
      expect(config.priority, 1);
      expect(config.url, 'https://roms.example.com/gba/');
      expect(config.path, '/gba');
      expect(config.toJson(), json);
    });

    test('SMB provider round-trips including nested auth', () {
      final json = {
        'type': 'smb',
        'priority': 2,
        'host': '192.168.1.100',
        'port': 445,
        'share': 'roms',
        'path': '/gba',
        'auth': {'user': 'bob', 'pass': 'pw'},
      };
      final config = ProviderConfig.fromJson(json);
      expect(config.type, ProviderType.smb);
      expect(config.host, '192.168.1.100');
      expect(config.port, 445);
      expect(config.share, 'roms');
      expect(config.auth, isNotNull);
      expect(config.auth!.user, 'bob');
      expect(config.toJson(), json);
    });

    test('FTP provider round-trips', () {
      final json = {
        'type': 'ftp',
        'priority': 3,
        'host': 'ftp.example.com',
        'port': 21,
        'path': '/retro',
        'auth': {'user': 'anon', 'pass': 'anon'},
      };
      final config = ProviderConfig.fromJson(json);
      expect(config.type, ProviderType.ftp);
      expect(config.toJson(), json);
    });

    test('RomM provider round-trips', () {
      final json = {
        'type': 'romm',
        'priority': 1,
        'url': 'https://romm.local:8080',
        'auth': {'api_key': 'abc123'},
        'platform_id': 42,
        'platform_name': 'Game Boy Advance',
      };
      final config = ProviderConfig.fromJson(json);
      expect(config.type, ProviderType.romm);
      expect(config.platformId, 42);
      expect(config.platformName, 'Game Boy Advance');
      expect(config.toJson(), json);
    });

    test('toJson omits null optional fields', () {
      const config = ProviderConfig(
        type: ProviderType.web,
        priority: 1,
        url: 'https://x.com',
      );
      final json = config.toJson();
      expect(json.keys, containsAll(['type', 'priority', 'url']));
      expect(json.containsKey('host'), isFalse);
      expect(json.containsKey('auth'), isFalse);
      expect(json.containsKey('platform_id'), isFalse);
    });

    test('fromJson defaults to web for unknown type string', () {
      final config = ProviderConfig.fromJson({
        'type': 'nfs',
        'priority': 1,
      });
      expect(config.type, ProviderType.web);
    });

    test('fromJson parses auth when present', () {
      final config = ProviderConfig.fromJson({
        'type': 'web',
        'priority': 1,
        'auth': {'user': 'u', 'pass': 'p'},
      });
      expect(config.auth, isNotNull);
      expect(config.auth!.user, 'u');
    });

    test('fromJson sets auth to null when key absent', () {
      final config = ProviderConfig.fromJson({
        'type': 'web',
        'priority': 1,
      });
      expect(config.auth, isNull);
    });
  });

  // ─── toJsonWithoutAuth ────────────────────────────────────────────

  group('ProviderConfig toJsonWithoutAuth', () {
    final config = ProviderConfig(
      type: ProviderType.smb,
      priority: 1,
      host: '10.0.0.1',
      port: 445,
      share: 'games',
      auth: const AuthConfig(user: 'me', pass: 'secret'),
    );

    test('strips auth from config with credentials', () {
      final json = config.toJsonWithoutAuth();
      expect(json.containsKey('auth'), isFalse);
    });

    test('preserves all non-auth fields', () {
      final json = config.toJsonWithoutAuth();
      expect(json['type'], 'smb');
      expect(json['priority'], 1);
      expect(json['host'], '10.0.0.1');
      expect(json['port'], 445);
      expect(json['share'], 'games');
    });

    test('differs from toJson only in auth key', () {
      final withAuth = config.toJson();
      final without = config.toJsonWithoutAuth();
      expect(withAuth.containsKey('auth'), isTrue);
      expect(without.containsKey('auth'), isFalse);
      // Everything else matches
      final withAuthCopy = Map<String, dynamic>.from(withAuth)..remove('auth');
      expect(without, withAuthCopy);
    });
  });

  // ─── shortLabel ───────────────────────────────────────────────────

  group('ProviderConfig shortLabel', () {
    ProviderConfig ofType(ProviderType t) =>
        ProviderConfig(type: t, priority: 1);

    test('returns WEB for web type', () {
      expect(ofType(ProviderType.web).shortLabel, 'WEB');
    });

    test('returns SMB for smb type', () {
      expect(ofType(ProviderType.smb).shortLabel, 'SMB');
    });

    test('returns FTP for ftp type', () {
      expect(ofType(ProviderType.ftp).shortLabel, 'FTP');
    });

    test('returns RomM for romm type', () {
      expect(ofType(ProviderType.romm).shortLabel, 'RomM');
    });
  });

  // ─── hostLabel ────────────────────────────────────────────────────

  group('ProviderConfig hostLabel', () {
    test('web extracts host from URL', () {
      const config = ProviderConfig(
        type: ProviderType.web,
        priority: 1,
        url: 'https://roms.example.com/path',
      );
      expect(config.hostLabel, 'roms.example.com');
    });

    test('romm extracts host from URL', () {
      const config = ProviderConfig(
        type: ProviderType.romm,
        priority: 1,
        url: 'http://romm.local:8080/api',
      );
      expect(config.hostLabel, 'romm.local');
    });

    test('web with null url returns empty string', () {
      const config = ProviderConfig(type: ProviderType.web, priority: 1);
      expect(config.hostLabel, '');
    });

    test('smb returns host field directly', () {
      const config = ProviderConfig(
        type: ProviderType.smb,
        priority: 1,
        host: '192.168.1.5',
      );
      expect(config.hostLabel, '192.168.1.5');
    });

    test('ftp with null host returns empty string', () {
      const config = ProviderConfig(type: ProviderType.ftp, priority: 1);
      expect(config.hostLabel, '');
    });
  });

  // ─── detailLabel ──────────────────────────────────────────────────

  group('ProviderConfig detailLabel', () {
    test('includes type and host when host available', () {
      const config = ProviderConfig(
        type: ProviderType.web,
        priority: 1,
        url: 'https://example.com',
      );
      expect(config.detailLabel, 'WEB \u00b7 example.com');
    });

    test('returns only shortLabel when host is empty', () {
      const config = ProviderConfig(type: ProviderType.ftp, priority: 1);
      expect(config.detailLabel, 'FTP');
    });
  });

  // ─── validate ─────────────────────────────────────────────────────

  group('ProviderConfig validate', () {
    test('valid configs return null', () {
      expect(
        const ProviderConfig(
          type: ProviderType.web,
          priority: 1,
          url: 'https://x.com',
        ).validate(),
        isNull,
      );
      expect(
        const ProviderConfig(
          type: ProviderType.smb,
          priority: 1,
          host: 'nas',
          share: 'roms',
        ).validate(),
        isNull,
      );
      expect(
        const ProviderConfig(
          type: ProviderType.ftp,
          priority: 1,
          host: 'ftp.local',
        ).validate(),
        isNull,
      );
      expect(
        const ProviderConfig(
          type: ProviderType.romm,
          priority: 1,
          url: 'https://romm.io',
        ).validate(),
        isNull,
      );
    });

    test('invalid configs return error strings', () {
      // web: no url
      expect(
        const ProviderConfig(type: ProviderType.web, priority: 1).validate(),
        isNotNull,
      );
      // web: no scheme
      expect(
        const ProviderConfig(
          type: ProviderType.web,
          priority: 1,
          url: 'example.com',
        ).validate(),
        isNotNull,
      );
      // smb: no host
      expect(
        const ProviderConfig(
          type: ProviderType.smb,
          priority: 1,
          share: 'x',
        ).validate(),
        isNotNull,
      );
      // smb: no share
      expect(
        const ProviderConfig(
          type: ProviderType.smb,
          priority: 1,
          host: 'h',
        ).validate(),
        isNotNull,
      );
      // smb: port 0
      expect(
        const ProviderConfig(
          type: ProviderType.smb,
          priority: 1,
          host: 'h',
          share: 's',
          port: 0,
        ).validate(),
        isNotNull,
      );
      // smb: port 65536
      expect(
        const ProviderConfig(
          type: ProviderType.smb,
          priority: 1,
          host: 'h',
          share: 's',
          port: 65536,
        ).validate(),
        isNotNull,
      );
      // ftp: no host
      expect(
        const ProviderConfig(type: ProviderType.ftp, priority: 1).validate(),
        isNotNull,
      );
      // romm: empty url
      expect(
        const ProviderConfig(
          type: ProviderType.romm,
          priority: 1,
          url: '',
        ).validate(),
        isNotNull,
      );
    });
  });

  // ─── copyWith ─────────────────────────────────────────────────────

  group('ProviderConfig copyWith', () {
    test('overrides specified fields, preserves others', () {
      const original = ProviderConfig(
        type: ProviderType.web,
        priority: 1,
        url: 'https://a.com',
        path: '/roms',
      );
      final copy = original.copyWith(priority: 5, url: 'https://b.com');
      expect(copy.type, ProviderType.web);
      expect(copy.priority, 5);
      expect(copy.url, 'https://b.com');
      expect(copy.path, '/roms');
    });
  });
}
