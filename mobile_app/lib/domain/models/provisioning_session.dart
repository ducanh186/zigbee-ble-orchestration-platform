import 'dart:convert';

const _supportedQrVersion = 1;
const _installCodeHexLengths = <int>{16, 20, 28, 36};
final _hexPattern = RegExp(r'^[0-9a-fA-F]+$');
final _eui64Pattern = RegExp(r'^[0-9a-fA-F]{16}$');

enum ProvisioningDeviceType {
  light,
  switchDevice,
  motion;

  static ProvisioningDeviceType fromJson(Object? value) {
    return switch (value) {
      'light' => ProvisioningDeviceType.light,
      'switch' => ProvisioningDeviceType.switchDevice,
      'motion' => ProvisioningDeviceType.motion,
      _ => throw FormatException('Unsupported provisioning device_type: $value'),
    };
  }

  String get wireValue => switch (this) {
    ProvisioningDeviceType.light => 'light',
    ProvisioningDeviceType.switchDevice => 'switch',
    ProvisioningDeviceType.motion => 'motion',
  };

  String get label => switch (this) {
    ProvisioningDeviceType.light => 'Light',
    ProvisioningDeviceType.switchDevice => 'Switch',
    ProvisioningDeviceType.motion => 'Motion',
  };
}

enum ProvisioningStatus {
  pending,
  permitOpen,
  joining,
  joined,
  failed,
  expired,
  cancelled;

  static ProvisioningStatus fromJson(Object? value) {
    return switch (value) {
      'pending' => ProvisioningStatus.pending,
      'permit_open' => ProvisioningStatus.permitOpen,
      'joining' => ProvisioningStatus.joining,
      'joined' => ProvisioningStatus.joined,
      'failed' => ProvisioningStatus.failed,
      'expired' => ProvisioningStatus.expired,
      'cancelled' => ProvisioningStatus.cancelled,
      _ => throw FormatException('Unsupported provisioning status: $value'),
    };
  }

  String get wireValue => switch (this) {
    ProvisioningStatus.pending => 'pending',
    ProvisioningStatus.permitOpen => 'permit_open',
    ProvisioningStatus.joining => 'joining',
    ProvisioningStatus.joined => 'joined',
    ProvisioningStatus.failed => 'failed',
    ProvisioningStatus.expired => 'expired',
    ProvisioningStatus.cancelled => 'cancelled',
  };

  bool get isTerminal =>
      this == ProvisioningStatus.joined ||
      this == ProvisioningStatus.failed ||
      this == ProvisioningStatus.expired ||
      this == ProvisioningStatus.cancelled;
}

class ProvisioningQrPayload {
  const ProvisioningQrPayload({
    required this.version,
    required this.eui64,
    required this.installCode,
    required this.deviceType,
    this.model,
  });

  factory ProvisioningQrPayload.parseJson(String value) {
    final decoded = jsonDecode(value);
    if (decoded is! Map) {
      throw const FormatException('Provisioning QR payload must be a JSON object');
    }
    return ProvisioningQrPayload.fromJson(Map<String, Object?>.from(decoded));
  }

  factory ProvisioningQrPayload.fromJson(Map<String, Object?> json) {
    final version = json['version'];
    if (version is! int || version != _supportedQrVersion) {
      throw FormatException('Unsupported provisioning QR version: $version');
    }

    final eui64 = _requiredString(json, 'eui64').trim();
    if (!_eui64Pattern.hasMatch(eui64)) {
      throw const FormatException('eui64 must be 16 hex characters');
    }

    final installCode = _requiredString(json, 'install_code').trim();
    if (!_hexPattern.hasMatch(installCode) ||
        !_installCodeHexLengths.contains(installCode.length)) {
      throw const FormatException(
        'install_code must be valid hex with CRC length',
      );
    }

    return ProvisioningQrPayload(
      version: version,
      eui64: eui64.toUpperCase(),
      installCode: installCode.toUpperCase(),
      deviceType: ProvisioningDeviceType.fromJson(json['device_type']),
      model: _optionalString(json, 'model'),
    );
  }

  final int version;
  final String eui64;
  final String installCode;
  final ProvisioningDeviceType deviceType;
  final String? model;
}

class ProvisioningSession {
  const ProvisioningSession({
    required this.sessionId,
    required this.status,
    required this.gatewayId,
    required this.roomId,
    required this.eui64,
    required this.deviceType,
    this.model,
    this.reason,
    this.expiresAt,
    this.createdAt,
    this.updatedAt,
  });

  final String sessionId;
  final ProvisioningStatus status;
  final String gatewayId;
  final String roomId;
  final String eui64;
  final ProvisioningDeviceType deviceType;
  final String? model;
  final String? reason;
  final String? expiresAt;
  final String? createdAt;
  final String? updatedAt;

  bool get isTerminal => status.isTerminal;
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('$key must be a non-empty string');
  }
  return value;
}

String? _optionalString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw FormatException('$key must be a string');
  }
  return value.isEmpty ? null : value;
}
