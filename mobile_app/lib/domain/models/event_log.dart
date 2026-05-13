class EventLog {
  const EventLog({
    required this.id,
    required this.eventType,
    required this.message,
    required this.occurredAt,
    this.deviceId,
    this.source,
    this.commandId,
  });

  final String id;
  final String? deviceId;
  final String eventType;
  final String message;
  final String occurredAt;
  final String? source;
  final String? commandId;
}
