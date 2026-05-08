enum DevicePower {
  on,
  off,
  unreachable,
  unknown;

  static DevicePower fromJson(Object? value, {bool reachable = true}) {
    if (!reachable) {
      return DevicePower.unreachable;
    }

    return switch (value) {
      'on' => DevicePower.on,
      'off' => DevicePower.off,
      _ => DevicePower.unknown,
    };
  }

  String get wireValue => switch (this) {
    DevicePower.on => 'on',
    DevicePower.off => 'off',
    DevicePower.unreachable || DevicePower.unknown => 'off',
  };

  String get label => switch (this) {
    DevicePower.on => 'ON',
    DevicePower.off => 'OFF',
    DevicePower.unreachable => 'UNREACHABLE',
    DevicePower.unknown => 'UNKNOWN',
  };

  bool get canCommand => this == DevicePower.on || this == DevicePower.off;
}
