void validateRuntimeSecurityConfig({
  required String apiBaseUrl,
  required bool hideLogin,
  required bool isReleaseMode,
}) {
  if (!isReleaseMode) {
    return;
  }

  final uri = Uri.tryParse(apiBaseUrl);
  if (uri == null || uri.scheme != 'https') {
    throw StateError('Release builds require an HTTPS API_BASE_URL.');
  }
  if (hideLogin) {
    throw StateError('Release builds must not enable HIDE_LOGIN.');
  }
}
