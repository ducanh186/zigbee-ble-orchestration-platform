import 'automation_rule.dart';
import 'cron_humanizer.dart';

String humanizeAutomationRule({
  required AutomationTrigger trigger,
  required List<AutomationAction> actions,
  Map<String, String> deviceNames = const {},
}) {
  final clauses = actions
      .map((action) => humanizeAutomationAction(action, deviceNames))
      .toList();
  final actionText = clauses.isEmpty ? '' : ', ${_joinClauses(clauses)}';

  return switch (trigger) {
    ScheduleAutomationTrigger(:final cron) =>
      '${_capitalize(humanizeCron(cron))}$actionText.',
    SensorThresholdAutomationTrigger trigger =>
      'When ${_deviceName(trigger.deviceId, deviceNames)} '
          '${_thresholdPhrase(trigger)}$actionText.',
    EventAutomationTrigger trigger =>
      'When ${_deviceName(trigger.deviceId, deviceNames)} '
          '${_eventPhrase(trigger)}$actionText.',
  };
}

String humanizeAutomationAction(
  AutomationAction action,
  Map<String, String> deviceNames,
) {
  return switch (action) {
    DeviceCommandAutomationAction(:final deviceId, :final command) =>
      '${_commandVerb(command)} ${_deviceName(deviceId, deviceNames)}'
          '${_commandTail(command)}',
    SceneActivateAutomationAction(:final sceneId) => 'activate $sceneId',
  };
}

String _eventPhrase(EventAutomationTrigger trigger) {
  if (trigger.event == AutomationTriggerEvent.switchToggle) {
    return 'toggles';
  }
  final occupancy = trigger.state['occupancy'];
  if (occupancy == 'occupied') {
    return 'reports occupied';
  }
  if (occupancy == 'unoccupied') {
    return 'reports unoccupied';
  }
  return 'changes occupancy';
}

String _thresholdPhrase(SensorThresholdAutomationTrigger trigger) {
  final metric = switch (trigger.metric) {
    EnvironmentMetric.temperature => 'temperature',
    EnvironmentMetric.humidity => 'humidity',
  };
  final operator = switch (trigger.operator) {
    ThresholdOperator.gte => 'is at least',
    ThresholdOperator.lte => 'is at most',
  };
  final unit = switch (trigger.metric) {
    EnvironmentMetric.temperature => '°C',
    EnvironmentMetric.humidity => '%',
  };
  return '$metric $operator ${_number(trigger.threshold)}$unit';
}

String _commandVerb(AutomationActionCommand command) {
  return switch (command) {
    AutomationActionCommand.toggle => 'toggle',
    AutomationActionCommand.on || AutomationActionCommand.off => 'turn',
  };
}

String _commandTail(AutomationActionCommand command) {
  return switch (command) {
    AutomationActionCommand.toggle => '',
    AutomationActionCommand.on => ' on',
    AutomationActionCommand.off => ' off',
  };
}

String _deviceName(String id, Map<String, String> deviceNames) {
  return deviceNames[id] ?? id;
}

String _joinClauses(List<String> clauses) {
  if (clauses.length == 1) {
    return clauses.first;
  }
  return '${clauses.sublist(0, clauses.length - 1).join(', ')} '
      'and ${clauses.last}';
}

String _capitalize(String value) {
  if (value.isEmpty) {
    return value;
  }
  return value[0].toUpperCase() + value.substring(1);
}

String _number(double value) {
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}
