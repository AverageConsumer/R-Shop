import 'package:flutter_test/flutter_test.dart';
import 'package:retro_eshop/models/config/provider_config.dart';
import 'package:retro_eshop/services/provider_factory.dart';
import 'package:retro_eshop/services/providers/ftp_provider.dart';
import 'package:retro_eshop/services/providers/romm_provider.dart';
import 'package:retro_eshop/services/providers/smb_provider.dart';
import 'package:retro_eshop/services/providers/web_provider.dart';

void main() {
  group('ProviderFactory', () {
    test('returns WebProvider for ProviderType.web', () {
      const config = ProviderConfig(
        type: ProviderType.web,
        priority: 1,
        url: 'https://example.com',
      );
      expect(ProviderFactory.getProvider(config), isA<WebProvider>());
    });

    test('returns SmbProvider for ProviderType.smb', () {
      const config = ProviderConfig(
        type: ProviderType.smb,
        priority: 1,
        host: 'nas',
        share: 'roms',
      );
      expect(ProviderFactory.getProvider(config), isA<SmbProvider>());
    });

    test('returns FtpProvider for ProviderType.ftp', () {
      const config = ProviderConfig(
        type: ProviderType.ftp,
        priority: 1,
        host: 'ftp.local',
      );
      expect(ProviderFactory.getProvider(config), isA<FtpProvider>());
    });

    test('returns RommProvider for ProviderType.romm', () {
      const config = ProviderConfig(
        type: ProviderType.romm,
        priority: 1,
        url: 'https://romm.local',
      );
      expect(ProviderFactory.getProvider(config), isA<RommProvider>());
    });
  });
}
