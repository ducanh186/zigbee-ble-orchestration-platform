# Manufacturing Registration Hotfix v1.2.4 Design

## Status

Approved in conversation on 2026-06-13.

## Objective

Ship hotfix `v1.2.4` with a secure manufacturing flow in which the Zigbee
Install Code is uploaded to Cloud while firmware is flashed. The printed QR
label remains public and must never contain the Install Code.

The hotfix also preserves the existing mobile and Cloud automation fixes,
documents the remaining Gateway work, and produces a tested Android APK.

## Scope

### In scope

- Add a PowerShell-first manufacturing registration CLI.
- Add a functionally equivalent Bash CLI for Ubuntu.
- Register one factory device per invocation.
- Upload the Install Code to the authenticated Cloud factory-device endpoint.
- Create and download a public provisioning label after registration.
- Remove stale UI and documentation that imply the Install Code belongs in a
  QR payload.
- Verify the existing mobile and Cloud provisioning contracts.
- Add a Gateway handoff describing the secure join flow and the remaining
  schedule-trigger compatibility work.
- Bump the mobile application version to `1.2.4+1204`.
- Build, install, and smoke-test the release APK.
- Push the branch, open a pull request, and publish GitHub release `v1.2.4`
  with the verified APK.

### Out of scope

- Batch CSV manufacturing registration.
- A new Cloud authentication mechanism.
- Changes to the Zigbee Install Code format or CRC algorithm.
- Gateway implementation of schedule triggers.
- Moving Install Codes into QR codes, mobile storage, logs, or release
  artifacts.

## Security Boundary

The Install Code is a secret manufacturing credential.

| Location | May contain Install Code? | Notes |
|---|---:|---|
| Manufacturing CLI process memory | Yes | Needed only while sending the authenticated request. |
| Cloud factory-device record | Yes | Existing server-side source of truth. |
| QR payload and SVG label | No | Public bootstrap identity only. |
| Mobile QR model | No | Accepts public identity fields only. |
| CLI console output and errors | No | Secret and access token must be redacted. |
| Gateway `prepare_join` command | Yes | Sent by Cloud over the existing protected MQTT path. |
| Git history and release assets | No | No secret fixtures or generated secret-bearing files. |

The access token is supplied through `SB_MANUFACTURING_ACCESS_TOKEN`. It must
not be accepted as a normal command-line argument because process arguments can
be exposed by shell history and process inspection.

## CLI Interface

Two native scripts provide the same behavior:

- `deploy/manufacturing-register.ps1`
- `deploy/manufacturing-register.sh`

Required inputs:

- `Eui64`
- `InstallCode`
- `DeviceType`

Optional inputs:

- `Model`
- `OutputDirectory`
- `SB_API_BASE_URL`, defaulting to `https://dashboard.iot-building.app`

Required environment:

- `SB_MANUFACTURING_ACCESS_TOKEN`

PowerShell is the primary documented workflow. The Bash script maps the same
inputs, environment variables, validation, requests, output files, and exit
behavior for Ubuntu manufacturing stations.

## Data Flow

1. The operator flashes firmware and obtains the device EUI-64 and Install
   Code.
2. The CLI validates and normalizes the public fields locally without printing
   the secret.
3. The CLI sends an authenticated request to
   `POST /api/provisioning/factory-devices` with EUI-64, Install Code, device
   type, and optional model.
4. The CLI verifies that Cloud reports `has_install_code: true`.
5. The CLI sends `POST /api/provisioning/labels` with only EUI-64 and device
   type.
6. The CLI writes the returned public `payload.json` and `label.svg` to the
   output directory.
7. During field provisioning, Mobile scans the public QR and requests a
   provisioning session.
8. Cloud resolves the factory record by EUI-64 and sends the server-owned
   Install Code to Gateway through `gateway.prepare_join`.

## Public QR Contract

The public QR payload remains:

```json
{
  "version": 1,
  "eui64": "00124B0000000001",
  "device_type": "light"
}
```

An optional public model field may be added only if the existing Cloud label
contract supports it. This hotfix does not expand that API solely for CLI
convenience.

The following keys are forbidden in QR payloads:

- `install_code`
- `access_token`
- MQTT credentials
- Wi-Fi credentials

## Error Handling

- Missing token or required input returns a non-zero exit code before any
  network request.
- Invalid EUI-64 or Install Code is rejected without echoing the secret.
- HTTP failures include the endpoint purpose and HTTP status.
- Server error bodies are sanitized before display.
- If factory registration succeeds but label creation fails, the CLI reports
  that registration is complete and exits non-zero so the operator can rerun
  the idempotent command.
- Existing output files are not silently overwritten unless the script's
  documented behavior explicitly permits it.

## UI and Contract Cleanup

The Cloud development UI must keep two operations separate:

1. Factory registration accepts the Install Code as a secret.
2. Label creation accepts only public identity data.

Any label form or JavaScript that copies an Install Code into a label request
or reads it from a label response must be removed.

`docs/CONTRACTS.md` and related provisioning documentation must state that QR
labels never carry Install Codes. `docs/SECURITY.md` remains the security
source of truth and must stay consistent with the API and scripts.

## Gateway Handoff

The handoff document will record:

- QR contains no Install Code.
- Cloud factory registration is completed during manufacturing.
- Gateway receives the secret only in `gateway.prepare_join`.
- Gateway must stage the Install Code by EUI-64 for a bounded join window.
- Gateway must not log the Install Code.
- Install Code CRC and join result handling must remain explicit.
- The observed `unsupported_trigger` response for schedule automation is a
  separate Gateway compatibility task and is not implemented by this hotfix.

## Verification

### Automated

- Cloud provisioning and label tests verify that labels contain no Install
  Code.
- Cloud factory-device tests verify normalization, CRC validation,
  idempotency, and `has_install_code`.
- Script tests verify request separation, output generation, redaction, and
  non-zero failure exits.
- PowerShell and Bash contract tests use equivalent fixtures.
- Existing focused automation and mobile tests remain green.
- Flutter static analysis and release build complete successfully.

### Runtime

- Run PowerShell CLI against a controlled test device record.
- Run Bash CLI on Ubuntu or a compatible Bash environment with the same
  inputs.
- Inspect `payload.json` and decoded QR content for forbidden secret keys.
- Install the release APK through ADB.
- Smoke-test login, automation list/create, and provisioning QR parsing.
- Review Android and Cloud logs for crashes, HTTP 5xx responses, secret
  leakage, and datatype errors.

## Release Process

1. Commit only the intended hotfix, tests, documentation, and version changes.
2. Build `app-release.apk` with the production API base URL.
3. Record APK size and SHA-256.
4. Push `fix/mobile-login-api-base-url`.
5. Open a ready pull request against `main`.
6. Create tag and GitHub release `v1.2.4` from the verified hotfix commit,
   attaching the APK and release notes.
7. Do not include local screenshots, design exports, test credentials, or
   manufacturing secrets in the commit or release.

## Success Criteria

- A manufacturing operator can register one device from Windows PowerShell or
  Ubuntu Bash using the same contract.
- QR payloads and labels contain no Install Code.
- Mobile provisioning still resolves the secret through Cloud.
- No token or Install Code appears in CLI output, logs, Git, APK metadata, or
  release assets.
- The production APK reports version `1.2.4` and passes ADB smoke testing.
- The pull request and release contain a discoverable Gateway handoff.
