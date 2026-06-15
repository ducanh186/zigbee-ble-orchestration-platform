import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';

class EnvironmentMetricCard extends StatelessWidget {
  const EnvironmentMetricCard({
    required this.icon,
    required this.value,
    required this.unit,
    required this.label,
    super.key,
  });

  final IconData icon;
  final double? value;
  final String unit;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: palette.primaryTint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: palette.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${_formatValue(value)}$unit',
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.primary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatValue(double? reading) {
    if (reading == null) {
      return '--';
    }
    return reading == reading.roundToDouble()
        ? reading.toStringAsFixed(0)
        : reading.toStringAsFixed(1);
  }
}
