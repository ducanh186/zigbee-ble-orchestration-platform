enum AutomationDeviceType {
  light,
  switchDevice,
  motion,
  environment;

  static AutomationDeviceType fromJson(Object? value) {
    return switch (value) {
      'light' => AutomationDeviceType.light,
      'switch' => AutomationDeviceType.switchDevice,
      'motion' => AutomationDeviceType.motion,
      'environment' => AutomationDeviceType.environment,
      _ => AutomationDeviceType.light,
    };
  }

  String get wireValue => switch (this) {
    AutomationDeviceType.light => 'light',
    AutomationDeviceType.switchDevice => 'switch',
    AutomationDeviceType.motion => 'motion',
    AutomationDeviceType.environment => 'environment',
  };

  String get label => switch (this) {
    AutomationDeviceType.light => 'Light',
    AutomationDeviceType.switchDevice => 'Switch',
    AutomationDeviceType.motion => 'Motion',
    AutomationDeviceType.environment => 'Environment',
  };
}

enum AutomationTriggerEvent {
  switchToggle,
  occupancyChanged;

  static AutomationTriggerEvent fromJson(Object? value) {
    return switch (value) {
      'toggle' || 'switch_toggle' => AutomationTriggerEvent.switchToggle,
      'occupancy_changed' => AutomationTriggerEvent.occupancyChanged,
      _ => AutomationTriggerEvent.occupancyChanged,
    };
  }

  // Canonical wire values per docs/AUTOMATION_MQTT_CONTRACT.md §4.3.
  // Gateway's automation_rule.c only accepts `switch_toggle`; emitting the
  // legacy `toggle` here makes rules fail sync with `unsupported_trigger`.
  // `fromJson` above still parses `toggle` so cached/legacy responses keep
  // working.
  String get wireValue => switch (this) {
    AutomationTriggerEvent.switchToggle => 'switch_toggle',
    AutomationTriggerEvent.occupancyChanged => 'occupancy_changed',
  };

  String get label => switch (this) {
    AutomationTriggerEvent.switchToggle => 'Switch toggles',
    AutomationTriggerEvent.occupancyChanged => 'Occupancy changes',
  };
}

enum AutomationActionCommand {
  on,
  off,
  toggle;

  static AutomationActionCommand fromJson(Object? value) {
    return switch (value) {
      'on' => AutomationActionCommand.on,
      'off' => AutomationActionCommand.off,
      'toggle' => AutomationActionCommand.toggle,
      _ => AutomationActionCommand.toggle,
    };
  }

  String get wireValue => switch (this) {
    AutomationActionCommand.on => 'on',
    AutomationActionCommand.off => 'off',
    AutomationActionCommand.toggle => 'toggle',
  };

  String get label => switch (this) {
    AutomationActionCommand.on => 'Turn on',
    AutomationActionCommand.off => 'Turn off',
    AutomationActionCommand.toggle => 'Toggle',
  };
}

enum AutomationSyncStatus {
  pending,
  synced,
  failed;

  static AutomationSyncStatus fromJson(Object? value) {
    return switch (value) {
      'synced' => AutomationSyncStatus.synced,
      'failed' => AutomationSyncStatus.failed,
      _ => AutomationSyncStatus.pending,
    };
  }

  String get wireValue => switch (this) {
    AutomationSyncStatus.pending => 'pending',
    AutomationSyncStatus.synced => 'synced',
    AutomationSyncStatus.failed => 'failed',
  };

  String get label => switch (this) {
    AutomationSyncStatus.pending => 'PENDING',
    AutomationSyncStatus.synced => 'SYNCED',
    AutomationSyncStatus.failed => 'FAILED',
  };

  bool get isFinal =>
      this == AutomationSyncStatus.synced ||
      this == AutomationSyncStatus.failed;
}

enum AutomationLastRunStatus {
  neverRun,
  executed,
  failed,
  timeout;

  static AutomationLastRunStatus fromJson(Object? value) {
    return switch (value) {
      'executed' => AutomationLastRunStatus.executed,
      'failed' => AutomationLastRunStatus.failed,
      'timeout' => AutomationLastRunStatus.timeout,
      _ => AutomationLastRunStatus.neverRun,
    };
  }

  String get wireValue => switch (this) {
    AutomationLastRunStatus.neverRun => 'never_run',
    AutomationLastRunStatus.executed => 'executed',
    AutomationLastRunStatus.failed => 'failed',
    AutomationLastRunStatus.timeout => 'timeout',
  };

