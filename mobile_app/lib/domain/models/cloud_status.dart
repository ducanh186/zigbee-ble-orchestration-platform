enum CloudConnectionState { online, offline, unknown, mock }

class CloudStatus {
  const CloudStatus({
    required this.state,
    this.version,
    this.detail,
    this.gatewayId,
    this.eventType,
    this.occurredAt,
  });

  const CloudStatus.online({
    String? version,
    String? gatewayId,
    String? eventType,
    String? occurredAt,
  }) : this(
         state: CloudConnectionState.online,
         version: version,
         gatewayId: gatewayId,
         eventType: eventType,
         occurredAt: occurredAt,
       );

  const CloudStatus.offline({
    String? detail,
    String? gatewayId,
    String? eventType,
    String? occurredAt,
  }) : this(
         state: CloudConnectionState.offline,
         detail: detail,
         gatewayId: gatewayId,
         eventType: eventType,
         occurredAt: occurredAt,
       );

  const CloudStatus.unknown({
    String? detail,
    String? gatewayId,
    String? eventType,
    String? occurredAt,
  }) : this(
         state: CloudConnectionState.unknown,
         detail: detail,
         gatewayId: gatewayId,
         eventType: eventType,
         occurredAt: occurredAt,
       );

  const CloudStatus.mock()
    : this(
        state: CloudConnectionState.mock,
        detail: 'Mock home hub log',
        gatewayId: 'gw-demo-01',
        eventType: 'gateway_online',
        occurredAt: '07:16 05/07/2026',
      );

  final CloudConnectionState state;
  final String? version;
  final String? detail;
  final String? gatewayId;
  final String? eventType;
  final String? occurredAt;

  bool get isOnline => state == CloudConnectionState.online;
}
