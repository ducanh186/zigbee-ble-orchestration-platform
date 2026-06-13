import 'package:flutter_test/flutter_test.dart';
import 'package:zigbee_smart_building/domain/models/light_scene.dart';

void main() {
  test('parses the Cloud light scene contract', () {
    final scene = LightScene.fromJson({
      'group_id': 'group-lab',
      'scene_id': 'scene-all-on',
      'label': 'Lab all on',
      'lights': [
        {'device_id': 'light-1', 'command': 'on'},
        {'device_id': 'light-2', 'command': 'off'},
      ],
    });

    expect(scene.groupId, 'group-lab');
    expect(scene.sceneId, 'scene-all-on');
    expect(scene.label, 'Lab all on');
    expect(scene.deviceIds, ['light-1', 'light-2']);
  });

  test('accepts the compact device_ids tuple for compatibility', () {
    final scene = LightScene.fromJson({
      'group_id': 'group-lab',
      'scene_id': 'scene-all-on',
      'label': 'Lab all on',
      'device_ids': ['light-1', 'light-2'],
    });

    expect(scene.deviceIds, ['light-1', 'light-2']);
  });
}
