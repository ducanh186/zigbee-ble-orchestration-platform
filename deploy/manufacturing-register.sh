#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage:
  manufacturing-register.sh \
    --eui64 EUI64 \
    --install-code INSTALL_CODE \
    --device-type light|switch|motion \
    [--model MODEL] \
    [--output-directory PATH] \
    [--api-base-url URL]

Required environment:
  SB_MANUFACTURING_ACCESS_TOKEN

Optional environment:
  SB_API_BASE_URL (default: https://dashboard.iot-building.app)
EOF
}

fail() {
  printf 'Manufacturing registration failed: %s\n' "$1" >&2
  exit 1
}

eui64=""
install_code=""
device_type=""
model=""
output_directory=""
api_base_url="${SB_API_BASE_URL:-https://dashboard.iot-building.app}"

while (($# > 0)); do
  case "$1" in
    --eui64)
      (($# >= 2)) || fail "Missing value for --eui64."
      eui64="$2"
      shift 2
      ;;
    --install-code)
      (($# >= 2)) || fail "Missing value for --install-code."
      install_code="$2"
      shift 2
      ;;
    --device-type)
      (($# >= 2)) || fail "Missing value for --device-type."
      device_type="$2"
      shift 2
      ;;
    --model)
      (($# >= 2)) || fail "Missing value for --model."
      model="$2"
      shift 2
      ;;
    --output-directory)
      (($# >= 2)) || fail "Missing value for --output-directory."
      output_directory="$2"
      shift 2
      ;;
    --api-base-url)
      (($# >= 2)) || fail "Missing value for --api-base-url."
      api_base_url="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      fail "Unknown argument."
      ;;
  esac
done

access_token="${SB_MANUFACTURING_ACCESS_TOKEN:-}"
[[ -n "$access_token" ]] || fail "SB_MANUFACTURING_ACCESS_TOKEN is required."
[[ -n "$eui64" ]] || fail "--eui64 is required."
[[ -n "$install_code" ]] || fail "--install-code is required."
[[ -n "$device_type" ]] || fail "--device-type is required."

eui64="${eui64^^}"
install_code="${install_code^^}"
[[ "$eui64" =~ ^[0-9A-F]{16}$ ]] ||
  fail "EUI64 must be exactly 16 hexadecimal characters."
[[ "$install_code" =~ ^[0-9A-F]+$ ]] ||
  fail "Install Code must be hexadecimal with a supported Zigbee length."
case "${#install_code}" in
  16|20|28|36) ;;
  *) fail "Install Code must be hexadecimal with a supported Zigbee length." ;;
esac
case "$device_type" in
  light|switch|motion) ;;
  *) fail "Device type must be light, switch, or motion." ;;
esac

[[ "$access_token" != *$'\n'* && "$access_token" != *$'\r'* && "$access_token" != *'"'* ]] ||
  fail "Access token contains unsupported characters."
[[ "$api_base_url" != *$'\n'* && "$api_base_url" != *$'\r'* && "$api_base_url" != *'"'* ]] ||
  fail "API base URL contains unsupported characters."

api_base_url="${api_base_url%/}"
if [[ -z "$output_directory" ]]; then
  output_directory="$PWD/manufacturing-output/$eui64"
fi
payload_path="$output_directory/payload.json"
label_path="$output_directory/label.svg"
[[ ! -e "$payload_path" && ! -e "$label_path" ]] ||
  fail "Output files already exist. Choose a new output directory."

command -v curl >/dev/null 2>&1 || fail "curl is required."
command -v python3 >/dev/null 2>&1 || fail "python3 is required."

temp_directory="$(mktemp -d)"
chmod 700 "$temp_directory"
cleanup() {
  rm -rf -- "$temp_directory"
}
trap cleanup EXIT

factory_request="$temp_directory/factory-request.json"
factory_response="$temp_directory/factory-response.json"
factory_config="$temp_directory/factory-curl.conf"
label_request="$temp_directory/label-request.json"
label_response="$temp_directory/label-response.json"
label_config="$temp_directory/label-curl.conf"
: >"$factory_request"
: >"$factory_response"
: >"$factory_config"
: >"$label_request"
: >"$label_response"
: >"$label_config"
chmod 600 "$factory_request" "$factory_response" "$factory_config" \
  "$label_request" "$label_response" "$label_config"

export SB_MFG_EUI64="$eui64"
export SB_MFG_INSTALL_CODE="$install_code"
export SB_MFG_DEVICE_TYPE="$device_type"
export SB_MFG_MODEL="$model"
python3 - "$factory_request" <<'PY'
import json
import os
import sys

body = {
    "eui64": os.environ["SB_MFG_EUI64"],
    "install_code": os.environ["SB_MFG_INSTALL_CODE"],
    "device_type": os.environ["SB_MFG_DEVICE_TYPE"],
}
model = os.environ.get("SB_MFG_MODEL", "").strip()
if model:
    body["model"] = model
with open(sys.argv[1], "w", encoding="utf-8") as stream:
    json.dump(body, stream, separators=(",", ":"))
PY
unset SB_MFG_INSTALL_CODE SB_MFG_MODEL

cat >"$factory_config" <<EOF
silent
show-error
header = "Authorization: Bearer $access_token"
header = "Content-Type: application/json"
request = "POST"
data-binary = "@-"
url = "$api_base_url/api/provisioning/factory-devices"
EOF

factory_status="$(
  curl \
    --config "$factory_config" \
    --output "$factory_response" \
    --write-out '%{http_code}' <"$factory_request" ||
    true
)"
[[ "$factory_status" =~ ^2[0-9][0-9]$ ]] ||
  fail "Factory registration failed (HTTP ${factory_status:-unknown})."

export SB_MFG_FACTORY_RESPONSE="$factory_response"
python3 <<'PY' ||
import json
import os

with open(os.environ["SB_MFG_FACTORY_RESPONSE"], encoding="utf-8") as stream:
    response = json.load(stream)
if response.get("has_install_code") is not True:
    raise SystemExit(1)
PY
  fail "Factory registration did not confirm Install Code storage."
unset SB_MFG_FACTORY_RESPONSE

export SB_MFG_DEVICE_TYPE="$device_type"
python3 - "$label_request" <<'PY'
import json
import os
import sys

body = {
    "eui64": os.environ["SB_MFG_EUI64"],
    "device_type": os.environ["SB_MFG_DEVICE_TYPE"],
}
with open(sys.argv[1], "w", encoding="utf-8") as stream:
    json.dump(body, stream, separators=(",", ":"))
PY

cat >"$label_config" <<EOF
silent
show-error
header = "Authorization: Bearer $access_token"
header = "Content-Type: application/json"
request = "POST"
data-binary = "@-"
url = "$api_base_url/api/provisioning/labels"
EOF

label_status="$(
  curl \
    --config "$label_config" \
    --output "$label_response" \
    --write-out '%{http_code}' <"$label_request" ||
    true
)"
[[ "$label_status" =~ ^2[0-9][0-9]$ ]] ||
  fail "Public label creation failed (HTTP ${label_status:-unknown})."

mkdir -p -- "$output_directory"
export SB_MFG_LABEL_RESPONSE="$label_response"
export SB_MFG_PAYLOAD_PATH="$payload_path"
export SB_MFG_LABEL_PATH="$label_path"
python3 <<'PY' ||
import json
import os

with open(os.environ["SB_MFG_LABEL_RESPONSE"], encoding="utf-8") as stream:
    response = json.load(stream)

payload_json = response.get("payload_json")
qr_svg = response.get("qr_svg")
if not isinstance(payload_json, str) or not isinstance(qr_svg, str):
    raise SystemExit(1)
payload = json.loads(payload_json)
if "install_code" in payload:
    raise SystemExit(1)

with open(os.environ["SB_MFG_PAYLOAD_PATH"], "w", encoding="utf-8") as stream:
    stream.write(payload_json)
with open(os.environ["SB_MFG_LABEL_PATH"], "w", encoding="utf-8") as stream:
    stream.write(qr_svg)
PY
  fail "Public label response is invalid or contains a forbidden secret field."

printf 'Factory device registered: %s\n' "$eui64"
printf 'Public QR payload: %s\n' "$payload_path"
printf 'Public QR label: %s\n' "$label_path"
