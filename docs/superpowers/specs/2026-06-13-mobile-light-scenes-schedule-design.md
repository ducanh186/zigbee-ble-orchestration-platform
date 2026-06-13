# Mobile Light Scenes and Schedule Templates Design

## Branch

`feat/66-mobile-scene-picker-schedule-template`

## Goals

- Add schedule-on and schedule-off templates to New Rule.
- Provide simple cron presets and a raw five-field cron field.
- Allow the action target to be one light or a light-only scene.
- Keep direct light schedules usable when Groups/Scenes support is unavailable.

## Product Meaning of a Scene

A Scene is a named collection of desired light states.

Example:

```text
Scene: Sleep
- Bedroom Light: OFF
- Hall Light: ON
```

This release supports lights only. Sensors, switches, curtains, HVAC, and other actuators
are not valid scene members.

## Cloud Scene Contract

List endpoint:

```text
GET /api/scenes
```

Response:

```json
[
  {
    "group_id": "bedroom",
    "scene_id": "sleep",
    "label": "Sleep",
    "lights": [
      {
        "device_id": "light-01",
        "command": "off"
      },
      {
        "device_id": "light-02",
        "command": "on"
      }
    ]
  }
]
```

Rules:

- Every member must reference a visible light.
- Commands are `on` or `off` for this release.
- Duplicate device IDs in one scene are rejected.
- Parent/admin may create or mutate scenes when the Cloud sibling exists.
- Viewer/member may list scenes but cannot create automations.

If `GET /api/scenes` returns 404, 501, or an empty list, Mobile displays
`No scenes available` and leaves direct light selection enabled.

No production mock scene data is allowed.

## Automation Action Contract

Direct light action remains:

```json
{
  "type": "device_command",
  "device_id": "light-01",
  "device_type": "light",
  "command": "on"
}
```

Scene action:

```json
{
  "type": "scene",
  "group_id": "bedroom",
  "scene_id": "sleep"
}
```

Cloud validates the scene at rule creation and owns the durable scene definition. Cloud
syncs the definition to Gateway. At execution time, Cloud publishes `scene.activate`;
Gateway resolves the synced scene and sends the On/Off commands to each Zigbee light.

Mobile must never serialize a scene action for an unavailable or unvalidated scene.

## New Rule Templates

Add:

- `schedule_on`
- `schedule_off`

Both templates:

- Use a schedule trigger.
- Allow a direct light or scene action target.
- Preselect the action command from the template.
- Keep the rule enabled by default.

Existing motion and switch templates remain unchanged.

## Cron Picker

Presets:

- Every weekday 07:00.
- Every Sunday 22:00.
- Every six hours.
- Custom.

Preset values:

```text
0 7 * * 1-5
0 22 * * 0
0 */6 * * *
```

Custom mode exposes one raw cron input. It accepts exactly five fields. Mobile performs
basic validation for immediate feedback; Cloud remains authoritative and returns 422 for
invalid cron.

No helper text is rendered beneath the cron input. Errors use border/tone and the shared
form-level validation area.

## UI Flow

```text
New Rule
-> Quick Template: Schedule On or Schedule Off
-> Schedule preset or Custom cron
-> Action target type: Light or Scene
-> Select direct light or available light-only scene
-> Enabled
-> Save Rule
```

Visual requirements:

- Reuse the approved dark rounded-card design.
- Keep selected cards highlighted in blue.
- Preserve the sticky Cancel and Save footer.
- Disable Save until schedule and action target are valid.
- Do not place small explanatory copy beneath inputs or toggles.

## i18n

All new labels originate in English ARB and have Vietnamese mappings:

- Schedule On.
- Schedule Off.
- Every weekday 07:00.
- Every Sunday 22:00.
- Every six hours.
- Custom schedule.
- Light.
- Scene.
- No scenes available.
- Invalid cron expression.

Wire values and cron expressions are not translated.

## Gateway Handoff

Write a tracked handoff defining the light-only scene execution requirement:

- Namespace-scoped Group and Scene identity.
- Scene lookup by `group_id` and `scene_id`.
- Retained Cloud-to-Gateway scene definition:
  `scenes/{scene_id}/desired`, with `group_id` and the light member list in the payload.
- Activation through the normal command request path with `op = scene.activate` and a
  target containing `group_id` and `scene_id`.
- Only On/Off light commands in this release.
- Per-light execution result reporting.
- Behavior when a light is unreachable.
- Idempotent activation of the same scene.

Until Gateway Groups/Scenes execution exists:

- Direct light schedules are fully supported.
- Scene picker may list only scenes that Cloud marks executable for the selected Gateway.
- Saving or executing an unsupported scene must fail explicitly, never silently succeed.

## Tests

Mobile:

- Schedule-on preset creates `0 7 * * 1-5`.
- Schedule-off preset chooses `off`.
- Sunday and six-hour presets serialize correctly.
- Custom valid cron enables Save.
- Invalid custom cron disables Save.
- Direct light schedule serializes correctly.
- Scene list renders light-only scenes.
- Empty or unsupported scene API shows the empty state.
- Direct light selection remains available with no scenes.
- Viewer/member cannot open the creation flow.
- Existing motion and switch modal tests remain green.

Cloud scene sibling or adapter tests:

- Scene list contains only visible light scenes.
- Non-light member is rejected.
- Duplicate light member is rejected.
- Unknown scene cannot be used in a rule.

## Acceptance

- Parent/admin can create a schedule-on or schedule-off rule for a direct light.
- Preset cron reaches Cloud exactly as specified.
- Scene picker lists Cloud-confirmed light-only scenes.
- Missing scene support does not block direct light scheduling.
- Unsupported scene save fails clearly.
- Widget tests, `flutter analyze`, and `flutter test` pass.
