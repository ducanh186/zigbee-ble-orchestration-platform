# Gateway Light Scenes Contract

## Status

This document defines the missing Gateway contract for light-only Scenes.

Current source truth:

- Cloud already validates automation actions with `type = "scene_activate"`.
- MQTT identity policy already allows `scenes/+/desired` and
  `scenes/+/event` inside each Gateway namespace.
- Mobile reads `GET /api/scenes`, but the current Cloud branch does not yet
  implement that route. Mobile treats HTTP 404 or 501 as "Scenes unavailable".
- Gateway Scene storage and `scene.activate` execution are not implemented yet.

Direct-light schedules do not depend on this contract and remain usable.

## Mental Model

A Scene is a named, durable list of desired light states. Cloud owns the
definition. Gateway keeps the latest definition locally so it can execute the
Scene even when Mobile is not connected.

Example:

```text
Scene "Lab all off"
  light-1 -> off
  light-2 -> off
```

## Identity And Isolation

Every topic must stay inside the existing namespace:

```text
sb/v1/{tenant_id}/{site_id}/{gateway_id}
```

`group_id` and `scene_id` are only meaningful inside that namespace. Gateway
must never resolve a Scene from another tenant, site, or Gateway.

## Scene Definition Sync

Cloud publishes the latest Scene definition as a retained message:

```text
sb/v1/{tenant_id}/{site_id}/{gateway_id}/scenes/{scene_id}/desired
```

Required payload:

```json
{
  "schema": "sb.v1",
  "msg_id": "9bf86a77bdf34b0ca4eb9739b35e8ad8",
  "ts": 1781312400000,
  "tenant_id": "tenant-a",
  "site_id": "site-1",
  "gateway_id": "gw-1",
  "source": "cloud",
  "payload": {
    "op": "scene.upsert",
    "group_id": "group-lab",
    "scene_id": "scene-all-off",
    "label": "Lab all off",
    "revision": 7,
    "lights": [
      {"device_id": "light-1", "command": "off"},
      {"device_id": "light-2", "command": "off"}
    ]
  }
}
```

Gateway validation:

- Accept only visible Zigbee lights owned by this Gateway.
- Accept only `on` or `off` commands in this release.
- Reject duplicate `device_id` values.
- Reject empty `group_id`, `scene_id`, or light lists.
- Apply only a newer `revision`; replaying the same revision is idempotent.
- Persist the accepted definition before reporting success.

Gateway reports the sync result on:

```text
sb/v1/{tenant_id}/{site_id}/{gateway_id}/scenes/{scene_id}/event
```

Use an explicit status and reason such as `synced`, `invalid_scene`,
`non_light_member`, or `unknown_light`.

## Scene Activation

Cloud uses the existing Gateway command topic:

```text
sb/v1/{tenant_id}/{site_id}/{gateway_id}/commands/{command_id}/request
```

The existing `sb.v1` command envelope remains unchanged. The new payload is:

```json
{
  "op": "scene.activate",
  "target": {
    "group_id": "group-lab",
    "scene_id": "scene-all-off"
  },
  "timeout_ms": 5000
}
```

Gateway must:

1. Resolve the namespace-scoped `group_id` and `scene_id`.
2. Load the persisted Scene definition.
3. Send the requested On/Off command to every Scene light.
4. Publish the normal command reply with `status` and `reason`.
5. Include one result per light so Cloud can distinguish full and partial
   execution.

Recommended reply payload:

```json
{
  "status": "executed",
  "reason": null,
  "results": [
    {"device_id": "light-1", "status": "executed"},
    {"device_id": "light-2", "status": "executed"}
  ]
}
```

If any light is unreachable, return a terminal failure or explicit partial
result. Do not silently report success. Repeating the same activation command
must be safe and must not change the stored Scene definition.

Required failure reasons:

- `unsupported_scene`
- `scene_not_found`
- `group_not_found`
- `unknown_light`
- `light_unreachable`
- `invalid_scene`

## Mobile And Cloud Boundary

Mobile writes this automation action:

```json
{
  "type": "scene_activate",
  "group_id": "group-lab",
  "scene_id": "scene-all-off"
}
```

Cloud must validate that the Scene exists and is executable for the selected
Gateway before saving the automation. Mobile must not create production mock
Scenes. Until Cloud and Gateway Scene support is available, Mobile shows
`No scenes available` and keeps direct-light scheduling enabled.

## Acceptance Checklist

- A retained Scene definition survives Gateway restart.
- A non-light member is rejected.
- Duplicate light members are rejected.
- Cross-namespace Scene lookup is impossible.
- `scene.activate` executes every configured light.
- Unreachable lights produce explicit per-light results.
- Unknown Scenes return `scene_not_found`.
- Replaying the same definition revision is idempotent.
- Repeating activation is safe.
- Direct-light schedules still work when Scene support is absent.
