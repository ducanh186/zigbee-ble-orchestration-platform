import '../../domain/models/event_log.dart';

/// JSON wire-format model for `GET /api/events` responses.
///
/// Cloud emits the gateway event_type string verbatim (e.g.
/// `occupancy_changed`, `toggle`, `automation.executed`,
/// `automation.failed`, `gateway_online`); the mobile app keeps the string
/// untouched here and lets [categoryForEventType] in the domain layer
/// classify it for display. We deliberately do NOT add new event_type
/// values on the gateway or cloud side — the notification center is a
/// read-only view over what the platform already publishes.
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

  /// Convenience accessor for the domain-side category. Equivalent to
  /// [EventLog.category] but available before the API model is mapped to a
  /// domain object — useful in repository-level filtering or analytics.
  EventCategory get category => categoryForEventType(eventType);

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
