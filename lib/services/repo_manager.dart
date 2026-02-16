import 'package:dio/dio.dart';
import 'package:html/parser.dart';

import 'storage_service.dart';

class ConnectionTestResult {
  final bool success;
  final String? error;

  const ConnectionTestResult({required this.success, this.error});
}

class RepoManager {
  final StorageService _storage;

  RepoManager(this._storage);

  String? get baseUrl => _storage.getRepoUrl();
  bool get isConfigured => baseUrl != null && baseUrl!.isNotEmpty;

  String buildSlugUrl(String slug) {
    final base = baseUrl!;
    final normalizedBase = base.endsWith('/') ? base : '$base/';
    return '$normalizedBase$slug/';
  }

  String get refererUrl {
    final base = baseUrl;
    if (base == null) return '';
    final uri = Uri.parse(base);
    return '${uri.scheme}://${uri.host}/';
  }

  static Future<ConnectionTestResult> testConnection(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || (!uri.hasScheme)) {
      return const ConnectionTestResult(
        success: false,
        error: 'Invalid URL format',
      );
    }

    try {
      final dio = Dio();
      dio.options.connectTimeout = const Duration(seconds: 10);
      dio.options.receiveTimeout = const Duration(seconds: 10);

      final response = await dio.get<String>(url);

      if (response.statusCode != 200) {
        return ConnectionTestResult(
          success: false,
          error: 'Server returned status ${response.statusCode}',
        );
      }

      final document = parse(response.data);
      final links = document.querySelectorAll('a');

      const fileExtensions = {
        '.zip', '.7z', '.rar', '.gz', '.bz2', '.xz',
        '.nes', '.sfc', '.smc', '.gba', '.gbc', '.gb', '.nds', '.n64', '.z64',
        '.iso', '.bin', '.cue', '.chd', '.gcm', '.nsp', '.xci', '.wad',
        '.rom', '.img', '.pbp', '.vpk', '.3ds', '.cia',
      };

      bool hasValidLink = links.any((link) {
        final href = link.attributes['href'];
        if (href == null || href.isEmpty) return false;
        // Subdirectory: relative path ending with /, not a parent nav link
        if (href.endsWith('/') && href != '../' && href != '/' && !href.startsWith('/') && !href.startsWith('http')) return true;
        // Downloadable file link
        final lower = href.toLowerCase();
        return fileExtensions.any((ext) => lower.endsWith(ext));
      });

      if (!hasValidLink) {
        return const ConnectionTestResult(
          success: false,
          error: 'No downloadable files or directories found',
        );
      }

      return const ConnectionTestResult(success: true);
    } on DioException catch (e) {
      return ConnectionTestResult(
        success: false,
        error: 'Could not connect: ${e.message}',
      );
    } catch (e) {
      return ConnectionTestResult(
        success: false,
        error: 'Connection failed: $e',
      );
    }
  }
}
