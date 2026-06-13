import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';

class ScheduleSelection {
  const ScheduleSelection({required this.cron, required this.isValid});

  final String cron;
  final bool isValid;
}

/// How the schedule is expressed. Every mode (except [custom]) builds a
/// canonical five-field cron under the hood so the backend contract is
/// unchanged — the cron string is still what gets sent.
enum ScheduleMode { hourly, daily, weekdays, weekly, custom }

/// Friendly schedule builder. Replaces the old preset chips + raw-cron field
/// with mode tabs (Hourly / Daily / Weekdays / Weekly / Custom) plus a time
/// picker, and shows a plain-language summary of the resulting schedule.
///
/// The emitted [ScheduleSelection.cron] is always a five-field cron string,
/// matching the existing rule contract.
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
  ScheduleMode _mode = ScheduleMode.daily;
  TimeOfDay _time = const TimeOfDay(hour: 7, minute: 0);
  int _minute = 0; // hourly: minute of every hour
  int _weekday = 1; // weekly: cron day-of-week (0=Sun .. 6=Sat), default Monday
  final _cronController = TextEditingController();
  bool _customTouched = false;

  // Short weekday labels indexed by cron day-of-week (0=Sun).
  static const _weekdayLabels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  @override
  void initState() {
    super.initState();
    // Emit a sensible default (Daily 07:00) so the rule has a valid schedule
    // as soon as the section appears.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _emit();
      }
    });
  }

  @override
  void dispose() {
    _cronController.dispose();
    super.dispose();
  }

  String _two(int value) => value.toString().padLeft(2, '0');

  String get _cron {
    switch (_mode) {
      case ScheduleMode.hourly:
        return '$_minute * * * *';
      case ScheduleMode.daily:
        return '${_time.minute} ${_time.hour} * * *';
      case ScheduleMode.weekdays:
        return '${_time.minute} ${_time.hour} * * 1-5';
      case ScheduleMode.weekly:
        return '${_time.minute} ${_time.hour} * * $_weekday';
      case ScheduleMode.custom:
        return _cronController.text.trim();
    }
  }

  bool get _isValid {
    if (_mode == ScheduleMode.custom) {
      return _hasFiveFields(_cronController.text);
    }
    return true;
  }

  void _emit() {
    widget.onChanged(ScheduleSelection(cron: _cron, isValid: _isValid));
    final showError =
        _mode == ScheduleMode.custom && _customTouched && !_isValid;
    widget.onValidationChanged?.call(
      showError ? AppLocalizations.of(context)!.invalidCronMessage : null,
    );
  }

  void _selectMode(ScheduleMode mode) {
    if (_mode == mode) {
      return;
    }
    setState(() {
      _mode = mode;
      if (mode == ScheduleMode.custom) {
        _customTouched = false;
      }
    });
    _emit();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _time = picked);
      _emit();
    }
  }

  void _setMinute(int minute) {
    setState(() => _minute = minute);
    _emit();
  }

  void _setWeekday(int weekday) {
    setState(() => _weekday = weekday);
    _emit();
  }

  void _updateCustomCron(String _) {
    setState(() => _customTouched = true);
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = context.palette;

    final modes = <(ScheduleMode, String)>[
      (ScheduleMode.hourly, l10n.scheduleModeHourly),
      (ScheduleMode.daily, l10n.scheduleModeDaily),
      (ScheduleMode.weekdays, l10n.scheduleModeWeekdays),
      (ScheduleMode.weekly, l10n.scheduleModeWeekly),
      (ScheduleMode.custom, l10n.scheduleModeCustom),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (mode, label) in modes)
              ChoiceChip(
                key: ValueKey('schedule-mode-${mode.name}'),
                label: Text(label),
                selected: _mode == mode,
                onSelected: (_) => _selectMode(mode),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _buildModeControls(l10n, palette),
        if (_mode != ScheduleMode.custom) ...[
          const SizedBox(height: 12),
          _ScheduleSummary(text: '${l10n.scheduleSummaryPrefix} ${_summary(l10n)}'),
        ],
      ],
    );
  }

  Widget _buildModeControls(AppLocalizations l10n, AppPalette palette) {
    switch (_mode) {
      case ScheduleMode.hourly:
        return Row(
          children: [
            Text(
              l10n.scheduleMinuteLabel,
              style: TextStyle(color: palette.textSecondary, fontSize: 13),
            ),
            const SizedBox(width: 12),
            _MinuteDropdown(value: _minute, onChanged: _setMinute),
          ],
        );
      case ScheduleMode.daily:
      case ScheduleMode.weekdays:
        return _TimeRow(
          label: l10n.scheduleTimeLabel,
          time: '${_two(_time.hour)}:${_two(_time.minute)}',
          onTap: _pickTime,
        );
      case ScheduleMode.weekly:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var dow = 0; dow < 7; dow++)
                  ChoiceChip(
                    key: ValueKey('schedule-weekday-$dow'),
                    label: Text(_weekdayLabels[dow]),
                    selected: _weekday == dow,
                    onSelected: (_) => _setWeekday(dow),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _TimeRow(
              label: l10n.scheduleTimeLabel,
              time: '${_two(_time.hour)}:${_two(_time.minute)}',
              onTap: _pickTime,
            ),
          ],
        );
      case ScheduleMode.custom:
        final showError = _customTouched && !_isValid;
        return TextField(
          key: const Key('raw-cron-field'),
          controller: _cronController,
          onChanged: _updateCustomCron,
          style: const TextStyle(fontFamily: 'JetBrains Mono'),
          decoration: InputDecoration(
            labelText: l10n.rawCronLabel,
            hintText: '0 7 * * 1-5',
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(
                color: showError ? palette.error : palette.border,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(
                color: showError ? palette.error : palette.primary,
                width: 1.5,
              ),
            ),
          ),
        );
    }
  }

  String _summary(AppLocalizations l10n) {
    final time = '${_two(_time.hour)}:${_two(_time.minute)}';
    switch (_mode) {
      case ScheduleMode.hourly:
        return '${l10n.scheduleModeHourly.toLowerCase()} • :${_two(_minute)}';
      case ScheduleMode.daily:
        return '${l10n.scheduleModeDaily.toLowerCase()} • $time';
      case ScheduleMode.weekdays:
        return '${l10n.scheduleModeWeekdays.toLowerCase()} • $time';
      case ScheduleMode.weekly:
        return '${_weekdayLabels[_weekday]} • $time';
      case ScheduleMode.custom:
        return _cron;
    }
  }

  static bool _hasFiveFields(String value) {
    final cron = value.trim();
    return cron.isNotEmpty && cron.split(RegExp(r'\s+')).length == 5;
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({required this.label, required this.time, required this.onTap});

  final String label;
  final String time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      children: [
        Text(label, style: TextStyle(color: palette.textSecondary, fontSize: 13)),
        const SizedBox(width: 12),
        Material(
          color: palette.surface,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            key: const Key('schedule-time-picker'),
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: palette.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.schedule, size: 16, color: palette.primary),
                  const SizedBox(width: 8),
                  Text(
                    time,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontFamily: 'JetBrains Mono',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MinuteDropdown extends StatelessWidget {
  const _MinuteDropdown({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    const minutes = [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          key: const Key('schedule-minute-dropdown'),
          value: value,
          isDense: true,
          items: [
            for (final minute in minutes)
              DropdownMenuItem(
                value: minute,
                child: Text(
                  ':${minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontFamily: 'JetBrains Mono'),
                ),
              ),
          ],
          onChanged: (selected) {
            if (selected != null) {
              onChanged(selected);
            }
          },
        ),
      ),
    );
  }
}

class _ScheduleSummary extends StatelessWidget {
  const _ScheduleSummary({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: palette.primaryTint,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.event_repeat, size: 16, color: palette.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              key: const Key('schedule-summary'),
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
