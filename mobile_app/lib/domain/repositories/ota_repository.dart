import '../models/ota_campaign.dart';

/// Read-only OTA progress source for the mobile operator. Write actions
/// (creating campaigns, retrying devices) are out of scope for SCRUM-25;
/// the mobile screen only mirrors cloud state.
abstract class OtaRepository {
  /// Returns the currently active and recently completed OTA campaigns.
  /// Ordering is repository-defined; the view sorts as needed.
  Future<List<OtaCampaign>> listCampaigns();
}
