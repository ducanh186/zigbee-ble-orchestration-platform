import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../domain/models/automation_rule.dart';
import '../../../../domain/models/smart_device.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../l10n/localized_error_message.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/section_title.dart';
import '../../devices/view_models/device_dashboard_view_model.dart';
import '../view_models/automation_view_model.dart';
import 'device_picker_row.dart';
import 'environment_condition_section.dart';
import 'rule_preview.dart';
import 'scene_target_section.dart';
import 'schedule_trigger_section.dart';

/// Whether the rule fires from a device event/condition or from a schedule.
enum _RuleKind { deviceTrigger, schedule }

/// Modal bottom-sheet form for creating a rule. A rule-type selector switches
/// between a device-triggered rule and a scheduled rule, followed by a sticky
/// footer and a plain-language preview for device-triggered rules.
class CreateRuleSheet extends StatefulWidget {
  const CreateRuleSheet({super.key});

  /// Shows the sheet and resolves to the rule id of the saved rule, or
  /// null if cancelled / save failed.
  static Future<String?> show(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x66000000),
      builder: (_) => const CreateRuleSheet(),
    );
  }

  @override
  State<CreateRuleSheet> createState() => _CreateRuleSheetState();
}

class _CreateRuleSheetState extends State<CreateRuleSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _thresholdController = TextEditingController(
    text: '30',
  );
  _RuleKind _ruleKind = _RuleKind.deviceTrigger;
  bool _enabled = true;
  String? _triggerId;
  AutomationDeviceType? _triggerDeviceType;
  AutomationTriggerEvent? _triggerEvent;
  Map<String, Object?> _triggerState = const {};
  EnvironmentMetric _environmentMetric = EnvironmentMetric.temperature;
  ThresholdOperator _thresholdOperator = ThresholdOperator.gte;
  AutomationActionCommand? _actionCommand;
  Set<String> _targetIds = {};
  Map<String, AutomationActionCommand> _targetActionCommands = {};
  ScheduleSelection? _scheduleSelection;
  ScheduleTargetSelection? _scheduleTarget;
  String? _scheduleValidationMessage;
  AutomationActionCommand _scheduleAction = AutomationActionCommand.on;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() => setState(() {}));
    _thresholdController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _thresholdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = AppLocalizations.of(context)!;
    final mediaQuery = MediaQuery.of(context);

    return Consumer2<AutomationViewModel, DeviceDashboardViewModel>(
      builder: (context, automation, dashboard, _) {
        final devices = dashboard.devices;
        final triggers = devices.where(_isTriggerDevice).toList();
        final lights = devices.where((device) => device.isLight).toList();

        _pruneSelections(triggers, lights);

        final triggerDevice = _findDevice(devices, _triggerId);
        final targetDevices = lights
            .where((light) => _targetIds.contains(light.id))
            .toList();

        final canSave = _canSave();

        return Padding(
          padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
          child: FractionallySizedBox(
            heightFactor: 0.92,
            child: Container(
              decoration: BoxDecoration(
                color: palette.surfaceElevated,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  _Grabber(palette: palette),
                  _Header(palette: palette, onClose: _onCancel),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SectionTitle(title: l10n.createRuleTitle),
                          const SizedBox(height: 12),
                          _FieldLabel(
                            label: l10n.ruleNameLabel,
                            required: true,
                          ),
                          const SizedBox(height: 6),
                          _NameField(controller: _nameController),
                          const SizedBox(height: 16),
                          _FieldLabel(label: l10n.ruleKindLabel),
                          const SizedBox(height: 6),
                          _RuleKindSelector(
                            kind: _ruleKind,
                            onChanged: _setRuleKind,
                          ),
                          const SizedBox(height: 16),
                          if (_ruleKind == _RuleKind.schedule) ...[
                            _FieldLabel(
                              label: l10n.scheduleActionLabel,
                              required: true,
                            ),
                            const SizedBox(height: 6),
                            _ScheduleActionSelector(
                              command: _scheduleAction,
                              onChanged: (command) =>
                                  setState(() => _scheduleAction = command),
                            ),
                            const SizedBox(height: 16),
                            _FieldLabel(
                              label: l10n.scheduleTriggerLabel,
                              required: true,
                            ),
                            const SizedBox(height: 6),
                            ScheduleTriggerSection(
                              key: const ValueKey('schedule-trigger'),
                              onChanged: (value) =>
                                  setState(() => _scheduleSelection = value),
                              onValidationChanged: (message) => setState(
                                () => _scheduleValidationMessage = message,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _FieldLabel(
                              label: l10n.targetTypeLabel,
                              required: true,
                            ),
                            const SizedBox(height: 6),
                            SceneTargetSection(
                              key: const ValueKey('schedule-target'),
                              availability: automation.sceneAvailability,
                              lights: lights,
                              scenes: automation.scenes,
                              onChanged: (value) =>
                                  setState(() => _scheduleTarget = value),
                            ),
                          ] else ...[
                            _FieldLabel(
                              label: l10n.triggerDeviceLabel,
                              required: true,
                            ),
                            const SizedBox(height: 6),
                            _TriggerSection(
                              triggers: triggers,
                              selectedId: _triggerId,
                              triggerDeviceType: _triggerDeviceType,
                              selectedState: _triggerState,
                              onDeviceChanged: _setTriggerDevice,
                              onStateChanged: _setTriggerState,
                            ),
                            if (_triggerDeviceType ==
                                AutomationDeviceType.environment) ...[
                              const SizedBox(height: 16),
                              _FieldLabel(
                                label: l10n.sensorConditionLabel,
                                required: true,
                              ),
                              const SizedBox(height: 6),
                              EnvironmentConditionSection(
                                metric: _environmentMetric,
                                operator: _thresholdOperator,
                                thresholdController: _thresholdController,
                                onMetricChanged: (metric) {
                                  setState(() => _environmentMetric = metric);
                                },
                                onOperatorChanged: (operator) {
                                  setState(
                                    () => _thresholdOperator = operator,
                                  );
                                },
                              ),
                            ],
                            const SizedBox(height: 16),
                            _FieldLabel(
                              label: l10n.targetLightsLabel,
                              required: true,
                              hint: l10n.selectedCount(_targetIds.length),
                            ),
                            const SizedBox(height: 6),
                            _TargetSection(
                              lights: lights,
                              selectedIds: _targetIds,
                              allowsMultipleTargets: _allowsMultipleTargets,
                              actionCommands: _targetActionCommands,
                              onToggle: _toggleTarget,
                              onActionChanged: _setActionCommand,
                            ),
                          ],
                          const SizedBox(height: 16),
                          _FieldLabel(label: l10n.enabledLabel),
                          const SizedBox(height: 6),
                          _EnabledRow(
                            enabled: _enabled,
                            onChanged: (value) =>
                                setState(() => _enabled = value),
                          ),
                          if (_triggerEvent != null &&
                              _previewActionCommand != null) ...[
                            const SizedBox(height: 16),
                            _FieldLabel(label: l10n.previewLabel),
                            const SizedBox(height: 6),
                            RulePreview(
                              triggerEvent: _triggerEvent!,
                              triggerState: _triggerState,
                              actionCommand: _previewActionCommand!,
                              trigger: triggerDevice,
                              targets: targetDevices,
                            ),
                          ],
                          if (automation.errorMessage != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              localizedErrorMessage(
                                l10n,
                                automation.errorMessage!,
                              ),
                              style: TextStyle(
                                color: palette.error,
                                fontSize: 12,
                              ),
                            ),
                          ],
                          if (_scheduleValidationMessage != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              _scheduleValidationMessage!,
                              key: const Key('form-validation-message'),
                              style: TextStyle(
                                color: palette.error,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  _Footer(
                    palette: palette,
                    isSaving: automation.isSaving,
                    canSave: canSave && !automation.isSaving,
                    onCancel: _onCancel,
                    onSave: () => _onSave(automation),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  bool _canSave() {
    if (_ruleKind == _RuleKind.schedule) {
      return _nameController.text.trim().isNotEmpty &&
          _scheduleSelection != null &&
          _scheduleSelection!.isValid &&
          _scheduleTarget != null;
    }
    final hasValidTrigger =
        _triggerDeviceType == AutomationDeviceType.environment
        ? _parsedThreshold != null
        : _triggerEvent != null;
    return _nameController.text.trim().isNotEmpty &&
        _triggerId != null &&
        _triggerDeviceType != null &&
        hasValidTrigger &&
        _targetIds.isNotEmpty &&
        _targetIds.every(_targetActionCommands.containsKey);
  }

  double? get _parsedThreshold {
    final threshold = double.tryParse(_thresholdController.text.trim());
    if (threshold == null) {
      return null;
    }
    final range = _environmentMetric == EnvironmentMetric.temperature
        ? (-20.0, 80.0)
        : (0.0, 100.0);
    return threshold >= range.$1 && threshold <= range.$2 ? threshold : null;
  }

  void _setRuleKind(_RuleKind kind) {
    if (_ruleKind == kind) {
      return;
    }
    setState(() {
      _ruleKind = kind;
      // Reset the other branch's selections so a half-filled form from one
      // rule kind never leaks into the other.
      _scheduleSelection = null;
      _scheduleTarget = null;
      _scheduleValidationMessage = null;
      _triggerId = null;
      _triggerDeviceType = null;
      _triggerEvent = null;
      _triggerState = const {};
      _actionCommand = null;
      _targetIds = {};
      _targetActionCommands = {};
    });
  }

  void _setTriggerDevice(SmartDevice? device) {
    setState(() {
      if (device == null) {
        _triggerId = null;
        _triggerDeviceType = null;
        _triggerEvent = null;
        _triggerState = const {};
        _actionCommand = null;
        _targetActionCommands = {};
        return;
      }

      final type = _automationTypeFor(device);
      _triggerId = device.id;
      _triggerDeviceType = type;
      _applyDefaultsForTriggerType(type);
    });
  }

  void _setTriggerState(Map<String, Object?> state) {
    final triggerDeviceType = _triggerDeviceType;
    if (triggerDeviceType == null) {
      return;
    }
    if (triggerDeviceType == AutomationDeviceType.environment) {
      return;
    }
    setState(() {
      _triggerState = state;
      _triggerEvent = triggerDeviceType == AutomationDeviceType.switchDevice
          ? AutomationTriggerEvent.switchToggle
          : AutomationTriggerEvent.occupancyChanged;
      _actionCommand ??= _actionForTrigger(triggerDeviceType, state);
    });
  }

  void _toggleTarget(String deviceId, bool selected) {
    setState(() {
      if (selected) {
        if (!_allowsMultipleTargets) {
          _targetIds = {deviceId};
          _targetActionCommands = {deviceId: _defaultActionCommand};
        } else {
          _targetIds = {..._targetIds, deviceId};
          _targetActionCommands = {
            ..._targetActionCommands,
            deviceId: _defaultActionCommand,
          };
        }
      } else {
        _targetIds = _targetIds.where((id) => id != deviceId).toSet();
        _targetActionCommands = Map.of(_targetActionCommands)..remove(deviceId);
      }
    });
  }

  void _setActionCommand(String deviceId, AutomationActionCommand command) {
    setState(() {
      _actionCommand = command;
      _targetActionCommands = {..._targetActionCommands, deviceId: command};
    });
  }

  void _pruneSelections(List<SmartDevice> triggers, List<SmartDevice> lights) {
    if (_triggerId != null &&
        !triggers.any((device) => device.id == _triggerId)) {
      _triggerId = null;
      _triggerDeviceType = null;
      _triggerEvent = null;
      _triggerState = const {};
      _actionCommand = null;
      _targetActionCommands = {};
    }
    final validLightIds = lights.map((device) => device.id).toSet();
    final keptTargets = _targetIds
        .where((id) => validLightIds.contains(id))
        .toSet();
    if (keptTargets.length != _targetIds.length) {
      _targetIds = keptTargets;
      _targetActionCommands = {
        for (final entry in _targetActionCommands.entries)
          if (keptTargets.contains(entry.key)) entry.key: entry.value,
      };
    }
  }

  bool get _allowsMultipleTargets => true;

  SmartDevice? _findDevice(List<SmartDevice> devices, String? deviceId) {
    if (deviceId == null) {
      return null;
    }
    for (final device in devices) {
      if (device.id == deviceId) {
        return device;
      }
    }
    return null;
  }

  bool _isTriggerDevice(SmartDevice device) {
    // Accept switches and any sensor — v2 'sensor'+kind or legacy
    // 'motion'/'environment' (isMotion/isEnvironment dual-read both).
    return device.deviceType == 'switch' ||
        device.deviceType == 'sensor' ||
        device.isMotion ||
        device.isEnvironment;
  }

  AutomationDeviceType _automationTypeFor(SmartDevice device) {
    if (device.isEnvironment) return AutomationDeviceType.environment;
    if (device.deviceType == 'switch') {
      return AutomationDeviceType.switchDevice;
    }
    return AutomationDeviceType.motion;
  }

  void _applyDefaultsForTriggerType(AutomationDeviceType type) {
    if (type == AutomationDeviceType.switchDevice) {
      _triggerEvent = AutomationTriggerEvent.switchToggle;
      _triggerState = const {};
      _actionCommand = AutomationActionCommand.toggle;
      _syncMissingTargetActions();
      return;
    }

    if (type == AutomationDeviceType.environment) {
      _triggerEvent = null;
      _triggerState = const {};
      _actionCommand = AutomationActionCommand.on;
      _syncMissingTargetActions();
      return;
    }

    final occupancy = _triggerState['occupancy'] == 'unoccupied'
        ? 'unoccupied'
        : 'occupied';
    _triggerEvent = AutomationTriggerEvent.occupancyChanged;
    _triggerState = {'occupancy': occupancy};
    _actionCommand = occupancy == 'unoccupied'
        ? AutomationActionCommand.off
        : AutomationActionCommand.on;
    _syncMissingTargetActions();
  }

  void _syncMissingTargetActions() {
    _targetActionCommands = {
      for (final targetId in _targetIds)
        targetId: _targetActionCommands[targetId] ?? _defaultActionCommand,
    };
  }

  AutomationActionCommand get _defaultActionCommand {
    return _actionCommand ?? AutomationActionCommand.toggle;
  }

  AutomationActionCommand? get _previewActionCommand {
    for (final targetId in _targetIds) {
      final command = _targetActionCommands[targetId];
      if (command != null) {
        return command;
      }
    }
    return _actionCommand;
  }

  AutomationActionCommand _actionForTrigger(
    AutomationDeviceType type,
    Map<String, Object?> state,
  ) {
    if (type == AutomationDeviceType.switchDevice) {
      return AutomationActionCommand.toggle;
    }
    return state['occupancy'] == 'unoccupied'
        ? AutomationActionCommand.off
        : AutomationActionCommand.on;
  }

  void _onCancel() {
    Navigator.of(context).maybePop();
  }

  Future<void> _onSave(AutomationViewModel automation) async {
    late final AutomationRuleDraft draft;
    if (_ruleKind == _RuleKind.schedule) {
      final schedule = _scheduleSelection;
      final target = _scheduleTarget;
      if (schedule == null || !schedule.isValid || target == null) {
        return;
      }
      final action = switch (target) {
        DirectLightTarget direct => DeviceCommandAutomationAction(
          deviceId: direct.deviceId,
          command: _scheduleAction,
        ),
        SceneTarget scene => SceneActivateAutomationAction(
          groupId: scene.groupId,
          sceneId: scene.sceneId,
        ),
      };
      draft = AutomationRuleDraft.typed(
        name: _nameController.text.trim(),
        enabled: _enabled,
        trigger: ScheduleAutomationTrigger(cron: schedule.cron),
        scheduleCron: schedule.cron,
        actions: [action],
      );
    } else {
      final triggerId = _triggerId;
      final triggerDeviceType = _triggerDeviceType;
      final triggerEvent = _triggerEvent;
      if (triggerId == null ||
          triggerDeviceType == null ||
          _targetIds.isEmpty ||
          !_targetIds.every(_targetActionCommands.containsKey)) {
        return;
      }
      final targetLightIds = _targetIds.toList(growable: false);
      if (triggerDeviceType == AutomationDeviceType.environment) {
        final threshold = _parsedThreshold;
        if (threshold == null) {
          return;
        }
        draft = AutomationRuleDraft.typed(
          name: _nameController.text.trim(),
          enabled: _enabled,
          trigger: SensorThresholdAutomationTrigger(
            deviceId: triggerId,
            metric: _environmentMetric,
            operator: _thresholdOperator,
            threshold: threshold,
          ),
          actions: [
            for (final targetId in targetLightIds)
              DeviceCommandAutomationAction(
                deviceId: targetId,
                command: _targetActionCommands[targetId]!,
              ),
          ],
        );
      } else {
        if (triggerEvent == null) {
          return;
        }
        draft = AutomationRuleDraft(
          name: _nameController.text.trim(),
          enabled: _enabled,
          triggerDeviceId: triggerId,
          triggerDeviceType: triggerDeviceType,
          triggerEvent: triggerEvent,
          triggerState: _triggerState,
          actionCommand: _previewActionCommand,
          targetLightIds: targetLightIds,
          targetActionCommands: {
            for (final targetId in targetLightIds)
              targetId: _targetActionCommands[targetId]!,
          },
        );
      }
    }

    final beforeIds = automation.rules.map((rule) => rule.id).toSet();
    await automation.createRule(draft);
    if (!mounted) {
      return;
    }
    if (automation.errorMessage != null) {
      return;
    }
    final created = automation.rules.firstWhere(
      (rule) => !beforeIds.contains(rule.id),
      orElse: () => automation.rules.first,
    );
    Navigator.of(context).pop(created.id);
  }
}

class _Grabber extends StatelessWidget {
  const _Grabber({required this.palette});

  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Center(
        child: Container(
          width: 38,
          height: 4,
          decoration: BoxDecoration(
            color: palette.border,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.palette, required this.onClose});

  final AppPalette palette;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.newRuleTitle,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.newRuleSubtitle,
                  style: TextStyle(fontSize: 12, color: palette.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            color: palette.textPrimary,
            onPressed: onClose,
            tooltip: l10n.closeTooltip,
          ),
        ],
      ),
    );
  }
}

class _NameField extends StatelessWidget {
  const _NameField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = AppLocalizations.of(context)!;
    return TextField(
      key: const Key('rule-name-field'),
      controller: controller,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        hintText: l10n.ruleNameHint,
        hintStyle: TextStyle(color: palette.textSecondary),
        filled: true,
        fillColor: palette.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.primary),
        ),
      ),
    );
  }
}

/// Segmented selector for the rule kind (device trigger vs schedule). This
/// replaces the old quick-template grid as the single switch between the two
/// rule shapes the sheet supports.
class _RuleKindSelector extends StatelessWidget {
  const _RuleKindSelector({required this.kind, required this.onChanged});

  final _RuleKind kind;
  final ValueChanged<_RuleKind> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: _SegButton(
            key: const ValueKey('rule-kind-deviceTrigger'),
            label: l10n.ruleKindDeviceTrigger,
            icon: Icons.sensors,
            selected: kind == _RuleKind.deviceTrigger,
            onTap: () => onChanged(_RuleKind.deviceTrigger),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SegButton(
            key: const ValueKey('rule-kind-schedule'),
            label: l10n.ruleKindSchedule,
            icon: Icons.schedule,
            selected: kind == _RuleKind.schedule,
            onTap: () => onChanged(_RuleKind.schedule),
          ),
        ),
      ],
    );
  }
}

