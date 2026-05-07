import 'package:flutter_test/flutter_test.dart';

import 'package:zigbee_smart_building/data/repositories/mock_device_repository.dart';
import 'package:zigbee_smart_building/main.dart';

void main() {
  testWidgets('renders LIGHT control dashboard', (tester) async {
    await tester.pumpWidget(
      ZigbeeSmartBuildingApp(
        repository: MockDeviceRepository(),
        apiBaseUrl: 'mock',
        useMockApi: true,
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Home'), findsWidgets);
    expect(find.text('QUICK LIGHTS'), findsOneWidget);
    expect(find.text('Lab Light 01'), findsOneWidget);
  });
}
