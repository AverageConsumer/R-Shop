import '../models/config/provider_config.dart';
import 'providers/ftp_provider.dart';
import 'providers/romm_provider.dart';
import 'providers/smb_provider.dart';
import 'providers/web_provider.dart';
import 'source_provider.dart';

class ProviderFactory {
  static SourceProvider getProvider(ProviderConfig config) {
    switch (config.type) {
      case ProviderType.web:
        return WebProvider(config);
      case ProviderType.smb:
        return SmbProvider(config);
      case ProviderType.ftp:
        return FtpProvider(config);
      case ProviderType.romm:
        return RommProvider(config);
    }
  }
}
