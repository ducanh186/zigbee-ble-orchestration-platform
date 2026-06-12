# Environment Sensor, Provisioning, and i18n Design

## Branch

`feat/107-environment-sensor-automation-ui`

## Goals

- Display DHT11 temperature and humidity on the Home screen.
- Allow parent/admin users to create temperature or humidity threshold rules.
- Allow viewer/member users to see Environment widgets but not create or modify rules.
- Remove any remaining Mobile requirement for `install_code`.
- Correct Gateway status display for parent/viewer users.
- Make English the source UI copy and map all supported copy to Vietnamese.

## Confirmed Current State

- Mobile QR payloads do not contain or parse `install_code`.
- Cloud stores install codes in factory and provisioning records.
- Cloud sends the install code to Gateway through `gateway.prepare_join`.
- DHT11 firmware and Zigbee-to-Gateway decoding are verified.
- Gateway currently writes Environment reports only to logs.
- No MQTT temperature or humidity report currently reaches Cloud.
- Gateway classifies clusters `0x0402` and `0x0405` as `unknown`.
- Parent users cannot see `gateway_online` events because those rows have
  `device_id = null` and the generic events endpoint filters by visible device IDs.

## Environment MQTT Contract

### Topic

```text
sb/v1/{tenant_id}/{site_id}/{gateway_id}/devices/environment/{device_id}/reported
```

Direction: Gateway to Cloud.

QoS: 1.

Retain: false.

### Envelope

```json
{
  "schema": "sb.v1",
  "msg_id": "unique-message-id",
  "ts": 1781269200000,
  "tenant_id": "tenant-01",
  "site_id": "site-01",
  "gateway_id": "gw-01",
  "source": "gateway",
  "payload": {
    "device_type": "environment",
    "eui64": "0000000000000053",
    "state": {
      "temperature_c": 28.5,
      "humidity_percent": 48.0,
      "sensor": "dht11",
      "reachable": true
    }
  }
}
```

Temperature and humidity may arrive in separate messages. A valid partial report may
contain only one metric.

### Gateway conversion

- Convert `temperature_c_x100` to `temperature_c` by dividing by 100.
- Convert `humidity_pct_x100` to `humidity_percent` by dividing by 100.
- Do not publish raw `*_x100` fields to Cloud.
- Do not use Zigbee `node_id` as durable identity.
- Do not publish fabricated zero values when DHT11 reads fail.
- Classify devices exposing clusters `0x0402` or `0x0405` as `environment`.

## Cloud State Handling

Cloud validates:

- `temperature_c`: number from -20 through 80.
- `humidity_percent`: number from 0 through 100.
- `sensor`: optional string; expected value `dht11`.
- `reachable`: boolean.

Before inserting a new `DeviceState`, Cloud merges a partial Environment report with the
latest state for the same device. This prevents a humidity-only report from erasing the
latest temperature and vice versa.

The existing endpoints remain the Mobile data source:

```text
GET /api/devices/
GET /api/devices/{device_id}/state
```

No sensor-specific REST endpoint is introduced.

## Home UI

The Home screen follows the approved reference image:

- Section title `ENVIRONMENT`.
- Two side-by-side dark rounded cards on normal phone widths.
- Temperature card with thermometer icon, value, `°C`, and sensor name.
- Humidity card with droplet icon, value, `%`, and sensor name.
- Cards wrap vertically on narrow screens.
- Missing metric displays `--`, never `0`.
- Stale or unreachable sensor uses the existing warning palette.

Visibility:

- `admin`, `parent`, and `viewer` all see Environment cards.
- Only `admin` and `parent` can create, update, enable, disable, or delete automation rules.

## Sensor Threshold Rule

### Trigger payload

```json
{
  "type": "sensor_threshold",
  "device_id": "0000000000000053",
  "device_type": "environment",
  "metric": "temperature_c",
  "operator": "gte",
  "threshold": 30
}
```

