# Gateway Handoff: Environment Sensor Telemetry and Threshold Rules

## Status

Cloud and Mobile are ready for the Environment device contract below. Gateway
and local Zigbee implementation remain the only runtime dependency.

The source handoff `dht11_environment_sensor_local_handoff (1).md` is a local
input only. It is already ignored by the repository Markdown ignore rule and
must not be committed.

## Evidence from the Local Zigbee Handoff

The DHT11 firmware exposes endpoint 1 with:

- HA profile `0x0104`
- device ID `0x0302`
- Temperature Measurement cluster `0x0402`
- Relative Humidity Measurement cluster `0x0405`
- `MeasuredValue` scaling of `0.01` units

Observed Gateway logs:

```text
@LOG {"tag":"ENV","event":"report","device_id":"0000000000000053","node_id":"0xA09A","temperature_c_x100":2850}
@LOG {"tag":"ENV","event":"report","device_id":"0000000000000053","node_id":"0xA09A","humidity_pct_x100":4800}
```

The current Gateway classifies this device as `unknown` and does not publish
either measurement to MQTT.

## Device Classification

When endpoint discovery finds server cluster `0x0402` or `0x0405`, classify the
device as:

```json
{
  "device_type": "environment"
}
```

Use the durable EUI64-based `device_id`; do not use the transient Zigbee
`node_id` as Cloud identity.

## MQTT Topic

```text
sb/v1/{tenant_id}/{site_id}/{gateway_id}/devices/environment/{device_id}/reported
```

This follows the existing tenant/site/gateway namespace boundary. Production
publishing must continue to use the configured MQTT TLS/mTLS credentials.

## MQTT Envelope

Temperature report:

```json
{
  "schema": "sb.v1",
  "msg_id": "01J...",
  "ts": "2026-06-13T08:00:05.123Z",
  "tenant_id": "tenant-01",
  "site_id": "site-01",
  "gateway_id": "gw-ubuntu-01",
  "source": "gateway",
  "payload": {
    "temperature_c": 28.5,
    "sensor": "dht11",
    "reachable": true
  }
}
```

Humidity report:

```json
{
  "schema": "sb.v1",
  "msg_id": "01J...",
  "ts": "2026-06-13T08:00:05.200Z",
  "tenant_id": "tenant-01",
  "site_id": "site-01",
  "gateway_id": "gw-ubuntu-01",
  "source": "gateway",
  "payload": {
    "humidity_percent": 48,
    "sensor": "dht11",
    "reachable": true
  }
}
```

Rules:

- Convert `temperature_c_x100 / 100.0` before publishing.
- Convert `humidity_pct_x100 / 100.0` before publishing.
- Temperature range accepted by Cloud: `-20..80` degrees Celsius.
- Humidity range accepted by Cloud: `0..100` percent.
- Publish only values actually present in the Zigbee report.
- Do not invent a missing measurement as `0`.
- Separate temperature and humidity reports are valid. Cloud merges them into
  the latest Environment state.
- Invalid Zigbee sentinel values (`0x8000` temperature, `0xFFFF` humidity) must
  not be published as measurements.
- Set `reachable=false` only from real liveness evidence, not from one missing
  attribute in a partial report.

## Cloud State

The resulting Cloud device state is:

```json
{
  "temperature_c": 28.5,
  "humidity_percent": 48,
  "sensor": "dht11",
  "reachable": true
}
```

Mobile renders the first visible `environment` device as two Home widgets.
Parent, viewer, and member roles can read these widgets.

## Sensor Threshold Automation

Cloud sends the existing automation upsert envelope with this trigger shape:

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

Supported values:

- `metric`: `temperature_c`, `humidity_percent`
- `operator`: `gte`, `lte`
- `threshold`: numeric value in the metric range

Gateway evaluation:

1. Merge the incoming partial Environment report into the device's latest
   local state.
2. Evaluate only when the selected metric is present.
3. Dispatch actions only on a `false -> true` condition crossing.
4. Re-arm the rule after the condition becomes false.
5. Do not repeatedly dispatch on every report while the condition stays true.
6. Disabled rules never execute.
7. Continue using the existing automation action path and command result/event
   reporting.

Example: `temperature_c gte 30` fires once when the temperature moves from
`29.5` to `30.0`, does not fire again at `31.0`, and re-arms after a report
below `30.0`.

## Gateway Status Compatibility

Gateway online/offline messages remain on the existing Gateway status topic and
are stored as Cloud events with `device_id=null`. Mobile now reads:

```text
GET /api/gateways/{gateway_id}/status
```

No Gateway payload change is required for this endpoint as long as the current
`gateway_online` event continues to include `value`, `gateway_id`, and
`source=gateway`.

## Gateway Acceptance Checklist

- Environment device is announced as `device_type=environment`.
- A `2850` temperature report publishes `temperature_c: 28.5`.
- A `4800` humidity report publishes `humidity_percent: 48`.
- A temperature-only report does not erase the latest humidity value in Cloud.
- A humidity-only report does not erase the latest temperature value in Cloud.
- Invalid sentinel values do not produce fake readings.
- `gte` and `lte` rules execute only on condition crossing.
- A disabled threshold rule does not execute.
- Existing motion, switch, and light MQTT flows remain unchanged.
