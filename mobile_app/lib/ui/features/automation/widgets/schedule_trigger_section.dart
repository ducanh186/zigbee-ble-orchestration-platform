import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';

class ScheduleSelection {
  const ScheduleSelection({required this.cron, required this.isValid});

  final String cron;
  final bool isValid;
}

class CronPreset {
  const CronPreset({required this.id, required this.cron});

  final String id;
  final String cron;
}

const schedulePresets = <CronPreset>[
  CronPreset(id: 'weekday_0700', cron: '0 7 * * 1-5'),
  CronPreset(id: 'sunday_2200', cron: '0 22 * * 0'),
  CronPreset(id: 'every_6_hours', cron: '0 */6 * * *'),
];

class ScheduleTriggerSection extends StatefulWidget {
  const ScheduleTriggerSection({
    required this.onChanged,
    this.onValidationChanged,
    super.key,
  });

  final ValueChanged<ScheduleSelection?> onChanged;
  final ValueChanged<String?>? onValidationChanged;

  @override
  State<ScheduleTriggerSection> createState() => _ScheduleTriggerSectionState();
}

class _ScheduleTriggerSectionState extends State<ScheduleTriggerSection> {
  static const _customId = 'custom';

  final _cronController = TextEditingController();
  String? _selectedId;
  bool _customTouched = false;

  bool get _isCustom => _selectedId == _customId;

  bool get _isCustomValid => _hasFiveFields(_cronController.text);

  @override
  void dispose() {
    _cronController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = context.palette;
    final labels = <String, String>{
      'weekday_0700': l10n.cronPresetWeekdaySeven,
      'sunday_2200': l10n.cronPresetSundayTwentyTwo,
      'every_6_hours': l10n.cronPresetEverySixHours,
    };
    final showCustomError = _isCustom && _customTouched && !_isCustomValid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final preset in schedulePresets)
              ChoiceChip(
                label: Text(labels[preset.id]!),
                selected: _selectedId == preset.id,
                onSelected: (_) => _selectPreset(preset),
              ),
            ChoiceChip(
              label: Text(l10n.rawCronLabel),
              selected: _isCustom,
              onSelected: (_) => _selectCustom(),
            ),
          ],
        ),
        if (_isCustom) ...[
          const SizedBox(height: 12),
          TextField(
            key: const Key('raw-cron-field'),
            controller: _cronController,
            onChanged: _updateCustomCron,
            decoration: InputDecoration(
              labelText: l10n.rawCronLabel,
              hintText: '0 7 * * 1-5',
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: showCustomError ? palette.error : palette.border,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: showCustomError ? palette.error : palette.primary,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _selectPreset(CronPreset preset) {
    setState(() {
      _selectedId = preset.id;
      _customTouched = false;
    });
    widget.onChanged(ScheduleSelection(cron: preset.cron, isValid: true));
    widget.onValidationChanged?.call(null);
  }

  void _selectCustom() {
    setState(() {
      _selectedId = _customId;
    });
    _emitCustomSelection();
    widget.onValidationChanged?.call(null);
  }

  void _updateCustomCron(String _) {
    setState(() {
      _customTouched = true;
    });
    _emitCustomSelection();
    widget.onValidationChanged?.call(
      _isCustomValid ? null : AppLocalizations.of(context)!.invalidCronMessage,
    );
  }

  void _emitCustomSelection() {
    final cron = _cronController.text.trim();
    widget.onChanged(
      ScheduleSelection(cron: cron, isValid: _hasFiveFields(cron)),
    );
  }

  static bool _hasFiveFields(String value) {
    final cron = value.trim();
    return cron.isNotEmpty && cron.split(RegExp(r'\s+')).length == 5;
  }
}
