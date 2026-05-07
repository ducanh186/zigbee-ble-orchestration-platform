import '../../domain/models/event_log.dart';

class EventApiModel {
  const EventApiModel({
    required this.id,
    required this.eventType,
    required this.message,
    required this.occurredAt,
    this.deviceId,
    this.source,
    this.commandId,
  });

  factory EventApiModel.fromJson(Map<String, Object?> json) {
    final payloadRaw = json['payload'];
    final payload = payloadRaw is Map
        ? Map<String, Object?>.from(payloadRaw)
        : const <String, Object?>{};
    final commandId =
        payload['command_id'] ?? payload['correlation_id'] ?? payload['id'];
    final message =
        payload['message'] ?? payload['status'] ?? payload['event'] ?? payload;

    return EventApiModel(
      id: json['id'].toString(),
      deviceId: json['device_id'] as String?,
      eventType: json['event_type'] as String? ?? 'event',
      message: message.toString(),
      occurredAt: json['occurred_at'] as String? ?? '',
      source: payload['source'] as String?,
      commandId: commandId?.toString(),
    );
  }

  final String id;
  final String? deviceId;
  final String eventType;
  final String message;
  final String occurredAt;
  final String? source;
  final String? commandId;

  EventLog toDomain() {
    return EventLog(
      id: id,
      deviceId: deviceId,
      eventType: eventType,
      message: message,
      occurredAt: occurredAt,
      source: source,
      commandId: commandId,
    );
  }
}
