abstract final class NetworkTimeouts {
  static const ftpConnect = Duration(seconds: 30);
  static const ftpCommand = Duration(seconds: 15);
  static const ftpList = Duration(seconds: 60);
  static const smbConnect = Duration(seconds: 30);
  static const httpConnect = Duration(seconds: 30);
  static const httpIdle = Duration(minutes: 5);
  static const apiConnect = Duration(seconds: 15);
  static const apiReceive = Duration(seconds: 30);
  static const providerDiscovery = Duration(seconds: 30);
}
