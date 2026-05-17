import 'package:flutter/foundation.dart';

import '../../../../data/services/api_client.dart';
import '../../../../domain/models/ota_campaign.dart';
import '../../../../domain/repositories/ota_repository.dart';

/// Holds the OTA campaign snapshot rendered by the settings progress
/// section. Currently a single-shot loader; periodic polling is deferred
/// until the cloud OTA router (SCRUM-8) lands.
class OtaProgressViewModel extends ChangeNotifier {
  OtaProgressViewModel({required OtaRepository repository})
    : _repository = repository;

  final OtaRepository _repository;

  List<OtaCampaign> _campaigns = const [];
  bool _isLoading = false;
  String? _errorMessage;

  List<OtaCampaign> get campaigns => List.unmodifiable(_campaigns);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _campaigns = await _repository.listCampaigns();
    } catch (error) {
      _errorMessage = friendlyErrorMessage(
        error,
        context: 'Khong tai duoc tien trinh OTA',
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
