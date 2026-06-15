#!/usr/bin/env bash
# One-time, idempotent Silicon Labs headless toolchain setup (no Studio GUI).
#
# Prepares slc-cli + GNU ARM toolchain + Gecko SDK so that
# scripts/kit.sh can build end-device kits from their .slcp without
# Simplicity Studio. Writes testing_tools/.silabs-env for kit.sh to source.
#
# Re-runnable: skips slc extraction if already present.
#
# NOTE: slc trust/configuration flag names vary across slc-cli versions.
# If a command below fails, check `~/slc_cli/slc --help`,
# `slc configuration --help`, and `slc signature --help`, then adjust and
# record the working invocation here.
set -euo pipefail

SLC_HOME="${SLC_HOME:-$HOME/slc_cli}"
SLC_ZIP="${SLC_ZIP:-$HOME/slc_cli_linux.zip}"
ARM_TOOLCHAIN="${ARM_TOOLCHAIN:-$HOME/SimplicityStudio_v5/developer/toolchains/gnu_arm/12.2.rel1_2023.7}"
COMMANDER="${COMMANDER:-$HOME/bin/commander}"

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# Full Gecko SDK 4.5.0 (must contain gecko_sdk.slcs descriptor; the per-kit
# end_devices/*/gecko_sdk_4.5.0 are thin copies without it). Override w/ SB_GECKO_SDK.
SDK="${SB_GECKO_SDK:-$HOME/SimplicityStudio/SDKs/gecko_sdk}"

# --- Extract slc-cli if needed ---
if [ ! -d "$SLC_HOME" ]; then
  echo "Extracting slc-cli from $SLC_ZIP ..."
  [ -f "$SLC_ZIP" ] || { echo "ERROR: slc-cli zip not found: $SLC_ZIP"; exit 1; }
  unzip -q "$SLC_ZIP" -d "$HOME"
fi
SLC="$SLC_HOME/slc"

# --- Sanity-check every tool ---
[ -x "$SLC" ]               || { echo "ERROR: slc not executable at $SLC"; exit 1; }
[ -d "$ARM_TOOLCHAIN/bin" ] || { echo "ERROR: GNU ARM toolchain missing: $ARM_TOOLCHAIN"; exit 1; }
[ -x "$COMMANDER" ]         || { echo "ERROR: commander missing: $COMMANDER"; exit 1; }
[ -d "$SDK" ]               || { echo "ERROR: Gecko SDK missing: $SDK (set SB_GECKO_SDK)"; exit 1; }
ls "$SDK"/*.slcs >/dev/null 2>&1 || { echo "ERROR: $SDK is not a full SDK (no *.slcs descriptor). Set SB_GECKO_SDK to a complete gecko_sdk 4.5.0."; exit 1; }

# --- slc-cli is a Java app; use the JRE bundled with Simplicity Studio ---
JRE_BIN="${JRE_BIN:-}"
if [ -z "$JRE_BIN" ]; then
  for cand in "$HOME"/SimplicityStudio_v5/jre*/bin "$HOME"/SimplicityStudio_v5/jre/bin; do
    [ -x "$cand/java" ] && { JRE_BIN="$cand"; break; }
  done
fi
[ -x "$JRE_BIN/java" ] || command -v java >/dev/null || {
  echo "ERROR: no Java for slc-cli (no Studio JRE found, none on PATH). Set JRE_BIN."; exit 1; }
[ -n "$JRE_BIN" ] && export PATH="$JRE_BIN:$PATH"

# --- slc needs the Studio adapter packs (esp. ZAP) to generate ZCL config (zap-config.h) ---
ADAPTER_PACKS="${STUDIO_ADAPTER_PACK_PATH:-$HOME/SimplicityStudio_v5/developer/adapter_packs}"
[ -d "$ADAPTER_PACKS/zap" ] || echo "WARN: ZAP adapter pack not found under $ADAPTER_PACKS — ZCL generation will fail"
export STUDIO_ADAPTER_PACK_PATH="$ADAPTER_PACKS"

# --- Make slc non-interactive: register + trust SDK and toolchain ---
"$SLC" configuration --sdk "$SDK"
"$SLC" signature trust --sdk "$SDK"
"$SLC" configuration --gcc-toolchain "$ARM_TOOLCHAIN"
# Some slc versions want the toolchain trusted explicitly; ignore if unsupported.
"$SLC" signature trust --sdk "$SDK" --extension-path "$ARM_TOOLCHAIN" 2>/dev/null || true

# --- Persist resolved paths for kit.sh ---
mkdir -p "$REPO_ROOT/testing_tools"
cat > "$REPO_ROOT/testing_tools/.silabs-env" <<ENV
SLC=$SLC
ARM_TOOLCHAIN=$ARM_TOOLCHAIN
COMMANDER=$COMMANDER
SDK=$SDK
JRE_BIN=$JRE_BIN
ADAPTER_PACKS=$ADAPTER_PACKS
ENV

echo "OK:"
echo "  slc        = $("$SLC" --version 2>&1 | head -1)"
echo "  toolchain  = $ARM_TOOLCHAIN"
echo "  sdk        = $SDK"
echo "  commander  = $("$COMMANDER" --version 2>&1 | head -1)"
echo "  env file   = $REPO_ROOT/testing_tools/.silabs-env"
