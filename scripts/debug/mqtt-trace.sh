#!/usr/bin/env bash
# TEMP DEBUG - REMOVE AFTER BUGFIX
# Live-subscribe to every topic relevant to cloud <-> gateway <-> device flow.
# Uses read-only 'monitor' credentials. Ctrl-C to stop.

set -u

BROKER_HOST="${BROKER_HOST:-localhost}"
BROKER_PORT="${BROKER_PORT:-1883}"
MON_USER="${MON_USER:-monitor}"
MON_PASS="${MON_PASS:-monitor123}"

PREFIX="sb/v1/hust/lab01/gw-ubuntu-01"

# -v prints "<topic> <payload>" per line
exec mosquitto_sub \
  -h "$BROKER_HOST" -p "$BROKER_PORT" \
  -u "$MON_USER" -P "$MON_PASS" \
  -v \
  -t "$PREFIX/commands/+/request" \
  -t "$PREFIX/commands/+/reply" \
  -t "$PREFIX/devices/+/+/reported" \
  -t "$PREFIX/devices/+/+/desired" \
  -t "$PREFIX/devices/+/+/event" \
  -t "$PREFIX/gateway/+"
