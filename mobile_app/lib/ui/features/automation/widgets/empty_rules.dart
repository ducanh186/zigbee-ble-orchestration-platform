import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Empty state shown when the rule list is empty. Single thin-line icon +
/// short Vietnamese copy + a primary CTA.
class EmptyRules extends StatelessWidget {
  const EmptyRules({required this.onCreate, super.key});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: palette.border),
            ),
            child: Icon(
              Icons.account_tree_outlined,
              size: 32,
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'No automation rules yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 240,
            child: Text(
              'Create a rule to react when a motion sensor or switch fires. '
              'Cloud will save it and sync to the gateway.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: palette.textSecondary,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('New rule'),
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
        ],
      ),
    );
  }
}
