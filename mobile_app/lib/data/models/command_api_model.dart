import '../../domain/models/command_result.dart';
import '../../domain/models/command_status.dart';

class CommandApiModel {
  const CommandApiModel({
    required this.id,
    required this.deviceId,
    required this.status,
    this.reason,
  });

  factory CommandApiModel.fromJson(Map<String, Object?> json) {
    return CommandApiModel(
      id: json['id'] as String,
      deviceId: json['device_id'] as String,
      status: CommandStatus.fromJson(json['status']),
      reason: json['reason'] as String?,
    );
  }

  final String id;
  final String deviceId;
  final CommandStatus status;
  final String? reason;

  CommandResult toDomain() {
    return CommandResult(
      id: id,
      deviceId: deviceId,
      status: status,
      reason: reason,
    );
  }
}
