import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../domain/models/automation_rule.dart';
import '../../../../domain/models/smart_device.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/error_banner.dart';
import '../../../core/widgets/section_title.dart';
import '../../../core/widgets/status_badge.dart';
import '../../devices/view_models/device_dashboard_view_model.dart';
import '../view_models/automation_view_model.dart';

class AutomationRulesView extends StatefulWidget {
  const AutomationRulesView({super.key});

  @override
  State<AutomationRulesView> createState() => _AutomationRulesViewState();
}

class _AutomationRulesViewState extends State<AutomationRulesView> {
  final TextEditingController _nameController = TextEditingController();
  AutomationRuleTemplate _template =
      AutomationRuleTemplate.motionOccupiedTurnsOnLights;
  bool _enabled = true;
  String? _triggerDeviceId;
  Set<String> _targetLightIds = {};

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onNameChanged);
  }

  @override
  void dispose() {
    _nameController
      ..removeListener(_onNameChanged)
      ..dispose();
    super.dispose();
  }

  void _onNameChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AutomationViewModel, DeviceDashboardViewModel>(
      builder: (context, automation, dashboard, _) {
        final devices = dashboard.devices;
        final lights = devices.where((device) => device.isLight).toList();
        final triggerDevices = devices
            .where(
              (device) =>
                  device.deviceType == _template.triggerDeviceType.wireValue,
            )
            .toList();
        _syncSelections(triggerDevices, lights);

        return CustomScrollView(
          slivers: [
            SliverAppBar(
              title: const Text('Automation Rules'),
              pinned: true,
              actions: [
                IconButton(
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh),
                  onPressed: automation.isLoading ? null : automation.load,
                ),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              sliver: SliverList.list(
                children: [
                  if (automation.errorMessage != null) ...[
                    ErrorBanner(
                      message: automation.errorMessage!,
                      onRetry: automation.load,
                    ),
                    const SizedBox(height: 16),
                  ],
                  _CreateRuleCard(
                    nameController: _nameController,
                    template: _template,
                    enabled: _enabled,
                    triggerDevices: triggerDevices,
                    lights: lights,
                    triggerDeviceId: _triggerDeviceId,
                    targetLightIds: _targetLightIds,
                    isSaving: automation.isSaving,
                    onTemplateChanged: _setTemplate,
                    onEnabledChanged: (value) =>
                        setState(() => _enabled = value),
                    onTriggerChanged: (value) =>
                        setState(() => _triggerDeviceId = value),
                    onLightChanged: _setLightSelected,
                    onSave: _canSave(triggerDevices, lights, automation)
                        ? () => _submit(automation)
                        : null,
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      const Expanded(child: SectionTitle(title: 'Rules')),
                      if (automation.isLoading)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (automation.rules.isEmpty && !automation.isLoading)
                    const AppCard(child: Text('No automation rules yet'))
                  else
                    ...automation.rules.map(
                      (rule) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _AutomationRuleCard(
                          rule: rule,
                          onEnabledChanged: automation.isSaving
                              ? null
                              : (value) => value
                                    ? automation.enableRule(rule.id)
                                    : automation.disableRule(rule.id),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _syncSelections(
    List<SmartDevice> triggerDevices,
    List<SmartDevice> lights,
  ) {
    if (!triggerDevices.any((device) => device.id == _triggerDeviceId)) {
      _triggerDeviceId = triggerDevices.isEmpty
          ? null
          : triggerDevices.first.id;
    }

    final validLightIds = lights.map((device) => device.id).toSet();
    _targetLightIds = _targetLightIds
        .where((deviceId) => validLightIds.contains(deviceId))
        .toSet();
    if (_targetLightIds.isEmpty && lights.isNotEmpty) {
      _targetLightIds = {lights.first.id};
    }
    if (!_template.allowsMultipleTargets && _targetLightIds.length > 1) {
      _targetLightIds = {_targetLightIds.first};
    }
  }

  bool _canSave(
    List<SmartDevice> triggerDevices,
    List<SmartDevice> lights,
    AutomationViewModel automation,
  ) {
    return !automation.isSaving &&
        _nameController.text.trim().isNotEmpty &&
        triggerDevices.isNotEmpty &&
        lights.isNotEmpty &&
        _triggerDeviceId != null &&
        _targetLightIds.isNotEmpty;
  }

  void _setTemplate(AutomationRuleTemplate? template) {
    if (template == null) {
      return;
    }
    setState(() {
      _template = template;
      _triggerDeviceId = null;
      if (!template.allowsMultipleTargets && _targetLightIds.length > 1) {
        _targetLightIds = {_targetLightIds.first};
      }
    });
  }

  void _setLightSelected(String deviceId, bool selected) {
    setState(() {
      if (selected) {
        _targetLightIds = _template.allowsMultipleTargets
            ? {..._targetLightIds, deviceId}
            : {deviceId};
      } else {
        _targetLightIds = _targetLightIds
            .where((selectedId) => selectedId != deviceId)
            .toSet();
      }
    });
  }

  Future<void> _submit(AutomationViewModel automation) async {
    final triggerDeviceId = _triggerDeviceId;
    if (triggerDeviceId == null || _targetLightIds.isEmpty) {
      return;
    }

    await automation.createRule(
      AutomationRuleDraft(
        name: _nameController.text.trim(),
        enabled: _enabled,
        template: _template,
        triggerDeviceId: triggerDeviceId,
        targetLightIds: _targetLightIds.toList(growable: false),
      ),
    );

    if (!mounted || automation.errorMessage != null) {
      return;
    }

    setState(() {
      _nameController.clear();
    });
  }
}

class _CreateRuleCard extends StatelessWidget {
  const _CreateRuleCard({
    required this.nameController,
    required this.template,
    required this.enabled,
    required this.triggerDevices,
    required this.lights,
    required this.triggerDeviceId,
    required this.targetLightIds,
    required this.isSaving,
    required this.onTemplateChanged,
    required this.onEnabledChanged,
    required this.onTriggerChanged,
    required this.onLightChanged,
    required this.onSave,
  });

  final TextEditingController nameController;
  final AutomationRuleTemplate template;
  final bool enabled;
  final List<SmartDevice> triggerDevices;
  final List<SmartDevice> lights;
  final String? triggerDeviceId;
  final Set<String> targetLightIds;
  final bool isSaving;
  final ValueChanged<AutomationRuleTemplate?> onTemplateChanged;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<String?> onTriggerChanged;
  final void Function(String deviceId, bool selected) onLightChanged;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(title: 'Create rule'),
          const SizedBox(height: 12),
          TextField(
            controller: nameController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Rule name',
              hintText: 'Motion turns on lab lights',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<AutomationRuleTemplate>(
            initialValue: template,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Template'),
            items: AutomationRuleTemplate.values
                .map(
                  (item) => DropdownMenuItem(
                    value: item,
                    child: Text(item.label, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: isSaving ? null : onTemplateChanged,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: triggerDeviceId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: '${template.triggerDeviceType.label} device',
            ),
            items: triggerDevices
                .map(
                  (device) => DropdownMenuItem(
                    value: device.id,
                    child: Text(device.name, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: isSaving || triggerDevices.isEmpty
                ? null
                : onTriggerChanged,
          ),
          if (triggerDevices.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'No ${template.triggerDeviceType.label.toLowerCase()} devices available',
              style: TextStyle(color: palette.warning),
            ),
          ],
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Enabled'),
            value: enabled,
            onChanged: isSaving ? null : onEnabledChanged,
          ),
          const SizedBox(height: 8),
          Text(
            template.actionLabel,
            style: TextStyle(
              color: palette.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          if (lights.isEmpty)
            Text(
              'No light devices available',
              style: TextStyle(color: palette.warning),
            )
          else
            ...lights.map(
              (light) => CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(light.name, overflow: TextOverflow.ellipsis),
                subtitle: Text(light.id),
                value: targetLightIds.contains(light.id),
                onChanged: isSaving
                    ? null
                    : (value) => onLightChanged(light.id, value ?? false),
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('Save rule'),
              onPressed: onSave,
            ),
          ),
        ],
      ),
    );
  }
}

class _AutomationRuleCard extends StatelessWidget {
  const _AutomationRuleCard({
    required this.rule,
    required this.onEnabledChanged,
  });

  final AutomationRule rule;
  final ValueChanged<bool>? onEnabledChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  rule.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Switch(value: rule.enabled, onChanged: onEnabledChanged),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusBadge(
                label: rule.syncStatus.label,
                tone: _syncTone(rule.syncStatus),
              ),
              StatusBadge(
                label: rule.lastRunStatus.label,
                tone: _runTone(rule.lastRunStatus),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _RuleLine(
            icon: Icons.sensors,
            label: 'When',
            value: _triggerSummary(rule.trigger),
            color: palette.primary,
          ),
          const SizedBox(height: 10),
          _RuleLine(
            icon: Icons.lightbulb_outline,
            label: 'Then',
            value: _actionSummary(rule.actions),
            color: palette.warning,
          ),
          if (rule.lastError != null && rule.lastError!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(rule.lastError!, style: TextStyle(color: palette.error)),
          ],
        ],
      ),
    );
  }

  BadgeTone _syncTone(AutomationSyncStatus status) {
    return switch (status) {
      AutomationSyncStatus.synced => BadgeTone.success,
      AutomationSyncStatus.failed => BadgeTone.error,
      AutomationSyncStatus.pending => BadgeTone.warning,
    };
  }

  BadgeTone _runTone(AutomationLastRunStatus status) {
    return switch (status) {
      AutomationLastRunStatus.executed => BadgeTone.success,
      AutomationLastRunStatus.failed ||
      AutomationLastRunStatus.timeout => BadgeTone.error,
      AutomationLastRunStatus.neverRun => BadgeTone.neutral,
    };
  }

  String _triggerSummary(AutomationTrigger trigger) {
    final occupancy = trigger.state['occupancy'];
    if (occupancy != null) {
      return '${trigger.deviceId} ${trigger.event.label}: $occupancy';
    }
    return '${trigger.deviceId} ${trigger.event.label}';
  }

  String _actionSummary(List<AutomationAction> actions) {
    if (actions.isEmpty) {
      return 'No action';
    }
    return actions
        .map((action) => '${action.command.label} ${action.deviceId}')
        .join(', ');
  }
}

class _RuleLine extends StatelessWidget {
  const _RuleLine({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        SizedBox(
          width: 52,
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
      ],
    );
  }
}
