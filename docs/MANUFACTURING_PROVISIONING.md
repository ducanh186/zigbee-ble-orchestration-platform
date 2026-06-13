# Manufacturing Provisioning

## Purpose

Register a Zigbee device's Install Code in Cloud while firmware is flashed,
then generate a public QR label. The QR identifies the device but never carries
the Install Code.

The manufacturing flow is:

1. Flash firmware and read the EUI-64 and Install Code.
2. Register the factory device through the authenticated Cloud API.
3. Generate `payload.json` and `label.svg`.
4. Print the public label.
5. During installation, Mobile scans the label and Cloud resolves the secret.

## Prerequisites

- An admin Cloud access token.
- EUI-64 as exactly 16 hexadecimal characters.
- A Zigbee Install Code with its valid CRC.
- Device type: `light`, `switch`, or `motion`.
- PowerShell 5.1+ on Windows, or Bash with `curl` and `python3` on Ubuntu.

The default API is `https://dashboard.iot-building.app`. Override it only for
an approved staging environment with `SB_API_BASE_URL`.

## Windows PowerShell

Set the token for the current terminal session:

```powershell
$env:SB_MANUFACTURING_ACCESS_TOKEN = '<ADMIN_ACCESS_TOKEN>'
```

Register one device:

```powershell
.\deploy\manufacturing-register.ps1 `
  -Eui64 '<16_HEX_EUI64>' `
  -InstallCode '<INSTALL_CODE_WITH_CRC>' `
  -DeviceType light `
  -Model 'EFR32MG12_LIGHT_KIT' `
  -OutputDirectory '.\manufacturing-output\<16_HEX_EUI64>'
```

Remove the token after the station finishes:

```powershell
Remove-Item Env:SB_MANUFACTURING_ACCESS_TOKEN
```

## Ubuntu Bash

Set the token for the current shell:

```bash
export SB_MANUFACTURING_ACCESS_TOKEN='<ADMIN_ACCESS_TOKEN>'
```

Register one device:

```bash
./deploy/manufacturing-register.sh \
  --eui64 '<16_HEX_EUI64>' \
  --install-code '<INSTALL_CODE_WITH_CRC>' \
  --device-type light \
  --model 'EFR32MG12_LIGHT_KIT' \
  --output-directory './manufacturing-output/<16_HEX_EUI64>'
```

Remove the token after the station finishes:

```bash
unset SB_MANUFACTURING_ACCESS_TOKEN
```

## Output

Each successful invocation writes:

- `payload.json`: public QR JSON.
- `label.svg`: printable QR image.

Expected payload:

```json
{
  "version": 1,
  "eui64": "00124B0000000001",
  "device_type": "light"
}
```

Neither file may contain `install_code`, access tokens, MQTT credentials, or
Wi-Fi credentials. The scripts refuse to overwrite existing output files.

## Failure And Rerun

- A missing token or invalid local input fails before an HTTP request.
- Cloud validates the Install Code CRC.
- Factory registration is an idempotent upsert.
- If registration succeeds but label generation fails, rerun the same command
  after fixing the reported API or authorization issue.
- Error output intentionally omits response bodies from the secret-bearing
  factory endpoint.

## Manufacturing Gate

Before printing a production label:

1. Confirm the command exits with code `0`.
2. Open `payload.json` and confirm it contains only public identity fields.
3. Decode the QR and compare EUI-64/device type with the flashed device.
4. Confirm Cloud reports `has_install_code: true`.
5. Never paste the Install Code, token, or private key into tickets, screenshots,
   Git commits, or release assets.

## Field Provisioning Data Flow

```text
Public QR -> Mobile -> Cloud provisioning session
                         |
                         +-> factory_devices lookup by EUI-64
                         |
                         +-> gateway.prepare_join with Install Code
                                      |
                                      +-> short Zigbee join window
```

Gateway continuation details are in
[`MANUFACTURING_INSTALL_CODE_GATEWAY_HANDOFF.md`](handoffs/MANUFACTURING_INSTALL_CODE_GATEWAY_HANDOFF.md).
