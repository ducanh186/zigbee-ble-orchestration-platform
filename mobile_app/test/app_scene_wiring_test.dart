import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zigbee_smart_building/data/repositories/mock_automation_repository.dart';
import 'package:zigbee_smart_building/data/repositories/mock_device_repository.dart';
import 'package:zigbee_smart_building/domain/models/light_scene.dart';
import 'package:zigbee_smart_building/domain/repositories/scene_repository.dart';
import 'package:zigbee_smart_building/main.dart';
import 'package:zigbee_smart_building/ui/features/automation/view_models/automation_view_model.dart';

void main() {
  testWidgets('wires scene repository into automation view model', (
    tester,
  ) async {
    await tester.pumpWidget(
      ZigbeeSmartBuildingApp(
        repository: MockDeviceRepository(),
        automationRepository: MockAutomationRepository(),
        sceneRepository: _FakeSceneRepository(),
        apiBaseUrl: 'http://localhost',
        useMockApi: true,
        hideLogin: true,
      ),
    );

    final context = tester.element(find.byType(MaterialApp));
    final viewModel = context.read<AutomationViewModel>();
    final load = viewModel.load();
    await tester.pump(const Duration(milliseconds: 200));
    await load;
    await tester.pumpAndSettle();

    expect(viewModel.scenes.single.sceneId, 'scene-all-on');
  });
}

class _FakeSceneRepository implements SceneRepository {
  @override
  SceneAvailability get lastAvailability => SceneAvailability.available;

  @override
  Future<List<LightScene>> fetchScenes() async {
    return const [
      LightScene(
        groupId: 'group-lab',
        sceneId: 'scene-all-on',
        label: 'Lab all on',
        deviceIds: ['light-1'],
      ),
    ];
  }
}
