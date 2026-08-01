import 'package:flutter_test/flutter_test.dart';
import 'package:retro_eshop/models/config/provider_config.dart';
import 'package:retro_eshop/services/native_smb_service.dart';
import 'package:retro_eshop/services/provider_factory.dart';
import 'package:retro_eshop/services/providers/ftp_provider.dart';
import 'package:retro_eshop/services/providers/romm_provider.dart';
import 'package:retro_eshop/services/providers/smb_provider.dart';
import 'package:retro_eshop/services/providers/web_provider.dart';

void main() {
  group('ProviderFactory', () {
    setUpAll(() {
      ProviderFactory.init(smbService: NativeSmbService());
    });

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

  group('ProviderFactory 未初始化', () {
    setUp(ProviderFactory.reset);

    // 還原 static 狀態，避免影響其他 group／測試檔。
    tearDown(() {
      ProviderFactory.init(smbService: NativeSmbService());
    });

    test('未呼叫 init() 就取得 SMB provider 會拋出可辨識的 StateError', () {
      const config = ProviderConfig(
        type: ProviderType.smb,
        priority: 1,
        host: 'nas',
        share: 'roms',
      );

      expect(
        () => ProviderFactory.getProvider(config),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('ProviderFactory.init'),
              contains('smbService'),
              contains('runApp'),
            ),
          ),
        ),
      );
    });

    test('未初始化時非 SMB 型別仍可正常建立', () {
      const config = ProviderConfig(
        type: ProviderType.web,
        priority: 1,
        url: 'https://example.com',
      );
      expect(ProviderFactory.getProvider(config), isA<WebProvider>());
    });
  });
}
