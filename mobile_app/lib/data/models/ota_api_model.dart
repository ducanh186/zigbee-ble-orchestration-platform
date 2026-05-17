import '../../domain/models/ota_campaign.dart';

/// Wire model for an OTA campaign returned by the cloud.
///
/// The JSON shape mirrors `docs/OTA_CAMPAIGN_CONTRACT.md`:
/// * `campaign_id` is sourced from the manifest.
/// * `firmware_version` comes from `artifact.file_version`.
/// * `device_ids` is the rolled-up list of target devices.
/// * `state` is collapsed by the cloud rollout manager into one of the four
///   operator-visible states (`queued`, `running`, `succeeded`, `failed`).
/// * `progress_pct` mirrors the per-device progress payload, rolled up to
///   a campaign-wide percentage.
class OtaCampaignApiModel {
  const OtaCampaignApiModel({
    required this.campaignId,
    required this.firmwareVersion,
    required this.deviceIds,
    required this.state,
    this.progressPct,
    this.errorMessage,
    this.startedAt,
    this.updatedAt,
  });

  factory OtaCampaignApiModel.fromJson(Map<String, Object?> json) {
    return OtaCampaignApiModel(
      campaignId: json['campaign_id'] as String,
      firmwareVersion: _firmwareVersionFromJson(json),
      deviceIds: (json['device_ids'] as List? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      state: _stateFromWire(json['state']?.toString()),
      progressPct: (json['progress_pct'] as num?)?.toDouble(),
      errorMessage: json['error_message'] as String?,
      startedAt: json['started_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  final String campaignId;
  final String firmwareVersion;
  final List<String> deviceIds;
  final OtaProgressState state;
  final double? progressPct;
  final String? errorMessage;
  final String? startedAt;
  final String? updatedAt;

  OtaCampaign toDomain() {
    return OtaCampaign(
      id: campaignId,
      firmwareVersion: firmwareVersion,
      deviceIds: deviceIds,
      state: state,
      progress: progressPct == null ? null : (progressPct! / 100.0).clamp(0, 1),
      errorMessage: errorMessage,
      startedAt: startedAt,
      updatedAt: updatedAt,
    );
  }
}

/// Reads either the top-level `firmware_version` field (preferred shape) or
/// falls back to the manifest's nested `artifact.file_version` so the mobile
/// app stays compatible with whichever shape the cloud rollout manager emits.
String _firmwareVersionFromJson(Map<String, Object?> json) {
  final direct = json['firmware_version'];
  if (direct != null) {
    return direct.toString();
  }
  final artifact = json['artifact'];
  if (artifact is Map) {
    final version = artifact['file_version'];
    if (version != null) {
      return version.toString();
    }
  }
  return '';
}

OtaProgressState _stateFromWire(String? wire) {
  switch (wire) {
    case 'queued':
      return OtaProgressState.queued;
    case 'running':
      return OtaProgressState.running;
    case 'succeeded':
    case 'success':
      return OtaProgressState.succeeded;
    case 'failed':
    case 'failure':
      return OtaProgressState.failed;
    default:
      return OtaProgressState.queued;
  }
}