/// ON / OFF action selector for scheduled rules. The chosen command is applied
/// to a direct-light target; scene targets activate the scene regardless.
class _ScheduleActionSelector extends StatelessWidget {
  const _ScheduleActionSelector({
    required this.command,
    required this.onChanged,
  });

  final AutomationActionCommand command;
  final ValueChanged<AutomationActionCommand> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _StateButtonRow(
      children: [
        _StateButton(
          key: const ValueKey('schedule-action-on'),
          label: l10n.turnOnLabel,
          icon: Icons.lightbulb_outline,
          selected: command == AutomationActionCommand.on,
          onTap: () => onChanged(AutomationActionCommand.on),
        ),
        _StateButton(
          key: const ValueKey('schedule-action-off'),
          label: l10n.turnOffLabel,
          icon: Icons.lightbulb,
          selected: command == AutomationActionCommand.off,
          onTap: () => onChanged(AutomationActionCommand.off),
        ),
      ],
    );
  }
}

/// Full-width segmented button used by [_RuleKindSelector].
class _SegButton extends StatelessWidget {
  const _SegButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = selected ? palette.primary : palette.textPrimary;
    return Material(
      color: selected ? palette.primaryTint : palette.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? palette.primary : palette.border,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TriggerSection extends StatelessWidget {
  const _TriggerSection({
    required this.triggers,
    required this.selectedId,
    required this.triggerDeviceType,
    required this.selectedState,
    required this.onDeviceChanged,
    required this.onStateChanged,
  });

  final List<SmartDevice> triggers;
  final String? selectedId;
  final AutomationDeviceType? triggerDeviceType;
  final Map<String, Object?> selectedState;
  final ValueChanged<SmartDevice?> onDeviceChanged;
  final ValueChanged<Map<String, Object?>> onStateChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = AppLocalizations.of(context)!;
    if (triggers.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: palette.warningTint,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.warning_amber_outlined,
              size: 14,
              color: palette.warning,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.noTriggerDevicesMessage,
                style: TextStyle(color: palette.warning, fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        for (final device in triggers)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Column(
              children: [
                DevicePickerRow(
                  device: device,
                  selected: selectedId == device.id,
                  kind: DevicePickerKind.radio,
                  onChanged: (selected) =>
                      onDeviceChanged(selected ? device : null),
                ),
                if (selectedId == device.id &&
                    triggerDeviceType != AutomationDeviceType.environment) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _TriggerStateSection(
                      triggerDeviceType: triggerDeviceType,
                      selectedState: selectedState,
                      onChanged: onStateChanged,
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _TargetSection extends StatelessWidget {
  const _TargetSection({
    required this.lights,
    required this.selectedIds,
    required this.allowsMultipleTargets,
    required this.actionCommands,
    required this.onToggle,
    required this.onActionChanged,
  });

  final List<SmartDevice> lights;
  final Set<String> selectedIds;
  final bool allowsMultipleTargets;
  final Map<String, AutomationActionCommand> actionCommands;
  final void Function(String deviceId, bool selected) onToggle;
  final void Function(String deviceId, AutomationActionCommand command)
  onActionChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = AppLocalizations.of(context)!;
    if (lights.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: palette.warningTint,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.warning_amber_outlined,
              size: 14,
              color: palette.warning,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.noLightDevicesMessage,
                style: TextStyle(color: palette.warning, fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }
    final kind = allowsMultipleTargets
        ? DevicePickerKind.check
        : DevicePickerKind.radio;
    return Column(
      children: [
        for (final light in lights)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Column(
              children: [
                DevicePickerRow(
                  device: light,
                  selected: selectedIds.contains(light.id),
                  kind: kind,
                  onChanged: (selected) => onToggle(light.id, selected),
                ),
                if (selectedIds.contains(light.id)) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _TargetActionSection(
                      actionCommand: actionCommands[light.id],
                      onChanged: (command) =>
                          onActionChanged(light.id, command),
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _TriggerStateSection extends StatelessWidget {
  const _TriggerStateSection({
    required this.triggerDeviceType,
    required this.selectedState,
    required this.onChanged,
  });

  final AutomationDeviceType? triggerDeviceType;
  final Map<String, Object?> selectedState;
  final ValueChanged<Map<String, Object?>> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = AppLocalizations.of(context)!;
    final type = triggerDeviceType;
    if (type == null) {
      return _DashedHint(
        palette: palette,
        label: l10n.chooseTriggerDeviceMessage,
      );
    }

    if (type == AutomationDeviceType.switchDevice) {
      return _StateButtonRow(
        children: [
          _StateButton(
            label: l10n.toggleLabel,
            icon: Icons.toggle_off,
            selected: true,
            onTap: () => onChanged(const {}),
          ),
        ],
      );
    }

    final occupancy = selectedState['occupancy'] == 'unoccupied'
        ? 'unoccupied'
        : 'occupied';
    return _StateButtonRow(
      children: [
        _StateButton(
          label: l10n.occupiedLabel,
          icon: Icons.person_outline,
          selected: occupancy == 'occupied',
          onTap: () => onChanged(const {'occupancy': 'occupied'}),
        ),
        _StateButton(
          label: l10n.unoccupiedLabel,
          icon: Icons.person_off_outlined,
          selected: occupancy == 'unoccupied',
          onTap: () => onChanged(const {'occupancy': 'unoccupied'}),
        ),
      ],
    );
  }
}

class _TargetActionSection extends StatelessWidget {
  const _TargetActionSection({
    required this.actionCommand,
    required this.onChanged,
  });

  final AutomationActionCommand? actionCommand;
  final ValueChanged<AutomationActionCommand> onChanged;

  @override
  Widget build(BuildContext context) {
    final command = actionCommand;
    final l10n = AppLocalizations.of(context)!;

    return _StateButtonRow(
      children: [
        _StateButton(
          label: l10n.turnOnLabel,
          icon: Icons.lightbulb_outline,
          selected: command == AutomationActionCommand.on,
          onTap: () => onChanged(AutomationActionCommand.on),
        ),
        _StateButton(
          label: l10n.turnOffLabel,
          icon: Icons.lightbulb,
          selected: command == AutomationActionCommand.off,
          onTap: () => onChanged(AutomationActionCommand.off),
        ),
        _StateButton(
          label: l10n.toggleLabel,
          icon: Icons.swap_horiz,
          selected: command == AutomationActionCommand.toggle,
          onTap: () => onChanged(AutomationActionCommand.toggle),
        ),
      ],
    );
  }
}

class _StateButtonRow extends StatelessWidget {
  const _StateButtonRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 8, runSpacing: 8, children: children);
  }
}

class _StateButton extends StatelessWidget {
  const _StateButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: selected ? palette.primaryTint : palette.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? palette.primary : palette.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: _contentColor(palette)),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: _contentColor(palette),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _contentColor(AppPalette palette) {
    return selected ? palette.primary : palette.textPrimary;
  }
}

class _DashedHint extends StatelessWidget {
  const _DashedHint({required this.palette, required this.label});

  final AppPalette palette;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(fontSize: 12, color: palette.textSecondary),
      ),
    );
  }
}

class _EnabledRow extends StatelessWidget {
  const _EnabledRow({required this.enabled, required this.onChanged});

  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Switch(value: enabled, onChanged: onChanged),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              enabled ? l10n.ruleEnabledLabel : l10n.ruleDisabledLabel,
              style: TextStyle(fontSize: 13, color: palette.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label, this.hint, this.required = false});

  final String label;
  final String? hint;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
            color: palette.textSecondary,
          ),
        ),
        if (required) ...[
          const SizedBox(width: 4),
          Text('•', style: TextStyle(fontSize: 11, color: palette.error)),
        ],
        const Spacer(),
        if (hint != null)
          Text(
            hint!,
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'JetBrains Mono',
              color: palette.textSecondary,
            ),
          ),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.palette,
    required this.isSaving,
    required this.canSave,
    required this.onCancel,
    required this.onSave,
  });

  final AppPalette palette;
  final bool isSaving;
  final bool canSave;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      decoration: BoxDecoration(
        color: palette.surfaceElevated,
        border: Border(top: BorderSide(color: palette.border)),
      ),
      child: Row(
        children: [
          OutlinedButton(
            onPressed: isSaving ? null : onCancel,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              side: BorderSide(color: palette.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              foregroundColor: palette.textPrimary,
            ),
            child: Text(l10n.cancelLabel),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              onPressed: canSave ? onSave : null,
              icon: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check, size: 16),
              label: Text(l10n.saveRuleLabel),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
