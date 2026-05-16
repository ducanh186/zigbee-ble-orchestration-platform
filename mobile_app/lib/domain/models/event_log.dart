/// High-level grouping of cloud events used by the mobile notification
/// center.
///
/// The cloud API emits event_type strings verbatim from the gateway (e.g.
/// `occupancy_changed`, `automation.executed`); the mobile app classifies
/// them into a small enum so the UI can pick the right badge tone and label
/// without sprinkling string comparisons across widgets.
enum EventCategory {
  motion,
  automationExecuted,
  automationFailed,
  other,
}

/// Maps a raw [eventType] string from the cloud `/api/events` response to a
/// mobile-side [EventCategory]. Defensive defaults — anything we don't know
/// about ends up as [EventCategory.other] and gets a neutral badge.
EventCategory categoryForEventType(String eventType) {
  final lower = eventType.toLowerCase();
  if (lower.contains('motion') || lower.contains('occupancy')) {
    return EventCategory.motion;
  }
  if (lower.contains('automation')) {
    if (lower.contains('fail') || lower.contains('error') ||
        lower.contains('timeout')) {
      return EventCategory.automationFailed;
    }
    return EventCategory.automationExecuted;
  }
  return EventCategory.other;
}

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

  EventCategory get category => categoryForEventType(eventType);
}
