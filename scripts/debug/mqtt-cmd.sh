#!/usr/bin/env bash
# TEMP DEBUG - REMOVE AFTER BUGFIX
# Publish a cloud-style command straight to MQTT (bypasses the FastAPI
# REST layer and the translation in cloud/app/schemas.py). This lets us
# verify the gateway side in isolation.
#
# Usage:
#   ./mqtt-cmd.sh on
#   ./mqtt-cmd.sh off
#   ./mqtt-cmd.sh set_level 128
#
# Target is hardcoded to the current light under test
# (device_id = EUI64 000000000000004F, endpoint 1).

set -euo pipefail

BROKER_HOST="${BROKER_HOST:-localhost}"
BROKER_PORT="${BROKER_PORT:-1883}"
# Use cloud/backend credentials. Monitor is read-only and can't publish.
CLI_USER="${CLI_USER:-client}"
CLI_PASS="${CLI_PASS:-client123}"

PREFIX="sb/v1/hust/lab01/gw-ubuntu-01"
DEVICE_ID="000000000000004F"

action="${1:-on}"
case "$action" in
  on|off)
    cluster="0x0006"
    command="$action"
    extra=""
    ;;
  set_level)
    level="${2:-128}"
    cluster="0x0008"
    command="set_level"
    extra=",\"level\":$level"
    ;;
  *)
    echo "unknown action: $action" >&2
    echo "usage: $0 {on|off|set_level [0-254]}" >&2
    exit 1
    ;;
esac

cmd_id="dbg-$(date +%s%N)"
topic="$PREFIX/commands/$cmd_id/request"
ts="$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)"

payload=$(cat <<JSON
{"schema":"sb.v1","msg_id":"$cmd_id","ts":"$ts","tenant_id":"hust","site_id":"lab01","gateway_id":"gw-ubuntu-01","source":"debug-script","payload":{"command_id":"$cmd_id","device_id":"$DEVICE_ID","device_type":"light","op":"device.command","target":{"endpoint":1,"cluster_id":"$cluster","command":"$command"$extra},"timeout_ms":5000}}
JSON
)

echo "publishing to: $topic"
echo "payload: $payload"
mosquitto_pub \
  -h "$BROKER_HOST" -p "$BROKER_PORT" \
  -u "$CLI_USER" -P "$CLI_PASS" \
  -q 1 \
  -t "$topic" \
  -m "$payload"
echo "(waiting 2 s for reply trace...)"
sleep 2
