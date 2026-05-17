import '../../domain/models/ota_campaign.dart';
import '../../domain/repositories/ota_repository.dart';
import '../models/ota_api_model.dart';
import '../services/api_client.dart';

/// HTTP-backed [OtaRepository] aligned with
/// `docs/OTA_CAMPAIGN_CONTRACT.md`.
///
/// IMPORTANT: as of 2026-05, the cloud has NO OTA router (see
/// `cloud/app/routers/`). The campaign manifests, progress, and event payloads
/// in the contract are exchanged directly over MQTT between the cloud and
/// Z3Gateway C. Until the cloud OTA rollout manager (SCRUM-8) lands and
/// exposes a REST mirror of those payloads, every call here will produce a
/// 404 `ApiException`. The endpoints below are the conventional REST
/// projection of the MQTT topics:
///
///   * `GET /api/ota/campaigns`         -> list of campaign snapshots
///   * `GET /api/ota/campaigns/{id}`    -> single campaign snapshot
///
/// The JSON shape consumed here matches [OtaCampaignApiModel.fromJson]; the
/// per-device progress fields (`device_id`, `progress_pct`, `status`) from
/// the contract are expected to be rolled up by the cloud into campaign-wide
/// state + progress percentage before being served to the mobile client.
class RemoteOtaRepository implements OtaRepository {
  RemoteOtaRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<List<OtaCampaign>> listCampaigns() async {
    try {
      final json = await _apiClient.getJson('/api/ota/campaigns');
      return (json as List)
          .whereType<Map>()
          .map(
            (item) => OtaCampaignApiModel.fromJson(
              Map<String, Object?>.from(item),
            ).toDomain(),
          )
          .toList(growable: false);
    } on ApiException catch (error) {
      // The cloud OTA router does not exist yet (SCRUM-8 dependency). Map
      // 404 to an empty list so the settings screen renders cleanly rather
      // than surfacing a noisy backend error during pre-launch. Any other
      // failure (5xx, validation, transport) is rethrown so the view model
      // can show its standard friendly message.
      if (error.statusCode == 404) {
        return const <OtaCampaign>[];
      }
      rethrow;
    }
  }
}