  String get label => switch (this) {
    AutomationLastRunStatus.neverRun => 'NEVER RUN',
    AutomationLastRunStatus.executed => 'EXECUTED',
    AutomationLastRunStatus.failed => 'FAILED',
    AutomationLastRunStatus.timeout => 'TIMEOUT',
  };
}

enum AutomationRuleTemplate {
  switchTogglesOneLight,
  switchTogglesLights,
  motionOccupiedTurnsOnLights,
  motionUnoccupiedTurnsOffLights,
  scheduleOn,
  scheduleOff;

  String get label => switch (this) {
    AutomationRuleTemplate.switchTogglesOneLight => 'Switch toggles one light',
    AutomationRuleTemplate.switchTogglesLights => 'Switch toggles lights',
    AutomationRuleTemplate.motionOccupiedTurnsOnLights =>
      'Motion becomes occupied',
    AutomationRuleTemplate.motionUnoccupiedTurnsOffLights =>
      'Motion becomes unoccupied',
    AutomationRuleTemplate.scheduleOn => 'Schedule on',
    AutomationRuleTemplate.scheduleOff => 'Schedule off',
  };

  String get actionLabel => switch (this) {
    AutomationRuleTemplate.switchTogglesOneLight => 'Toggle selected light',
    AutomationRuleTemplate.switchTogglesLights => 'Toggle selected lights',
    AutomationRuleTemplate.motionOccupiedTurnsOnLights =>
      'Turn selected lights on',
    AutomationRuleTemplate.motionUnoccupiedTurnsOffLights =>
      'Turn selected lights off',
    AutomationRuleTemplate.scheduleOn => 'Turn selected light on',
    AutomationRuleTemplate.scheduleOff => 'Turn selected light off',
  };

  AutomationDeviceType get triggerDeviceType => switch (this) {
    AutomationRuleTemplate.switchTogglesOneLight ||
    AutomationRuleTemplate.switchTogglesLights =>
      AutomationDeviceType.switchDevice,
    AutomationRuleTemplate.motionOccupiedTurnsOnLights ||
    AutomationRuleTemplate.motionUnoccupiedTurnsOffLights =>
      AutomationDeviceType.motion,
    AutomationRuleTemplate.scheduleOn || AutomationRuleTemplate.scheduleOff =>
      throw StateError('Schedule templates do not use a trigger device'),
  };

  AutomationTriggerEvent get triggerEvent => switch (this) {
    AutomationRuleTemplate.switchTogglesOneLight ||
    AutomationRuleTemplate.switchTogglesLights =>
      AutomationTriggerEvent.switchToggle,
    AutomationRuleTemplate.motionOccupiedTurnsOnLights ||
    AutomationRuleTemplate.motionUnoccupiedTurnsOffLights =>
      AutomationTriggerEvent.occupancyChanged,
    AutomationRuleTemplate.scheduleOn || AutomationRuleTemplate.scheduleOff =>
      throw StateError('Schedule templates do not use a trigger event'),
  };

  AutomationActionCommand get actionCommand => switch (this) {
    AutomationRuleTemplate.switchTogglesOneLight ||
    AutomationRuleTemplate.switchTogglesLights =>
      AutomationActionCommand.toggle,
    AutomationRuleTemplate.motionOccupiedTurnsOnLights =>
      AutomationActionCommand.on,
    AutomationRuleTemplate.motionUnoccupiedTurnsOffLights =>
      AutomationActionCommand.off,
    AutomationRuleTemplate.scheduleOn => AutomationActionCommand.on,
    AutomationRuleTemplate.scheduleOff => AutomationActionCommand.off,
  };

  Map<String, Object?> get triggerState => switch (this) {
    AutomationRuleTemplate.motionOccupiedTurnsOnLights => {
      'occupancy': 'occupied',
    },
    AutomationRuleTemplate.motionUnoccupiedTurnsOffLights => {
      'occupancy': 'unoccupied',
    },
    _ => const {},
  };

  bool get allowsMultipleTargets =>
      this != AutomationRuleTemplate.switchTogglesOneLight && !isSchedule;

  bool get isSchedule =>
      this == AutomationRuleTemplate.scheduleOn ||
      this == AutomationRuleTemplate.scheduleOff;
}

enum AutomationTriggerType {
  event,
  schedule;

  String get wireValue => switch (this) {
    AutomationTriggerType.event => 'event',
    AutomationTriggerType.schedule => 'schedule',
  };
}

