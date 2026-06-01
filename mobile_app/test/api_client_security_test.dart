import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zigbee_smart_building/data/services/api_client.dart';

void main() {
  test('attaches bearer token to API requests', () async {
    final apiClient = ApiClient(
      baseUrl: 'https://cloud.example.test',
      accessToken: 'test-api-token',
      httpClient: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer test-api-token');
        return http.Response(
          '{}',
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await apiClient.getJson('/api/devices');
  });
}
