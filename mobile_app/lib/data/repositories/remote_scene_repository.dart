import '../../domain/models/light_scene.dart';
import '../../domain/repositories/scene_repository.dart';
import '../services/api_client.dart';

class RemoteSceneRepository implements SceneRepository {
  RemoteSceneRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  SceneAvailability lastAvailability = SceneAvailability.unavailable;

  @override
  Future<List<LightScene>> fetchScenes() async {
    try {
      final json = await _apiClient.getJson('/api/scenes');
      final scenes = (json as List)
          .whereType<Map>()
          .map((item) => LightScene.fromJson(Map<String, Object?>.from(item)))
          .toList(growable: false);
      lastAvailability = scenes.isEmpty
          ? SceneAvailability.empty
          : SceneAvailability.available;
      return scenes;
    } on ApiException catch (error) {
      if (error.statusCode == 404 || error.statusCode == 501) {
        lastAvailability = SceneAvailability.unavailable;
        return const [];
      }
      rethrow;
    }
  }
}
