import 'app_localizations.dart';

const validationErrorMessage = 'The data is invalid. Check the input fields.';

String localizedErrorMessage(AppLocalizations l10n, String message) {
  const baseMessages = <String>[
    'The network response took too long. Try again.',
    'No network connection. Check Wi-Fi or mobile data.',
    'The data is invalid. Check the input fields.',
    'Your session is invalid. Sign in again.',
    'The server has a problem. Try again later.',
    'An unknown error occurred. Try again.',
  ];
  final base = baseMessages.cast<String?>().firstWhere(
    (candidate) => message == candidate || message.endsWith('. $candidate'),
    orElse: () => null,
  );
  final context = base == null || message == base
      ? null
      : message.substring(0, message.length - base.length - 2);

  final localizedBase = switch (base) {
    'The network response took too long. Try again.' =>
      l10n.errorTimeoutMessage,
    'No network connection. Check Wi-Fi or mobile data.' =>
      l10n.errorOfflineMessage,
    'The data is invalid. Check the input fields.' =>
      l10n.errorValidationMessage,
    'Your session is invalid. Sign in again.' => l10n.errorUnauthorizedMessage,
    'The server has a problem. Try again later.' => l10n.errorServerMessage,
    'An unknown error occurred. Try again.' => l10n.errorUnknownMessage,
    _ when message.startsWith('FormatException:') =>
      l10n.errorValidationMessage,
    _ => l10n.errorUnknownMessage,
  };

  final localizedContext = switch (context) {
    'Login failed' => l10n.errorLoginContext,
    'Password change failed' => l10n.errorPasswordChangeContext,
    'Could not load automation rules' => l10n.errorLoadRulesContext,
    'Could not create automation rule' => l10n.errorCreateRuleContext,
    'Could not delete automation rule' => l10n.errorDeleteRuleContext,
    'Could not update automation rule' => l10n.errorUpdateRuleContext,
    'Could not connect to Cloud API' => l10n.errorCloudConnectionContext,
    'Could not rename device' => l10n.errorRenameDeviceContext,
    _ => context,
  };

  return localizedContext == null || localizedContext.isEmpty
      ? localizedBase
      : '$localizedContext. $localizedBase';
}
