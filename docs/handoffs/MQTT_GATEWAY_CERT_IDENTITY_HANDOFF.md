# MQTT Gateway Certificate Identity Handoff

## Purpose

Production Mosquitto now authenticates clients by the common name in their
mTLS certificate. Each Gateway certificate is authorized for one exact
`tenant/site/gateway` namespace.

This handoff describes the Gateway changes required before production broker
cutover. The current MQTT topic suffixes and message payloads must not change.

## Required Gateway Changes

### Configuration

Add:

```text
SB_MQTT_CERT_IDENTITY_ENABLED=true
SB_MQTT_PRINCIPAL_ID=<principal_id>
```

When certificate identity is enabled:

- Require the broker host and TLS port.
- Require the CA certificate, Gateway certificate, and Gateway private key.
- Require tenant, site, and gateway identifiers.
- Require the certificate common name to equal `SB_MQTT_PRINCIPAL_ID`.
- Do not require or send `SB_MQTT_USERNAME` and `SB_MQTT_PASSWORD`.
- Reject production startup when TLS or mTLS is disabled.

Keep username/password authentication available only for the existing local
development mode.

### MQTT Client Identity

Replace the fixed client id `z3gw-host` with a unique value derived from
`principal_id`. A suitable shape is:

```text
z3gw-<principal_id>
```

Validate the final client id against the MQTT library length and character
rules. Do not silently fall back to a shared client id because two Gateways
using the same id will disconnect each other.

### Topic Contract

Continue using:

```text
sb/v1/{tenant_id}/{site_id}/{gateway_id}/...
```

Preserve every current topic suffix, QoS choice, retain flag, and message
payload. This security change affects authentication and authorization only.

The certificate `principal_id` and topic namespace tuple are separate values:

- `principal_id` identifies the certificate.
- `tenant_id/site_id/gateway_id` identifies the only application namespace
  that certificate may access.

## Key And CSR Workflow

Generate the private key on the Gateway host. The private key must never be
sent to Cloud, the deployment host, source control, chat, or a ticket.

```bash
install -d -m 0700 /etc/sb-gateway/mqtt
openssl genrsa \
  -out /etc/sb-gateway/mqtt/gateway.key \
  2048
chmod 0600 /etc/sb-gateway/mqtt/gateway.key

openssl req -new \
  -key /etc/sb-gateway/mqtt/gateway.key \
  -out /etc/sb-gateway/mqtt/gateway.csr \
  -subj "/CN=gateway-hust-lab01-01"
```

The CSR common name must exactly equal the inventory `principal_id`. Send only
the CSR to the deployment owner.

The deployment owner adds a row to the ignored production inventory:

```csv
principal_id,tenant_id,site_id,gateway_id,csr_file
gateway-hust-lab01-01,hust,lab01,gw-ubuntu-01,mqtt-csrs/gateway-hust-lab01-01.csr
```

After signing, install the returned Gateway certificate and CA certificate
without replacing or transferring the local private key.

Recommended file modes:

```text
/etc/sb-gateway/mqtt/gateway.key  0600
/etc/sb-gateway/mqtt/gateway.crt  0644
/etc/sb-gateway/mqtt/ca.crt       0644
```

Verify the returned certificate:

```bash
openssl verify \
  -CAfile /etc/sb-gateway/mqtt/ca.crt \
  /etc/sb-gateway/mqtt/gateway.crt

openssl x509 \
  -in /etc/sb-gateway/mqtt/gateway.crt \
  -noout -subject -issuer -dates
```

## Readiness Checklist

- [ ] The private key was generated on the Gateway and has mode `0600`.
- [ ] No Gateway private key was transferred off the Gateway.
- [ ] The CSR signature is valid.
- [ ] The CSR and signed certificate contain exactly one common name.
- [ ] The common name exactly equals `SB_MQTT_PRINCIPAL_ID`.
- [ ] The inventory tuple matches the Gateway's tenant, site, and gateway id.
- [ ] The CA, certificate, and key paths exist and are readable by the service.
- [ ] Certificate identity mode does not require username/password variables.
- [ ] Production startup fails when TLS or mTLS configuration is incomplete.
- [ ] The client id is unique and derived from `principal_id`.
- [ ] Existing topic suffixes, QoS, retain flags, and payloads are unchanged.
- [ ] Reconnect behavior has been tested after broker and network restarts.

Broker cutover is blocked until Gateway owners confirm every checklist item.

## Smoke Tests

Set these examples to the Gateway's real paths and namespace:

```bash
BROKER=<broker-host>
PORT=8883
CA=/etc/sb-gateway/mqtt/ca.crt
CERT=/etc/sb-gateway/mqtt/gateway.crt
KEY=/etc/sb-gateway/mqtt/gateway.key
PREFIX=sb/v1/hust/lab01/gw-ubuntu-01
```

Confirm the Gateway identity can subscribe to its command namespace:

```bash
mosquitto_sub -h "$BROKER" -p "$PORT" \
  --cafile "$CA" --cert "$CERT" --key "$KEY" \
  -t "$PREFIX/commands/+/request" -d
```

Confirm it can publish an allowed Gateway event:

```bash
mosquitto_pub -h "$BROKER" -p "$PORT" \
  --cafile "$CA" --cert "$CERT" --key "$KEY" \
  -t "$PREFIX/gateway/event" -m '{}' -q 1 -d
```

Negative tests are mandatory:

- Change the tenant id and confirm subscribe and publish are denied.
- Change the site id and confirm subscribe and publish are denied.
- Change the gateway id and confirm subscribe and publish are denied.
- Connect without `--cert` and `--key` and confirm TLS rejects the client.
- Use a valid certificate with an unknown common name and confirm application
  topics are denied.

Finally, run the Gateway process and verify:

- It connects without MQTT username/password variables.
- Its client id contains the expected `principal_id`.
- It receives commands and publishes replies in its own namespace.
- It reconnects after Mosquitto restarts.
- No current message schema or topic suffix changes.

## Coordinated Cutover

1. Back up the current Mosquitto config, ACL, compose file, password file, and
   Gateway environment.
2. Generate and install every Gateway certificate before stopping services.
3. Confirm all Gateway owners completed the readiness checklist.
4. Stop Gateway clients and the production MQTT/Cloud stack.
5. Deploy the certificate-identity broker config, generated ACL, and Cloud
   certificate environment.
6. Start Mosquitto and Cloud.
7. Start each updated Gateway one at a time.
8. Run the positive and negative smoke tests.
9. Reopen normal operations only after namespace isolation is confirmed.

Use a coordinated short-downtime cutover. Do not create a temporary plaintext
or password listener for migration.

## Rollback

Rollback remains available during the first cutover because legacy password
material is retained but not mounted or regenerated.

1. Stop the updated Gateway clients and production stack.
2. Restore the backed-up Mosquitto config, ACL, compose file, and password
   file.
3. Restore the previous Gateway environment and authentication settings.
4. Restart the previous broker, Cloud, and Gateway versions.
5. Confirm command and reporting flow on the previous configuration.

Do not delete the new Gateway private keys during rollback. Protect them for a
later coordinated retry or rotate the affected principal if key exposure is
suspected.

## Principal Replacement

Certificate revocation currently uses principal replacement:

1. Generate a new local private key and CSR with a new `principal_id`.
2. Add the new inventory row and remove the old row.
3. Regenerate certificates and the production ACL.
4. Install the new certificate and update Gateway configuration.
5. Restart or reload the broker and Gateway.
6. Confirm the old principal no longer has topic permissions.
