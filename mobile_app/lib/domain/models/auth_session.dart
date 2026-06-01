class AuthSession {
  const AuthSession({
    required this.accessToken,
    this.username,
    this.userId,
    this.role,
    this.homeId,
    this.expiresAt,
  });

  final String accessToken;
  final String? username;
  final String? userId;
  final String? role;
  final String? homeId;
  final DateTime? expiresAt;

  bool get isExpired {
    final expiry = expiresAt;
    if (expiry == null) {
      return false;
    }
    return !DateTime.now().toUtc().isBefore(expiry.toUtc());
  }
}