sealed class AutomationTrigger {
  const AutomationTrigger();

  AutomationTriggerType get triggerType;
  Map<String, Object?> toJson();

  String get deviceId => switch (this) {
    EventAutomationTrigger trigger => trigger.deviceId,
    SensorThresholdAutomationTrigger trigger => trigger.deviceId,
    ScheduleAutomationTrigger() => '',
  };

  AutomationDeviceType get deviceType => switch (this) {
    EventAutomationTrigger trigger => trigger.deviceType,
    SensorThresholdAutomationTrigger() => AutomationDeviceType.environment,
    ScheduleAutomationTrigger() => AutomationDeviceType.light,
  };

  AutomationTriggerEvent get event => switch (this) {
    EventAutomationTrigger trigger => trigger.event,
    SensorThresholdAutomationTrigger() ||
    ScheduleAutomationTrigger() => AutomationTriggerEvent.occupancyChanged,
  };

  Map<String, Object?> get state => switch (this) {
    EventAutomationTrigger trigger => trigger.state,
    SensorThresholdAutomationTrigger() ||
    ScheduleAutomationTrigger() => const {},
  };
}

final class EventAutomationTrigger extends AutomationTrigger {
  const EventAutomationTrigger({
    required this.deviceId,
    required this.deviceType,
    required this.event,
    this.state = const {},
  });

  @override
  final String deviceId;
  @override
  final AutomationDeviceType deviceType;
  @override
  final AutomationTriggerEvent event;
  @override
  final Map<String, Object?> state;

  @override
  AutomationTriggerType get triggerType => AutomationTriggerType.event;

  @override
  Map<String, Object?> toJson() {
    return {
      'type': 'device_event',
      'device_id': deviceId,
      'device_type': deviceType.wireValue,
      'event': event.wireValue,
      if (state.isNotEmpty) 'state': state,
    };
  }
}

enum EnvironmentMetric {
  temperature,
  humidity;

  String get wireValue => switch (this) {
    EnvironmentMetric.temperature => 'temperature_c',
    EnvironmentMetric.humidity => 'humidity_percent',
  };
}

enum ThresholdOperator {
  gte,
  lte;

  String get wireValue => switch (this) {
    ThresholdOperator.gte => 'gte',
    ThresholdOperator.lte => 'lte',
  };
}

final class SensorThresholdAutomationTrigger extends AutomationTrigger {
  const SensorThresholdAutomationTrigger({
    required this.deviceId,
    required this.metric,
    required this.operator,
    required this.threshold,
  });

  @override
  final String deviceId;
  final EnvironmentMetric metric;
  final ThresholdOperator operator;
  final double threshold;

  @override
  AutomationTriggerType get triggerType => AutomationTriggerType.event;

  @override
  Map<String, Object?> toJson() {
    return {
      'type': 'sensor_threshold',
      'device_id': deviceId,
      'device_type': AutomationDeviceType.environment.wireValue,
      'metric': metric.wireValue,
      'operator': operator.wireValue,
      'threshold': threshold,
    };
  }
}

final class ScheduleAutomationTrigger extends AutomationTrigger {
  const ScheduleAutomationTrigger({required this.cron});

  final String cron;

  @override
  AutomationTriggerType get triggerType => AutomationTriggerType.schedule;

  @override
  Map<String, Object?> toJson() => const {'type': 'schedule'};
}

sealed class AutomationAction {
  const AutomationAction();

  Map<String, Object?> toJson();

  String get deviceId => switch (this) {
    DeviceCommandAutomationAction action => action.deviceId,
    SceneActivateAutomationAction() => '',
  };

  AutomationDeviceType get deviceType => AutomationDeviceType.light;

  AutomationActionCommand get command => switch (this) {
    DeviceCommandAutomationAction action => action.command,
    SceneActivateAutomationAction() => AutomationActionCommand.on,
  };
}

final class DeviceCommandAutomationAction extends AutomationAction {
  const DeviceCommandAutomationAction({
    required this.deviceId,
    this.deviceType = AutomationDeviceType.light,
    required this.command,
  });

  @override
  final String deviceId;
  @override
  final AutomationDeviceType deviceType;
  @override
  final AutomationActionCommand command;

  @override
  Map<String, Object?> toJson() {
    return {
      'type': 'device_command',
      'device_id': deviceId,
      'device_type': deviceType.wireValue,
      'command': command.wireValue,
    };
  }
}

