/// Represents the lifecycle of a cloud-coordinated OTA rollout from the
/// mobile operator's point of view. The values intentionally collapse the
/// per-device states defined in [docs/OTA_CAMPAIGN_CONTRACT.md] (e.g.
/// `staging`, `staged`) into the four states the operator cares about on
/// the progress screen.
enum OtaProgressState {
  /// Campaign has been published but not started yet (e.g. inside its
  /// rollout window but no device has begun staging).
  queued,

  /// At least one device is staging, offering, or applying the firmware.
  running,

  /// All targeted devices reached `staged` (or later) without failure.
  succeeded,

  /// One or more targeted devices reported a terminal failure event such as
  /// `artifact_stage_failed`.
  failed;

  String get label => switch (this) {
    OtaProgressState.queued => 'Queued',
    OtaProgressState.running => 'Running',
    OtaProgressState.succeeded => 'Succeeded',
    OtaProgressState.failed => 'Failed',
  };
}

/// Snapshot of a cloud OTA campaign as displayed on the mobile progress
/// screen. The campaign id and firmware version come from the manifest
/// (`campaign_id`, `artifact.file_version`); [progress] is the rolled-up
/// percentage of [deviceIds] that have reached the `staged` state.
class OtaCampaign {
  const OtaCampaign({
    required this.id,
    required this.firmwareVersion,
    required this.deviceIds,
    required this.state,
    this.progress,
    this.errorMessage,
    this.startedAt,
    this.updatedAt,
  });

  final String id;
  final String firmwareVersion;
  final List<String> deviceIds;
  final OtaProgressState state;

  /// Progress fraction in `[0.0, 1.0]`. Null when [state] is
  /// [OtaProgressState.queued] because no device has reported progress yet.
  final double? progress;

  /// Operator-facing failure reason, populated when [state] is
  /// [OtaProgressState.failed].
  final String? errorMessage;

  final String? startedAt;
  final String? updatedAt;

  int get targetedDeviceCount => deviceIds.length;
}
