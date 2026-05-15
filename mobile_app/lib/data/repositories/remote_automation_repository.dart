import '../../domain/models/automation_rule.dart';
import '../../domain/repositories/automation_repository.dart';
import '../models/automation_api_model.dart';
import '../services/api_client.dart';

class RemoteAutomationRepository implements AutomationRepository {
  RemoteAutomationRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<List<AutomationRule>> fetchRules() async {
    final json = await _apiClient.getJson('/api/automations');
    return (json as List)
        .whereType<Map>()
        .map(
          (item) => AutomationRuleApiModel.fromJson(
            Map<String, Object?>.from(item),
          ).toDomain(),
        )
        .toList();
  }

  @override
  Future<AutomationRule> fetchRule(String ruleId) async {
    final json = await _apiClient.getJson('/api/automations/$ruleId');
    return _ruleFromJson(json);
  }

  @override
  Future<AutomationRule> createRule(AutomationRuleDraft draft) async {
    final json = await _apiClient.postJson(
      '/api/automations',
      AutomationRuleDraftApiModel(draft: draft).toJson(),
    );
    return _ruleFromJson(json);
  }

  @override
  Future<AutomationRule> enableRule(String ruleId) async {
    final json = await _apiClient.postJson(
      '/api/automations/$ruleId/enable',
      <String, Object?>{},
    );
    return json == null ? fetchRule(ruleId) : _ruleFromJson(json);
  }

  @override
  Future<AutomationRule> disableRule(String ruleId) async {
    final json = await _apiClient.postJson(
      '/api/automations/$ruleId/disable',
      <String, Object?>{},
    );
    return json == null ? fetchRule(ruleId) : _ruleFromJson(json);
  }

  AutomationRule _ruleFromJson(Object? json) {
    return AutomationRuleApiModel.fromJson(
      Map<String, Object?>.from(json as Map),
    ).toDomain();
  }
}
