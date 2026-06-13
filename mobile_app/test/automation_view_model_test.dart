import 'package:flutter_test/flutter_test.dart';
import 'package:zigbee_smart_building/domain/models/automation_rule.dart';
import 'package:zigbee_smart_building/domain/models/light_scene.dart';
import 'package:zigbee_smart_building/domain/repositories/automation_repository.dart';
import 'package:zigbee_smart_building/domain/repositories/scene_repository.dart';
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

  test('loads scenes without blocking automation rules', () async {
    final sceneRepository = _FakeSceneRepository(
      scenes: const [
        LightScene(
          groupId: 'group-lab',
          sceneId: 'scene-on',
          label: 'Lab on',
          deviceIds: ['light-01'],
        ),
      ],
    );
    final viewModel = AutomationViewModel(
      repository: _FakeAutomationRepository(
        initialRules: [_rule(syncStatus: AutomationSyncStatus.pending)],
      ),
      sceneRepository: sceneRepository,
    );

    await viewModel.load();

    expect(viewModel.rules, hasLength(1));
    expect(viewModel.scenes.single.label, 'Lab on');
    expect(viewModel.sceneAvailability, SceneAvailability.available);
    expect(viewModel.errorMessage, isNull);
  });

  test('scene endpoint failure preserves direct light flow', () async {
    final viewModel = AutomationViewModel(
      repository: _FakeAutomationRepository(),
      sceneRepository: _FakeSceneRepository(
        availability: SceneAvailability.unavailable,
      ),
    );

    await viewModel.load();

    expect(viewModel.scenes, isEmpty);
    expect(viewModel.sceneAvailability, SceneAvailability.unavailable);
    expect(viewModel.errorMessage, isNull);
  });

  test(
    'unexpected scene failure keeps rules and surfaces friendly error',
    () async {
      final viewModel = AutomationViewModel(
        repository: _FakeAutomationRepository(
          initialRules: [_rule(syncStatus: AutomationSyncStatus.pending)],
        ),
        sceneRepository: _FakeSceneRepository(error: Exception('token leaked')),
      );

      await viewModel.load();

      expect(viewModel.rules, hasLength(1));
      expect(viewModel.sceneAvailability, SceneAvailability.unavailable);
      expect(viewModel.errorMessage, contains('Khong tai duoc scenes'));
      expect(viewModel.errorMessage, isNot(contains('token leaked')));
    },
  );

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

  test(
    'createRule surfaces friendly error without leaking raw exception',
    () async {
      final repository = _FakeAutomationRepository(createError: 'network down');
      final viewModel = AutomationViewModel(repository: repository);

      await viewModel.createRule(_draft());

      expect(viewModel.rules, isEmpty);
      expect(viewModel.errorMessage, isNotNull);
      expect(
        viewModel.errorMessage,
        contains('Khong tao duoc automation rule'),
      );
      // Raw repository exception text must not be surfaced to the user.
      expect(viewModel.errorMessage, isNot(contains('network down')));
    },
  );

  test('deleteRule refreshes the rules from repository after delete', () async {
    final repository = _FakeAutomationRepository(
      initialRules: [
        _rule(syncStatus: AutomationSyncStatus.synced),
        _rule(id: 'automation-02', syncStatus: AutomationSyncStatus.synced),
      ],
      rulesAfterDelete: [
        _rule(id: 'automation-02', syncStatus: AutomationSyncStatus.synced),
      ],
    );
    final viewModel = AutomationViewModel(repository: repository);

    await viewModel.load();
    await viewModel.deleteRule('automation-01');

    expect(repository.deletedRuleIds, ['automation-01']);
    expect(repository.fetchRulesCount, 2);
    expect(viewModel.rules.map((rule) => rule.id), ['automation-02']);
    expect(viewModel.errorMessage, isNull);
  });

  test(
    'deleteRule surfaces an error when cloud reload still returns deleted rule',
    () async {
      final repository = _FakeAutomationRepository(
        initialRules: [_rule(syncStatus: AutomationSyncStatus.synced)],
        rulesAfterDelete: [_rule(syncStatus: AutomationSyncStatus.synced)],
      );
      final viewModel = AutomationViewModel(repository: repository);

      await viewModel.load();
      await viewModel.deleteRule('automation-01');

      expect(repository.deletedRuleIds, ['automation-01']);
      expect(repository.fetchRulesCount, 2);
      expect(viewModel.rules.single.id, 'automation-01');
      expect(
        viewModel.errorMessage,
        'Cloud chua xoa rule. Kiem tra backend release hoac API endpoint.',
      );
    },
  );

  test(
    'deleteRule keeps the rule and surfaces friendly error on failure',
    () async {
      final repository = _FakeAutomationRepository(
        initialRules: [_rule(syncStatus: AutomationSyncStatus.synced)],
        deleteError: 'delete failed',
      );
      final viewModel = AutomationViewModel(repository: repository);

      await viewModel.load();
      await viewModel.deleteRule('automation-01');

      expect(viewModel.rules.single.id, 'automation-01');
      expect(
        viewModel.errorMessage,
        contains('Khong xoa duoc automation rule'),
      );
      expect(viewModel.errorMessage, isNot(contains('delete failed')));
    },
  );
}

