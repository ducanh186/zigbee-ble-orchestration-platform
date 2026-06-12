import 'package:flutter/material.dart';

import '../../../../domain/models/automation_rule.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';

class EnvironmentConditionSection extends StatelessWidget {
  const EnvironmentConditionSection({
    required this.metric,
    required this.operator,
    required this.thresholdController,
    required this.onMetricChanged,
    required this.onOperatorChanged,
    super.key,
  });

  final EnvironmentMetric metric;
  final ThresholdOperator operator;
  final TextEditingController thresholdController;
  final ValueChanged<EnvironmentMetric> onMetricChanged;
  final ValueChanged<ThresholdOperator> onOperatorChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = context.palette;

    InputDecoration decoration() {
      return InputDecoration(
        filled: true,
        fillColor: palette.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
      );
    }

    return Row(
      children: [
        Expanded(
          flex: 4,
          child: DropdownButtonFormField<EnvironmentMetric>(
            key: const Key('environment-metric-dropdown'),
            initialValue: metric,
            isExpanded: true,
            decoration: decoration(),
            items: [
              DropdownMenuItem(
                value: EnvironmentMetric.temperature,
                child: Text(
                  l10n.temperatureLabel,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              DropdownMenuItem(
                value: EnvironmentMetric.humidity,
                child: Text(
                  l10n.humidityLabel,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                onMetricChanged(value);
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: DropdownButtonFormField<ThresholdOperator>(
            key: const Key('environment-operator-dropdown'),
            initialValue: operator,
            decoration: decoration(),
            items: const [
              DropdownMenuItem(
                value: ThresholdOperator.gte,
                child: Text('>='),
              ),
              DropdownMenuItem(
                value: ThresholdOperator.lte,
                child: Text('<='),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                onOperatorChanged(value);
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: TextField(
            key: const Key('environment-threshold-field'),
            controller: thresholdController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: decoration().copyWith(
              suffixText: metric == EnvironmentMetric.temperature ? '°C' : '%',
            ),
          ),
        ),
      ],
    );
  }
}
