import '../models/light_scene.dart';

enum SceneAvailability { available, empty, unavailable }

abstract interface class SceneRepository {
  SceneAvailability get lastAvailability;

  Future<List<LightScene>> fetchScenes();
}
