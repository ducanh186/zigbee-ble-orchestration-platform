#!/usr/bin/env bash
# EC2 cloud automation MQTT contract patch — operator-runnable.
#
# Run this in a regular terminal (gnome-terminal / Konsole / tmux pane —
# NOT through Claude Code) so the harness's per-action approval gates
# don't apply. The script is fully idempotent except for the final
# docker restart, which always runs.
#
# Prerequisites:
#   * SSH key at /home/phu/Downloads/2110.pem accessible
#   * Working tree at /home/phu/Desktop/Repos/zigbee-ble-orchestration-platform
#   * Backup directory already exists from prior session at
#     /home/ubuntu/iot-platform/backups/cloud_automation_patch_20260517_183842/
#
# Output is verbose by design — operator should review each step.

set -euo pipefail

REPO=/home/phu/Desktop/Repos/zigbee-ble-orchestration-platform
KEY=/home/phu/Downloads/2110.pem
HOST=ubuntu@98.83.4.87

SSH="ssh -i $KEY -o StrictHostKeyChecking=no $HOST"
SCP="scp -i $KEY -o StrictHostKeyChecking=no"

echo "════════════════════════════════════════════════════════════════════"
echo " Step 1/4 — SCP working-tree cloud files to EC2 staging"
echo "════════════════════════════════════════════════════════════════════"
$SSH 'mkdir -p /tmp/cloud_patch && rm -f /tmp/cloud_patch/*'
$SCP "$REPO/cloud/app/mqtt_client.py" \
     "$REPO/cloud/app/schemas.py" \
     "$REPO/cloud/app/models.py" \
     "$REPO/cloud/app/database.py" \
     "$REPO/cloud/app/automation_sync.py" \
     "${HOST}:/tmp/cloud_patch/"
$SCP "$REPO/cloud/app/routers/automations.py" \
     "${HOST}:/tmp/cloud_patch/routers_automations.py"
echo "Staged files on EC2:"
$SSH 'ls -la /tmp/cloud_patch/'

echo ""
echo "════════════════════════════════════════════════════════════════════"
echo " Step 2/4 — docker cp INTO sb-cloud-api container + py_compile"
echo "════════════════════════════════════════════════════════════════════"
$SSH 'for f in mqtt_client.py schemas.py models.py database.py automation_sync.py; do
    docker cp /tmp/cloud_patch/$f sb-cloud-api:/app/cloud/app/$f
    echo "  copied $f"
done
docker cp /tmp/cloud_patch/routers_automations.py sb-cloud-api:/app/cloud/app/routers/automations.py
echo "  copied routers/automations.py"
echo ""
echo "Syntax check:"
docker exec sb-cloud-api python -c "import py_compile
for p in [
    \"/app/cloud/app/mqtt_client.py\",
    \"/app/cloud/app/routers/automations.py\",
    \"/app/cloud/app/schemas.py\",
    \"/app/cloud/app/models.py\",
    \"/app/cloud/app/database.py\",
    \"/app/cloud/app/automation_sync.py\",
]:
    py_compile.compile(p, doraise=True)
    print(\"  ok\", p)
print(\"syntax-ok\")"'

echo ""
echo "════════════════════════════════════════════════════════════════════"
echo " Step 3/4 — restart sb-cloud-api"
echo "════════════════════════════════════════════════════════════════════"
$SSH 'docker restart sb-cloud-api'
echo "  waiting 6s for app to come up..."
sleep 6

echo ""
echo "════════════════════════════════════════════════════════════════════"
echo " Step 4/4 — health probe + container log tail"
echo "════════════════════════════════════════════════════════════════════"
HEALTH_BODY_FILE=$(mktemp -t cloud_health.XXXXXX)
HEALTH=$(curl -sS -o "$HEALTH_BODY_FILE" --max-time 5 -w '%{http_code}' http://98.83.4.87:8000/health || echo curl_failed)
echo "  GET /health → HTTP $HEALTH"
if [ -s "$HEALTH_BODY_FILE" ]; then
  echo -n "  body: "
  cat "$HEALTH_BODY_FILE"; echo
fi
rm -f "$HEALTH_BODY_FILE"
if [ "$HEALTH" != "200" ]; then
  echo "  ❌ /health returned $HEALTH — aborting before further probes."
  exit 1
fi
echo ""
echo "  /api/automations sample (looking for 'version' field):"
curl -sS --max-time 5 http://98.83.4.87:8000/api/automations \
  | python3 -c "import json,sys
rows = json.load(sys.stdin)
print(f'    total rules: {len(rows)}')
if rows:
    print(f'    has version: {\"version\" in rows[0]}')
    print(f'    sample sync_status: {rows[0].get(\"sync_status\")}')"
echo ""
echo "  last 25 lines of sb-cloud-api log:"
$SSH 'docker logs --tail 25 sb-cloud-api 2>&1 | sed "s/^/    /"'

echo ""
echo "════════════════════════════════════════════════════════════════════"
echo " DONE — report back the output to the agent for Phase F/G/H."
echo "════════════════════════════════════════════════════════════════════"
echo ""
echo "If anything failed, rollback procedure is in"
echo "  evidence/automation_phase4_ec2_cloud/01_backup.md"
echo "Backup directory on EC2:"
echo "  /home/ubuntu/iot-platform/backups/cloud_automation_patch_20260517_183842/"
