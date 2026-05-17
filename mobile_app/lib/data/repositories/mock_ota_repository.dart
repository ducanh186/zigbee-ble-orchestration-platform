import '../../domain/models/ota_campaign.dart';
import '../../domain/repositories/ota_repository.dart';

/// In-memory [OtaRepository] used in mock mode and as a default while the
/// cloud OTA rollout manager (SCRUM-8) is unavailable. Returns a small set
/// of representative campaigns covering each progress state so operators
/// can preview the UI without a live backend.
class MockOtaRepository implements OtaRepository {
  @override
  Future<List<OtaCampaign>> listCampaigns() async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    return const [
      OtaCampaign(
        id: 'ota-camp-001',
        firmwareVersion: '3',
        deviceIds: ['light-01', 'light-02', 'light-03'],
        state: OtaProgressState.running,
        progress: 0.42,
        startedAt: '07:10 05/17/2026',
        updatedAt: '07:14 05/17/2026',
      ),
      OtaCampaign(
        id: 'ota-camp-002',
        firmwareVersion: '4',
        deviceIds: ['light-04'],
        state: OtaProgressState.queued,
      ),
    ];
  }
}
