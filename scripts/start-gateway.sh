#!/usr/bin/env bash
# Persistent start path for Z3Gateway host on the dev box.
#
# Mirrors the documented launch sequence in docs/instruct.md §G with two
# automation env vars pinned to the values we want from now on:
#
#   SB_AUTOMATION_SWITCH_HOOK=1  — cloud-pushed automation rules drive the
#                                  switch → light path. AUTO init log must
#                                  show skip_switch:false, hook:true.
#   SB_RULES_SWITCH_TO_LIGHT=0   — legacy hardcoded relay stays off. RULE
#                                  engine init log must show
#                                  switch_to_light_relay:false.
#
# Why a script (and not just docs): the env-var combo is now load-bearing
# for switch-to-light behavior. Drift here = silent dead-toggle.
#
# Stop first per §G:
#   kill "$(cat /tmp/z3gw.pid)" 2>/dev/null
#   while fuser /dev/ttyACM0 >/dev/null 2>&1; do sleep 1; done
#
# Usage:
#   scripts/start-gateway.sh                  # uses defaults below
#   SB_DEBUG_VERBOSE=1 scripts/start-gateway.sh   # extra debug logs
set -eu

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$REPO_ROOT/gateway/Z3Gateway/Z3GatewayHost/build/debug/Z3Gateway"
UART="${UART:-/dev/ttyACM0}"
BAUD="${BAUD:-115200}"
LOG="${LOG:-/tmp/z3gw.log}"
PIDFILE="${PIDFILE:-/tmp/z3gw.pid}"

# MQTT — match docs/instruct.md §G dev defaults.
export SB_MQTT_HOST="${SB_MQTT_HOST:-localhost}"
export SB_MQTT_PORT="${SB_MQTT_PORT:-1883}"
export SB_MQTT_USERNAME="${SB_MQTT_USERNAME:-gateway}"
export SB_MQTT_PASSWORD="${SB_MQTT_PASSWORD:-gateway123}"

# Automation routing: cloud rules own switch → light. Legacy relay off.
export SB_AUTOMATION_SWITCH_HOOK="${SB_AUTOMATION_SWITCH_HOOK:-1}"
export SB_RULES_SWITCH_TO_LIGHT="${SB_RULES_SWITCH_TO_LIGHT:-0}"

# Pass through optional debug.
[ -n "${SB_DEBUG_VERBOSE:-}" ] && export SB_DEBUG_VERBOSE
[ -n "${SB_AUTOMATION_EXECUTE:-}" ] && export SB_AUTOMATION_EXECUTE

if [ ! -x "$BIN" ]; then
  echo "ERROR: gateway binary not found or not executable: $BIN" >&2
  exit 1
fi
if fuser "$UART" >/dev/null 2>&1; then
  echo "ERROR: $UART is held by another process. Stop the current gateway first:" >&2
  echo "  kill \"\$(cat $PIDFILE)\" 2>/dev/null" >&2
  echo "  while fuser $UART >/dev/null 2>&1; do sleep 1; done" >&2
  exit 1
fi

# sleep infinity provides a never-EOF stdin to sl_iostream — see docs/instruct.md §G.
cd "$(dirname "$BIN")"
( sleep infinity | "$BIN" -p "$UART" -b "$BAUD" >"$LOG" 2>&1 ) &
disown

# Capture the gateway PID (the subshell's PID is the leftmost in the pipe).
sleep 1
GW_PID="$(pgrep -fx "$BIN -p $UART -b $BAUD" || true)"
if [ -z "$GW_PID" ]; then
  echo "ERROR: gateway did not start; tail $LOG for details" >&2
  exit 1
fi
echo "$GW_PID" >"$PIDFILE"
echo "gateway pid=$GW_PID log=$LOG pidfile=$PIDFILE"
