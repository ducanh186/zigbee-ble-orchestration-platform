import 'command_status.dart';

class CommandResult {
  const CommandResult({
    required this.id,
    required this.deviceId,
    required this.status,
    this.reason,
  });

  final String id;
  final String deviceId;
  final CommandStatus status;
  final String? reason;
}
