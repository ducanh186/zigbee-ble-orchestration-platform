import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Stable mobile-facing error categories produced by [ApiClient]. View models
/// pattern-match on these to surface a friendly message without leaking raw
/// exception text to the UI.
enum ApiErrorKind {
  /// Network request did not complete within the client deadline.
  timeout,

  /// No network reachable (DNS, socket, or connection reset).
  offline,

  /// Server rejected the request as invalid (400 / 422).
  validation,

  /// Caller is not authenticated or lacks access (401 / 403).
  unauthorized,

  /// Server responded with 5xx.
  server,

  /// Anything else — unexpected response shape, JSON parse error, etc.
  unknown,
}

class ApiClient {
  ApiClient({required String baseUrl, http.Client? httpClient})
    : baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), ''),
      _httpClient = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _httpClient;
  String? _accessToken;

  /// Sets the bearer token attached to subsequent requests. Pass `null` to
  /// clear the token (e.g. on logout).
  void setAccessToken(String? token) {
    _accessToken = token;
  }

  Future<Object?> getJson(String path) async {
    return _send(() async {
      final response = await _httpClient.get(_uri(path), headers: _headers());
      return _decode(response);
    });
  }

  Future<Object?> postJson(String path, Map<String, Object?> body) async {
    return _send(() async {
      final response = await _httpClient.post(
        _uri(path),
        headers: _headers(includeJsonContentType: true),
        body: jsonEncode(body),
      );
      return _decode(response);
    });
  }

  /// Wraps a request lambda to normalize transport-level exceptions into a
  /// typed [ApiException]. HTTP-level errors are already handled by [_decode].
  Future<Object?> _send(Future<Object?> Function() request) async {
    try {
      return await request();
    } on ApiException {
      rethrow;
    } on TimeoutException catch (error) {
      throw ApiException(
        statusCode: 0,
        kind: ApiErrorKind.timeout,
        message: error.message ?? 'Request timed out',
      );
    } on SocketException catch (error) {
      throw ApiException(
        statusCode: 0,
        kind: ApiErrorKind.offline,
        message: error.message.isEmpty ? 'Network unreachable' : error.message,
      );
    } on http.ClientException catch (error) {
      throw ApiException(
        statusCode: 0,
        kind: ApiErrorKind.offline,
        message: error.message,
      );
    } on FormatException catch (error) {
      throw ApiException(
        statusCode: 0,
        kind: ApiErrorKind.unknown,
        message: error.message,
      );
    }
  }

  Map<String, String> _headers({bool includeJsonContentType = false}) {
    final headers = <String, String>{};
    if (includeJsonContentType) {
      headers['Content-Type'] = 'application/json';
    }
    final token = _accessToken;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Uri _uri(String path) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$normalizedPath');
  }

  Object? _decode(http.Response response) {
    final body = response.body;
    final contentType = response.headers['content-type'] ?? '';
    final isJson = contentType.contains('application/json') || body.isEmpty;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        statusCode: response.statusCode,
        kind: _kindFromStatus(response.statusCode),
        message: _errorMessage(body),
      );
    }

    if (!isJson) {
      throw ApiException(
        statusCode: response.statusCode,
        kind: ApiErrorKind.unknown,
        message:
            'Expected JSON but received ${contentType.isEmpty ? 'unknown content' : contentType}: ${_snippet(body)}',
      );
    }

    if (body.isEmpty) {
      return null;
    }

    return jsonDecode(body);
  }

  static ApiErrorKind _kindFromStatus(int statusCode) {
    if (statusCode == 408) {
      return ApiErrorKind.timeout;
    }
    if (statusCode == 401 || statusCode == 403) {
      return ApiErrorKind.unauthorized;
    }
    if (statusCode == 400 || statusCode == 422) {
      return ApiErrorKind.validation;
    }
    if (statusCode >= 500 && statusCode < 600) {
      return ApiErrorKind.server;
    }
    return ApiErrorKind.unknown;
  }

  String _errorMessage(String body) {
    if (body.isEmpty) {
      return 'Empty response body';
    }

    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, Object?> && decoded['detail'] != null) {
        return decoded['detail'].toString();
      }
    } on FormatException {
      return _snippet(body);
    }

    return _snippet(body);
  }

  String _snippet(String body) {
    final compact = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= 180) {
      return compact;
    }
    return '${compact.substring(0, 180)}...';
  }

  void close() => _httpClient.close();
}

class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    required this.message,
    this.kind = ApiErrorKind.unknown,
  });

  final int statusCode;
  final String message;
  final ApiErrorKind kind;

  @override
  String toString() => 'API $statusCode (${kind.name}): $message';
}

/// Maps any thrown object to a user-friendly Vietnamese (ASCII-folded) string
/// suitable for surfacing in the mobile UI. View models call this in their
/// `catch` blocks instead of interpolating raw exception text.
///
/// The optional [context] is prepended so callers can tailor the leading
/// phrase per feature (e.g. "Khong tai duoc automation rules").
String friendlyErrorMessage(Object error, {String? context}) {
  final base = _baseFriendlyMessage(error);
  if (context == null || context.isEmpty) {
    return base;
  }
  return '$context. $base';
}

String _baseFriendlyMessage(Object error) {
  if (error is ApiException) {
    switch (error.kind) {
      case ApiErrorKind.timeout:
        return 'Mang phan hoi qua lau. Vui long thu lai.';
      case ApiErrorKind.offline:
        return 'Khong co ket noi mang. Kiem tra Wi-Fi hoac du lieu di dong.';
      case ApiErrorKind.validation:
        return 'Du lieu khong hop le. Kiem tra lai cac truong nhap.';
      case ApiErrorKind.unauthorized:
        return 'Phien dang nhap khong hop le. Vui long dang nhap lai.';
      case ApiErrorKind.server:
        return 'May chu dang gap su co. Vui long thu lai sau.';
      case ApiErrorKind.unknown:
        return 'Da xay ra loi khong xac dinh. Vui long thu lai.';
    }
  }
  return 'Da xay ra loi khong xac dinh. Vui long thu lai.';
}
