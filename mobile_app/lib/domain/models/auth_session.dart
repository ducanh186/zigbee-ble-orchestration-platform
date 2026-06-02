class AuthSession {
  const AuthSession({
    required this.accessToken,
    this.username,
    this.userId,
    this.displayName,
    this.role,
    this.homeId,
    this.mustChangePassword = false,
    this.expiresAt,
  });

  final String accessToken;
  final String? username;
  final String? userId;
  final String? displayName;
  final String? role;
  final String? homeId;
  final bool mustChangePassword;
  final DateTime? expiresAt;

  String get canonicalRole {
    final normalized = (role ?? '').trim().toLowerCase();
    return switch (normalized) {
      'admin' => 'admin',
      'parent' || 'operator' || 'user' => 'parent',
      _ => 'viewer',
    };
  }

  bool get isAdmin => canonicalRole == 'admin';
  bool get isParent => canonicalRole == 'parent';
  bool get isViewer => canonicalRole == 'viewer';
  bool get canMutateHome => isAdmin || isParent;
  bool get canUseProvisioning => canMutateHome;
  bool get canManageAutomation => canMutateHome;
  bool get canControlDevices => canMutateHome;

  bool get isExpired {
    final expiry = expiresAt;
    if (expiry == null) {
      return false;
    }
    return !DateTime.now().toUtc().isBefore(expiry.toUtc());
  }
}
