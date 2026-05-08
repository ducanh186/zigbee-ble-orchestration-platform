enum CommandStatus {
  idle,
  accepted,
  queued,
  sent,
  executed,
  failed,
  timeout;

  static CommandStatus fromJson(Object? value) {
    return switch (value) {
      'accepted' => CommandStatus.accepted,
      'queued' => CommandStatus.queued,
      'sent' => CommandStatus.sent,
      'executed' => CommandStatus.executed,
      'failed' => CommandStatus.failed,
      'timeout' => CommandStatus.timeout,
      _ => CommandStatus.idle,
    };
  }

  String get label => switch (this) {
    CommandStatus.idle => 'IDLE',
    CommandStatus.accepted => 'ACCEPTED',
    CommandStatus.queued => 'QUEUED',
    CommandStatus.sent => 'SENT',
    CommandStatus.executed => 'EXECUTED',
    CommandStatus.failed => 'FAILED',
    CommandStatus.timeout => 'TIMEOUT',
  };

  bool get isTerminal =>
      this == CommandStatus.executed ||
      this == CommandStatus.failed ||
      this == CommandStatus.timeout;

  bool get isPending =>
      this == CommandStatus.accepted ||
      this == CommandStatus.queued ||
      this == CommandStatus.sent;
}
