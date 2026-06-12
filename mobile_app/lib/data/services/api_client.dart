import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../domain/models/auth_session.dart';

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
  ApiClient({
    required String baseUrl,
    http.Client? httpClient,
    Future<AuthSession?> Function()? currentSessionProvider,
    Future<AuthSession?> Function(String refreshToken)? refreshSession,
  }) : baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), ''),
       _httpClient = httpClient ?? http.Client(),
       _currentSessionProvider = currentSessionProvider,
       _refreshSession = refreshSession;

  final String baseUrl;
  final http.Client _httpClient;
  String? _accessToken;
  Future<AuthSession?> Function()? _currentSessionProvider;
  Future<AuthSession?> Function(String refreshToken)? _refreshSession;

  /// Sets the bearer token attached to subsequent requests. Pass `null` to
  /// clear the token (e.g. on logout).
  void setAccessToken(String? token) {
    _accessToken = token;
  }

  void configureAuthHooks({
    Future<AuthSession?> Function()? currentSessionProvider,
    Future<AuthSession?> Function(String refreshToken)? refreshSession,
  }) {
    _currentSessionProvider = currentSessionProvider;
    _refreshSession = refreshSession;
  }

  Future<Object?> getJson(String path, {bool authenticate = true}) async {
    return _send(() async {
      final response = await _httpClient.get(
        _uri(path),
        headers: _headers(authenticate: authenticate),
      );
      return _decode(response);
    }, authenticate: authenticate);
  }

  Future<Object?> postJson(
    String path,
    Map<String, Object?> body, {
    bool authenticate = true,
  }) async {
    return _send(() async {
      final response = await _httpClient.post(
        _uri(path),
        headers: _headers(
          includeJsonContentType: true,
          authenticate: authenticate,
        ),
        body: jsonEncode(body),
      );
      return _decode(response);
    }, authenticate: authenticate);
  }

  Future<Object?> patchJson(
    String path,
    Map<String, Object?> body, {
    bool authenticate = true,
  }) async {
    return _send(() async {
      final response = await _httpClient.patch(
        _uri(path),
        headers: _headers(
          includeJsonContentType: true,
          authenticate: authenticate,
        ),
        body: jsonEncode(body),
      );
      return _decode(response);
    }, authenticate: authenticate);
  }

  Future<Object?> deleteJson(String path, {bool authenticate = true}) async {
    return _send(() async {
      final response = await _httpClient.delete(
        _uri(path),
        headers: _headers(authenticate: authenticate),
      );
      return _decode(response);
    }, authenticate: authenticate);
  }

  /// Wraps a request lambda to normalize transport-level exceptions into a
  /// typed [ApiException]. HTTP-level errors are already handled by [_decode].
  Future<Object?> _send(
    Future<Object?> Function() request, {
    required bool authenticate,
    bool allowRefresh = true,
  }) async {
    try {
      return await request();
    } on ApiException catch (error) {
      if (authenticate && allowRefresh && error.statusCode == 401) {
        final refreshed = await _attemptRefresh();
        if (refreshed) {
          return _send(
            request,
            authenticate: authenticate,
            allowRefresh: false,
          );
        }
      }
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

  Future<bool> _attemptRefresh() async {
    final refreshSession = _refreshSession;
    final currentSessionProvider = _currentSessionProvider;
    if (refreshSession == null || currentSessionProvider == null) {
      return false;
    }

    try {
      final session = await currentSessionProvider();
      final refreshToken = session?.refreshToken;
      if (session == null ||
          refreshToken == null ||
          refreshToken.isEmpty ||
          session.isRefreshExpired) {
        return false;
      }
      final refreshed = await refreshSession(refreshToken);
      if (refreshed == null) {
        return false;
      }
      _accessToken = refreshed.accessToken;
      return true;
    } on ApiException {
      return false;
    }
  }

  Map<String, String> _headers({
    bool includeJsonContentType = false,
    bool authenticate = true,
  }) {
    final headers = <String, String>{};
    if (includeJsonContentType) {
      headers['Content-Type'] = 'application/json';
    }
    final token = authenticate ? _accessToken : null;
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

/// Maps any thrown object to a stable English message. The presentation layer
/// localizes this message for the active app locale.
///
/// The optional [context] is prepended so callers can tailor the leading
/// phrase per feature (e.g. "Could not load automation rules").
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
        return 'The network response took too long. Try again.';
      case ApiErrorKind.offline:
        return 'No network connection. Check Wi-Fi or mobile data.';
      case ApiErrorKind.validation:
        return 'The data is invalid. Check the input fields.';
      case ApiErrorKind.unauthorized:
        return 'Your session is invalid. Sign in again.';
      case ApiErrorKind.server:
        return 'The server has a problem. Try again later.';
      case ApiErrorKind.unknown:
        return 'An unknown error occurred. Try again.';
    }
  }
  return 'An unknown error occurred. Try again.';
}
