import 'dart:io';

typedef FtpProgressCallback = void Function(double percent, int received, int total);

sealed class DownloadHandle {
  const DownloadHandle();
}

final class HttpDownloadHandle extends DownloadHandle {
  final String url;
  final Map<String, String>? headers;

  const HttpDownloadHandle({required this.url, this.headers});
}

final class NativeSmbDownloadHandle extends DownloadHandle {
  final String host;
  final int port;
  final String share;
  final String filePath;
  final String user;
  final String pass;
  final String domain;

  const NativeSmbDownloadHandle({
    required this.host,
    required this.port,
    required this.share,
    required this.filePath,
    required this.user,
    required this.pass,
    required this.domain,
  });
}

final class FtpDownloadHandle extends DownloadHandle {
  final Future<void> Function(File destination, {FtpProgressCallback? onProgress}) downloadToFile;
  final Future<void> Function()? disconnect;

  const FtpDownloadHandle({required this.downloadToFile, this.disconnect});
}

/// Represents a single file inside a remote SMB folder.
class SmbFolderEntry {
  final String path;
  final String name;
  final int size;

  const SmbFolderEntry({required this.path, required this.name, required this.size});
}

final class NativeSmbFolderDownloadHandle extends DownloadHandle {
  final String host;
  final int port;
  final String share;
  final String folderPath;
  final String user;
  final String pass;
  final String domain;

  const NativeSmbFolderDownloadHandle({
    required this.host,
    required this.port,
    required this.share,
    required this.folderPath,
    required this.user,
    required this.pass,
    required this.domain,
  });
}

final class FtpFolderDownloadHandle extends DownloadHandle {
  final Future<List<String>> Function() listFiles;
  final Future<void> Function(String remotePath, File dest, {FtpProgressCallback? onProgress}) downloadFile;
  final Future<void> Function()? disconnect;

  const FtpFolderDownloadHandle({required this.listFiles, required this.downloadFile, this.disconnect});
}
