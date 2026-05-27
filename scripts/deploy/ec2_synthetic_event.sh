#!/usr/bin/env bash
# Phase G — publish a synthetic automation event as `gateway` user, from
# inside the EC2 sb-mosquitto container (which holds the broker creds).
# Verifies the deployed cloud `_handle_automation_event` end-to-end without
# needing the user to type a real password.
#
# Run in a regular terminal (not Claude Code).

set -euo pipefail
KEY=/home/phu/Downloads/2110.pem
HOST=ubuntu@98.83.4.87
SSH="ssh -i $KEY -o StrictHostKeyChecking=no $HOST"

# Use the F_ID created in Phase F if available locally, else require arg.
F_ID="${1:-}"
if [ -z "$F_ID" ]; then
  F_ID=$(cat /home/phu/Desktop/Repos/zigbee-ble-orchestration-platform/evidence/automation_phase4_ec2_cloud/_f_id.txt 2>/dev/null || echo "")
fi
if [ -z "$F_ID" ]; then
  echo "Usage: $0 <automation_id>" >&2
  exit 1
fi
echo "Publishing synthetic event for automation_id=$F_ID"

TS=$(date +%s%3N)

# Use docker exec to run mosquitto_pub from inside the broker container.
# Broker creds: gateway user (full ACL). The container has both the
# mosquitto client binaries AND access to the credential file. We avoid
# echoing the password by piping it via env on the docker exec — but
# even simpler: connect over localhost (the broker container itself)
# and authenticate as gateway. The password value still appears in the
# docker exec command line. To avoid that, use BROKER_PASS env from
# the operator's local shell.
: "${BROKER_USER:?BROKER_USER env var must be set (e.g. gateway)}"
: "${BROKER_PASS:?BROKER_PASS env var must be set}"

# Publish from EC2 host directly to the broker (gateway user has writeACL).
$SSH BROKER_USER="$BROKER_USER" BROKER_PASS="$BROKER_PASS" F_ID="$F_ID" TS="$TS" bash -s <<'REMOTE'
set -eu
docker exec -e BROKER_USER -e BROKER_PASS -e F_ID -e TS sb-mosquitto \
  sh -lc 'mosquitto_pub -h localhost -p 1883 -u "$BROKER_USER" -P "$BROKER_PASS" -q 1 \
    -t "sb/v1/hust/lab01/gw-ubuntu-01/automations/$F_ID/event" \
    -m "{\"schema\":\"sb.v1\",\"msg_id\":\"synthetic-event-01\",\"ts\":$TS,\"tenant_id\":\"hust\",\"site_id\":\"lab01\",\"gateway_id\":\"gw-ubuntu-01\",\"source\":\"gateway\",\"correlation_id\":\"auto_$F_ID\",\"payload\":{\"automation_id\":\"$F_ID\",\"event\":\"rule_fired\",\"run_id\":\"run_synthetic_01\",\"version\":1,\"trigger\":{\"device_id\":\"0000000000000053\",\"event\":\"occupancy_changed\",\"occupancy\":\"occupied\"},\"actions\":[{\"device_id\":\"000000000000004F\",\"command\":\"on\",\"status\":\"executed\",\"reason\":null,\"command_id\":null}],\"status\":\"executed\",\"last_error\":null}}"' \
  && echo "  synthetic event published"
sleep 2
echo "--- cloud-api log tail (last 10 lines mentioning automation/event) ---"
docker logs --since 30s sb-cloud-api 2>&1 | grep -iE "automation|event" | tail -10
REMOTE

echo ""
echo "--- verify Cloud DB: last_run_status should now be 'executed' ---"
curl -sS --max-time 5 "http://98.83.4.87:8000/api/automations/$F_ID" \
  | python3 -c "import json,sys
d=json.load(sys.stdin)
print(f'  last_run_status: {d.get(\"last_run_status\")}')
print(f'  last_error:      {d.get(\"last_error\")}')"

echo ""
echo "--- verify Cloud Event Center: automation_rule_fired row present ---"
curl -sS --max-time 5 "http://98.83.4.87:8000/api/events/?limit=5" \
  | python3 -c "import json,sys
rows=json.load(sys.stdin)
auto_rows = [r for r in rows if 'automation' in (r.get('event_type') or '').lower()]
print(f'  total rows: {len(rows)}, automation rows: {len(auto_rows)}')
for r in auto_rows[:3]:
    print(f'    type={r.get(\"event_type\")} occurred_at={r.get(\"occurred_at\")} run_id={(r.get(\"payload\") or {}).get(\"run_id\")}')"
