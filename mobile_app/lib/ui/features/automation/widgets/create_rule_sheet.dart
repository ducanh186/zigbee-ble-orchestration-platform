import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../domain/models/automation_rule.dart';
import '../../../../domain/models/smart_device.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/section_title.dart';
import '../../devices/view_models/device_dashboard_view_model.dart';
import '../view_models/automation_view_model.dart';
import 'automation_visuals.dart';
import 'device_picker_row.dart';
import 'rule_preview.dart';
import 'scene_target_section.dart';
import 'schedule_trigger_section.dart';
import 'template_card.dart';

/// Modal bottom-sheet form for creating a rule. Mirrors the design's
/// `CreateRuleSheet.jsx` — sectioned form, sticky footer, plain-language
/// preview that appears once a template is chosen.
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
  AutomationRuleTemplate? _template;
  bool _isTemplateExpanded = false;
  bool _enabled = true;
  String? _triggerId;
  AutomationDeviceType? _triggerDeviceType;
  AutomationTriggerEvent? _triggerEvent;
  Map<String, Object?> _triggerState = const {};
  AutomationActionCommand? _actionCommand;
  Set<String> _targetIds = {};
  Map<String, AutomationActionCommand> _targetActionCommands = {};
  ScheduleSelection? _scheduleSelection;
  ScheduleTargetSelection? _scheduleTarget;
  String? _scheduleValidationMessage;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
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
                          const SectionTitle(title: 'Create rule'),
                          const SizedBox(height: 12),
                          _FieldLabel(label: 'Rule name', required: true),
                          const SizedBox(height: 6),
                          _NameField(controller: _nameController),
                          const SizedBox(height: 16),
                          _QuickTemplateSection(
                            selected: _template,
                            isExpanded: _isTemplateExpanded,
                            onToggleExpanded: () => setState(
                              () => _isTemplateExpanded = !_isTemplateExpanded,
                            ),
                            onChanged: _setTemplate,
                          ),
                          const SizedBox(height: 16),
                          if (_isScheduleTemplate) ...[
                            _FieldLabel(
                              label: l10n.scheduleTriggerLabel,
                              required: true,
                            ),
                            const SizedBox(height: 6),
                            ScheduleTriggerSection(
                              key: ValueKey(
                                'schedule-trigger-${_template!.name}',
                              ),
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
                              key: ValueKey(
                                'schedule-target-${_template!.name}',
                              ),
                              availability: automation.sceneAvailability,
                              lights: lights,
                              scenes: automation.scenes,
                              onChanged: (value) =>
                                  setState(() => _scheduleTarget = value),
                            ),
                          ] else ...[
                            _FieldLabel(
                              label: 'Trigger device',
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
                            const SizedBox(height: 16),
                            _FieldLabel(
                              label: 'Target lights',
                              required: true,
                              hint: '${_targetIds.length} selected',
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
                          _FieldLabel(
                            label: 'Enabled',
                            hint: 'active immediately after save',
                          ),
                          const SizedBox(height: 6),
                          _EnabledRow(
                            enabled: _enabled,
                            onChanged: (value) =>
                                setState(() => _enabled = value),
                          ),
                          if (_triggerEvent != null &&
                              _previewActionCommand != null) ...[
                            const SizedBox(height: 16),
                            _FieldLabel(label: 'Preview'),
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
                              automation.errorMessage!,
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
    if (_isScheduleTemplate) {
      return _nameController.text.trim().isNotEmpty &&
          _scheduleSelection != null &&
          _scheduleSelection!.isValid &&
          _scheduleTarget != null;
    }
    return _nameController.text.trim().isNotEmpty &&
        _triggerId != null &&
        _triggerDeviceType != null &&
        _triggerEvent != null &&
        _targetIds.isNotEmpty &&
        _targetIds.every(_targetActionCommands.containsKey);
  }

  void _setTemplate(AutomationRuleTemplate template) {
    setState(() {
      final previousTriggerType = _triggerDeviceType;
      _template = template;
      if (template.isSchedule) {
        _triggerId = null;
        _triggerDeviceType = null;
        _triggerEvent = null;
        _triggerState = const {};
        _actionCommand = template.actionCommand;
        _targetIds = {};
        _targetActionCommands = {};
        _scheduleSelection = null;
        _scheduleTarget = null;
        _scheduleValidationMessage = null;
        return;
      }
      _scheduleSelection = null;
      _scheduleTarget = null;
      _scheduleValidationMessage = null;
      _triggerDeviceType = template.triggerDeviceType;
      _triggerEvent = template.triggerEvent;
      _triggerState = template.triggerState;
      _actionCommand = template.actionCommand;
      _targetActionCommands = {
        for (final targetId in _targetIds) targetId: template.actionCommand,
      };
      if (_triggerId != null &&
          previousTriggerType != null &&
          previousTriggerType != template.triggerDeviceType) {
        _triggerId = null;
      }
      if (!_allowsMultipleTargets && _targetIds.length > 1) {
        _targetIds = {_targetIds.first};
      }
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
      if (_template != null && _template!.triggerDeviceType != type) {
        _template = null;
      }
      _applyDefaultsForTriggerType(type);
    });
  }

  void _setTriggerState(Map<String, Object?> state) {
    final triggerDeviceType = _triggerDeviceType;
    if (triggerDeviceType == null) {
      return;
    }
    setState(() {
      _triggerState = state;
      _triggerEvent = triggerDeviceType == AutomationDeviceType.switchDevice
          ? AutomationTriggerEvent.switchToggle
          : AutomationTriggerEvent.occupancyChanged;
      _actionCommand ??= _actionForTrigger(triggerDeviceType, state);
      if (_template != null &&
          (_template!.triggerState.toString() != state.toString() ||
              _template!.actionCommand != _actionCommand)) {
        _template = null;
      }
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
      if (_template != null && _template!.actionCommand != command) {
        _template = null;
      }
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

  bool get _allowsMultipleTargets {
    return _template != AutomationRuleTemplate.switchTogglesOneLight;
  }

  bool get _isScheduleTemplate => _template?.isSchedule ?? false;

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
    return device.deviceType == AutomationDeviceType.switchDevice.wireValue ||
        device.deviceType == AutomationDeviceType.motion.wireValue;
  }

  AutomationDeviceType _automationTypeFor(SmartDevice device) {
    return device.deviceType == AutomationDeviceType.switchDevice.wireValue
        ? AutomationDeviceType.switchDevice
        : AutomationDeviceType.motion;
  }

  void _applyDefaultsForTriggerType(AutomationDeviceType type) {
    if (type == AutomationDeviceType.switchDevice) {
      _triggerEvent = AutomationTriggerEvent.switchToggle;
      _triggerState = const {};
      _actionCommand = AutomationActionCommand.toggle;
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
    final template = _template;
    late final AutomationRuleDraft draft;
    if (template?.isSchedule ?? false) {
      final schedule = _scheduleSelection;
      final target = _scheduleTarget;
      if (schedule == null || target == null) {
        return;
      }
      final action = switch (target) {
        DirectLightTarget direct => DeviceCommandAutomationAction(
          deviceId: direct.deviceId,
          command: template!.actionCommand,
        ),
        SceneTarget scene => SceneActivateAutomationAction(
          groupId: scene.groupId,
          sceneId: scene.sceneId,
        ),
      };
      draft = AutomationRuleDraft.typed(
        name: _nameController.text.trim(),
        enabled: _enabled,
        template: template,
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
          triggerEvent == null ||
          _targetIds.isEmpty ||
          !_targetIds.every(_targetActionCommands.containsKey)) {
        return;
      }
      final targetLightIds = _targetIds.toList(growable: false);
      draft = AutomationRuleDraft(
        name: _nameController.text.trim(),
        enabled: _enabled,
        template: template,
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'New rule',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'When something happens, do something.',
                  style: TextStyle(fontSize: 12, color: palette.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            color: palette.textPrimary,
            onPressed: onClose,
            tooltip: 'Close',
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
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        hintText: 'e.g. Motion turns on lab lights',
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

class _QuickTemplateSection extends StatelessWidget {
  const _QuickTemplateSection({
    required this.selected,
    required this.isExpanded,
    required this.onToggleExpanded,
    required this.onChanged,
  });

  final AutomationRuleTemplate? selected;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;
  final ValueChanged<AutomationRuleTemplate> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _FieldLabel(
                label: 'Quick template',
                hint: selected?.label,
              ),
            ),
            IconButton(
              key: const Key('quick-template-toggle'),
              tooltip: isExpanded
                  ? 'Collapse quick template'
                  : 'Expand quick template',
              onPressed: onToggleExpanded,
              icon: Icon(
                isExpanded ? Icons.expand_less : Icons.expand_more,
                color: palette.textSecondary,
              ),
            ),
          ],
        ),
        if (isExpanded) ...[
          const SizedBox(height: 6),
          _TemplateGrid(selected: selected, onChanged: onChanged),
        ],
      ],
    );
  }
}

class _TemplateGrid extends StatelessWidget {
  const _TemplateGrid({required this.selected, required this.onChanged});

  final AutomationRuleTemplate? selected;
  final ValueChanged<AutomationRuleTemplate> onChanged;

  @override
  Widget build(BuildContext context) {
    final templates = AutomationVisuals.templateOrder;
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth = (constraints.maxWidth - 8) / 2;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final template in templates)
              SizedBox(
                width: cellWidth,
                child: TemplateCard(
                  template: template,
                  selected: selected == template,
                  onTap: () => onChanged(template),
                ),
              ),
          ],
        );
      },
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
                'No switch or motion devices available',
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
                if (selectedId == device.id) ...[
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
                'No light devices available',
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
    final type = triggerDeviceType;
    if (type == null) {
      return _DashedHint(
        palette: palette,
        label: 'Choose a trigger device first',
      );
    }

    if (type == AutomationDeviceType.switchDevice) {
      return _StateButtonRow(
        children: [
          _StateButton(
            label: 'Toggle',
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
          label: 'Occupied',
          icon: Icons.person_outline,
          selected: occupancy == 'occupied',
          onTap: () => onChanged(const {'occupancy': 'occupied'}),
        ),
        _StateButton(
          label: 'Unoccupied',
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

    return _StateButtonRow(
      children: [
        _StateButton(
          label: AutomationActionCommand.on.label,
          icon: Icons.lightbulb_outline,
          selected: command == AutomationActionCommand.on,
          onTap: () => onChanged(AutomationActionCommand.on),
        ),
        _StateButton(
          label: AutomationActionCommand.off.label,
          icon: Icons.lightbulb,
          selected: command == AutomationActionCommand.off,
          onTap: () => onChanged(AutomationActionCommand.off),
        ),
        _StateButton(
          label: AutomationActionCommand.toggle.label,
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
              enabled
                  ? 'On — rule is active'
                  : 'Off — rule saved but not running',
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
            child: const Text('Cancel'),
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
              label: const Text('Save rule'),
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
