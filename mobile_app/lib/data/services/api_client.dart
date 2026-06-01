import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiClient {
  ApiClient({required String baseUrl, String? accessToken, http.Client? httpClient})
    : baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), ''),
      accessToken = accessToken?.trim(),
      _httpClient = httpClient ?? http.Client();

  final String baseUrl;
  final String? accessToken;
  final http.Client _httpClient;

  Future<Object?> getJson(String path) async {
    final response = await _httpClient.get(_uri(path), headers: _headers());
    return _decode(response);
  }

  Future<Object?> postJson(String path, Map<String, Object?> body) async {
    final response = await _httpClient.post(
      _uri(path),
      headers: _headers(json: true),
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Map<String, String> _headers({bool json = false}) {
    return {
      if (json) 'Content-Type': 'application/json',
      if (accessToken != null && accessToken!.isNotEmpty)
        'Authorization': 'Bearer $accessToken',
    };
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
        message: _errorMessage(body),
      );
    }

    if (!isJson) {
      throw ApiException(
        statusCode: response.statusCode,
        message:
            'Expected JSON but received ${contentType.isEmpty ? 'unknown content' : contentType}: ${_snippet(body)}',
      );
    }

    if (body.isEmpty) {
      return null;
    }

    return jsonDecode(body);
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
  const ApiException({required this.statusCode, required this.message});

  final int statusCode;
  final String message;

  @override
  String toString() => 'API $statusCode: $message';
}
