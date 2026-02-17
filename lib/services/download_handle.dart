import 'dart:io';

import 'providers/smb_provider.dart';

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
  final Future<void> Function(File destination) downloadToFile;

  const FtpDownloadHandle({required this.downloadToFile});
}
