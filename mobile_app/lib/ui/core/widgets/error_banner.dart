import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../l10n/localized_error_message.dart';
import '../theme/app_theme.dart';

class ErrorBanner extends StatelessWidget {
  const ErrorBanner({required this.message, required this.onRetry, super.key});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.errorTint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.error.withValues(alpha: 0.32)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_outlined, color: palette.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              localizedErrorMessage(l10n, message),
              style: TextStyle(color: palette.textPrimary, fontSize: 13),
            ),
          ),
          TextButton(onPressed: onRetry, child: Text(l10n.retryLabel)),
        ],
      ),
    );
  }
}
