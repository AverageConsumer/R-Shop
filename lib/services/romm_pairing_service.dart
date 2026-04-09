import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Result of a successful pairing-code exchange against a RomM 4.8+ server.
///
/// The token string is the bearer credential that subsequent API calls must
/// send via `Authorization: Bearer <token>`. The remaining fields describe
/// the token's identity and lifetime, used by R-Shop to surface "borrowed"
/// status, expiry warnings, and revoke buttons in the Sources screen.
@immutable
class RommPairResult {
  const RommPairResult({
    required this.serverUrl,
    required this.token,
    required this.tokenId,
    required this.name,
    required this.scopes,
    required this.userId,
    this.expiresAt,
  });

  /// Normalized server base URL (no trailing slash, no `/pair?...` suffix).
  final String serverUrl;

  /// Bearer token to use for all future authenticated requests.
  final String token;

  /// Server-side token identifier; needed for status polling and revoke.
  final int tokenId;

  /// Human-readable token name as set by the issuing user.
  final String name;

  /// Granted permission scopes (e.g. `roms.read`, `platforms.read`).
  final List<String> scopes;

  /// Owning RomM user id (the issuer of the token).
  final int userId;

  /// Optional expiry. `null` means the token never expires.
  final DateTime? expiresAt;
}

/// Parsed contents of a RomM pairing QR code.
///
/// RomM 4.8 encodes pairing data as a plain URL of the form:
///   `http(s)://<host>[:port]/pair?code=XXXX-XXXX`
@immutable
class RommPairCodeData {
  const RommPairCodeData({required this.serverUrl, required this.code});

  /// Normalized base URL of the RomM server (e.g. `https://romm.example.com`).
  final String serverUrl;

  /// Short pairing code (e.g. `B7K9-3MX2`).
  final String code;
}

/// Errors thrown by [RommPairingService]. UI layers can switch on the
/// concrete subtype to render the right user-facing message.
sealed class RommPairingException implements Exception {
  const RommPairingException(this.message);
  final String message;
  @override
  String toString() => '$runtimeType: $message';
}

class RommPairInvalidQrException extends RommPairingException {
  const RommPairInvalidQrException(super.message);
}

class RommPairCodeExpiredException extends RommPairingException {
  const RommPairCodeExpiredException(super.message);
}

class RommPairServerUnreachableException extends RommPairingException {
  const RommPairServerUnreachableException(super.message);
}

class RommPairUnknownException extends RommPairingException {
  const RommPairUnknownException(super.message);
}

/// Stateless client for the RomM 4.8+ Client API Token pairing flow.
///
/// Flow overview:
/// 1. Server admin creates an API token and clicks "Pair Device" → server
///    shows a QR encoding `<server>/pair?code=XXXX-XXXX`.
/// 2. R-Shop scans the QR (or user types Server + Code manually).
/// 3. R-Shop calls [exchangeCode] which POSTs the code and receives the
///    actual bearer token plus metadata.
/// 4. The token is stored locally; subsequent requests use it directly.
///
/// This service is intentionally stateless and Dio-injectable so it can be
/// unit-tested without a live server.
class RommPairingService {
  RommPairingService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  static final RegExp _pairUrlPattern = RegExp(
    r'^(https?://[^/\s]+)/pair\?code=([A-Za-z0-9-]+)$',
    caseSensitive: false,
  );

  /// Parses a QR code payload into a [RommPairCodeData].
  ///
  /// Throws [RommPairInvalidQrException] if the payload doesn't look like
  /// a RomM pairing URL. The pattern matches `http(s)://host[:port]/pair?code=…`.
  RommPairCodeData parseQrPayload(String payload) {
    final trimmed = payload.trim();
    final match = _pairUrlPattern.firstMatch(trimmed);
    if (match == null) {
      throw const RommPairInvalidQrException(
        'QR code is not a valid RomM pairing link',
      );
    }
    return RommPairCodeData(
      serverUrl: match.group(1)!,
      code: normalizeCode(match.group(2)!),
    );
  }

