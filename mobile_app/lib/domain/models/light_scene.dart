class LightScene {
  const LightScene({
    required this.groupId,
    required this.sceneId,
    required this.label,
    required this.deviceIds,
  });

  factory LightScene.fromJson(Map<String, Object?> json) {
    final compactIds = (json['device_ids'] as List?)
        ?.whereType<String>()
        .toList(growable: false);
    final lights = (json['lights'] as List?)
        ?.whereType<Map>()
        .map((item) => item['device_id'])
        .whereType<String>()
        .toList(growable: false);

    return LightScene(
      groupId: json['group_id'] as String,
      sceneId: json['scene_id'] as String,
      label: json['label'] as String,
      deviceIds: List.unmodifiable(compactIds ?? lights ?? const <String>[]),
    );
  }

  final String groupId;
  final String sceneId;
  final String label;
  final List<String> deviceIds;
}
