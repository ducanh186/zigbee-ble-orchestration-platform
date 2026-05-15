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
  const AutomationTriggerApiModel({
    required this.deviceId,
    required this.deviceType,
    required this.event,
    this.state = const {},
  });

  factory AutomationTriggerApiModel.fromJson(Map<String, Object?> json) {
    return AutomationTriggerApiModel(
      deviceId: json['device_id'] as String? ?? '',
      deviceType: AutomationDeviceType.fromJson(json['device_type']),
      event: AutomationTriggerEvent.fromJson(json['event']),
      state: Map<String, Object?>.from(json['state'] as Map? ?? const {}),
    );
  }

  factory AutomationTriggerApiModel.fromDomain(AutomationTrigger trigger) {
    return AutomationTriggerApiModel(
      deviceId: trigger.deviceId,
      deviceType: trigger.deviceType,
      event: trigger.event,
      state: trigger.state,
    );
  }

  final String deviceId;
  final AutomationDeviceType deviceType;
  final AutomationTriggerEvent event;
  final Map<String, Object?> state;

  AutomationTrigger toDomain() {
    return AutomationTrigger(
      deviceId: deviceId,
      deviceType: deviceType,
      event: event,
      state: state,
    );
  }

  Map<String, Object?> toJson() {
    final json = <String, Object?>{
      'device_id': deviceId,
      'device_type': deviceType.wireValue,
      'event': event.wireValue,
    };
    if (state.isNotEmpty) {
      json['state'] = state;
    }
    return json;
  }
}

class AutomationActionApiModel {
  const AutomationActionApiModel({
    required this.deviceId,
    required this.deviceType,
    required this.command,
  });

  factory AutomationActionApiModel.fromJson(Map<String, Object?> json) {
    return AutomationActionApiModel(
      deviceId: json['device_id'] as String? ?? '',
      deviceType: AutomationDeviceType.fromJson(json['device_type']),
      command: AutomationActionCommand.fromJson(json['command']),
    );
  }

  factory AutomationActionApiModel.fromDomain(AutomationAction action) {
    return AutomationActionApiModel(
      deviceId: action.deviceId,
      deviceType: action.deviceType,
      command: action.command,
    );
  }

  final String deviceId;
  final AutomationDeviceType deviceType;
  final AutomationActionCommand command;

  AutomationAction toDomain() {
    return AutomationAction(
      deviceId: deviceId,
      deviceType: deviceType,
      command: command,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'device_id': deviceId,
      'device_type': deviceType.wireValue,
      'command': command.wireValue,
    };
  }
}

class AutomationRuleDraftApiModel {
  const AutomationRuleDraftApiModel({required this.draft});

  final AutomationRuleDraft draft;

  Map<String, Object?> toJson() {
    return {
      'name': draft.name,
      'enabled': draft.enabled,
      'trigger': AutomationTriggerApiModel.fromDomain(draft.trigger).toJson(),
      'actions': draft.actions
          .map((action) => AutomationActionApiModel.fromDomain(action).toJson())
          .toList(),
    };
  }
}