Allowed metrics:

- `temperature_c`
- `humidity_percent`

Allowed operators:

- `gte`
- `lte`

The Gateway evaluates the condition on transitions from false to true. Repeated reports
that remain true do not repeatedly execute the action.

### New Rule UI

When an Environment device is selected, show a compact `CONDITION` section:

```text
[ Temperature ] [ >= ] [ 30 ] °C
```

Requirements:

- Match the approved dark card reference.
- Selected device and light cards use the existing blue highlight.
- Unit changes automatically with metric.
- Save stays disabled until all required values are valid.
- No helper or explanatory text appears under text boxes, selectors, or toggles.
- Validation uses border/tone and a form-level message area.
- Existing motion and switch creation remain unchanged.

Threshold ranges:

- Temperature: -20 through 80.
- Humidity: 0 through 100.

## Gateway Status Correction

Add a dedicated status API rather than exposing all gateway events:

```text
GET /api/gateways/{gateway_id}/status
```

Response fields:

```json
{
  "gateway_id": "gw-01",
  "state": "online",
  "version": "optional",
  "last_seen_at": "2026-06-13T08:00:00Z",
  "event_type": "gateway_online",
  "detail": null
}
```

Access:

- Admin may read any configured Gateway.
- Parent/viewer may read only the Gateway associated with their home/site.

Mobile stops deriving Gateway status from `/api/events/` and uses this endpoint.

## Provisioning Audit

The Mobile provisioning form contains:

- Room ID.
- QR scanner.
- QR JSON field for scanned or pasted public payload.

It must not contain:

- Install-code field.
- Install-code validation.
- Install-code helper text.
- Install-code serialization.

Regression tests prove:

- QR without `install_code` parses.
- Session creation does not send `install_code`.
- Cloud session output never exposes `install_code`.
- Cloud still resolves and sends the stored code through `gateway.prepare_join`.

## i18n Audit

Source of truth:

- English: `app_en.arb`.
- Vietnamese: `app_vi.arb`.

Audit all user-visible copy:

- Page titles and navigation labels.
- Buttons, fields, selectors, cards, badges, empty states, and dialogs.
- Default text and fallback text.
- Validation and network/API error messages.
- Automation, provisioning, Home, device detail, logs, profile, and settings.

Remove hard-coded Vietnamese ASCII messages such as `Khong tai duoc...`.
Technical wire values remain English and are not translated.

ARB key parity is mandatory: every English key has a Vietnamese mapping and vice versa.

## Tests

Cloud:

- Environment payload validation.
- Partial-state merge in both metric arrival orders.
- Out-of-range rejection.
- Gateway status access and latest-state mapping.
- Provisioning install-code non-exposure regression.

Mobile:

- Environment model detection without hard-coded device ID.
- Viewer and parent Environment widget visibility.
- Viewer cannot access automation mutation flow.
- Condition unit, operator, range, save validation, and payload serialization.
- Existing motion and switch widget tests.
- Provisioning QR regression.
- English/Vietnamese ARB parity and representative UI localization tests.

Commands:

```text
pytest
flutter analyze
flutter test
```

## Handoff

Write a tracked Gateway handoff under `docs/handoffs/` with:

- Environment classification change.
- MQTT topic and envelope.
- Conversion rules.
- Partial-report behavior.
- False-to-true threshold semantics.
- Gateway build and runtime checks.

The received file `dht11_environment_sensor_local_handoff (1).md` remains local-only and
must not be committed.

## Acceptance

- All roles see real Environment values when Cloud has sensor state.
- Viewer/member cannot mutate automations.
- Parent/admin can save a valid threshold rule.
- Invalid threshold cannot be saved.
- Motion and switch rule creation still works.
- Provisioning never requests an install code from Mobile.
- Gateway status no longer shows unknown solely because generic events are filtered.
- English and Vietnamese UI copy are complete and generated successfully.
- Cloud and Flutter checks pass.
