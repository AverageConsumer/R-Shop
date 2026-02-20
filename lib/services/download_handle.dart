import 'dart:io';

import 'providers/smb_provider.dart';

typedef FtpProgressCallback = void Function(double percent, int received, int total);

sealed class DownloadHandle {
  const DownloadHandle();
}

final class HttpDownloadHandle extends DownloadHandle {
  final String url;
  final Map<String, String>? headers;

  const HttpDownloadHandle({required this.url, this.headers});
}

final class SmbDownloadHandle extends DownloadHandle {
  final Future<SmbFileReader> Function() openFile;

  const SmbDownloadHandle({required this.openFile});
}

final class FtpDownloadHandle extends DownloadHandle {
  final Future<void> Function(File destination, {FtpProgressCallback? onProgress}) downloadToFile;
  final Future<void> Function()? disconnect;

  const FtpDownloadHandle({required this.downloadToFile, this.disconnect});
}
