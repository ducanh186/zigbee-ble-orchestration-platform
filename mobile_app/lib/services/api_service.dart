import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/device.dart';

/// Service for communicating with the SmartBridge cloud REST API.
///
/// Default [baseUrl] points to localhost; update it to the EC2 endpoint
/// (e.g. "http://<ec2-host>:8000") for production use.
class ApiService {
  ApiService({
    String? baseUrl,
    http.Client? client,
  })  : baseUrl = baseUrl ?? 'http://localhost:8000',
        _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  // ---------------------------------------------------------------------------
  // Devices
  // ---------------------------------------------------------------------------

  /// Fetch all devices, optionally filtered by [roomId].
  Future<List<Device>> getDevices({String? roomId}) async {
    final uri = Uri.parse('$baseUrl/api/devices/').replace(
      queryParameters: roomId != null ? {'room_id': roomId} : null,
    );

    final response = await _client.get(uri);
    _ensureSuccess(response);

    final List<dynamic> body = jsonDecode(response.body) as List<dynamic>;
    return body
        .map((json) => Device.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Fetch a single device by its [deviceId].
  Future<Device> getDevice(String deviceId) async {
    final uri = Uri.parse('$baseUrl/api/devices/$deviceId');

    final response = await _client.get(uri);
    _ensureSuccess(response);

    return Device.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  // ---------------------------------------------------------------------------
  // Device State
  // ---------------------------------------------------------------------------

  /// Get the latest reported state for a device.
  ///
  /// Returns the state as a raw JSON map. The shape of the `state` field
  /// varies per device type.
  Future<Map<String, dynamic>> getDeviceState(String deviceId) async {
    final uri = Uri.parse('$baseUrl/api/devices/$deviceId/state');

    final response = await _client.get(uri);
    _ensureSuccess(response);

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // ---------------------------------------------------------------------------
  // Commands
  // ---------------------------------------------------------------------------

  /// Send a command to a device.
  ///
  /// [op] is the operation name (e.g. "on", "off", "set_level").
  /// [target] is the payload for the operation (e.g. {"level": 128}).
  /// [timeoutMs] defaults to 5000 ms on the server side.
  ///
  /// Returns the created command record including its server-assigned `id`
  /// and initial `status` ("accepted").
  Future<Map<String, dynamic>> sendCommand(
    String deviceId, {
    required String op,
    required Map<String, dynamic> target,
    int? timeoutMs,
  }) async {
    final uri = Uri.parse('$baseUrl/api/devices/$deviceId/command');

    final payload = <String, dynamic>{
      'op': op,
      'target': target,
    };
    if (timeoutMs != null) {
      payload['timeout_ms'] = timeoutMs;
    }

    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    _ensureSuccess(response);

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Poll the status of a previously issued command.
  Future<Map<String, dynamic>> getCommandStatus(String commandId) async {
    final uri = Uri.parse('$baseUrl/api/commands/$commandId');

    final response = await _client.get(uri);
    _ensureSuccess(response);

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // ---------------------------------------------------------------------------
  // Events
  // ---------------------------------------------------------------------------

  /// Fetch event history with optional filters.
  Future<List<Map<String, dynamic>>> getEvents({
    String? deviceId,
    String? eventType,
    int? limit,
    int? offset,
  }) async {
    final queryParams = <String, String>{};
    if (deviceId != null) queryParams['device_id'] = deviceId;
    if (eventType != null) queryParams['event_type'] = eventType;
    if (limit != null) queryParams['limit'] = limit.toString();
    if (offset != null) queryParams['offset'] = offset.toString();

    final uri = Uri.parse('$baseUrl/api/events').replace(
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );

    final response = await _client.get(uri);
    _ensureSuccess(response);

    final List<dynamic> body = jsonDecode(response.body) as List<dynamic>;
    return body.cast<Map<String, dynamic>>();
  }

  // ---------------------------------------------------------------------------
  // Health
  // ---------------------------------------------------------------------------

  /// Check API health.
  Future<Map<String, dynamic>> healthCheck() async {
    final uri = Uri.parse('$baseUrl/health');

    final response = await _client.get(uri);
    _ensureSuccess(response);

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  void _ensureSuccess(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        statusCode: response.statusCode,
        message: response.body,
      );
    }
  }

  /// Release the underlying HTTP client when the service is no longer needed.
  void dispose() {
    _client.close();
  }
}

/// Exception thrown when the API returns a non-2xx status code.
class ApiException implements Exception {
  const ApiException({required this.statusCode, required this.message});

  final int statusCode;
  final String message;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
