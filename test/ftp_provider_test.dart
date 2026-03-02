import 'package:flutter_test/flutter_test.dart';
import 'package:retro_eshop/models/config/provider_config.dart';
import 'package:retro_eshop/services/providers/ftp_provider.dart';

void main() {
  group('FtpProvider', () {
    group('construction', () {
      test('throws on null host', () {
        const config = ProviderConfig(
          type: ProviderType.ftp,
          priority: 1,
        );
        final provider = FtpProvider(config);
        expect(
          () => provider.testConnection(),
          throwsA(isA<StateError>()),
        );
      });

      test('throws on empty host', () {
        const config = ProviderConfig(
          type: ProviderType.ftp,
          priority: 1,
          host: '',
        );
        final provider = FtpProvider(config);
        expect(
          () => provider.testConnection(),
          throwsA(isA<StateError>()),
        );
      });

      test('rejects invalid host format', () {
        const config = ProviderConfig(
          type: ProviderType.ftp,
          priority: 1,
          host: 'host with spaces',
        );
        final provider = FtpProvider(config);
        expect(
          () => provider.testConnection(),
          throwsA(isA<StateError>()),
        );
      });

      test('displayLabel shows host and default port', () {
        const config = ProviderConfig(
          type: ProviderType.ftp,
          priority: 1,
          host: 'ftp.example.com',
        );
        final provider = FtpProvider(config);
        expect(provider.displayLabel, 'FTP: ftp.example.com');
      });

      test('displayLabel shows custom port', () {
        const config = ProviderConfig(
          type: ProviderType.ftp,
          priority: 1,
          host: 'ftp.example.com',
          port: 2121,
        );
        final provider = FtpProvider(config);
        expect(provider.displayLabel, 'FTP: ftp.example.com:2121');
      });

      test('displayLabel omits port when 21', () {
        const config = ProviderConfig(
          type: ProviderType.ftp,
          priority: 1,
          host: 'ftp.local',
          port: 21,
        );
        final provider = FtpProvider(config);
        expect(provider.displayLabel, 'FTP: ftp.local');
      });
    });

    group('host validation', () {
      test('accepts valid hostname', () {
        const config = ProviderConfig(
          type: ProviderType.ftp,
          priority: 1,
          host: 'my-nas.local',
        );
        // Should not throw on construction
        final provider = FtpProvider(config);
        expect(provider.displayLabel, contains('my-nas.local'));
      });

      test('accepts IPv4 address', () {
        const config = ProviderConfig(
          type: ProviderType.ftp,
          priority: 1,
          host: '192.168.1.100',
        );
        final provider = FtpProvider(config);
        expect(provider.displayLabel, contains('192.168.1.100'));
      });

      test('accepts bracketed IPv6', () {
        const config = ProviderConfig(
          type: ProviderType.ftp,
          priority: 1,
          host: '[::1]',
        );
        final provider = FtpProvider(config);
        expect(provider.displayLabel, contains('[::1]'));
      });

      test('rejects host with newlines (injection)', () {
        const config = ProviderConfig(
          type: ProviderType.ftp,
          priority: 1,
          host: 'evil\nCWD /etc',
        );
        final provider = FtpProvider(config);
        expect(
          () => provider.testConnection(),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('_splitPath (static)', () {
      // Access the static method via a helper since it's private
      // We test it indirectly through the behavior of resolveDownload
      // But since it's static and private, we test the logic via integration

      test('FTP provider stores config correctly', () {
        const config = ProviderConfig(
          type: ProviderType.ftp,
          priority: 1,
          host: '192.168.1.1',
          path: '/roms/gba',
          auth: AuthConfig(user: 'ftpuser', pass: 'ftppass'),
        );
        final provider = FtpProvider(config);
        expect(provider.config, config);
      });
    });

    group('path traversal protection', () {
      test('blocks ".." (parent directory)', () {
        expect(FtpProvider.isTraversalName('..'), isTrue);
      });

      test('blocks "..." (triple dots)', () {
        expect(FtpProvider.isTraversalName('...'), isTrue);
      });

      test('blocks names containing ".."', () {
        expect(FtpProvider.isTraversalName('foo/../bar'), isTrue);
      });

      test('blocks names with forward slash', () {
        expect(FtpProvider.isTraversalName('foo/bar'), isTrue);
      });

      test('blocks names with backslash', () {
        expect(FtpProvider.isTraversalName('foo\\bar'), isTrue);
      });

      test('allows normal directory name', () {
        expect(FtpProvider.isTraversalName('Pokemon Emerald'), isFalse);
      });

      test('allows name with single dot', () {
        expect(FtpProvider.isTraversalName('game.v2'), isFalse);
      });

      test('allows dotfile name (blocked separately)', () {
        expect(FtpProvider.isTraversalName('.hidden'), isFalse);
      });
    });

    group('IPv6 host validation', () {
      test('accepts [::1] (loopback)', () {
        final provider = FtpProvider(const ProviderConfig(
          type: ProviderType.ftp, priority: 1, host: '[::1]',
        ));
        expect(provider.displayLabel, contains('[::1]'));
      });

      test('accepts [2001:db8::1]', () {
        final provider = FtpProvider(const ProviderConfig(
          type: ProviderType.ftp, priority: 1, host: '[2001:db8::1]',
        ));
        expect(provider.displayLabel, contains('[2001:db8::1]'));
      });

      test('accepts full IPv6', () {
        final provider = FtpProvider(const ProviderConfig(
          type: ProviderType.ftp,
          priority: 1,
          host: '[2001:0db8:85a3:0000:0000:8a2e:0370:7334]',
        ));
        expect(provider.displayLabel, contains('2001:'));
      });

      test('accepts link-local with zone ID', () {
        final provider = FtpProvider(const ProviderConfig(
          type: ProviderType.ftp, priority: 1, host: '[fe80::1%eth0]',
        ));
        expect(provider.displayLabel, contains('fe80'));
      });

      test('accepts IPv4-mapped IPv6', () {
        final provider = FtpProvider(const ProviderConfig(
          type: ProviderType.ftp,
          priority: 1,
          host: '[::ffff:192.168.1.1]',
        ));
        expect(provider.displayLabel, contains('ffff'));
      });

      test('rejects [:] (single colon)', () {
        final provider = FtpProvider(const ProviderConfig(
          type: ProviderType.ftp, priority: 1, host: '[:]',
        ));
        expect(
          () => provider.testConnection(),
          throwsA(isA<StateError>()),
        );
      });

      test('rejects [ABCD1234] (no colons)', () {
        final provider = FtpProvider(const ProviderConfig(
          type: ProviderType.ftp, priority: 1, host: '[ABCD1234]',
        ));
        expect(
          () => provider.testConnection(),
          throwsA(isA<StateError>()),
        );
      });

      test('rejects [] (empty brackets)', () {
        final provider = FtpProvider(const ProviderConfig(
          type: ProviderType.ftp, priority: 1, host: '[]',
        ));
        expect(
          () => provider.testConnection(),
          throwsA(isA<StateError>()),
        );
      });
    });
  });
}
