import 'package:flutter/foundation.dart';

import '../models/config/provider_config.dart';
import 'native_smb_service.dart';
import 'providers/ftp_provider.dart';
import 'providers/romm_provider.dart';
import 'providers/smb_provider.dart';
import 'providers/web_provider.dart';
import 'source_provider.dart';

class ProviderFactory {
  static NativeSmbService? _smbService;

  static void init({required NativeSmbService smbService}) {
    _smbService = smbService;
  }

  /// 僅供測試使用：清除 [init] 設定的 static 狀態，讓測試能驗證未初始化的行為。
  /// 正式程式碼不應呼叫。
  @visibleForTesting
  static void reset() {
    _smbService = null;
  }

  static SourceProvider getProvider(ProviderConfig config) {
    switch (config.type) {
      case ProviderType.web:
        return WebProvider(config);
      case ProviderType.smb:
        final smbService = _smbService;
        if (smbService == null) {
          throw StateError(
            'ProviderFactory 尚未初始化：使用 SMB provider 前必須先呼叫 '
            'ProviderFactory.init(smbService: ...)，'
            '正常應在 main() 的 runApp() 之前完成。',
          );
        }
        return SmbProvider(config, smbService);
      case ProviderType.ftp:
        return FtpProvider(config);
      case ProviderType.romm:
        return RommProvider(config);
    }
  }
}
