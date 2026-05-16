class AuthSession {
  const AuthSession({
    required this.accessToken,
    this.userId,
    this.expiresAt,
  });

  final String accessToken;
  final String? userId;
  final DateTime? expiresAt;

  bool get isExpired {
    final expiry = expiresAt;
    if (expiry == null) {
      return false;
    }
    return !DateTime.now().toUtc().isBefore(expiry.toUtc());
  }
}