final class SceneActivateAutomationAction extends AutomationAction {
  const SceneActivateAutomationAction({
    required this.groupId,
    required this.sceneId,
  });

  final String groupId;
  final String sceneId;

  @override
  Map<String, Object?> toJson() {
    return {'type': 'scene_activate', 'group_id': groupId, 'scene_id': sceneId};
  }
}

class AutomationRuleDraft {
  const AutomationRuleDraft({
    required this.name,
    required this.enabled,
    required this.triggerDeviceId,
    AutomationDeviceType? triggerDeviceType,
    AutomationTriggerEvent? triggerEvent,
    Map<String, Object?> triggerState = const {},
    AutomationActionCommand? actionCommand,
    required this.targetLightIds,
    this.targetActionCommands = const {},
    this.template,
  }) : _typedTrigger = null,
       _typedActions = null,
       scheduleCron = null,
       _triggerDeviceType = triggerDeviceType,
       _triggerEvent = triggerEvent,
       _triggerState = triggerState,
       _actionCommand = actionCommand;

  const AutomationRuleDraft.typed({
    required this.name,
    required this.enabled,
    required AutomationTrigger trigger,
    required List<AutomationAction> actions,
    this.scheduleCron,
    this.template,
  }) : triggerDeviceId = '',
       targetLightIds = const [],
       targetActionCommands = const {},
       _triggerDeviceType = null,
       _triggerEvent = null,
       _triggerState = const {},
       _actionCommand = null,
       _typedTrigger = trigger,
       _typedActions = actions;

  final String name;
  final bool enabled;
  final AutomationRuleTemplate? template;
  final String? scheduleCron;
  final String triggerDeviceId;
  final List<String> targetLightIds;
  final Map<String, AutomationActionCommand> targetActionCommands;
  final AutomationDeviceType? _triggerDeviceType;
  final AutomationTriggerEvent? _triggerEvent;
  final Map<String, Object?> _triggerState;
  final AutomationActionCommand? _actionCommand;
  final AutomationTrigger? _typedTrigger;
  final List<AutomationAction>? _typedActions;

  AutomationDeviceType get triggerDeviceType {
    return _triggerDeviceType ?? _templateOrThrow.triggerDeviceType;
  }

  AutomationTriggerEvent get triggerEvent {
    return _triggerEvent ?? _templateOrThrow.triggerEvent;
  }

  Map<String, Object?> get triggerState {
    return _triggerEvent == null && _triggerState.isEmpty
        ? _templateOrThrow.triggerState
        : _triggerState;
  }

  AutomationActionCommand get actionCommand {
    return _actionCommand ?? _templateOrThrow.actionCommand;
  }

  AutomationRuleTemplate get _templateOrThrow {
    final selectedTemplate = template;
    if (selectedTemplate == null) {
      throw StateError('AutomationRuleDraft needs explicit fields or template');
    }
    return selectedTemplate;
  }

  AutomationTrigger get trigger {
    return _typedTrigger ??
        EventAutomationTrigger(
          deviceId: triggerDeviceId,
          deviceType: triggerDeviceType,
          event: triggerEvent,
          state: triggerState,
        );
  }

  List<AutomationAction> get actions {
    return _typedActions ??
        targetLightIds
            .map(
              (deviceId) => DeviceCommandAutomationAction(
                deviceId: deviceId,
                command: targetActionCommands[deviceId] ?? actionCommand,
              ),
            )
            .toList(growable: false);
  }
}

class AutomationRule {
  const AutomationRule({
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

  final String id;
  final String name;
  final bool enabled;
  final AutomationTrigger trigger;
  final List<AutomationAction> actions;
  final AutomationSyncStatus syncStatus;
  final AutomationLastRunStatus lastRunStatus;
  final String? lastError;
  final String? createdAt;
  final String? updatedAt;

  AutomationRule copyWith({
    String? id,
    String? name,
    bool? enabled,
    AutomationTrigger? trigger,
    List<AutomationAction>? actions,
    AutomationSyncStatus? syncStatus,
    AutomationLastRunStatus? lastRunStatus,
    String? lastError,
    String? createdAt,
    String? updatedAt,
  }) {
    return AutomationRule(
      id: id ?? this.id,
      name: name ?? this.name,
      enabled: enabled ?? this.enabled,
      trigger: trigger ?? this.trigger,
      actions: actions ?? this.actions,
      syncStatus: syncStatus ?? this.syncStatus,
      lastRunStatus: lastRunStatus ?? this.lastRunStatus,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
