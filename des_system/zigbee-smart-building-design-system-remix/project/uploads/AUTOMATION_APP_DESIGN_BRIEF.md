# Automation App Design Brief

Audience: product designer, mobile developer, demo owner  
Feature: `SCRUM-43 - Mobile automation rule management screen`

## What This Screen Is For

The Automation screen lets a user create and monitor simple "when this happens,
do that" rules for Zigbee devices.

For MVP, the app is not a full rule builder. It is a guided form for a few rule
templates that are safe to demo:

- when a motion sensor becomes occupied, turn selected lights on
- when a motion sensor becomes unoccupied, turn selected lights off
- when a switch toggles, toggle one light
- when a switch toggles, toggle selected lights

The app only creates and displays rules. Cloud stores the rule and sends it to
the Gateway. Gateway is responsible for running the rule when the physical event
happens.

## Current Product Context

The app already has these tabs:

- Home
- Automation
- Provisioning
- Settings

The Home screen already shows live devices, quick light cards, and Gateway
status. Automation should feel like the next operational screen, not a marketing
page.

Design style should stay practical:

- dense enough for repeated testing
- clear labels
- visible status chips
- no hero section
- no decorative cards inside cards
- no fake "smart home" illustrations

## Primary User Flow

1. User opens the Automation tab.
2. User sees the Create Rule card.
3. User enters a rule name.
4. User selects a template.
5. User selects the trigger device.
6. User selects one or more target lights.
7. User leaves the rule enabled or turns it off.
8. User taps Save rule.
9. App creates the rule through Cloud API.
10. App shows the rule in the list with sync status.

## Screen Sections

### Header

Content:

- title: `Automation Rules`
- refresh icon button

Behavior:

- refresh reloads rules from Cloud
- if Cloud is unreachable, show the existing error banner pattern

### Create Rule Card

Fields:

- Rule name
- Template
- Trigger device
- Enabled toggle
- Target lights
- Save rule button

States:

- disabled Save button until required fields are valid
- loading state while saving
- error banner if Cloud rejects the rule
- form reset after successful creation

Design notes:

- Keep the form compact but readable.
- Long device IDs must wrap or truncate cleanly.
- Target lights should support selecting one or more lights.
- The selected template should explain the action in plain text, for example:
  `Turn selected lights on`.

### Rule List

Each rule card should show:

- rule name
- enabled switch
- sync status chip
- last run status chip
- trigger summary
- action summary

Example:

```text
Motion turns on lab lights
PENDING    NEVER RUN

WHEN
0000000000000053 occupancy changes: occupied

THEN
000000000000004F on
0000000000000055 on
```

## Status Chips

### sync_status

`pending`

- Meaning: Cloud saved the rule, but Gateway has not confirmed sync yet.
- Suggested chip: amber / warning.

`synced`

- Meaning: Gateway confirmed it received the rule.
- Suggested chip: green / success.

`failed`

- Meaning: Cloud or Gateway could not sync the rule.
- Suggested chip: red / error.

### last_run_status

`never_run`

- Meaning: The rule has not matched a real device event yet.
- Suggested chip: grey / neutral.

`executed`

- Meaning: Gateway ran the rule successfully.
- Suggested chip: green / success.

`failed`

- Meaning: Gateway tried to run the rule but failed.
- Suggested chip: red / error.

`timeout`

- Meaning: The expected action did not complete in time.
- Suggested chip: red / error.

## Empty, Loading, and Error States

Empty rule list:

```text
No automation rules yet
```

Loading:

- show the normal app loading indicator in the Rules section
- avoid blocking the whole screen if only the list is refreshing

Cloud error:

```text
Unable to load automation rules
```

Validation error:

```text
This rule is not supported by the current MVP.
```

No motion devices:

```text
No motion devices available
```

No light devices:

```text
No light devices available
```

## MVP Design Constraints

Do not design these for v1:

- nested conditions
- time schedules
- scenes
- room groups
- color control
- advanced Zigbee binding configuration
- free-form rule expressions
- local rule execution in the app

These can be future work. MVP should be easy to test on real kits next week.

## Device Data Used by the UI

Device list comes from:

```text
GET /api/devices
GET /api/devices/{device_id}/state
```

Automation rules come from:

```text
GET  /api/automations
POST /api/automations
GET  /api/automations/{automation_id}
POST /api/automations/{automation_id}/enable
POST /api/automations/{automation_id}/disable
```

Supported device types:

- `light`
- `switch`
- `motion`

Motion uses `occupancy`, with values:

- `occupied`
- `unoccupied`

## Demo Scenario to Support

Primary demo:

```text
Create rule:
When motion-01 becomes occupied
Turn light-01 and light-02 on
```

Expected result:

- rule appears in the list
- sync status starts as `pending`
- when Gateway sync is implemented, it should move to `synced`
- when motion is triggered, lights turn on and last run status updates

Backup demo:

```text
Create rule:
When switch-01 toggles
Toggle light-01
```

Use this only after confirming the switch path does not double-toggle due to
direct Zigbee binding.

## Design Acceptance Checklist

- Automation tab has one clear create flow.
- User can understand why Save rule is disabled.
- Status chips are visually distinct and readable.
- Rule cards are scannable on a phone screen.
- Long device IDs do not break the layout.
- The screen still looks good with zero rules.
- The screen still looks good with at least three rules.
- The design does not imply that the app runs automation locally.
