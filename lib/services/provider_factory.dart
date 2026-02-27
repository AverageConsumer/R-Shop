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

  static SourceProvider getProvider(ProviderConfig config) {
    switch (config.type) {
      case ProviderType.web:
        return WebProvider(config);
      case ProviderType.smb:
        return SmbProvider(config, _smbService!);
      case ProviderType.ftp:
        return FtpProvider(config);
      case ProviderType.romm:
        return RommProvider(config);
    }
  }
}