AutomationRuleDraft _draft() {
  return const AutomationRuleDraft(
    name: 'Motion turns on lab lights',
    enabled: true,
    triggerDeviceId: 'pir-01',
    triggerDeviceType: AutomationDeviceType.motion,
    triggerEvent: AutomationTriggerEvent.occupancyChanged,
    triggerState: {'occupancy': 'occupied'},
    actionCommand: AutomationActionCommand.on,
    targetLightIds: ['light-01'],
  );
}

AutomationRule _rule({
  String id = 'automation-01',
  required AutomationSyncStatus syncStatus,
}) {
  return AutomationRule(
    id: id,
    name: 'Motion turns on lab lights',
    enabled: true,
    trigger: const EventAutomationTrigger(
      deviceId: 'pir-01',
      deviceType: AutomationDeviceType.motion,
      event: AutomationTriggerEvent.occupancyChanged,
      state: {'occupancy': 'occupied'},
    ),
    actions: const [
      DeviceCommandAutomationAction(
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
    List<AutomationRule>? rulesAfterDelete,
    String? createError,
    String? deleteError,
  }) : _rules = List.of(initialRules ?? []),
       _createdRule = createdRule,
       _fetchedRule = fetchedRule,
       _rulesAfterDelete = rulesAfterDelete,
       _createError = createError,
       _deleteError = deleteError;

  final List<AutomationRule> _rules;
  final AutomationRule? _createdRule;
  final AutomationRule? _fetchedRule;
  final List<AutomationRule>? _rulesAfterDelete;
  final String? _createError;
  final String? _deleteError;
  final List<AutomationRuleDraft> createdDrafts = [];
  final List<String> fetchedRuleIds = [];
  final List<String> deletedRuleIds = [];
  int fetchRulesCount = 0;

  @override
  Future<List<AutomationRule>> fetchRules() async {
    fetchRulesCount++;
    if (deletedRuleIds.isNotEmpty && _rulesAfterDelete != null) {
      return List.unmodifiable(_rulesAfterDelete);
    }
    return List.unmodifiable(_rules);
  }

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

  @override
  Future<void> deleteRule(String ruleId) async {
    if (_deleteError != null) {
      throw Exception(_deleteError);
    }
    deletedRuleIds.add(ruleId);
    _rules.removeWhere((rule) => rule.id == ruleId);
  }
}

class _FakeSceneRepository implements SceneRepository {
  _FakeSceneRepository({
    this.scenes = const [],
    this.error,
    SceneAvailability? availability,
  }) : lastAvailability =
           availability ??
           (scenes.isEmpty
               ? SceneAvailability.empty
               : SceneAvailability.available);

  final List<LightScene> scenes;
  final Object? error;

  @override
  SceneAvailability lastAvailability;

  @override
  Future<List<LightScene>> fetchScenes() async {
    if (error != null) {
      lastAvailability = SceneAvailability.unavailable;
      throw error!;
    }
    return scenes;
  }
}
