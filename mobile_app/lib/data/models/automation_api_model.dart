import '../../domain/models/automation_rule.dart';

class AutomationRuleApiModel {
  const AutomationRuleApiModel({
    required this.id,
    required this.name,
    required this.enabled,
    required this.trigger,
    required this.actions,
    required this.syncStatus,
    required this.lastRunStatus,
    this.lastError,
    this.createdAt,
    this.updatedAt,
  });

  factory AutomationRuleApiModel.fromJson(Map<String, Object?> json) {
    return AutomationRuleApiModel(
      id: json['id'] as String,
      name: json['name'] as String,
      enabled: json['enabled'] as bool? ?? true,
      trigger: AutomationTriggerApiModel.fromJson(
        Map<String, Object?>.from(json['trigger'] as Map? ?? const {}),
        scheduleCron: json['schedule_cron'] as String?,
      ),
      actions: (json['actions'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) => AutomationActionApiModel.fromJson(
              Map<String, Object?>.from(item),
            ),
          )
          .toList(growable: false),
      syncStatus: AutomationSyncStatus.fromJson(json['sync_status']),
      lastRunStatus: AutomationLastRunStatus.fromJson(json['last_run_status']),
      lastError: json['last_error'] as String?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  final String id;
  final String name;
  final bool enabled;
  final AutomationTriggerApiModel trigger;
  final List<AutomationActionApiModel> actions;
  final AutomationSyncStatus syncStatus;
  final AutomationLastRunStatus lastRunStatus;
  final String? lastError;
  final String? createdAt;
  final String? updatedAt;

  AutomationRule toDomain() {
    return AutomationRule(
      id: id,
      name: name,
      enabled: enabled,
      trigger: trigger.toDomain(),
      actions: actions.map((action) => action.toDomain()).toList(),
      syncStatus: syncStatus,
      lastRunStatus: lastRunStatus,
      lastError: lastError,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class AutomationTriggerApiModel {
  const AutomationTriggerApiModel({required this.value});

  factory AutomationTriggerApiModel.fromJson(
    Map<String, Object?> json, {
    String? scheduleCron,
  }) {
    final type = json['type'] as String? ?? 'device_event';
    final trigger = switch (type) {
      'schedule' => ScheduleAutomationTrigger(cron: scheduleCron ?? ''),
      'sensor_threshold' => SensorThresholdAutomationTrigger(
        deviceId: json['device_id'] as String? ?? '',
        metric: json['metric'] == 'humidity_percent'
            ? EnvironmentMetric.humidity
            : EnvironmentMetric.temperature,
        operator: json['operator'] == 'lte'
            ? ThresholdOperator.lte
            : ThresholdOperator.gte,
        threshold: (json['threshold'] as num?)?.toDouble() ?? 0,
      ),
      _ => EventAutomationTrigger(
        deviceId: json['device_id'] as String? ?? '',
        deviceType: AutomationDeviceType.fromJson(json['device_type']),
        event: AutomationTriggerEvent.fromJson(json['event']),
        state: Map<String, Object?>.from(json['state'] as Map? ?? const {}),
      ),
    };
    return AutomationTriggerApiModel(value: trigger);
  }

  factory AutomationTriggerApiModel.fromDomain(AutomationTrigger trigger) {
    return AutomationTriggerApiModel(value: trigger);
  }

  final AutomationTrigger value;

  AutomationTrigger toDomain() => value;

  Map<String, Object?> toJson() => value.toJson();
}

class AutomationActionApiModel {
  const AutomationActionApiModel({required this.value});

  factory AutomationActionApiModel.fromJson(Map<String, Object?> json) {
    final type = json['type'] as String? ?? 'device_command';
    final action = switch (type) {
      'scene_activate' => SceneActivateAutomationAction(
        groupId: json['group_id'] as String? ?? '',
        sceneId: json['scene_id'] as String? ?? '',
      ),
      _ => DeviceCommandAutomationAction(
        deviceId: json['device_id'] as String? ?? '',
        command: AutomationActionCommand.fromJson(json['command']),
      ),
    };
    return AutomationActionApiModel(value: action);
  }

  factory AutomationActionApiModel.fromDomain(AutomationAction action) {
    return AutomationActionApiModel(value: action);
  }

  final AutomationAction value;

  AutomationAction toDomain() => value;

  Map<String, Object?> toJson() => value.toJson();
}

class AutomationRuleDraftApiModel {
  const AutomationRuleDraftApiModel({required this.draft});

  final AutomationRuleDraft draft;

  Map<String, Object?> toJson() {
    return {
      'name': draft.name,
      'enabled': draft.enabled,
      'trigger_type': draft.trigger.triggerType.wireValue,
      'schedule_cron': draft.scheduleCron,
      'trigger': AutomationTriggerApiModel.fromDomain(draft.trigger).toJson(),
      'actions': draft.actions
          .map((action) => AutomationActionApiModel.fromDomain(action).toJson())
          .toList(),
    };
  }
}
