# Automation Contract

## Schedule Trigger Extension

This extension does not change existing event-rule payloads. Event rules continue
to use `trigger_type: "event"` (the default) and `schedule_cron: null`.

Schedule rules are Cloud-owned and use a five-field cron expression:

```json
{
  "name": "Weekday 7am light",
  "enabled": true,
  "trigger_type": "schedule",
  "schedule_cron": "0 7 * * 1-5",
  "trigger": {
    "type": "schedule"
  },
  "actions": [
    {
      "type": "device_command",
      "device_id": "light-01",
      "device_type": "light",
      "command": "on"
    }
  ]
}
```

Rules:

- Cron has exactly five fields: minute, hour, day-of-month, month, day-of-week.
- Cloud evaluates schedules in `Asia/Ho_Chi_Minh`.
- The worker aligns evaluation to each minute and dispatches at most once per rule
  per minute.
- Disabled rules are excluded before cron evaluation.
- Invalid cron strings are rejected by the API with HTTP 422.
- Schedule execution uses the normal command persistence and MQTT publication path.
- Every attempted action creates an `automation_events` audit row.
- Gateway receives normal device commands at execution time; it does not evaluate
  Cloud schedules.

The initial schedule release supports direct light `on` and `off` actions. Scene
activation requires the separate Groups/Scenes Cloud and Gateway contract.
