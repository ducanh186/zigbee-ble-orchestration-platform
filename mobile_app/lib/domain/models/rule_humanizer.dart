import 'automation_rule.dart';
import 'cron_humanizer.dart';

enum AutomationRuleLanguage { english, vietnamese }

AutomationRuleLanguage automationRuleLanguageForCode(String languageCode) {
  return languageCode.toLowerCase() == 'vi'
      ? AutomationRuleLanguage.vietnamese
      : AutomationRuleLanguage.english;
}

String humanizeAutomationRule({
  required AutomationTrigger trigger,
  required List<AutomationAction> actions,
  Map<String, String> deviceNames = const {},
  AutomationRuleLanguage language = AutomationRuleLanguage.english,
}) {
  final clauses = actions
      .map(
        (action) =>
            humanizeAutomationAction(action, deviceNames, language: language),
      )
      .toList();
  final actionText = clauses.isEmpty
      ? ''
      : ', ${_joinClauses(clauses, language)}';

  if (language == AutomationRuleLanguage.vietnamese) {
    return switch (trigger) {
      ScheduleAutomationTrigger(:final cron) =>
        '${_capitalize(_humanizeCronVi(cron))}$actionText.',
      SensorThresholdAutomationTrigger trigger =>
        'Khi ${_deviceName(trigger.deviceId, deviceNames)} '
            '${_thresholdPhraseVi(trigger)}$actionText.',
      EventAutomationTrigger trigger =>
        'Khi ${_deviceName(trigger.deviceId, deviceNames)} '
            '${_eventPhraseVi(trigger)}$actionText.',
    };
  }

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
  Map<String, String> deviceNames, {
  AutomationRuleLanguage language = AutomationRuleLanguage.english,
}) {
  if (language == AutomationRuleLanguage.vietnamese) {
    return switch (action) {
      DeviceCommandAutomationAction(:final deviceId, :final command) =>
        '${_commandVerbVi(command)} ${_deviceName(deviceId, deviceNames)}',
      SceneActivateAutomationAction(:final sceneId) => 'kích hoạt $sceneId',
    };
  }

  return switch (action) {
    DeviceCommandAutomationAction(:final deviceId, :final command) =>
      '${_commandVerb(command)} ${_deviceName(deviceId, deviceNames)}'
          '${_commandTail(command)}',
    SceneActivateAutomationAction(:final sceneId) => 'activate $sceneId',
  };
}

String _eventPhraseVi(EventAutomationTrigger trigger) {
  if (trigger.event == AutomationTriggerEvent.switchToggle) {
    return 'được bật/tắt';
  }
  final occupancy = trigger.state['occupancy'];
  if (occupancy == 'occupied') {
    return 'báo có người';
  }
  if (occupancy == 'unoccupied') {
    return 'báo không có người';
  }
  return 'thay đổi trạng thái có người';
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

String _thresholdPhraseVi(SensorThresholdAutomationTrigger trigger) {
  final metric = switch (trigger.metric) {
    EnvironmentMetric.temperature => 'nhiệt độ',
    EnvironmentMetric.humidity => 'độ ẩm',
  };
  final operator = switch (trigger.operator) {
    ThresholdOperator.gte => 'từ',
    ThresholdOperator.lte => 'tối đa',
  };
  final tail = switch (trigger.operator) {
    ThresholdOperator.gte => ' trở lên',
    ThresholdOperator.lte => '',
  };
  final unit = switch (trigger.metric) {
    EnvironmentMetric.temperature => '°C',
    EnvironmentMetric.humidity => '%',
  };
  return 'có $metric $operator ${_number(trigger.threshold)}$unit$tail';
}

String _commandVerb(AutomationActionCommand command) {
  return switch (command) {
    AutomationActionCommand.toggle => 'toggle',
    AutomationActionCommand.on || AutomationActionCommand.off => 'turn',
  };
}

String _commandVerbVi(AutomationActionCommand command) {
  return switch (command) {
    AutomationActionCommand.toggle => 'đảo trạng thái',
    AutomationActionCommand.on => 'bật',
    AutomationActionCommand.off => 'tắt',
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

String _joinClauses(List<String> clauses, AutomationRuleLanguage language) {
  if (clauses.length == 1) {
    return clauses.first;
  }
  if (language == AutomationRuleLanguage.vietnamese) {
    return '${clauses.sublist(0, clauses.length - 1).join(', ')} '
        'và ${clauses.last}';
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

String _humanizeCronVi(String cron) {
  final parts = cron.trim().split(RegExp(r'\s+'));
  if (parts.length != 5) {
    return 'theo lịch "$cron"';
  }
  final minute = int.tryParse(parts[0]);
  final hour = int.tryParse(parts[1]);
  if (minute == null || hour == null) {
    return 'theo lịch "$cron"';
  }
  final time =
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  final dayOfMonth = parts[2];
  final month = parts[3];
  final dayOfWeek = parts[4];
  if (dayOfMonth == '*' && month == '*' && dayOfWeek == '*') {
    return 'mỗi ngày lúc $time';
  }
  if (dayOfMonth == '*' && month == '*' && dayOfWeek == '1-5') {
    return 'mỗi ngày trong tuần lúc $time';
  }
  final weekday = _weekdayVi(dayOfWeek);
  if (dayOfMonth == '*' && month == '*' && weekday != null) {
    return 'mỗi $weekday lúc $time';
  }
  return 'theo lịch "$cron"';
}

String? _weekdayVi(String value) {
  return switch (value) {
    '0' => 'Chủ nhật',
    '1' => 'Thứ Hai',
    '2' => 'Thứ Ba',
    '3' => 'Thứ Tư',
    '4' => 'Thứ Năm',
    '5' => 'Thứ Sáu',
    '6' => 'Thứ Bảy',
    _ => null,
  };
}
