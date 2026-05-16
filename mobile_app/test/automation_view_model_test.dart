import 'package:flutter_test/flutter_test.dart';
import 'package:zigbee_smart_building/domain/models/automation_rule.dart';
import 'package:zigbee_smart_building/domain/repositories/automation_repository.dart';
import 'package:zigbee_smart_building/ui/features/automation/view_models/automation_view_model.dart';

void main() {
  test('load exposes automation rules from repository', () async {
    final repository = _FakeAutomationRepository(
      initialRules: [_rule(syncStatus: AutomationSyncStatus.pending)],
    );
    final viewModel = AutomationViewModel(repository: repository);

    await viewModel.load();

    expect(viewModel.rules, hasLength(1));
    expect(viewModel.rules.single.name, 'Motion turns on lab lights');
    expect(viewModel.errorMessage, isNull);
  });

  test('createRule polls pending rule until sync status is final', () async {
    final repository = _FakeAutomationRepository(
      createdRule: _rule(syncStatus: AutomationSyncStatus.pending),
      fetchedRule: _rule(syncStatus: AutomationSyncStatus.synced),
    );
    final viewModel = AutomationViewModel(
      repository: repository,
      pollDelay: Duration.zero,
      maxPollAttempts: 2,
    );

    await viewModel.createRule(_draft());

    expect(repository.createdDrafts, hasLength(1));
    expect(repository.fetchedRuleIds, ['automation-01']);
    expect(viewModel.rules.single.syncStatus, AutomationSyncStatus.synced);
  });

  test('createRule surfaces friendly error without leaking raw exception',
      () async {
    final repository = _FakeAutomationRepository(createError: 'network down');
    final viewModel = AutomationViewModel(repository: repository);

    await viewModel.createRule(_draft());

    expect(viewModel.rules, isEmpty);
    expect(viewModel.errorMessage, isNotNull);
    expect(viewModel.errorMessage, contains('Khong tao duoc automation rule'));
    // Raw repository exception text must not be surfaced to the user.
    expect(viewModel.errorMessage, isNot(contains('network down')));
  });
}

AutomationRuleDraft _draft() {
  return const AutomationRuleDraft(
    name: 'Motion turns on lab lights',
    enabled: true,
    template: AutomationRuleTemplate.motionOccupiedTurnsOnLights,
    triggerDeviceId: 'pir-01',
    targetLightIds: ['light-01'],
  );
}

AutomationRule _rule({required AutomationSyncStatus syncStatus}) {
  return AutomationRule(
    id: 'automation-01',
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
    syncStatus: syncStatus,
    lastRunStatus: AutomationLastRunStatus.neverRun,
    createdAt: '2026-05-15T08:00:00Z',
    updatedAt: '2026-05-15T08:00:00Z',
  );
}

class _FakeAutomationRepository implements AutomationRepository {
  _FakeAutomationRepository({
    List<AutomationRule>? initialRules,
    AutomationRule? createdRule,
    AutomationRule? fetchedRule,
    String? createError,
  }) : _rules = List.of(initialRules ?? []),
       _createdRule = createdRule,
       _fetchedRule = fetchedRule,
       _createError = createError;

  final List<AutomationRule> _rules;
  final AutomationRule? _createdRule;
  final AutomationRule? _fetchedRule;
  final String? _createError;
  final List<AutomationRuleDraft> createdDrafts = [];
  final List<String> fetchedRuleIds = [];

  @override
  Future<List<AutomationRule>> fetchRules() async => List.unmodifiable(_rules);

  @override
  Future<AutomationRule> fetchRule(String ruleId) async {
    fetchedRuleIds.add(ruleId);
    return _fetchedRule ?? _rules.firstWhere((rule) => rule.id == ruleId);
  }

  @override
  Future<AutomationRule> createRule(AutomationRuleDraft draft) async {
    if (_createError != null) {
      throw Exception(_createError);
    }
    createdDrafts.add(draft);
    final rule =
        _createdRule ?? _rule(syncStatus: AutomationSyncStatus.pending);
    _rules.add(rule);
    return rule;
  }

  @override
  Future<AutomationRule> enableRule(String ruleId) async => fetchRule(ruleId);

  @override
  Future<AutomationRule> disableRule(String ruleId) async => fetchRule(ruleId);
}
