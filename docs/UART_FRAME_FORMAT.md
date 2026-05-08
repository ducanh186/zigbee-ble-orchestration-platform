# Native Boundary and Application Architecture

## Production Architecture (Frozen)

The production architecture is **single-process Z3Gateway C with direct MQTT integration**.

```text
Cloud / API / Mobile
    │
    ▼
MQTT broker (Mosquitto)
    │
    ▼
Z3Gateway C  ← single process on Ubuntu host
    │            • MQTT client (subscribe + publish)
    │            • command lifecycle management
    │            • device registry
    │            • local automation / rule engine
    │            • Zigbee EZSP/ASH handling
    ▼
EFR32 NCP (radio) ── EZSP/ASH over serial/UART
    │
    ▼
Zigbee end-devices (light, switch, motion)
```

Key points:

- **Z3Gateway C is the sole host process** — it handles both Zigbee radio communication
  and MQTT pub/sub directly in a single binary.
- There is **no IPC socket**, **no separate MQTT bridge process**, and **no NDJSON wire
  format** between components.
- The MQTT client (using Paho C or equivalent) runs inside Z3Gateway C.
- The serial/UART link between the Ubuntu host and EFR32 NCP uses **EZSP/ASH** —
  this is owned by the Silabs Z3Gateway stack, not by this repository.

## Host–Radio Boundary

This repository does **not** define any custom application UART frame format on the
host–radio serial link. The EZSP/ASH protocol between Z3Gateway and the NCP is the
only wire format on that boundary, and it is entirely managed by the Silabs EmberZNet
stack.

> **Legacy note:** older planning docs and the debug CLI reference `@DATA` / `@CMD` /
> `@ACK` line markers. Those are **superseded** and are **not** part of the production
> contract. `@CMD` may still appear on the local debug console of Z3Gateway for manual
> testing, but no production component relies on it.

## Application Boundary (Frozen)

The application boundary used by this repo is:

```text
Z3Gateway C  <──MQTT──>  MQTT broker  <──MQTT──>  Cloud / API / Mobile
```

There is no intermediate process or socket. Z3Gateway C directly:

- **Subscribes** to command requests, desired state, OTA manifests from cloud
- **Publishes** reported state, events, command replies, gateway health to cloud

The MQTT contract is defined in [MQTT_CONTRACT.md](./MQTT_CONTRACT.md).

## Internal Data Flow

### Cloud-driven command path

```text
Cloud/API
  → MQTT  .../commands/{command_id}/request
  → Z3Gateway C receives directly
  → parse command payload
  → dispatch by device_type (light_on, light_off, light_set_level, ...)
  → send Zigbee command via Ember AF / EZSP
  → publish .../commands/{command_id}/reply  (accepted → sent → executed|failed|timeout)
  → publish .../devices/{type}/{id}/reported  if state changed
```

### Device-driven uplink path

```text
Zigbee device state change / attribute report
  → NCP receives over-the-air, delivers via EZSP
  → Z3Gateway C callback (emberAfReportAttributesCallback, etc.)
  → normalize payload (device_id, device_type, state)
  → publish MQTT  .../devices/{type}/{id}/reported   (QoS 1, retain)
  → publish MQTT  .../devices/{type}/{id}/event       (QoS 1, no retain)  — if discrete event
```

### Gateway-driven local automation path

```text
Switch toggle event  (or motion occupied event)
  → Z3Gateway C rule engine evaluates local rules
  → send Zigbee command to target light
  → publish  .../devices/switch/{id}/event
  → publish  .../devices/light/{id}/reported   after state confirms
```

## Historical Note

> **IPC architecture (superseded):** earlier versions of this project defined an
> internal boundary using a Unix domain socket (`/tmp/sb-gateway.sock`) with NDJSON
> records between a "local adapter" process and a "MQTT bridge" process. That
> architecture was replaced by direct MQTT integration inside Z3Gateway C. The IPC
> kinds (`reported`, `event`, `command_reply`, `desired`, `command_request`,
> `ota_manifest`, `ota_desired`, etc.) are no longer part of the production contract.
> See git history for the original IPC specification.