  /// Canonicalises a pairing code to the server-expected `XXXX-XXXX` form.
  ///
  /// Strips spaces, hyphens, and lowercase letters; if the result is exactly
  /// 8 characters it is split into two 4-character groups separated by a
  /// hyphen. Shorter or longer codes are returned uppercase but unchanged so
  /// the server can reject them with a meaningful error.
  static String normalizeCode(String input) {
    final stripped = input
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll('-', '')
        .toUpperCase();
    if (stripped.length == 8) {
      return '${stripped.substring(0, 4)}-${stripped.substring(4)}';
    }
    return stripped;
  }

  /// Exchanges a pairing [code] against [serverUrl] for a bearer token.
  ///
  /// Throws:
  /// - [RommPairCodeExpiredException] on HTTP 4xx with "expired"/"invalid".
  /// - [RommPairServerUnreachableException] on connection failures.
  /// - [RommPairUnknownException] for any other error.
  Future<RommPairResult> exchangeCode({
    required String serverUrl,
    required String code,
  }) async {
    final normalized = _normalizeServerUrl(serverUrl);
    final canonicalCode = normalizeCode(code);
    final endpoint = '$normalized/api/client-tokens/exchange';

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        endpoint,
        data: {'code': canonicalCode},
        options: Options(
          contentType: Headers.jsonContentType,
          responseType: ResponseType.json,
          // Don't throw on 4xx — we want to inspect the body to map errors.
          validateStatus: (status) => status != null && status < 500,
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      final status = response.statusCode ?? 0;
      final body = response.data ?? const <String, dynamic>{};

      if (status >= 200 && status < 300) {
        return _parseExchangeResponse(serverUrl: normalized, json: body);
      }

      final detail = (body['detail'] ?? '').toString().toLowerCase();
      if (detail.contains('expired') ||
          detail.contains('invalid') ||
          status == 400 ||
          status == 404) {
        throw RommPairCodeExpiredException(
          body['detail']?.toString() ?? 'Pairing code invalid or expired',
        );
      }
      throw RommPairUnknownException('HTTP $status: ${body['detail'] ?? body}');
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        throw RommPairServerUnreachableException(
          'Server $normalized is not reachable',
        );
      }
      rethrow;
    }
  }

  /// Convenience: parse a QR payload and immediately exchange the code.
  Future<RommPairResult> pairFromQr(String payload) async {
    final parsed = parseQrPayload(payload);
    return exchangeCode(serverUrl: parsed.serverUrl, code: parsed.code);
  }

  /// Lightweight reachability check used by the manual-entry form to give
  /// inline feedback ("✓ RomM 4.8.1 erreicht") before the user submits.
  ///
  /// Returns the RomM version string on success, or `null` on any failure.
  Future<String?> probeServer(String serverUrl) async {
    final normalized = _normalizeServerUrl(serverUrl);
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$normalized/api/heartbeat',
        options: Options(
          responseType: ResponseType.json,
          sendTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
          validateStatus: (s) => s == 200,
        ),
      );
      final system = response.data?['SYSTEM'] as Map<String, dynamic>?;
      return system?['VERSION']?.toString();
    } catch (_) {
      return null;
    }
  }

  RommPairResult _parseExchangeResponse({
    required String serverUrl,
    required Map<String, dynamic> json,
  }) {
    // RomM 4.8 returns the bearer in `raw_token`. Older preview builds used
    // `token`; accept both so the parser is forward/backward tolerant.
    final token = (json['raw_token'] ?? json['token'])?.toString();
    if (token == null || token.isEmpty) {
      throw const RommPairUnknownException(
        'Server response did not contain a token',
      );
    }

    final scopesRaw = json['scopes'];
    final scopes = scopesRaw is List
        ? scopesRaw.map((e) => e.toString()).toList(growable: false)
        : const <String>[];

    DateTime? expiresAt;
    final expRaw = json['expires_at'];
    if (expRaw is String && expRaw.isNotEmpty) {
      expiresAt = DateTime.tryParse(expRaw);
    }

    return RommPairResult(
      serverUrl: serverUrl,
      token: token,
      tokenId: _asInt(json['id'] ?? json['token_id']),
      name: json['name']?.toString() ?? 'R-Shop',
      scopes: scopes,
      userId: _asInt(json['user_id']),
      expiresAt: expiresAt,
    );
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  String _normalizeServerUrl(String url) {
    var normalized = url.trim();
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }
}
