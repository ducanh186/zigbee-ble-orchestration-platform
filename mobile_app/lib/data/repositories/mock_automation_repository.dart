import '../../domain/models/automation_rule.dart';
import '../../domain/repositories/automation_repository.dart';

class MockAutomationRepository implements AutomationRepository {
  final List<AutomationRule> _rules = [
    AutomationRule(
      id: 'automation-mock-01',
      name: 'Motion turns on lab lights',
      enabled: true,
      trigger: const AutomationTrigger(
        deviceId: 'pir-01',
        deviceType: AutomationDeviceType.motion,
        event: AutomationTriggerEvent.occupancyChanged,
        state: {'occupancy': 'occupied'},
      ),
      actions: const [
        AutomationAction(
          deviceId: 'light-01',
          deviceType: AutomationDeviceType.light,
          command: AutomationActionCommand.on,
        ),
      ],
      syncStatus: AutomationSyncStatus.pending,
      lastRunStatus: AutomationLastRunStatus.neverRun,
      createdAt: '2026-05-15T08:00:00Z',
      updatedAt: '2026-05-15T08:00:00Z',
    ),
  ];

  int _nextRule = 2;

  @override
  Future<List<AutomationRule>> fetchRules() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return List.unmodifiable(_rules);
  }

  @override
  Future<AutomationRule> fetchRule(String ruleId) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return _rules.firstWhere((rule) => rule.id == ruleId);
  }

  @override
  Future<AutomationRule> createRule(AutomationRuleDraft draft) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    final rule = AutomationRule(
      id: 'automation-mock-${_nextRule++}',
      name: draft.name,
      enabled: draft.enabled,
      trigger: draft.trigger,
      actions: draft.actions,
      syncStatus: AutomationSyncStatus.pending,
      lastRunStatus: AutomationLastRunStatus.neverRun,
      createdAt: DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
    );
    _rules.insert(0, rule);
    return rule;
  }

  @override
  Future<AutomationRule> enableRule(String ruleId) async {
    return _setEnabled(ruleId, true);
  }

  @override
  Future<AutomationRule> disableRule(String ruleId) async {
    return _setEnabled(ruleId, false);
  }

  @override
  Future<void> deleteRule(String ruleId) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    _rules.removeWhere((rule) => rule.id == ruleId);
  }

  Future<AutomationRule> _setEnabled(String ruleId, bool enabled) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final index = _rules.indexWhere((rule) => rule.id == ruleId);
    final rule = _rules[index].copyWith(enabled: enabled);
    _rules[index] = rule;
    return rule;
  }
}
