import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zigbee_smart_building/data/repositories/remote_scene_repository.dart';
import 'package:zigbee_smart_building/data/services/api_client.dart';
import 'package:zigbee_smart_building/domain/repositories/scene_repository.dart';

void main() {
  test('fetchScenes maps light-only scene tuples', () async {
    final repository = RemoteSceneRepository(
      apiClient: ApiClient(
        baseUrl: 'http://example.test',
        httpClient: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/scenes');
          return http.Response(
            jsonEncode([
              {
                'group_id': 'group-lab',
                'scene_id': 'scene-on',
                'label': 'Lab lights on',
                'lights': [
                  {'device_id': 'light-1', 'command': 'on'},
                  {'device_id': 'light-2', 'command': 'on'},
                ],
              },
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      ),
    );

    final scenes = await repository.fetchScenes();

    expect(scenes.single.label, 'Lab lights on');
    expect(scenes.single.deviceIds, ['light-1', 'light-2']);
    expect(repository.lastAvailability, SceneAvailability.available);
  });

  for (final statusCode in [404, 501]) {
    test('$statusCode scene endpoint becomes unavailable', () async {
      final repository = RemoteSceneRepository(
        apiClient: ApiClient(
          baseUrl: 'http://example.test',
          httpClient: MockClient(
            (_) async => http.Response(
              '{"detail":"Not supported"}',
              statusCode,
              headers: {'content-type': 'application/json'},
            ),
          ),
        ),
      );

      final scenes = await repository.fetchScenes();

      expect(scenes, isEmpty);
      expect(repository.lastAvailability, SceneAvailability.unavailable);
    });
  }

  test('successful empty response is distinct from unavailable', () async {
    final repository = RemoteSceneRepository(
      apiClient: ApiClient(
        baseUrl: 'http://example.test',
        httpClient: MockClient(
          (_) async => http.Response(
            '[]',
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
      ),
    );

    expect(await repository.fetchScenes(), isEmpty);
    expect(repository.lastAvailability, SceneAvailability.empty);
  });
}
